#!/bin/bash

set -e

# Git worktree and symlink management script
# Supports creating worktrees, setting up shared symlinks, or both

# Prompt for yes/no with default to yes
# Accepts: y, yes, ye (case insensitive) for yes
# Accepts: n, no (case insensitive) for no
# Returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local response
    read -p "$prompt (Y/n): " response
    response="${response,,}"  # Convert to lowercase

    # Default to yes if empty
    if [[ -z "$response" ]]; then
        return 0
    fi

    case "$response" in
        y|yes|ye)
            return 0
            ;;
        n|no)
            return 1
            ;;
        *)
            echo "Invalid response. Please enter y/yes/ye or n/no."
            confirm "$prompt"
            return $?
            ;;
    esac
}

find_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.bare" ]]; then
            echo "$current_dir"
            return 0
        fi
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done
    echo "" >&2
    return 1
}

# Setup shared symlinks with custom path option
setup_shared_links() {
    local root_dir="$1"
    local shared_dir="${2:-$root_dir/Shared}"

    if [[ ! -d "$shared_dir" ]]; then
        echo "⚠ Warning: Shared folder not found at $shared_dir"
        echo "Skipping symlink setup"
        return 0
    fi

    echo "Setting up shared symlinks..."
    echo "  Root directory: $root_dir"
    echo "  Shared directory: $shared_dir"
    echo "  Current directory: $PWD"
    echo ""

    shopt -s dotglob

    for item in "$shared_dir"/*; do
        item_name=$(basename "$item")
        link_path="$PWD/$item_name"

        if [[ -e "$link_path" ]] || [[ -L "$link_path" ]]; then
            echo "⚠ Skipping '$item_name' - already exists"
            continue
        fi

        ln -s "$item" "$link_path"
        echo "✓ Created symlink: $item_name"
    done

    echo ""
    echo "✓ Done! All shared items have been symlinked."
}

# Create a new worktree only
create_worktree_only() {
    local root_dir="$1"
    local bare_dir="$root_dir/.bare"

    echo "========================================="
    echo "  Git Worktree Creation"
    echo "========================================="
    echo ""

    local git_dir="$bare_dir"
    if [[ ! -d "$bare_dir" ]]; then
        git_dir="$root_dir/.git"
    fi

    if [[ ! -d "$git_dir" ]]; then
        echo "Error: Git directory not found" >&2
        return 1
    fi

    read -p "Enter worktree folder path: " worktree_path
    if [[ -z "$worktree_path" ]]; then
        echo "Error: Worktree folder path is required" >&2
        return 1
    fi

    if [[ "$worktree_path" != /* ]]; then
        worktree_path="$root_dir/$worktree_path"
    fi

    read -p "Enter branch name to use (leave empty to use folder name): " branch_name
    if [[ -z "$branch_name" ]]; then
        branch_name=$(basename "$worktree_path")
        echo "Using folder name as branch name: $branch_name"
    fi

    read -p "Enter source branch name (leave empty to use 'main'): " source_branch
    if [[ -z "$source_branch" ]]; then
        source_branch="main"
        echo "Using 'main' as source branch"
    fi

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path: $worktree_path"
    echo "  Branch Name: $branch_name"
    echo "  Source Branch: $source_branch"
    echo ""

    cd "$git_dir"
    if git show-ref --quiet --verify "refs/heads/$branch_name" 2>/dev/null; then
        echo "✓ Branch '$branch_name' already exists"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?"; then
            echo "Cancelled. Branch not created." >&2
            return 1
        fi

        if ! git show-ref --quiet --verify "refs/heads/$source_branch" 2>/dev/null; then
            echo "Error: Source branch '$source_branch' does not exist" >&2
            return 1
        fi

        echo "Creating branch '$branch_name' from '$source_branch'..."
        git branch "$branch_name" "$source_branch"
        echo "✓ Branch created successfully"
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    git worktree add "$worktree_path" "$branch_name"
    echo "✓ Worktree created successfully"

    echo ""
    echo "========================================="
    echo "✓ Worktree creation complete!"
    echo "========================================="
    echo "You are now in the worktree directory:"
    echo "  $worktree_path"
    echo ""
}

# Create symlinks only with custom path option
create_links_only() {
    local root_dir="$1"

    echo "========================================="
    echo "  Setup Shared Symlinks"
    echo "========================================="
    echo ""

    read -p "Enter shared folder path (leave empty to use '<root/Shared>'): " custom_shared_dir

    if [[ -z "$custom_shared_dir" ]]; then
        setup_shared_links "$root_dir"
    else
        if [[ "$custom_shared_dir" != /* ]]; then
            custom_shared_dir="$root_dir/$custom_shared_dir"
        fi
        setup_shared_links "$root_dir" "$custom_shared_dir"
    fi

    echo ""
    echo "========================================="
    echo "✓ Symlink setup complete!"
    echo "========================================="
    echo ""
}

# Create worktree and setup symlinks
create_worktree_with_links() {
    local root_dir="$1"
    local bare_dir="$root_dir/.bare"

    echo "========================================="
    echo "  Git Worktree Creation + Symlinks"
    echo "========================================="
    echo ""

    local git_dir="$bare_dir"
    if [[ ! -d "$bare_dir" ]]; then
        git_dir="$root_dir/.git"
    fi

    if [[ ! -d "$git_dir" ]]; then
        echo "Error: Git directory not found" >&2
        return 1
    fi

    read -p "Enter worktree folder path: " worktree_path
    if [[ -z "$worktree_path" ]]; then
        echo "Error: Worktree folder path is required" >&2
        return 1
    fi

    if [[ "$worktree_path" != /* ]]; then
        worktree_path="$root_dir/$worktree_path"
    fi

    read -p "Enter branch name to use (leave empty to use folder name): " branch_name
    if [[ -z "$branch_name" ]]; then
        branch_name=$(basename "$worktree_path")
        echo "Using folder name as branch name: $branch_name"
    fi

    read -p "Enter source branch name (leave empty to use 'main'): " source_branch
    if [[ -z "$source_branch" ]]; then
        source_branch="main"
        echo "Using 'main' as source branch"
    fi

    read -p "Enter shared folder path (leave empty to use '<root/Shared>'): " custom_shared_dir

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path: $worktree_path"
    echo "  Branch Name: $branch_name"
    echo "  Source Branch: $source_branch"
    if [[ -n "$custom_shared_dir" ]]; then
        echo "  Shared Folder: $custom_shared_dir"
    fi
    echo ""

    cd "$git_dir"
    if git show-ref --quiet --verify "refs/heads/$branch_name" 2>/dev/null; then
        echo "✓ Branch '$branch_name' already exists"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?"; then
            echo "Cancelled. Branch not created." >&2
            return 1
        fi

        if ! git show-ref --quiet --verify "refs/heads/$source_branch" 2>/dev/null; then
            echo "Error: Source branch '$source_branch' does not exist" >&2
            return 1
        fi

        echo "Creating branch '$branch_name' from '$source_branch'..."
        git branch "$branch_name" "$source_branch"
        echo "✓ Branch created successfully"
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    git worktree add "$worktree_path" "$branch_name"
    echo "✓ Worktree created successfully"

    echo ""
    cd "$worktree_path"
    if [[ -z "$custom_shared_dir" ]]; then
        setup_shared_links "$root_dir"
    else
        if [[ "$custom_shared_dir" != /* ]]; then
            custom_shared_dir="$root_dir/$custom_shared_dir"
        fi
        setup_shared_links "$root_dir" "$custom_shared_dir"
    fi

    echo ""
    echo "========================================="
    echo "✓ Worktree creation + symlinks complete!"
    echo "========================================="
    echo "You are now in the worktree directory:"
    echo "  $worktree_path"
    echo ""
}

# Main menu
main() {
    root_dir=$(find_root)
    if [[ -z "$root_dir" ]]; then
        echo "Error: Could not find repository root" >&2
        echo "Make sure you're inside a git repository (with .git or .bare folder)" >&2
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        echo "Git Worktree Management Tool"
        echo "============================="
        echo ""
        echo "Available commands:"
        echo ""
        echo "  Worktree only:"
        echo "    git-worktree worktree     - Create a new git worktree"
        echo "    git-worktree wt           - Shorthand for worktree"
        echo ""
        echo "  Symlinks only:"
        echo "    git-worktree links        - Setup shared symlinks (with custom path option)"
        echo "    git-worktree ln           - Shorthand for links"
        echo ""
        echo "  Both:"
        echo "    git-worktree all          - Create worktree and setup symlinks"
        echo "    git-worktree setup        - Alias for 'all'"
        echo "    git-worktree a            - Shorthand for 'all'"
        echo ""
        return 0
    fi

    case "$1" in
        worktree|wt)
            create_worktree_only "$root_dir"
            ;;
        links|ln)
            create_links_only "$root_dir"
            ;;
        all|setup|a)
            create_worktree_with_links "$root_dir"
            ;;
        *)
            echo "Unknown command: $1" >&2
            echo ""
            echo "Available commands:"
            echo "  worktree, wt  - Create worktree only"
            echo "  links, ln     - Setup symlinks only"
            echo "  all, setup, a - Create worktree and symlinks"
            echo ""
            echo "Run with no arguments to see full help"
            return 1
            ;;
    esac
}

main "$@"
