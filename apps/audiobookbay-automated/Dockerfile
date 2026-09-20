# syntax=docker/dockerfile:1

# AudiobookBay Automated — built from source vendored into this repo
# (apps/audiobookbay-automated/), so the image is self-contained and does not
# depend on the upstream release pipeline. Upstream has no tagged releases;
# source is vendored at github.com/JamesRy96/audiobookbay-automated @ b8e252c.
# Served with gunicorn rather than the Flask dev server; gunicorn is added to
# the vendored requirements.txt.

FROM python:3.12-slim

ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"

WORKDIR /app

# deps first for layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# app package (app.py exposes the Flask app object `app`; static/ + templates/)
COPY app/ /app/

EXPOSE 5078

USER 65534:65534

CMD ["gunicorn", "--bind", "0.0.0.0:5078", "--workers", "2", "app:app"]
