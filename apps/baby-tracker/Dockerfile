# syntax=docker/dockerfile:1

# Baby Tracker — built from source vendored into this repo (apps/baby-tracker/),
# so the image is fully self-contained and does not depend on an upstream tag or
# the upstream release pipeline. Source of truth for the app remains
# github.com/hms-homelab/hms-baby-tracker; changes are vendored here on purpose.

FROM python:3.12-slim

ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"

WORKDIR /app

# deps first for layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# app package + the static SPA (main.py resolves web as <parent-of-app>/web)
COPY app/ /app/app/
COPY web/ /app/web/

ENV DATA_DIR=/data \
    TZ=America/Los_Angeles \
    MQTT_ENABLED=1
RUN mkdir -p /data
VOLUME /data
EXPOSE 8099

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8099"]
