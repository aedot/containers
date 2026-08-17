"""AI summaries (SDD-003): build a DE-IDENTIFIED digest of a period (daily,
weekly, or monthly), run it through the configured LLM provider, and
store/publish a warm recap.

Privacy is enforced here: `build_digest` emits ONLY aggregate numbers and labels
(counts, sleep, trends, last temp/weight) — never a note, special note, name, or
any free text. Feed volume is the one value parsed out of a note (users log the
bottle amount as e.g. "55mL"), but only the summed number leaves this module,
never the surrounding text, so the de-identified invariant still holds.
`build_prompt` appends that digest to the (editable) instruction, so the provider
never receives identifiable data regardless of the prompt.
"""
from __future__ import annotations

import contextlib
import datetime as dt
import logging
import re
from zoneinfo import ZoneInfo

from . import display, i18n, llm

# Valid summary periods, longest window last.
PERIODS = ("daily", "weekly", "monthly")

# Bottle volume is logged as free text in the note (e.g. "55mL", "55 ml"). We
# extract only the leading number, never the rest of the note.
_ML_RE = re.compile(r"(\d+(?:\.\d+)?)\s*ml\b", re.IGNORECASE)


def _note_ml(note) -> float | None:
    """The mL figure embedded in a feed note, or None if the note has none."""
    m = _ML_RE.search(str(note or ""))
    return float(m.group(1)) if m else None


log = logging.getLogger("baby.summary")


class CapReached(Exception):
    """The local 2/day cap is already used up for today."""


def _parse(iso: str) -> dt.datetime:
    d = dt.datetime.fromisoformat(str(iso).replace("Z", "+00:00"))
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d


def _fmt(n) -> str:
    if n is None:
        return "?"
    return str(int(n)) if float(n) == int(n) else str(round(float(n), 2))


def _sleep_minutes(rows, start, end, now):
    """Minutes of sleep overlapping the [start, end) window (clips cross-midnight
    stretches so each day gets its own share). An open 'start' (currently
    sleeping) counts up to now."""
    evs = sorted((r for r in rows if r["event_type"] == "sleep"),
                 key=lambda r: _parse(r["logged_at"]))
    total = 0.0
    pending = None
    for r in evs:
        t = _parse(r["logged_at"])
        if r.get("event_subtype") == "start":
            pending = t
        elif r.get("event_subtype") == "end" and pending is not None:
            a, b = max(pending, start), min(t, end)
            if b > a:
                total += (b - a).total_seconds() / 60
            pending = None
    if pending is not None:
        a, b = max(pending, start), min(now, end)
        if b > a:
            total += (b - a).total_seconds() / 60
    return round(total)


def _hm(mins) -> str:
    return f"{int(mins) // 60}h{int(mins) % 60}m"


def _day(cfg, now: dt.datetime) -> str:
    return now.astimezone(ZoneInfo(cfg.timezone)).strftime("%Y-%m-%d")


def _local_time(cfg, now: dt.datetime) -> str:
    """Localized "<Mon D>, <h:mm AM/PM>" stamp for when the summary was generated
    (published as the retained sensor's `time` attribute, shown on the dashboard
    card). Includes the date, not just the clock, so a recap read the next day
    still says when it was made."""
    t = now.astimezone(ZoneInfo(cfg.timezone))
    h = t.hour % 12 or 12
    clock = f"{h}:{t.minute:02d} {'PM' if t.hour >= 12 else 'AM'}"
    return f"{t.strftime('%b')} {t.day}, {clock}"


def _fmt_hm(mins) -> str:
    """"Xh Ym" — same shape the stats module uses for sleep totals."""
    m = int(mins)
    return f"{m // 60}h {m % 60}m"


