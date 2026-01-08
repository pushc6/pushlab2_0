#!/bin/bash
# sync-inventory-symlinks.sh
#
# Synchronizes host_vars and group_vars symlinks at the inventories/ level.
# This is required because when Ansible uses a directory as inventory, it looks
# for host_vars at inventories/host_vars/, not in each subdirectory.
#
# This script is run automatically by pre-commit to ensure symlinks stay in sync.

set -e

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

# Track if any changes were made
CHANGES_MADE=0

# Function to create symlink if it doesn't exist
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$(basename "$source")"

    if [ ! -e "$target/$name" ]; then
        ln -sf "$source" "$target/"
        echo -e "${GREEN}  + Created symlink: $name${NC}"
        CHANGES_MADE=1
    fi
}

# Function to remove broken symlinks
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

# Sync host_vars from all subdirectories
echo "Checking host_vars..."
for subdir in "$INVENTORIES_DIR"/*/; do
    subdir_name=$(basename "$subdir")
    # Skip the parent host_vars/group_vars directories
    if [ "$subdir_name" = "host_vars" ] || [ "$subdir_name" = "group_vars" ]; then
        continue
    fi

    if [ -d "$subdir/host_vars" ]; then
        for item in "$subdir/host_vars"/*; do
            if [ -e "$item" ]; then
                # Create relative symlink
                rel_path="../${subdir_name}/host_vars/$(basename "$item")"
                name="$(basename "$item")"
                if [ ! -e "$INVENTORIES_DIR/host_vars/$name" ]; then
                    ln -sf "$rel_path" "$INVENTORIES_DIR/host_vars/"
                    echo -e "${GREEN}  + Created symlink: host_vars/$name -> $rel_path${NC}"
                    CHANGES_MADE=1
                fi
            fi
        done
    fi
done

# Sync group_vars from all subdirectories
echo "Checking group_vars..."
for subdir in "$INVENTORIES_DIR"/*/; do
    subdir_name=$(basename "$subdir")
    # Skip the parent host_vars/group_vars directories
    if [ "$subdir_name" = "host_vars" ] || [ "$subdir_name" = "group_vars" ]; then
        continue
    fi

    if [ -d "$subdir/group_vars" ]; then
        for item in "$subdir/group_vars"/*; do
            if [ -e "$item" ]; then
                # Create relative symlink
                rel_path="../${subdir_name}/group_vars/$(basename "$item")"
                name="$(basename "$item")"
                if [ ! -e "$INVENTORIES_DIR/group_vars/$name" ]; then
                    ln -sf "$rel_path" "$INVENTORIES_DIR/group_vars/"
                    echo -e "${GREEN}  + Created symlink: group_vars/$name -> $rel_path${NC}"
                    CHANGES_MADE=1
                fi
            fi
        done
    fi
done

# Clean up broken symlinks
echo "Checking for broken symlinks..."
cleanup_broken_symlinks "$INVENTORIES_DIR/host_vars"
cleanup_broken_symlinks "$INVENTORIES_DIR/group_vars"

if [ $CHANGES_MADE -eq 1 ]; then
    echo -e "${YELLOW}Symlinks updated. Please stage the changes and commit again.${NC}"
    # Add the symlinks to git staging
    git add "$INVENTORIES_DIR/host_vars" "$INVENTORIES_DIR/group_vars" 2>/dev/null || true
    exit 1
else
    echo -e "${GREEN}All symlinks are up to date.${NC}"
    exit 0
fi
