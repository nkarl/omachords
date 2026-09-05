#!/usr/bin/env bash
set -euo pipefail

plugin_id="nkarl.omachords"
plugin_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bindings_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"
shortcut='SUPER + SHIFT + K'
toggle_command="omarchy-shell shell toggle $plugin_id {}"
configure_shortcut=true

if [[ "${1:-}" == "--no-shortcut" ]]; then
  configure_shortcut=false
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--no-shortcut]\n' "$0" >&2
  exit 2
fi

if [[ ! -f "$plugin_dir/manifest.json" ]]; then
  printf 'Omachords manifest not found in %s.\n' "$plugin_dir" >&2
  exit 1
fi

missing=()
for command in cargo rustc pkg-config install; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing build tools: %s\n' "${missing[*]}" >&2
  printf 'On Omarchy, install the required packages with:\n' >&2
  printf '  omarchy pkg add rust alsa-lib pkgconf\n' >&2
  exit 1
fi

if ! pkg-config --exists alsa; then
  printf 'The ALSA development package is missing. Install build dependencies with:\n' >&2
  printf '  omarchy pkg add rust alsa-lib pkgconf\n' >&2
  exit 1
fi

cargo build --locked --release --manifest-path "$plugin_dir/engine/Cargo.toml"
mkdir -p "$plugin_dir/bin"
install -m 0755 "$plugin_dir/engine/target/release/omachords-engine" "$plugin_dir/bin/omachords-engine"

if [[ "$configure_shortcut" == true ]]; then
  mkdir -p "$(dirname -- "$bindings_file")"
  touch "$bindings_file"

  if grep -Eq 'SUPER[[:space:]]*\+[[:space:]]*SHIFT[[:space:]]*\+[[:space:]]*K' "$bindings_file" \
    && ! grep -Fq "$toggle_command" "$bindings_file"; then
    printf '%s is already customized in %s; leaving that binding unchanged.\n' "$shortcut" "$bindings_file" >&2
    printf 'Toggle Omachords directly with: %s\n' "$toggle_command" >&2
  elif ! grep -Fq "$toggle_command" "$bindings_file"; then
    backup="$bindings_file.bak.omachords.$(date +%s)"
    cp -- "$bindings_file" "$backup"
    printf '\n-- Omachords: begin\nhl.unbind("SUPER + SHIFT + K")\no.bind("SUPER + SHIFT + K", "Omachords", "omarchy-shell shell toggle nkarl.omachords {}")\n-- Omachords: end\n' >> "$bindings_file"
    hyprctl reload
    hyprctl configerrors
    printf 'Configured %s. Backup: %s\n' "$shortcut" "$backup"
  fi
fi

omarchy plugin enable "$plugin_id"
printf 'Omachords is ready. Toggle it with: %s\n' "$toggle_command"