def _window(cfg, period: str, now: dt.datetime, daily_previous: bool = False):
    """(start, end, label, days) for the period, in the configured timezone.

      daily          -> midnight today .. now       (1 day, partial)
      daily_previous -> the whole previous calendar day — for a morning run that
                        recaps the day that just ended, not the empty new one
      weekly         -> the 7 whole days before today
      monthly        -> the previous calendar month
    """
    tz = ZoneInfo(cfg.timezone)
    now_local = now.astimezone(tz)
    today_start = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == "weekly":
        start, end = today_start - dt.timedelta(days=7), today_start
        label = (f"{start.strftime('%b %d')}–"
                 f"{(end - dt.timedelta(days=1)).strftime('%b %d')}")
        return start, end, label, 7
    if period == "monthly":
        first_this = today_start.replace(day=1)
        prev_last = first_this - dt.timedelta(days=1)   # last day of prev month
        start = prev_last.replace(day=1)
        return start, first_this, start.strftime("%B %Y"), prev_last.day
    if daily_previous:
        start = today_start - dt.timedelta(days=1)
        return start, today_start, start.strftime("%b %d"), 1
    end = now_local + dt.timedelta(minutes=1)
    return today_start, end, today_start.strftime("%b %d"), 1


def _trend(count, sleep_fn, period, start, end, cap):
    """Bucketed [{label, feeds, diapers, sleep_min}] giving the model the shape
    of the period: daily -> 3 days ending today, weekly -> its 7 days, monthly
    -> weekly buckets tiling the month."""
    out = []
    if period == "monthly":
        b = start
        while b < end:
            be = min(b + dt.timedelta(days=7), end)
            out.append({"label": b.strftime("%b %d"), "feeds": count("feed", b, be),
                        "diapers": count("diaper", b, be), "sleep_min": sleep_fn(b, be)})
            b = be
        return out
    if period == "weekly":
        first, n = start, 7
    else:  # daily: 3 days ending on the window's day (handles the yesterday
        # window too, via end-1min), with 2 look-back days for context
        first, n = (end - dt.timedelta(minutes=1)).replace(
            hour=0, minute=0, second=0, microsecond=0) - dt.timedelta(days=2), 3
    for i in range(n):
        d0 = first + dt.timedelta(days=i)
        d1 = min(d0 + dt.timedelta(days=1), cap)
        out.append({"label": d0.strftime("%b %d"), "feeds": count("feed", d0, d1),
                    "diapers": count("diaper", d0, d1), "sleep_min": sleep_fn(d0, d1)})
    return out


