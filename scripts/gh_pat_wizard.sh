#!/usr/bin/env bash
set -euo pipefail

# ── Library (identical to template) ────────────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  BLUE=$(tput setaf 4); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
fi

TOTAL_STAGES=3
_STAGE_INDEX=0
WRITTEN_ENV=()
SKIPPED=()

_clear() { [[ -t 1 ]] || return 0; if command -v tput >/dev/null 2>&1; then tput clear; else printf '\033[2J\033[3J\033[H'; fi; }
banner() { _clear; printf '\n%s%s  %s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"; printf '%s  %s stages%s\n\n' "$DIM" "$TOTAL_STAGES" "$RESET"; printf '%s  You drive the browser; this wizard tells you exactly what to do and\n' "$DIM"; printf '  captures the values you copy back. Stop any time with Ctrl-C and re-run\n'; printf '  later, since it remembers values already saved.%s\n' "$RESET"; pause "Ready to start?"; }
stage() { _clear; _STAGE_INDEX=$((_STAGE_INDEX + 1)); printf '\n%s%s▸ Stage %s/%s · %s%s\n' "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"; }
say()  { printf '  %s\n' "$1"; }
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }
open_url() { local url="$1"; printf '  %s↗ opening%s %s\n' "$GREEN" "$RESET" "$url"; { if command -v wslview >/dev/null 2>&1; then wslview "$url"; elif command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$url"; elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$url"; elif command -v open >/dev/null 2>&1; then open "$url"; else warn "couldn't open a browser; visit it manually: $url"; fi; } >/dev/null 2>&1 || warn "couldn't open a browser, so visit it manually: $url"; }
pause() { printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"; read -r _ || true; }
confirm() { local reply=""; printf '  %s? %s [y/N] ' "$YELLOW" "$1"; read -r reply || true; [[ "$reply" =~ ^[Yy] ]]; }
ask_secret() { local key="$1" prompt="$2" current input; current=""; printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"; read -rs input || true; printf '\n'; printf -v "$key" '%s' "$input"; }
finish() { _clear; printf '\n%s%s  ✓ Setup complete%s\n' "$BOLD" "$GREEN" "$RESET"; if (( ${#WRITTEN_ENV[@]} )); then note "wrote ${#WRITTEN_ENV[@]} value(s): ${WRITTEN_ENV[*]}"; fi; if (( ${#SKIPPED[@]} )); then printf '\n'; warn "still to do by hand:"; for s in "${SKIPPED[@]}"; do note "  - $s"; done; fi; printf '\n'; }

# ── STAGES ─────────────────────────────────────────────────────────────────

banner "GitHub Personal Access Token setup"

stage "Open GitHub Token page"
say "We'll create a Personal Access Token for gh CLI authentication."
open_url "https://github.com/settings/tokens/new"
step "1. Fill 'Note' with a name, e.g. 'DSH gh CLI'."
step "2. Set 'Expiration' as you prefer (90 days recommended)."
step "3. Under 'Select scopes', check:"
step "   ✓ repo (Full control of private repositories)"
step "   ✓ read:org (Read org and team membership)"
step "   ✓ workflow (Update GitHub Action workflows, optional)"
step "4. Click 'Generate token' at the bottom."
step "5. COPY the token (starts with ghp_...) — you won't see it again!"
pause "Press Enter after you've copied the token..."

stage "Enter your token"
ask_secret GH_TOKEN "Paste your GitHub PAT (ghp_...):"
if [[ -z "$GH_TOKEN" ]]; then
  warn "No token entered. Skipping."
  SKIPPED+=("GH_TOKEN (paste it manually)")
else
  # Save to .env for reference
  ENV_FILE="${ENV_FILE:-.env}"
  touch "$ENV_FILE"
  tmp=$(mktemp)
  grep -vE "^GH_TOKEN=" "$ENV_FILE" > "$tmp" || true
  printf 'GH_TOKEN=%s\n' "$GH_TOKEN" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
  WRITTEN_ENV+=("GH_TOKEN")
  printf '  %s✓ wrote%s GH_TOKEN → %s\n' "$GREEN" "$RESET" "$ENV_FILE"
  note "Now set it as a Windows environment variable:"
  note "  powershell -Command \"[System.Environment]::SetEnvironmentVariable('GH_TOKEN', '$GH_TOKEN', 'User')\""
  note "Then restart DSH Desktop for it to take effect."
fi
pause "Press Enter to continue..."

stage "Verify authentication"
say "Testing gh auth with your token..."
export GH_TOKEN
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    printf '  %s✓ gh authenticated successfully!%s\n' "$GREEN" "$RESET"
    gh auth status 2>&1 | head -5
  else
    warn "gh auth status failed. Check your token scopes."
  fi
else
  warn "gh CLI not found. Set DSH_GH_PATH first."
fi
pause "Press Enter to finish..."

finish
