#!/usr/bin/env bash
set -euo pipefail

interval="${SCHEDULER_INTERVAL:-60}"

if ! [[ "$interval" =~ ^[0-9]+$ ]] || [[ "$interval" -le 0 ]]; then
  echo "Invalid SCHEDULER_INTERVAL: $interval" >&2
  interval=60
fi

shutdown_requested=false
trap 'shutdown_requested=true' TERM INT

while true; do
  # 默认任务：重发失败的异步通知、订单统计清理。自动结算等按需加到 SCHEDULER_TASKS
  for task in ${SCHEDULER_TASKS:-notify notify2 order}; do
    if ! out=$(php /var/www/html/cron.php "do=$task" 2>&1); then
      echo "[scheduler] cron.php do=$task failed: $out" >&2
    fi
  done

  if $shutdown_requested; then
    break
  fi

  sleep "$interval" &
  wait $! || true

  if $shutdown_requested; then
    break
  fi

done