async def build_digest(db, cfg, now: dt.datetime | None = None,
                       period: str = "daily", daily_previous: bool = False) -> dict:
    """De-identified aggregate digest for the LLM over `period`. Numbers only,
    no free text. Keys are named `*_today` for continuity with the daily path,
    but hold the period total; `label`/`days`/`period`/`frame` carry the scope.
    `daily_previous` shifts the daily window to the whole previous day."""
    tz = ZoneInfo(cfg.timezone)
    now = now or dt.datetime.now(dt.timezone.utc)
    start, end, label, days = _window(cfg, period, now, daily_previous)

    # The daily path keeps its cheap fixed LIMIT; longer periods fetch by range
    # (one extra look-back day so the daily trend's context days are covered).
    if period == "daily":
        rows = await db.recent(500)
    else:
        since = (start - dt.timedelta(days=1)).astimezone(dt.timezone.utc).isoformat()
        rows = await db.recent_since(since)

    def local(r):
        return _parse(r["logged_at"]).astimezone(tz)

    def count(etype, a, b, sub=None):
        return sum(1 for r in rows if r["event_type"] == etype
                   and a <= local(r) < b
                   and (sub is None or r.get("event_subtype") == sub))

    # feed subtype breakdown over the window
    feed_breakdown = {s: count("feed", start, end, s)
                      for s in ("breast", "bottle", "solid")}

    # total feed volume (mL) over the window, parsed from the "NNmL" note; only
    # the summed number is kept, never the note text.
    feed_volume_ml = 0.0
    for r in rows:
        if r["event_type"] == "feed" and start <= local(r) < end:
            ml = _note_ml(r.get("note"))
            if ml is not None:
                feed_volume_ml += ml

    # diaper subtype breakdown over the window (pee / poop / both / change)
    diaper_breakdown = {s: count("diaper", start, end, s)
                        for s in ("pee", "poop", "both", "change")}

    # currently sleeping = the latest sleep event in range is an unmatched start.
    # Only meaningful for the LIVE today window (end == now); a yesterday, weekly,
    # or monthly window ends in the past, so "currently sleeping" would be a stale
    # claim — force it False there rather than report a past midnight sleep as "now".
    sleep_evs = sorted((r for r in rows if r["event_type"] == "sleep"
                        and local(r) < end), key=lambda r: _parse(r["logged_at"]))
    is_sleeping = (period == "daily" and not daily_previous and bool(sleep_evs)
                   and sleep_evs[-1].get("event_subtype") == "start")

    trend = _trend(count, lambda a, b: _sleep_minutes(rows, a, b, now),
                   period, start, end, end)

    # average feed gap over the window (minutes)
    feed_ts = sorted(local(r).timestamp() for r in rows
                     if r["event_type"] == "feed" and start <= local(r) < end)
    avg_feed_gap = None
    if len(feed_ts) >= 2:
        gaps = [(feed_ts[i + 1] - feed_ts[i]) / 60.0 for i in range(len(feed_ts) - 1)]
        avg_feed_gap = round(sum(gaps) / len(gaps), 1)

    # last temperature (+ fever)
    last_temp = None
    for r in rows:
        if r.get("event_type") == "temperature" and r.get("value") is not None:
            v, u = r["value"], (r.get("value_unit") or "")
            c = (v - 32) * 5 / 9 if "F" in u else v
            last_temp = {"value": v, "unit": u, "fever": c >= cfg.fever_threshold_c}
            break

    # latest growth metric + delta
    growth = {}
    for m in ("weight", "length", "head_circumference"):
        series = await db.metric_series(m, 5)
        if series:
            last = series[-1]
            delta = round(last["value"] - series[-2]["value"], 2) if len(series) >= 2 else None
            growth[m] = {"value": last["value"], "unit": last.get("value_unit"), "delta": delta}

    # `span` = the descriptive window for the prompt; `frame` = the short phrase
    # the recap should use ("today"/"yesterday"/"last week"/"last month").
    if period == "daily":
        span = frame = "yesterday" if daily_previous else "today"
    elif period == "weekly":
        span, frame = "the last 7 days", "last week"
    else:  # monthly
        span, frame = "the previous calendar month", "last month"

    return {
        "period": period,
        "label": label,
        "days": days,
        "span": span,
        "frame": frame,
        "feeds_today": count("feed", start, end),
        "feeds_by": feed_breakdown,
        "feed_volume_ml": round(feed_volume_ml) or None,
        "trend": trend,
        "avg_feed_gap_min": avg_feed_gap,
        "diapers_today": count("diaper", start, end),
        "diapers_by": diaper_breakdown,
        "sleep_today": _fmt_hm(_sleep_minutes(rows, start, end, now)),
        "is_sleeping": is_sleeping,
        "pumps_today": count("pump", start, end),
        "baths_today": count("bath", start, end),
        "tummy_today": count("tummy_time", start, end),
        "medicines_today": count("medicine", start, end),
        "contractions_today": count("contraction", start, end),
        "last_temp": last_temp,
        "growth": growth,
    }


