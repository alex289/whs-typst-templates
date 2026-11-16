#!/bin/bash
set -euo pipefail

# Run from any directory; override the packages checkout when needed.
TEMPLATES_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEMPLATES_REPO/scripts/check-versions.sh"
PACKAGES_REPO="${PACKAGES_REPO:-$HOME/dev/typst-packages}"
SOURCE_REPO="typst/typst-packages"
TARGET_REPO="alex289/typst-packages"

warn() { printf '%bWARN: %s%b\n' "$YELLOW" "$1" "$NC"; }

usage() {
  cat <<'EOF'
Usage: ./sync.sh [template]

Without a template, sync prompts for one. Every sync bumps the patch version,
updates the example import, and commits both files in this repository before
copying the release into typst-packages. Both checkouts must be clean.
The new version is higher than the local and published versions.
Pushing the packages branch is optional.
EOF
}

chosen_dir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) error "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [ -n "$chosen_dir" ]; then
        error "Choose only one template"
        exit 1
      fi
      chosen_dir="$1"
      ;;
  esac
  shift
done

options=()
for manifest in "$TEMPLATES_REPO"/templates/*/typst.toml; do
  [ -f "$manifest" ] || continue
  template="$(basename "$(dirname "$manifest")")"
  [[ "$template" =~ ^[a-z0-9-]+$ ]] || continue
  options+=("$template")
done
if [ "${#options[@]}" -eq 0 ]; then
  error "No templates found in $TEMPLATES_REPO/templates"
  exit 1
fi

if [ -n "$chosen_dir" ]; then
  valid=false
  for template in "${options[@]}"; do
    if [ "$template" = "$chosen_dir" ]; then valid=true; break; fi
  done
  if ! "$valid"; then
    error "Unknown template: $chosen_dir"
    exit 1
  fi
fi

if [ -z "$chosen_dir" ]; then
  echo "Available templates:"
  select chosen_dir in "${options[@]}"; do
    if [ -n "$chosen_dir" ]; then break; fi
    error "Invalid selection."
  done
fi
if [ -z "$chosen_dir" ]; then
  error "No template selected"
  exit 1
fi

chosen_path="$TEMPLATES_REPO/templates/$chosen_dir"
package_name="modern-whs-$chosen_dir"
version=$(get_version "$chosen_dir")
# Validate that there is an import we can update, even if its version is stale.
get_example_version "$chosen_dir" >/dev/null

source_status=$(git -C "$TEMPLATES_REPO" status --porcelain)
if [ -n "$source_status" ]; then
  error "Commit or stash changes in $TEMPLATES_REPO before syncing."
  exit 1
fi
packages_status=$(git -C "$PACKAGES_REPO" status --porcelain)
if [ -n "$packages_status" ]; then
  error "Commit or stash changes in $PACKAGES_REPO before syncing."
  exit 1
fi

# Check against refreshed upstream main before changing either release's files.
cd "$PACKAGES_REPO"
gh repo sync "$TARGET_REPO" --source "$SOURCE_REPO"
git checkout main
git pull --ff-only

# Start above both the local version and every release already on upstream main.
IFS=. read -r major minor patch <<< "$version"
for release_dir in "packages/preview/$package_name/"*; do
  [ -d "$release_dir" ] || continue
  published_version="${release_dir##*/}"
  [[ "$published_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || continue
  IFS=. read -r published_major published_minor published_patch <<< "$published_version"
  if (( published_major > major ||
        (published_major == major && published_minor > minor) ||
        (published_major == major && published_minor == minor && published_patch > patch) )); then
    major="$published_major"
    minor="$published_minor"
    patch="$published_patch"
  fi
done
next_version="$major.$minor.$((patch + 1))"
info "Bumping $package_name from $version to $next_version"
version="$next_version"
target_dir="packages/preview/$package_name/$version"
if [ -e "$target_dir" ]; then
  error "Release path already exists: $target_dir"
  exit 1
fi

commit_message="$package_name:$version"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
awk -v version="$version" '
  /^[[:space:]]*\[/ { package = ($0 ~ /^[[:space:]]*\[package\][[:space:]]*$/) }
  package && /^[[:space:]]*version[[:space:]]*=/ { sub(/"[^"]*"/, "\"" version "\"") }
  { print }
' "$chosen_path/typst.toml" > "$temp_dir/typst.toml"
sed -E "s/^([[:space:]]*#import[[:space:]]+\"@preview\/modern-whs-${chosen_dir}:)[^\"]+(\".*)$/\1$version\2/" \
  "$chosen_path/example/main.typ" > "$temp_dir/main.typ"
cp "$temp_dir/typst.toml" "$chosen_path/typst.toml"
cp "$temp_dir/main.typ" "$chosen_path/example/main.typ"
check_template "$chosen_dir"
git -C "$TEMPLATES_REPO" add -- "templates/$chosen_dir/typst.toml" "templates/$chosen_dir/example/main.typ"
git -C "$TEMPLATES_REPO" commit -m "chore: bump $commit_message"
info "Committed $commit_message in $TEMPLATES_REPO"

branch_name="whs-$chosen_dir"
if git show-ref --verify --quiet "refs/heads/$branch_name"; then
  git branch -D "$branch_name"
fi
git checkout -b "$branch_name"

mkdir -p "$target_dir"
cp -R "$chosen_path/"* "$target_dir/"
cp "$TEMPLATES_REPO/LICENSE" "$target_dir/"
git add -- "$target_dir"
git commit -m "$commit_message"
info "Committed $commit_message in $PACKAGES_REPO"

response=""
read -r -p "Push changes to remote? [y/N] " response || true
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  git push origin "$branch_name"
else
  warn "Push aborted."
fi

info "Script completed."
