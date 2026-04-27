#!/usr/bin/env bash

DATADIR="$(psql -Atc "show data_directory;" 2>/dev/null)"
LOGDIR="$(psql -Atc "show log_directory;" 2>/dev/null)"

# fallback if psql not available for telegraf user
: "${DATADIR:=/var/lib/pgsql/data}"
: "${LOGDIR:=log}"

[[ "$LOGDIR" != /* ]] && LOGDIR="$DATADIR/$LOGDIR"

LOGFILE="$(ls -1t "$LOGDIR"/postgresql-*.log 2>/dev/null | head -n1)"

fatal=0
error=0
if [[ -n "$LOGFILE" && -r "$LOGFILE" ]]; then
  fatal=$(grep -c 'FATAL' "$LOGFILE" 2>/dev/null || true)
  error=$(grep -c 'ERROR' "$LOGFILE" 2>/dev/null || true)
fi

echo "postgresql_log_counts fatal=${fatal}i,error=${error}i"
exit 0
