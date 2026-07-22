# syntax=docker/dockerfile:1.6
# Grok-Register — multi-stage image (CLI + Turnstile mint + Chromium)
#
#   docker build -t remmai/grok-register:latest .
#   docker compose up -d
#   docker compose exec grok grok start -t 5 --thread 2

# ---------- build CLI ----------
FROM golang:1.24-bookworm AS builder
WORKDIR /src
ENV GOTOOLCHAIN=auto \
    CGO_ENABLED=0 \
    GOOS=linux

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ARG VERSION=0.1.0
RUN go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/grok ./cmd/grok

# ---------- runtime ----------
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    GROK_HOME=/data \
    GROK_PYTHON=/usr/local/bin/python3 \
    GROK_TURNSTILE_SCRIPT=/opt/grok-reg/scripts/turnstile_mint.py \
    GROK_TURNSTILE_POOL_SCRIPT=/opt/grok-reg/scripts/turnstile_pool.py \
    CHROME_PATH=/usr/bin/chromium \
    DISPLAY=:99 \
    LANG=C.UTF-8 \
    PATH=/usr/local/bin:/usr/bin:/bin

WORKDIR /opt/grok-reg

# Chromium + fonts + Xvfb (headful path under virtual display for Turnstile)
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      chromium \
      curl \
      dumb-init \
      fonts-dejavu-core \
      fonts-liberation \
      fonts-noto-cjk \
      libasound2 \
      libatk-bridge2.0-0 \
      libgbm1 \
      libgtk-3-0 \
      libnss3 \
      libx11-xcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxrandr2 \
      libxshmfence1 \
      procps \
      xvfb \
 && rm -rf /var/lib/apt/lists/* \
 && (ln -sf /usr/bin/chromium /usr/bin/chromium-browser || ln -sf /usr/bin/chromium /usr/bin/google-chrome || true) \
 && chromium --version || chromium-browser --version || true

COPY scripts/requirements-turnstile.txt /opt/grok-reg/scripts/requirements-turnstile.txt
RUN python -m pip install --upgrade pip \
 && python -m pip install -r /opt/grok-reg/scripts/requirements-turnstile.txt \
 && python -m playwright install --with-deps chromium || true

COPY scripts/turnstile_mint.py scripts/turnstile_pool.py /opt/grok-reg/scripts/
RUN chmod +x /opt/grok-reg/scripts/turnstile_mint.py /opt/grok-reg/scripts/turnstile_pool.py

COPY --from=builder /out/grok /usr/local/bin/grok
COPY docker/config.env.example /opt/grok-reg/config.env.example
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && mkdir -p /data \
 && chmod 700 /data

VOLUME ["/data"]
WORKDIR /data

ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["idle"]
