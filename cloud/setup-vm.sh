#!/usr/bin/env bash
# setup-vm.sh - Sets up the demo environment with one command (Ubuntu 24.04, Google Cloud):
#   - SAP ABAP Cloud Developer Trial 2025 (container: a4h)
#   - GreenMail test mail server (container: greenmail)
#   - PowerShell 7 and imap.ps1 inside the SAP container (/usr/sap/sapimap)
#   - Sample mails
#
# Run (from the project folder):  sudo bash cloud/setup-vm.sh
# All ports are opened on 127.0.0.1 only; SAP GUI uses an SSH tunnel.
set -euo pipefail

SAP_IMAGE="sapse/abap-cloud-developer-trial:2025"
MAIL_IMAGE="greenmail/standalone:2.1.14"
PWSH_VERSION="7.4.6"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="/usr/sap/sapimap"

step() { echo; echo "=== $*"; }

if [[ $EUID -ne 0 ]]; then echo "run with sudo: sudo bash cloud/setup-vm.sh"; exit 1; fi

step "1/8 Docker"
if ! command -v docker >/dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl
fi
systemctl enable --now docker >/dev/null
df -h /var/lib/docker | tail -1

step "2/8 Kernel settings (values required by the SAP trial)"
cat > /etc/sysctl.d/90-sap-trial.conf <<'EOF'
vm.max_map_count = 2147483647
fs.file-max = 20000000
fs.aio-max-nr = 18446744073709551615
EOF
sysctl --system >/dev/null

step "3/8 SAP license"
echo "SAP ABAP Cloud Developer Trial is for trial and learning purposes only."
echo "License terms: https://hub.docker.com/r/sapse/abap-cloud-developer-trial"
read -r -p "I have read and accept the SAP trial license (yes/no): " answer
[[ "$answer" == "yes" ]] || { echo "Cancelled."; exit 1; }

step "4/8 Docker Hub login (needed to download the SAP image)"
docker login

step "5/8 Network and GreenMail"
docker network inspect sapimap-net >/dev/null 2>&1 || docker network create sapimap-net >/dev/null
if ! docker container inspect greenmail >/dev/null 2>&1; then
  docker run -d --name greenmail --network sapimap-net \
    -p 127.0.0.1:3025:3025 -p 127.0.0.1:3993:3993 \
    -e GREENMAIL_OPTS="-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.users=sap:sapdemo@demo.local -Dgreenmail.users.login=email" \
    "$MAIL_IMAGE" >/dev/null
fi

step "6/8 SAP image (about 23 GB download, 53 GB unpacked) and first start"
docker pull "$SAP_IMAGE"
if ! docker container inspect a4h >/dev/null 2>&1; then
  docker run -dit --stop-timeout 3600 --name a4h -h vhcala4hci --network sapimap-net \
    -p 127.0.0.1:3200:3200 -p 127.0.0.1:3300:3300 \
    -p 127.0.0.1:50000:50000 -p 127.0.0.1:50001:50001 \
    --sysctl kernel.shmmax=21474836480 --sysctl kernel.shmmni=32768 \
    --sysctl kernel.shmall=5242880 --sysctl kernel.msgmni=1024 \
    --sysctl "kernel.sem=1250 256000 100 8192" \
    --ulimit nofile=1048576:1048576 \
    "$SAP_IMAGE" -agree-to-sap-license >/dev/null
fi
echo "SAP is starting; waiting for 'All services have been started' (at most 90 min)..."
started=0
for _ in $(seq 1 180); do
  if docker logs a4h 2>&1 | grep -qi "all services have been started"; then started=1; break; fi
  sleep 30
done
if [[ $started -ne 1 ]]; then
  echo "SAP did not start within 90 minutes. Log: docker logs --tail 50 a4h"; exit 1
fi
echo "SAP started."

step "7/8 PowerShell 7 and imap.ps1 into the SAP container"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if ! docker exec a4h test -x /opt/microsoft/powershell/7/pwsh; then
  curl -fsSL -o "$tmp/pwsh.tar.gz" \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz"
  docker cp "$tmp/pwsh.tar.gz" a4h:/tmp/pwsh.tar.gz
  docker exec a4h bash -c 'mkdir -p /opt/microsoft/powershell/7 &&
    tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7 &&
    chmod +x /opt/microsoft/powershell/7/pwsh && rm -f /tmp/pwsh.tar.gz'
fi
# Wrapper that starts PowerShell in "invariant" mode if the ICU library is missing
docker exec a4h bash -c 'cat > /usr/bin/pwsh <<EOF
#!/bin/sh
if ! ls /usr/lib64/libicu* /usr/lib/libicu* >/dev/null 2>&1; then
  export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
fi
exec /opt/microsoft/powershell/7/pwsh "\$@"
EOF
chmod 755 /usr/bin/pwsh'
docker exec a4h pwsh -NoProfile -Command '"PowerShell " + $PSVersionTable.PSVersion'
docker exec a4h bash -c 'command -v curl >/dev/null && curl --version | head -1' \
  || { echo "No curl in the SAP container."; exit 1; }

# The same server setup a Basis administrator runs (server/setup-server.sh),
# here inside the SAP container. --allow-insecure only because GreenMail
# uses a self-signed certificate.
docker exec a4h rm -rf /tmp/zche_imap-pkg
docker exec a4h mkdir -p /tmp/zche_imap-pkg
docker cp "$REPO_DIR/server" a4h:/tmp/zche_imap-pkg/server
docker cp "$REPO_DIR/script" a4h:/tmp/zche_imap-pkg/script
docker exec a4h bash /tmp/zche_imap-pkg/server/setup-server.sh --root "$WORK" \
  --sap-user a4hadm --allowed-hosts greenmail --allow-insecure --force

step "8/8 Sample mails"
curl -s -k -u 'sap@demo.local:sapdemo' 'imaps://127.0.0.1:3993/' -X 'CREATE SAP-Processed' >/dev/null || true
for f in "$REPO_DIR"/test/samples/*.eml; do
  curl -s 'smtp://127.0.0.1:3025' --mail-from 'supplier@demo.local' \
    --mail-rcpt 'sap@demo.local' -T "$f" && echo "sent: $(basename "$f")"
done
echo
echo "Self-test as the SAP user (what ZCHE_IMAP_INSTALL checks through SM69):"
docker exec -u a4hadm a4h pwsh -NoProfile -NonInteractive -File "$WORK/bin/imap.ps1" test

cat <<'EOF'

=== Setup complete.
Next steps are in cloud/GCP-DEMO.md:
  - SSH tunnel from Windows and SAP GUI connection
  - SE38: create ZCHE_IMAP_INSTALL, paste ZCHE_IMAP_INSTALL.abap, F8
  - ZCHE_IMAP_CONFIG: mailbox greenmail:3993, IMAPS, certificate check off,
    user sap@demo.local, password sapdemo
To stop: docker stop -t 7200 a4h
EOF
