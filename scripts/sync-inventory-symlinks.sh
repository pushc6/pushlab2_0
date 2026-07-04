#!/bin/bash
# sync-inventory-symlinks.sh
#
# Synchronizes host_vars and group_vars symlinks at the inventories/ level.
# This is required because when Ansible uses a directory as inventory, it looks
# for host_vars at inventories/host_vars/, not in each subdirectory.
#
# This script is run automatically by pre-commit to ensure symlinks stay in sync.
#
# Reconciliation rules for each entry at inventories/{host,group}_vars/<name>:
#   - missing            -> create symlink to the subdirectory copy
#   - valid symlink      -> leave as-is (even if it points at a different
#                           subdirectory, e.g. prod/ vs manual/ — first source wins)
#   - broken symlink     -> repoint at the subdirectory copy
#   - regular file, identical to the subdirectory copy -> replace with symlink
#   - regular file, DIFFERENT from the subdirectory copy -> fail loudly; a
#     shadow copy like this makes the two inventories disagree and must be
#     reconciled by hand (merge into the subdirectory copy, then delete it)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INVENTORIES_DIR="$REPO_ROOT/ansible/inventories"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Syncing inventory host_vars/group_vars symlinks...${NC}"

# Create parent directories if they don't exist
mkdir -p "$INVENTORIES_DIR/host_vars"
mkdir -p "$INVENTORIES_DIR/group_vars"

# Track if any changes were made / conflicts found
CHANGES_MADE=0
CONFLICTS=0

# Ensure inventories/<kind>/<name> is a symlink to the subdirectory copy,
# following the reconciliation rules documented above.
# $1 = source path (the real file/dir in a subdirectory)
# $2 = relative symlink target (e.g. ../manual/host_vars/foo.yml)
# $3 = destination directory (inventories/host_vars or inventories/group_vars)
ensure_symlink() {
    local source="$1"
    local rel_path="$2"
    local dest_dir="$3"
    local name
    name="$(basename "$source")"
    local dest="$dest_dir/$name"

    if [ -L "$dest" ]; then
        if [ -e "$dest" ]; then
            # Valid symlink (possibly to another subdirectory) — leave it.
            return 0
        fi
        echo -e "${YELLOW}  ~ Repointing broken symlink: $name -> $rel_path${NC}"
        ln -sfn "$rel_path" "$dest"
        CHANGES_MADE=1
    elif [ -e "$dest" ]; then
        # Regular file (or directory) shadowing the subdirectory copy.
        if diff -rq "$dest" "$source" >/dev/null 2>&1; then
            echo -e "${GREEN}  + Replacing identical copy with symlink: $name -> $rel_path${NC}"
            rm -rf "$dest"
            ln -s "$rel_path" "$dest"
            CHANGES_MADE=1
        else
            echo -e "${RED}  ! CONFLICT: $dest is a regular copy that DIFFERS from $source${NC}"
            echo -e "${RED}    Merge the differences into $source, delete the copy, and re-run.${NC}"
            CONFLICTS=1
        fi
    else
        ln -s "$rel_path" "$dest"
        echo -e "${GREEN}  + Created symlink: $name -> $rel_path${NC}"
        CHANGES_MADE=1
    fi
}

# Function to remove broken symlinks (sources that no longer exist anywhere)
cleanup_broken_symlinks() {
    local dir="$1"
    for link in "$dir"/*; do
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            echo -e "${RED}  - Removing broken symlink: $(basename "$link")${NC}"
            rm "$link"
            CHANGES_MADE=1
        fi
    done
}

# Sync host_vars/group_vars from all inventory subdirectories
for kind in host_vars group_vars; do
    echo "Checking $kind..."
    for subdir in "$INVENTORIES_DIR"/*/; do
        subdir_name=$(basename "$subdir")
        # Skip the parent host_vars/group_vars directories
        if [ "$subdir_name" = "host_vars" ] || [ "$subdir_name" = "group_vars" ]; then
            continue
        fi

        if [ -d "$subdir/$kind" ]; then
            for item in "$subdir/$kind"/*; do
                if [ -e "$item" ]; then
                    ensure_symlink "$item" "../${subdir_name}/$kind/$(basename "$item")" "$INVENTORIES_DIR/$kind"
                fi
            done
        fi
    done
done

# Clean up broken symlinks
echo "Checking for broken symlinks..."
cleanup_broken_symlinks "$INVENTORIES_DIR/host_vars"
cleanup_broken_symlinks "$INVENTORIES_DIR/group_vars"

if [ $CONFLICTS -eq 1 ]; then
    echo -e "${RED}Drifted shadow copies found — resolve the conflicts above before committing.${NC}"
    exit 1
elif [ $CHANGES_MADE -eq 1 ]; then
    echo -e "${YELLOW}Symlinks updated. Please stage the changes and commit again.${NC}"
    # Add the symlinks to git staging
    git add "$INVENTORIES_DIR/host_vars" "$INVENTORIES_DIR/group_vars" 2>/dev/null || true
    exit 1
else
    echo -e "${GREEN}All symlinks are up to date.${NC}"
    exit 0
fi
