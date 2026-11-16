#!/bin/bash
set -euo pipefail

TEMPLATES_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ANSI color codes shared with sync.sh.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { printf '%bINFO: %s%b\n' "$GREEN" "$1" "$NC"; }
error() { printf '%bERROR: %s%b\n' "$RED" "$1" "$NC" >&2; }

get_package_value() {
  local template="$1" key="$2"
  local manifest="$TEMPLATES_REPO/templates/$template/typst.toml"
  if [ ! -f "$manifest" ]; then
    error "typst.toml not found for $template"
    return 1
  fi
  awk -F '"' -v key="$key" '
    /^[[:space:]]*\[package\][[:space:]]*$/ { package = 1; next }
    /^[[:space:]]*\[/ { package = 0 }
    package && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print $2 }
  ' "$manifest"
}

get_version() {
  local template="$1" version name
  name=$(get_package_value "$template" name)
  version=$(get_package_value "$template" version)
  if [ "$name" != "modern-whs-$template" ]; then
    error "Expected package name modern-whs-$template in templates/$template/typst.toml"
    return 1
  fi
  if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    error "Expected a major.minor.patch version in templates/$template/typst.toml"
    return 1
  fi
  printf '%s\n' "$version"
}

get_example_version() {
  local template="$1" version
  local example="$TEMPLATES_REPO/templates/$template/example/main.typ"
  if [ ! -f "$example" ]; then
    error "Example not found: $example"
    return 1
  fi
  version=$(sed -nE "s/^[[:space:]]*#import[[:space:]]+\"@preview\/modern-whs-${template}:([^\"]+)\".*/\1/p" "$example")
  if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    error "Expected one versioned import of @preview/modern-whs-$template in $example"
    return 1
  fi
  printf '%s\n' "$version"
}

check_template() {
  local template="$1" version example_version
  version=$(get_version "$template")
  example_version=$(get_example_version "$template")
  if [ "$version" != "$example_version" ]; then
    error "$template: typst.toml is $version, but example/main.typ imports $example_version. Run sync.sh to update both versions together."
    return 1
  fi
  info "$template: manifest and example use $version"
}

# Sync sources these helpers; running this file directly only validates versions.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  found=false
  for manifest in "$TEMPLATES_REPO"/templates/*/typst.toml; do
    [ -f "$manifest" ] || continue
    found=true
    check_template "$(basename "$(dirname "$manifest")")"
  done
  if ! "$found"; then
    error "No templates found in $TEMPLATES_REPO/templates"
    exit 1
  fi
fi
