#!/usr/bin/env bash
set -euo pipefail

plugin_id="nkarl.omachords"
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$plugin_id"
bindings_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"

if [[ -f "$bindings_file" ]] && grep -Fq -- '-- Omachords: begin' "$bindings_file"; then
  backup="$bindings_file.bak.omachords-remove.$(date +%s)"
  temp_file="$(mktemp)"
  trap 'rm -f -- "$temp_file"' EXIT
  cp -- "$bindings_file" "$backup"
  awk '
    /-- Omachords: begin/ { skipping = 1; next }
    /-- Omachords: end/   { skipping = 0; next }
    !skipping { print }
  ' "$bindings_file" > "$temp_file"
  install -m 0644 "$temp_file" "$bindings_file"
  hyprctl reload
  hyprctl configerrors
  printf 'Removed the Omachords shortcut. Backup: %s\n' "$backup"
fi

if [[ -d "$plugin_dir" ]]; then
  omarchy plugin remove "$plugin_id"
else
  printf 'Omachords is not installed at %s.\n' "$plugin_dir"
fi
