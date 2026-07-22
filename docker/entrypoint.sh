#!/usr/bin/env bash
# Container entrypoint for grok-register.
set -euo pipefail

export GROK_HOME="${GROK_HOME:-/data}"
export GROK_PYTHON="${GROK_PYTHON:-/usr/local/bin/python3}"
export GROK_TURNSTILE_SCRIPT="${GROK_TURNSTILE_SCRIPT:-/opt/grok-reg/scripts/turnstile_mint.py}"
export GROK_TURNSTILE_POOL_SCRIPT="${GROK_TURNSTILE_POOL_SCRIPT:-/opt/grok-reg/scripts/turnstile_pool.py}"
export CHROME_PATH="${CHROME_PATH:-/usr/bin/chromium}"

mkdir -p "$GROK_HOME" "$GROK_HOME/logs" "$GROK_HOME/outputs"
chmod 700 "$GROK_HOME" 2>/dev/null || true

# Seed config.env from example on first run (never overwrite user config).
if [ ! -f "$GROK_HOME/config.env" ]; then
  if [ -f /opt/grok-reg/config.env.example ]; then
    cp /opt/grok-reg/config.env.example "$GROK_HOME/config.env"
    echo "[*] seeded $GROK_HOME/config.env - edit then restart / re-run start"
  fi
fi

# Virtual display for Chromium/Playwright (Turnstile often fails pure headless).
if [ "${ENABLE_XVFB:-1}" = "1" ] && command -v Xvfb >/dev/null 2>&1; then
  if ! pgrep -x Xvfb >/dev/null 2>&1; then
    Xvfb "${DISPLAY:-:99}" -screen 0 1920x1080x24 -nolisten tcp -ac >/tmp/xvfb.log 2>&1 &
    sleep 0.5
  fi
fi

# If user passes full "grok ..." keep compatibility.
if [ "${1:-}" = "grok" ]; then
  shift
fi

# Default: idle (keep container alive under compose)
if [ $# -eq 0 ]; then
  set -- idle
fi

cmd="${1:-idle}"

# Keep container alive for docker compose up / exec workflows.
if [ "$cmd" = "help" ] || [ "$cmd" = "idle" ] || [ "$cmd" = "sleep" ]; then
  /usr/local/bin/grok help || true
  echo "[*] idle - run: docker compose exec grok grok start -t 5 --thread 2"
  exec sleep infinity
fi

# "start" forks a worker then exits on the host CLI - keep container alive by waiting.
if [ "$cmd" = "start" ]; then
  shift
  /usr/local/bin/grok start "$@"
  pid_file="$GROK_HOME/run.pid"
  for _ in $(seq 1 50); do
    if [ -f "$pid_file" ]; then
      break
    fi
    sleep 0.1
  done
  if [ -f "$pid_file" ]; then
    worker_pid="$(tr -d '[:space:]' <"$pid_file" || true)"
    echo "[*] waiting on worker pid=${worker_pid:-?}"
    if [ -n "${worker_pid:-}" ] && kill -0 "$worker_pid" 2>/dev/null; then
      trap 'kill -TERM "$worker_pid" 2>/dev/null || true' TERM INT
      while kill -0 "$worker_pid" 2>/dev/null; do
        sleep 2
      done
      exit 0
    fi
  fi
  echo "[!] worker pid not found; tailing logs under $GROK_HOME/logs"
  mkdir -p "$GROK_HOME/logs"
  touch "$GROK_HOME/logs/.keep"
  exec tail -F "$GROK_HOME/logs"/*.log 2>/dev/null || exec sleep infinity
fi

if [ "$cmd" = "--worker" ] || [ "$cmd" = "worker" ]; then
  if [ "$cmd" = "worker" ]; then
    shift
    exec /usr/local/bin/grok --worker "$@"
  fi
  exec /usr/local/bin/grok "$@"
fi

exec /usr/local/bin/grok "$@"