def render_digest(d: dict) -> str:
    daily = d.get("period", "daily") == "daily"
    when = d.get("frame", "today") if daily else f"over {d.get('label', '')}"
    days = d.get("days", 1) or 1

    def avg(n):
        return "" if daily else f" (avg {round(n / days)}/day)"

    lines = []
    fb = d["feeds_by"]
    parts = [f"{k} {v}" for k, v in fb.items() if v]
    lines.append(f"Feeds {when}: {d['feeds_today']}{avg(d['feeds_today'])}"
                 + (f" ({', '.join(parts)})" if parts else ""))
    if d.get("feed_volume_ml"):
        lines.append(f"Total feed volume {when}: {d['feed_volume_ml']} mL")
    if d["avg_feed_gap_min"] is not None:
        lines.append(f"Average gap between feeds {when}: {d['avg_feed_gap_min']} min")
    db_ = d.get("diapers_by") or {}
    dparts = [f"{k} {v}" for k, v in db_.items() if v]
    lines.append(f"Diapers {when}: {d['diapers_today']}{avg(d['diapers_today'])}"
                 + (f" ({', '.join(dparts)})" if dparts else ""))
    lines.append(f"Sleep {when}: {d['sleep_today']}"
                 + (" (currently sleeping)" if d["is_sleeping"] else ""))
    lines.append(f"Pumps {d['pumps_today']}, baths {d['baths_today']}, "
                 f"tummy time {d['tummy_today']}, medicines {d['medicines_today']}")
    if d["contractions_today"]:
        lines.append(f"Contractions {when}: {d['contractions_today']}")
    if d["last_temp"]:
        t = d["last_temp"]
        lines.append(f"Last temperature: {_fmt(t['value'])} {t['unit']}"
                     + (" (FEVER)" if t["fever"] else ""))
    labels = {"weight": "Weight", "length": "Length", "head_circumference": "Head"}
    for k, g in d["growth"].items():
        delta = f" (change {'+' if (g['delta'] or 0) >= 0 else ''}{_fmt(g['delta'])} {g['unit']})" \
            if g["delta"] is not None else ""
        lines.append(f"{labels[k]}: {_fmt(g['value'])} {g['unit']}{delta}")
    if d.get("trend"):
        trend = ", ".join(f"{x['label']} {x['feeds']}f/{x['diapers']}d/{_hm(x['sleep_min'])}"
                          for x in d["trend"])
        lines.append(f"Trend (feeds/diapers/sleep): {trend}")
    return "\n".join(lines)


def stats_footer(cfg, digest: dict) -> str:
    """Deterministic tally of the day's headline numbers, appended to the recap
    so the exact counts ALWAYS appear regardless of whether the LLM echoes them.

    Built from the same de-identified digest, localized to the device language
    (same as the recap) via the shared catalog, with zero/empty categories
    dropped. Returns "" when there is nothing to show, so a quiet day appends
    no footer at all."""
    lang = display.device_lang(cfg)
    dd = getattr(cfg, "data_dir", None)
    daily = digest.get("period", "daily") == "daily"
    days = digest.get("days", 1) or 1

    def L(key: str, **v) -> str:
        return i18n.t(key, lang, dd, **v)

    def avg(total) -> str:
        """" (avg N/day)" for a multi-day period, "" for the daily digest."""
        return "" if daily else f" ({L('sum.avgPerDay', n=round(total / days))})"

    def tally(total, by: dict, order) -> str:
        """"<total>[ (avg N/day)] (<label n> · <label n>)", 0s dropped."""
        parts = [f"{L('btn.' + k)} {by[k]}" for k in order if by.get(k)]
        return f"{total}{avg(total)}" + (f" ({' · '.join(parts)})" if parts else "")

    lines = []
    if digest.get("feeds_today"):
        feed = (f"🍼 {L('group.feed')} "
                + tally(digest["feeds_today"], digest.get("feeds_by") or {},
                        ("breast", "bottle", "solid")))
        if digest.get("feed_volume_ml"):
            feed += f" · {digest['feed_volume_ml']} mL"
        lines.append(feed)
    if digest.get("diapers_today"):
        lines.append(f"🚼 {L('group.diaper')} "
                     + tally(digest["diapers_today"], digest.get("diapers_by") or {},
                             ("pee", "poop", "both", "change")))
    if digest.get("sleep_today"):
        sleep = f"😴 {L('journal.sleep')} {digest['sleep_today']}"
        if digest.get("is_sleeping"):
            sleep += f" ({L('sum.asleep')})"
        lines.append(sleep)
    # Secondary counts on one line, each shown only when non-zero.
    extra = [("stat.pumps", digest.get("pumps_today")),
             ("stat.baths", digest.get("baths_today")),
             ("stat.tummy", digest.get("tummy_today")),
             ("stat.meds", digest.get("medicines_today")),
             ("stat.contractions", digest.get("contractions_today"))]
    ep = [f"{L(k)} {n}" for k, n in extra if n]
    if ep:
        lines.append("• " + " · ".join(ep))
    return "\n".join(lines)


