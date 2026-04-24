#!/usr/bin/env bash
set -euo pipefail

# Defaults (kannst du anpassen)
TELEGRAF_VERSION="${TELEGRAF_VERSION:-1.30.3}"
REGION="${REGION:-westeurope}"

# Weiterhin required:
: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${POSTGRES_DB:?POSTGRES_DB not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set}"

# Packages
zypper -n ref
zypper -n in wget gpg2 rpm ca-certificates

# Dirs
install -d -m 0755 /etc/telegraf/telegraf.d

# Main config
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
cat > /etc/telegraf/telegraf.d/postgresql.conf <<EOF
[[inputs.postgresql]]
  address = "host=localhost user=${POSTGRES_USER} database=${POSTGRES_DB} password=${POSTGRES_PASSWORD} sslmode=disable"
EOF
chmod 0644 /etc/telegraf/telegraf.d/postgresql.conf

# Install telegraf RPM
rpm_file="/tmp/telegraf.rpm"
url="https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}-1.x86_64.rpm"
wget -O "${rpm_file}" "${url}"

# If already installed, upgrade; else install. Influx RPM header unsigned -> --nosignature
if rpm -q telegraf >/dev/null 2>&1; then
  rpm -Uvh --nosignature "${rpm_file}"
else
  rpm -ivh --nosignature "${rpm_file}"
fi

# Enable/start service
systemctl enable --now telegraf
systemctl restart telegraf
