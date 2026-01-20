#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Repository paths
TEMPLATES_REPO="$HOME/dev/whs-typst-templates"
PACKAGES_REPO="$HOME/dev/typst-packages"

# GitHub sync repos
SOURCE_REPO="typst/typst-packages"
TARGET_REPO="alex289/typst-packages"

# Function to display colored messages
info() {
  echo -e "${GREEN}INFO: ${1}${NC}"
}

warn() {
  echo -e "${YELLOW}WARN: ${1}${NC}"
}

error() {
  echo -e "${RED}ERROR: ${1}${NC}"
}

# Function to get the version from typst.toml
get_version() {
  local toml_file="$1/typst.toml"
  if [ ! -f "$toml_file" ]; then
    error "typst.toml not found in $1"
    return 1
  fi

  # Extract version using sed (assumes version is in a specific format)
  version=$(grep '^version = ' "$toml_file" | sed -E 's/^version = "(.*)"/\1/')

  if [ -z "$version" ]; then
    error "Could not extract version from $toml_file"
    return 1
  fi

  echo "$version"
}

# --- Main Script ---

# 1. Choose the subdirectory
pushd "$TEMPLATES_REPO/templates" || exit 1

options=()
for dir in */; do
  options+=("$(basename "$dir")")
done

if [ ${#options[@]} -eq 0 ]; then
  error "No subdirectories found in $TEMPLATES_REPO/templates"
  exit 1
fi

echo "Available templates:"
select chosen_dir in "${options[@]}"; do
  if [ -n "$chosen_dir" ]; then
    break
  else
    error "Invalid selection."
  fi
done

if [ -z "$chosen_dir" ]; then
  error "No directory selected."
  exit 1
fi

chosen_path="$TEMPLATES_REPO/templates/$chosen_dir"
popd || exit 1

info "Selected directory: $chosen_dir"

# 2. Get the version
version=$(get_version "$chosen_path")
if [ $? -ne 0 ]; then
  exit 1
fi
info "Version: $version"

# 3. Checkout main and pull in typst-packages
pushd "$PACKAGES_REPO" || exit 1
gh repo sync $TARGET_REPO --source $SOURCE_REPO
git checkout main &>/dev/null || { error "Failed to checkout main"; exit 1; }
git pull &>/dev/null || { error "Failed to pull main"; exit 1; }
info "Checked out and pulled main in $PACKAGES_REPO"

# 4. Checkout a new branch
branch_name="whs-${chosen_dir%-*/}" # Remove trailing slash
if git show-ref --verify --quiet "refs/heads/$branch_name"; then
  git branch -D "$branch_name" &>/dev/null || { error "Failed to delete existing branch $branch_name"; exit 1; }
  info "Deleted existing branch: $branch_name"
fi
git checkout -b "$branch_name" &>/dev/null || { error "Failed to create branch $branch_name"; exit 1; }
info "Created and checked out branch: $branch_name"

# 5. Copy the content
target_dir="packages/preview/modern-whs-${chosen_dir%-*/}/$version"
rm -rf "$target_dir" # Remove the directory if it exists
mkdir -p "$target_dir"
cp -r "$chosen_path/"* "$target_dir/" || { error "Failed to copy files"; exit 1; }
cp "$TEMPLATES_REPO/LICENSE" "$target_dir/" || { error "Failed to copy LICENSE"; exit 1; }
info "Copied files to $target_dir"

# 6. Commit the changes
git add "$target_dir" &>/dev/null || { error "Failed to add files to git"; exit 1; }
commit_message="modern-whs-${chosen_dir%-*/}:$version"
git commit -m "$commit_message" &>/dev/null || { error "Failed to commit changes"; exit 1; }
info "Committed changes with message: $commit_message"

# 7. Confirm and push
read -r -p "Push changes to remote? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  git push origin "$branch_name" || { error "Failed to push changes"; exit 1; }
  info "Pushed changes to origin/$branch_name"
else
  warn "Push aborted."
fi

popd || exit 1

info "Script completed."

exit 0
