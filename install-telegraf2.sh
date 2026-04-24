#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/install-telegraf.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"

# stdout+stderr in Logfile + Konsole umleiten
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date -Is) START install-telegraf ==="
trap 'rc=$?; echo "=== $(date -Is) END install-telegraf rc=$rc ==="; exit $rc' EXIT

# Defaults
TELEGRAF_VERSION="${TELEGRAF_VERSION:-1.38.3}"
REGION="${REGION:-westeurope}"

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-changeme}"

# Packages
echo "[INFO] zypper refresh"
zypper -n ref
echo "[INFO] zypper install packages"
zypper -n in wget gpg2 ca-certificates rpm

# Dirs
echo "[INFO] create /etc/telegraf/telegraf.d"
install -d -m 0755 /etc/telegraf/telegraf.d

# Main config
echo "[INFO] write /etc/telegraf/telegraf.conf"
cat > /etc/telegraf/telegraf.conf <<EOF
[agent]
  interval = "10s"
  round_interval = true
  metric_buffer_limit = 1000
  flush_interval = "10s"
  flush_jitter = "0s"
  collection_jitter = "0s"

[[outputs.azure_monitor]]
  region  = "${REGION}"
  timeout = "20s"

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = true

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs"]

[[inputs.procstat]]
  exe = "postgres"
  interval = "10s"
  fieldinclude = ["running"]
  name_override = "postgres_service"
EOF
chmod 0644 /etc/telegraf/telegraf.conf

# PostgreSQL input config
echo "[INFO] write /etc/telegraf/telegraf.d/postgresql.conf"
cat > /etc/telegraf/telegraf.d/postgresql.conf <<EOF
[[inputs.postgresql]]
  address = "host=localhost user=${POSTGRES_USER} database=${POSTGRES_DB} password=${POSTGRES_PASSWORD} sslmode=disable"
EOF
chmod 0644 /etc/telegraf/telegraf.d/postgresql.conf

# Install telegraf RPM
rpm_file="/tmp/telegraf.rpm"
url="https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-1.x86_64.rpm"
echo "[INFO] download telegraf rpm: $url"
wget -O "${rpm_file}" "${url}"

echo "[INFO] install/upgrade telegraf rpm"
if rpm -q telegraf >/dev/null 2>&1; then
  rpm -Uvh --nosignature "${rpm_file}"
else
  rpm -ivh --nosignature "${rpm_file}"
fi

# Enable/start service
echo "[INFO] enable and restart telegraf service"
systemctl enable --now telegraf
systemctl restart telegraf
