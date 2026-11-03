#!/usr/bin/env bash
# Print a read-only snapshot of the live infrastructure, so it can be compared
# with the notes in machines/ and network/. Changes nothing.
#
# Usage: scripts/refresh.sh [ssh-host ...]
# Edit HOSTS and DOMAINS below, or pass hosts on the command line.
# Needs: SSH access to each host (BatchMode, so keys only).

set -uo pipefail

HOSTS=(my-server)
DOMAINS=(example.com)

if [ "$#" -gt 0 ]; then
  HOSTS=("$@")
fi

section() { printf '\n===== %s =====\n' "$1"; }

section "Snapshot"
echo "Taken $(date '+%Y-%m-%d %H:%M %Z') from $(hostname -s)"

section "Tailscale"
if command -v tailscale >/dev/null; then
  tailscale status
else
  echo "tailscale not installed here"
fi

for host in "${HOSTS[@]}"; do
  section "$host"
  # Every command here only reads. Add your own, for example `sudo -n ufw status`.
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" 'bash -s' <<'REMOTE' || echo "(could not reach $host)"
echo "--- os"; . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME"; uname -r
echo "--- uptime"; uptime
echo "--- resources"; nproc; free -h | sed -n 2p; df -h / | tail -1
echo "--- addresses"; ip -4 -br addr 2>/dev/null | grep -vE '^(lo|veth|docker|br-)'
echo "--- listening"; ss -tlnH 2>/dev/null | awk '{print $4}' | sort -u
echo "--- containers"; docker ps --format '{{.Names}} ({{.Image}}) {{.Ports}}' 2>/dev/null || echo "(no docker)"
echo "--- failed units"; systemctl --failed --no-legend 2>/dev/null || true
REMOTE
done

section "DNS"
for d in "${DOMAINS[@]}"; do
  printf '%-24s %s\n' "$d" "$(dig +short "$d" A 2>/dev/null | tr '\n' ' ')"
done
