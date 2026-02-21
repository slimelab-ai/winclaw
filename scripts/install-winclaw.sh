#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
WinClaw installer bootstrap

Usage:
  curl -fsSL <this-script-url> | bash

Behavior (Windows):
  - Requires administrator privileges.
  - Prompts for a service user first (default: current user).
  - Exports OPENCLAW_WINDOWS_SERVICE_USER for downstream daemon install.
  - Attempts to run install with HOME/USERPROFILE mapped to selected user profile.

Extra env overrides:
  OPENCLAW_INSTALL_URL   Upstream install script URL (default: https://openclaw.ai/install.sh)
  WINCLAW_SERVICE_USER   Preselect/force service user (skip prompt if set)
  WINCLAW_PORT           Optional gateway port override forwarded to installer when possible
EOF
  exit 0
fi

is_windows=false
case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
  msys*|mingw*|cygwin*) is_windows=true ;;
esac

if [[ "$is_windows" != true ]]; then
  echo "[WinClaw] Non-Windows environment detected; delegating to OpenClaw installer."
  INSTALL_URL="${OPENCLAW_INSTALL_URL:-https://openclaw.ai/install.sh}"
  curl -fsSL "$INSTALL_URL" | bash
  exit 0
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "[WinClaw] powershell.exe is required on Windows."
  exit 1
fi

if ! powershell.exe -NoProfile -Command '$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if($p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)){exit 0}else{exit 1}' >/dev/null 2>&1; then
  cat <<'EOF'
[WinClaw] This installer must be run from an Administrator account/elevated shell.

Please:
  1) Open an elevated terminal as Administrator
  2) Re-run the WinClaw one-liner

No changes were made.
EOF
  exit 1
fi

trim_crlf() {
  local v="$1"
  v="${v//$'\r'/}"
  v="${v//$'\n'/}"
  printf "%s" "$v"
}

current_user="$(trim_crlf "$(powershell.exe -NoProfile -Command '$u=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name; if($u -match "\\\\"){$u.Split("\\")[1]} else {$u}'")")"
if [[ -z "$current_user" ]]; then
  current_user="${USERNAME:-}"
fi

list_users() {
  powershell.exe -NoProfile -Command 'Get-LocalUser | Where-Object { -not $_.Disabled } | Select-Object -ExpandProperty Name' \
    | tr -d '\r' \
    | sed '/^$/d'
}

resolve_user_profile() {
  local username="$1"
  powershell.exe -NoProfile -Command "\$u='${username}'; \$p=(Get-CimInstance Win32_UserProfile | Where-Object { \$_.LocalPath -match ('\\\\'+[regex]::Escape(\$u)+'$') } | Select-Object -First 1 -ExpandProperty LocalPath); if(\$p){Write-Output \$p}else{Write-Output ('C:\\Users\\'+\$u)}" \
    | tr -d '\r' \
    | tail -n 1
}

service_user="${WINCLAW_SERVICE_USER:-}"
if [[ -z "$service_user" ]]; then
  mapfile -t users < <(list_users)
  if [[ ${#users[@]} -eq 0 ]]; then
    echo "[WinClaw] Could not enumerate local users."
    exit 1
  fi

  echo "[WinClaw] Select service user (default: ${current_user}):"
  for i in "${!users[@]}"; do
    printf "  %2d) %s\n" "$((i + 1))" "${users[$i]}"
  done
  printf "Enter number or username [%s]: " "$current_user"
  read -r sel
  if [[ -z "${sel}" ]]; then
    service_user="$current_user"
  elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#users[@]} )); then
    service_user="${users[$((sel - 1))]}"
  else
    service_user="$sel"
  fi
fi

service_user="$(trim_crlf "$service_user")"
if [[ -z "$service_user" ]]; then
  echo "[WinClaw] Service user cannot be empty."
  exit 1
fi

service_profile="$(trim_crlf "$(resolve_user_profile "$service_user")")"
if [[ -z "$service_profile" ]]; then
  echo "[WinClaw] Could not resolve profile path for user '$service_user'."
  exit 1
fi

if [[ -z "${WINCLAW_PORT:-}" ]]; then
  printf "Gateway port [default OpenClaw port]: "
  read -r maybe_port
  WINCLAW_PORT="$maybe_port"
fi

export OPENCLAW_WINDOWS_SERVICE_USER="$service_user"
export WINCLAW_SERVICE_USER="$service_user"
export USERPROFILE="$service_profile"
export HOME="$service_profile"
export OPENCLAW_HOME="$service_profile\\.openclaw"

if [[ -n "${WINCLAW_PORT:-}" ]]; then
  export OPENCLAW_GATEWAY_PORT="$WINCLAW_PORT"
fi

echo "[WinClaw] Service user: $service_user"
echo "[WinClaw] Service profile: $service_profile"
if [[ -n "${WINCLAW_PORT:-}" ]]; then
  echo "[WinClaw] Gateway port override: ${WINCLAW_PORT}"
fi

INSTALL_URL="${OPENCLAW_INSTALL_URL:-https://openclaw.ai/install.sh}"
echo "[WinClaw] Starting base install..."
curl -fsSL "$INSTALL_URL" | bash

echo
echo "[WinClaw] Base install finished."
echo "[WinClaw] If needed, enforce service user with:"
echo "  OPENCLAW_WINDOWS_SERVICE_USER='${service_user}' openclaw daemon install --force${WINCLAW_PORT:+ --port ${WINCLAW_PORT}}"
