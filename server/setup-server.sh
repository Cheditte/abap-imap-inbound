#!/usr/bin/env bash
# setup-server.sh - abap-imap-inbound server setup (Linux).
# Run as root, from the root folder of the package:
#
#   sudo bash server/setup-server.sh --sap-user a4hadm --allowed-hosts mail.example.com
#
# Options:
#   --root DIR            work folder (default /usr/sap/sapimap)
#   --sap-user USER       user of the SAP work processes (<sid>adm)
#   --allowed-hosts A,B   allowed mail servers (comma separated)
#   --allow-insecure      allow disabling the certificate check (test)
#   --allow-plain         allow unencrypted IMAP
#   --force               overwrite an existing policy.psd1
#   --set-password KEY    SID_CLIENT_PROFILE (password source O)
#   --curl-path FILE      curl 8.0.0+ outside /usr/bin (default /usr/bin/curl)
#
# Requirements: PowerShell 7 (pwsh) and curl 8.0.0 or newer with IMAPS support.
set -euo pipefail

ROOT=/usr/sap/sapimap; SAPUSER=""; HOSTS=""; INSECURE='$false'; PLAIN='$false'
FORCE=0; SETPW=""; CURL=/usr/bin/curl
PKG="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2;;
    --sap-user) SAPUSER="$2"; shift 2;;
    --allowed-hosts) HOSTS="$2"; shift 2;;
    --allow-insecure) INSECURE='$true'; shift;;
    --allow-plain) PLAIN='$true'; shift;;
    --force) FORCE=1; shift;;
    --set-password) SETPW="$2"; shift 2;;
    --curl-path) CURL="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 2;;
  esac
done

fail() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

[[ $EUID -eq 0 ]] || fail "run as root"
[[ -n "$SAPUSER" ]] || fail "give --sap-user (example: a4hadm)"
id "$SAPUSER" >/dev/null 2>&1 || fail "user not found: $SAPUSER"
SAPGROUP="$(id -gn "$SAPUSER")"

