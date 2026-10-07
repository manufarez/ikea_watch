#!/bin/zsh
# Runs the check on this Mac (launchd fallback). Secrets live in ~/.config/ikea-watch/env (chmod 600),
# never in the plist, which is world-readable.
set -euo pipefail

# launchd starts with a bare PATH. Use mise shims so .ruby-version picks Ruby 3.4, not the system Ruby 2.6.
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/bin:/bin"

env_file="$HOME/.config/ikea-watch/env"
if [[ -f "$env_file" ]]; then
  set -a
  source "$env_file"
  set +a
fi

cd "${0:A:h}/.."
echo "--- $(date '+%Y-%m-%d %H:%M:%S')"
exec ruby bin/check.rb "$@"
