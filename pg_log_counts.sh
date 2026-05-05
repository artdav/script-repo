#!/usr/bin/env bash

LOGDIR="/var/lib/pgsql/data/log"
STATE="/var/tmp/telegraf_pglog.state"

LOGFILE="$(ls -1t "$LOGDIR"/postgresql-*.log 2>/dev/null | head -n1)"

fatal=0; error=0
if [[ -n "$LOGFILE" && -r "$LOGFILE" ]]; then
  # load previous state
  read -r old_inode old_pos < "$STATE" 2>/dev/null || { old_inode=""; old_pos=0; }
  inode="$(stat -c %i "$LOGFILE" 2>/dev/null || echo "")"
  size="$(stat -c %s "$LOGFILE" 2>/dev/null || echo 0)"

  # rotation/new file or truncated -> start from 0
  if [[ "$inode" != "$old_inode" || "$old_pos" -gt "$size" ]]; then
    old_pos=0
  fi

  # read only new bytes, count in that chunk
  if [[ "$size" -gt "$old_pos" ]]; then
    chunk="$(dd if="$LOGFILE" bs=1 skip="$old_pos" status=none 2>/dev/null)"
    fatal=$(grep -c 'FATAL' <<<"$chunk" 2>/dev/null || true)
    error=$(grep -c 'ERROR' <<<"$chunk" 2>/dev/null || true)
  fi

  # store new state
  echo "$inode $size" > "$STATE"
fi

echo "postgresql_log_counts_new fatal=${fatal}i,error=${error}i"
exit 0
