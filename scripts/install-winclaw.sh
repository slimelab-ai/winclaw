#!/usr/bin/env bash
set -euo pipefail

# WinClaw bootstrap installer entrypoint.
# Purpose: enforce admin-run flow, then hand off to upstream installer for now.
# This script is intentionally small so we can evolve behavior without changing the one-liner.

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
WinClaw bootstrap installer

Usage:
  curl -fsSL <this-script-url> | bash

Behavior:
  - Requires administrator privileges on Windows.
  - Delegates to upstream OpenClaw install script for base install.

Notes:
  - Dedicated service-user install flow is being added in WinClaw.
EOF
  exit 0
fi

is_windows=false
case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
  msys*|mingw*|cygwin*) is_windows=true ;;
esac

if [[ "$is_windows" == true ]]; then
  # In Git Bash on Windows, `net session` returns 0 only when elevated.
  if command -v net >/dev/null 2>&1; then
    if ! net session >/dev/null 2>&1; then
      cat <<'EOF'
[WinClaw] This installer must be run from an Administrator account/elevated shell.

Please:
  1) Open an elevated terminal as Administrator
  2) Re-run the WinClaw one-liner

No changes were made.
EOF
      exit 1
    fi
  fi
fi

echo "[WinClaw] Admin check passed. Starting base install..."
INSTALL_URL="${OPENCLAW_INSTALL_URL:-https://openclaw.ai/install.sh}"
curl -fsSL "$INSTALL_URL" | bash

echo
echo "[WinClaw] Base install finished."
echo "[WinClaw] Next milestone: dedicated Windows service-user selection + per-user daemon task."