# The parent chain must stay under root control while this process runs.
# Never canonicalize through a link: that would hide an unsafe input path.
[[ "$ROOT" == /* && "$ROOT" != / && "$ROOT" != *"'"* &&
   "$ROOT" != *$'\n'* && "$ROOT" != *$'\r'* ]] || fail "unsafe --root"
ROOT="${ROOT%/}"
[[ "$ROOT/" != *'/../'* && "$ROOT/" != *'/./'* &&
   "$ROOT" != *'//'* ]] || fail "use a normalized absolute --root"
check_root_chain() {
  local part current="" owner mode
  IFS=/ read -r -a parts <<< "$ROOT"
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    current="$current/$part"
    [[ ! -L "$current" ]] || fail "symlink in root path: $current"
    if [[ -e "$current" ]]; then
      [[ -d "$current" ]] || fail "not a directory: $current"
      owner="$(stat -c %u "$current")"
      mode="$(stat -c %a "$current")"
      [[ "$owner" == 0 ]] || fail "root must own parent: $current"
      (( (8#$mode & 0022) == 0 )) || fail "writable parent: $current"
    fi
  done
}
check_root_chain
for d in bin conf secret in done tmp log; do
  [[ ! -L "$ROOT/$d" ]] || fail "symlink directory: $ROOT/$d"
  if [[ -e "$ROOT/$d" && ! -d "$ROOT/$d" ]]; then
    fail "not a directory: $ROOT/$d"
  fi
done
if [[ -d "$ROOT/bin" ]]; then
  [[ "$(stat -c %u "$ROOT/bin")" == 0 ]] || fail "root must own bin"
  BINMODE="$(stat -c %a "$ROOT/bin")"
  (( (8#$BINMODE & 0022) == 0 )) || fail "bin must not be writable by SAP"
  BADENTRY="$(find -P "$ROOT/bin" -mindepth 1 \( -type l -o -type d -o -links +1 \) -print -quit)"
  [[ -z "$BADENTRY" ]] || fail "unexpected linked/nested bin entry: $BADENTRY"
fi

if [[ -n "$SETPW" ]]; then
  [[ "$SETPW" =~ ^[A-Z0-9]{3}_[0-9]{3}_[A-Z0-9_]{1,20}$ ]] ||
    fail "use SID_CLIENT_PROFILE (example A4H_001_INVOICE)"
  [[ -d "$ROOT/secret" ]] || fail "run server setup first"
  read -r -p "Mail user name (empty: the one in ZCHE_IMAP_CONFIG is used): " U
  read -r -s -p "Password: " P; echo
  [[ -n "$P" && "$P" != *$'\r'* && "$U" != *$'\r'* ]] ||
    fail "password must be nonempty and single-line"
  umask 077
  STAGE="$(mktemp -d "$ROOT/.credential.XXXXXXXX")"
  trap 'rm -f -- "$STAGE/credential"; rmdir -- "$STAGE"' EXIT
  F="$STAGE/credential"
  { if [[ -n "$U" ]]; then printf 'USER=%s\n' "$U"; fi
    printf 'PASSWORD=%s\n' "$P"; } > "$F"
  unset P
  chmod 600 "$F"; chown "$SAPUSER:$SAPGROUP" "$F"
  # Same-filesystem rename replaces the entry, never its link target.
  mv -fT -- "$F" "$ROOT/secret/$SETPW.cred"
  echo "Written: $ROOT/secret/$SETPW.cred"; exit 0
fi

step "pwsh and curl check"
command -v pwsh >/dev/null || fail "PowerShell 7 (pwsh) is not installed"
[[ -x "$CURL" ]] || fail "curl not found: $CURL (install curl 8.0.0+ and pass --curl-path)"
"$CURL" --version | grep -qw imaps || fail "curl does not support IMAPS"
CURLMAJOR="$("$CURL" --version | head -1 | sed -n 's/^curl \([0-9][0-9]*\)\..*/\1/p')"
[[ -n "$CURLMAJOR" && "$CURLMAJOR" -ge 8 ]] || fail "curl 8.0.0 or newer is required: $("$CURL" --version | head -1 | cut -d' ' -f1-2) (pass --curl-path)"
echo "$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') / $("$CURL" --version | head -1 | cut -d' ' -f1-2)"

step "Folders: $ROOT"
for module in imap.ps1 mime.ps1; do
  [[ -f "$PKG/script/$module" ]] || fail "package module missing: $module"
done
mkdir -p "$ROOT"/{bin,conf,secret,in,done,tmp,log}
check_root_chain
for module in imap.ps1 mime.ps1; do
  [[ ! -L "$ROOT/bin/$module" ]] || fail "symlink module: $module"
  install -m 644 -o root -g root "$PKG/script/$module" "$ROOT/bin/$module"
done
[[ ! -L "$ROOT/bin/policy.psd1" ]] || fail "symlink policy.psd1"

if [[ -f "$ROOT/bin/policy.psd1" && $FORCE -eq 0 ]]; then
  echo "policy.psd1 already exists, kept (use --force to replace it)"
else
  [[ -n "$HOSTS" ]] || fail "give the allowed mail servers: --allowed-hosts mail.example.com"
  [[ "$HOSTS" =~ ^[A-Za-z0-9.,_-]+$ ]] || fail "invalid allowed host list"
  LIST="$(echo "$HOSTS" | tr 'A-Z' 'a-z' | sed "s/[[:space:]]//g; s/^/'/; s/,/', '/g; s/\$/'/")"
  cat > "$ROOT/bin/policy.psd1" <<EOF
# policy.psd1 - limits set by Basis (generated by setup-server.sh).
@{
    WorkDir          = '$ROOT'
    AllowedHosts     = @($LIST)
    AllowInsecure    = $INSECURE
    AllowPlainImap   = $PLAIN
    CaCert           = ''
    CurlPath         = '$CURL'
    MaxMailBytes     = 52428800
    RetentionDaysMax = 365
    TimeoutSecMax    = 600
}
EOF
  echo "policy.psd1 written: allowed servers $LIST"
fi

step "Permissions (SAP user: $SAPUSER)"
chown root:root "$ROOT" "$ROOT/bin" "$ROOT/bin/"*
chmod 755 "$ROOT" "$ROOT/bin"; chmod 644 "$ROOT/bin/"*
for d in conf secret in done tmp log; do
  LINK="$(find -P "$ROOT/$d" -type l -print -quit)"
  [[ -z "$LINK" ]] || fail "remove unexpected symlink before setup: $LINK"
  chown -hR -P "$SAPUSER:$SAPGROUP" "$ROOT/$d"
done
chmod 750 "$ROOT"/{conf,in,done,tmp,log}
chmod 700 "$ROOT/secret"

step "Installation test"
OUT="$(su -s /bin/sh "$SAPUSER" -c "pwsh -NoProfile -NonInteractive -File '$ROOT/bin/imap.ps1' test" || true)"
echo "$OUT" | sed 's/^/  /'
[[ "$(echo "$OUT" | tail -1)" == "OK" ]] || fail "installation test failed"

echo
echo "Server ready. On the SAP side:"
echo "  SE38 > ZCHE_IMAP_INSTALL > Server folder: $ROOT/"
echo "  Then define the mailbox profile with ZCHE_IMAP_CONFIG."