def build_prompt(cfg, digest: dict) -> str:
    """The instruction, a timeframe line, the (optional) output-language line,
    then the digest.

    The extra lines are APPENDED, never substituted, so the configured prompt
    body survives untouched — including its "do not use em-dashes" instruction,
    which measurably changes the output. The timeframe line anchors the recap to
    the digest's `frame` (today / yesterday / last week / last month) so the model
    names the right period instead of always saying "today".
    """
    prompt = cfg.summary_prompt
    lang = display.device_lang(cfg)
    period = digest.get("period", "daily")
    span, frame = digest.get("span", "today"), digest.get("frame", "today")
    line = f'This recap covers {span}; refer to that timeframe as "{frame}"'
    if frame != "today":
        line += ', never "today"'
    if period != "daily":
        line += ", and describe the trends across the whole period rather than a single day"
    prompt = f"{prompt}\n{line}."
    if lang != "en":
        prompt = f"{prompt}\nRespond in {i18n.english_name(lang)}."
    return f"{prompt}\n\nRecent activity:\n{render_digest(digest)}"


def _alert_title(cfg, period: str) -> str:
    """Localized notification title for the period (daily/weekly/monthly)."""
    key = {"weekly": "alert.summaryWeekly",
           "monthly": "alert.summaryMonthly"}.get(period, "alert.summaryDaily")
    return i18n.t(key, display.device_lang(cfg), getattr(cfg, "data_dir", None))


async def generate(db, cfg, mqtt=None, install_token: str | None = None,
                   source: str = "manual", now: dt.datetime | None = None,
                   period: str = "daily") -> dict | None:
    """Run one summary for `period` (daily/weekly/monthly). Returns the stored
    row, or None when disabled.

    Raises `CapReached` when the local daily cap is used up (daily only), or
    `llm.CapError` / `llm.ProviderError` on provider issues (the caller maps
    these to responses).
    """
    if not cfg.summary_enabled:
        return None
    now = now or dt.datetime.now(dt.timezone.utc)
    day = _day(cfg, now)
    # The 2/day cap guards the on-demand daily digest; the scheduled weekly and
    # monthly recaps fire at most once per week/month and are not capped.
    if period == "daily" and await db.count_summaries_today(day) >= cfg.summary_daily_cap:
        raise CapReached(day)
    # A SCHEDULED daily recaps the whole day that just ended (so an early-morning
    # run isn't summarizing an empty new day); an on-demand "Summarize now" stays
    # a live snapshot of today.
    daily_previous = (period == "daily" and source != "manual")
    digest = await build_digest(db, cfg, now, period, daily_previous)
    text = (await llm.generate(cfg, build_prompt(cfg, digest), install_token)) or ""
    text = text.strip() or "No summary available."
    # Append the exact period tally to the recap so the numbers always appear in
    # the stored summary, the retained sensor, AND the phone alert alike.
    footer = stats_footer(cfg, digest)
    if footer:
        text = f"{text}\n\n{footer}"
    row = await db.insert_summary(text, cfg.summary_provider, source, day)
    if mqtt is not None:
        await mqtt.publish_summary(text, _local_time(cfg, now), source, period)
        # Every SCHEDULED recap (daily/weekly/monthly) rides the unified
        # baby/alert bus so HA automations can push it to phones/email — the same
        # delivery path fever and feed/pump reminders already use. Manual
        # "generate" runs from the UI stay quiet (retained sensor only), so
        # tapping generate never fires a phone notification.
        if source != "manual":
            with contextlib.suppress(Exception):
                await mqtt.publish_alert("summary", _alert_title(cfg, period),
                                         text, {"period": period})
    log.info("summary[%s/%s] via %s: %s", source, period, cfg.summary_provider, text[:80])
    return row
