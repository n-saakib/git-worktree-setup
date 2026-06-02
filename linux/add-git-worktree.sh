#!/bin/bash

# Git worktree and symlink management script — Linux
# Usage: git-worktree <command> [-y]
#   -y  Accept all defaults without prompting (still prompts for required values)

set -e

find_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.bare" ]]; then echo "$current_dir"; return 0; fi
        if [[ -d "$current_dir/.git" ]];  then echo "$current_dir"; return 0; fi
        current_dir="$(dirname "$current_dir")"
    done
    echo "" >&2; return 1
}

# confirm <prompt> [auto]
# Returns 0 for yes, 1 for no. Defaults to yes on empty input or when auto=true.
confirm() {
    local prompt="$1" auto="${2:-false}"
    if [[ "$auto" == true ]]; then
        echo "$prompt (Y/n): Y"
        return 0
    fi
    local response
    while true; do
        read -p "$prompt (Y/n): " response
        response="${response,,}"
        case "${response:-y}" in
            y|yes|ye) return 0 ;;
            n|no)     return 1 ;;
            *) echo "Please enter y/yes or n/no." ;;
        esac
    done
}

setup_shared_links() {
    local root_dir="$1" shared_dir="${2:-$1/Shared}"

    if [[ ! -d "$shared_dir" ]]; then
        echo "⚠ Warning: Shared folder not found at $shared_dir"
        echo "Skipping symlink setup"
        return 0
    fi

    echo "Setting up shared symlinks..."
    echo "  Shared directory: $shared_dir"
    echo "  Target directory: $PWD"
    echo ""

    shopt -s dotglob
    for item in "$shared_dir"/*; do
        local item_name link_path
        item_name="$(basename "$item")"
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

# Resolve shared dir from user input (empty = default)
resolve_shared_dir() {
    local root_dir="$1" input="$2"
    if [[ -z "$input" ]]; then
        echo "$root_dir/Shared"
    elif [[ "$input" != /* ]]; then
        echo "$root_dir/$input"
    else
        echo "$input"
    fi
}

create_worktree_only() {
    local root_dir="$1" use_defaults="$2"
    local bare_dir="$root_dir/.bare"
    # For bare repos: run git commands from inside .bare (it IS the repo).
    # For standard repos: run from the root (parent of .git), not inside .git/.
    local git_dir
    if [[ -d "$bare_dir" ]]; then
        git_dir="$bare_dir"
    else
        git_dir="$root_dir"
    fi

    if [[ ! -d "$git_dir" ]]; then
        echo "Error: Git directory not found" >&2; return 1
    fi

    echo "========================================="
    echo "  Git Worktree Creation"
    echo "========================================="
    echo ""

    # Worktree path — no default, always prompt
    read -p "Enter worktree folder path: " worktree_path
    if [[ -z "$worktree_path" ]]; then
        echo "Error: Worktree folder path is required" >&2; return 1
    fi
    [[ "$worktree_path" != /* ]] && worktree_path="$root_dir/$worktree_path"

    # Branch name — defaults to folder name
    local branch_name
    if [[ "$use_defaults" == true ]]; then
        branch_name="$(basename "$worktree_path")"
        echo "Branch name: $branch_name (default)"
    else
        read -p "Enter branch name (default: folder name '$(basename "$worktree_path")'): " branch_name
        branch_name="${branch_name:-$(basename "$worktree_path")}"
    fi

    # Source branch — defaults to main
    local source_branch
    if [[ "$use_defaults" == true ]]; then
        source_branch="main"
        echo "Source branch: main (default)"
    else
        read -p "Enter source branch (default: main): " source_branch
        source_branch="${source_branch:-main}"
    fi

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path:  $worktree_path"
    echo "  Branch:         $branch_name"
    echo "  Source Branch:  $source_branch"
    echo ""

    cd "$git_dir"
    if git show-ref --quiet --verify "refs/heads/$branch_name" 2>/dev/null; then
        echo "✓ Branch '$branch_name' already exists"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?" "$use_defaults"; then
            echo "Cancelled." >&2; return 1
        fi
        if ! git show-ref --quiet --verify "refs/heads/$source_branch" 2>/dev/null; then
            echo "Error: Source branch '$source_branch' does not exist" >&2; return 1
        fi
        echo "Creating branch '$branch_name' from '$source_branch'..."
        git branch "$branch_name" "$source_branch"
        echo "✓ Branch created"
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    git worktree add "$worktree_path" "$branch_name"
    echo "✓ Worktree created"

    echo ""
    echo "========================================="
    echo "✓ Worktree creation complete!"
    echo "========================================="
    echo "  $worktree_path"
    echo ""
}

create_links_only() {
    local root_dir="$1" use_defaults="$2"

    echo "========================================="
    echo "  Setup Shared Symlinks"
    echo "========================================="
    echo ""

    local custom_shared_dir
    if [[ "$use_defaults" == true ]]; then
        echo "Shared folder: <root/Shared> (default)"
        custom_shared_dir=""
    else
        read -p "Enter shared folder path (default: <root/Shared>): " custom_shared_dir
    fi

    setup_shared_links "$root_dir" "$(resolve_shared_dir "$root_dir" "$custom_shared_dir")"

    echo ""
    echo "========================================="
    echo "✓ Symlink setup complete!"
    echo "========================================="
    echo ""
}

create_worktree_with_links() {
    local root_dir="$1" use_defaults="$2"
    local bare_dir="$root_dir/.bare"
    # For bare repos: run git commands from inside .bare (it IS the repo).
    # For standard repos: run from the root (parent of .git), not inside .git/.
    local git_dir
    if [[ -d "$bare_dir" ]]; then
        git_dir="$bare_dir"
    else
        git_dir="$root_dir"
    fi

    if [[ ! -d "$git_dir" ]]; then
        echo "Error: Git directory not found" >&2; return 1
    fi

    echo "========================================="
    echo "  Git Worktree Creation + Symlinks"
    echo "========================================="
    echo ""

    # Worktree path — no default, always prompt
    read -p "Enter worktree folder path: " worktree_path
    if [[ -z "$worktree_path" ]]; then
        echo "Error: Worktree folder path is required" >&2; return 1
    fi
    [[ "$worktree_path" != /* ]] && worktree_path="$root_dir/$worktree_path"

    # Branch name
    local branch_name
    if [[ "$use_defaults" == true ]]; then
        branch_name="$(basename "$worktree_path")"
        echo "Branch name: $branch_name (default)"
    else
        read -p "Enter branch name (default: folder name '$(basename "$worktree_path")'): " branch_name
        branch_name="${branch_name:-$(basename "$worktree_path")}"
    fi

    # Source branch
    local source_branch
    if [[ "$use_defaults" == true ]]; then
        source_branch="main"
        echo "Source branch: main (default)"
    else
        read -p "Enter source branch (default: main): " source_branch
        source_branch="${source_branch:-main}"
    fi

    # Shared folder
    local custom_shared_dir
    if [[ "$use_defaults" == true ]]; then
        echo "Shared folder: <root/Shared> (default)"
        custom_shared_dir=""
    else
        read -p "Enter shared folder path (default: <root/Shared>): " custom_shared_dir
    fi

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path:  $worktree_path"
    echo "  Branch:         $branch_name"
    echo "  Source Branch:  $source_branch"
    echo ""

    cd "$git_dir"
    if git show-ref --quiet --verify "refs/heads/$branch_name" 2>/dev/null; then
        echo "✓ Branch '$branch_name' already exists"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?" "$use_defaults"; then
            echo "Cancelled." >&2; return 1
        fi
        if ! git show-ref --quiet --verify "refs/heads/$source_branch" 2>/dev/null; then
            echo "Error: Source branch '$source_branch' does not exist" >&2; return 1
        fi
        echo "Creating branch '$branch_name' from '$source_branch'..."
        git branch "$branch_name" "$source_branch"
        echo "✓ Branch created"
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    git worktree add "$worktree_path" "$branch_name"
    echo "✓ Worktree created"

    echo ""
    cd "$worktree_path"
    setup_shared_links "$root_dir" "$(resolve_shared_dir "$root_dir" "$custom_shared_dir")"

    echo ""
    echo "========================================="
    echo "✓ Worktree creation + symlinks complete!"
    echo "========================================="
    echo "  $worktree_path"
    echo ""
}

show_help() {
    echo "Git Worktree Management Tool"
    echo "============================="
    echo ""
    echo "Usage: $(basename "$0") <command> [-y]"
    echo ""
    echo "  -y  Accept all defaults (still prompts for values with no default)"
    echo ""
    echo "Commands:"
    echo ""
    echo "  worktree, wt   Create a new git worktree"
    echo "  links, ln      Setup shared symlinks (custom path supported)"
    echo "  all, setup, a  Create worktree and setup symlinks"
    echo ""
}

main() {
    local root_dir command="" use_defaults=false

    for arg in "$@"; do
        case "$arg" in
            -y) use_defaults=true ;;
            -*) ;;
            *)  [[ -z "$command" ]] && command="$arg" ;;
        esac
    done

    root_dir="$(find_root)"
    if [[ -z "$root_dir" ]]; then
        echo "Error: Could not find repository root" >&2
        echo "Make sure you're inside a git repository (.git or .bare)" >&2
        return 1
    fi

    case "$command" in
        "")              show_help ;;
        worktree|wt)     create_worktree_only "$root_dir" "$use_defaults" ;;
        links|ln)        create_links_only "$root_dir" "$use_defaults" ;;
        all|setup|a)     create_worktree_with_links "$root_dir" "$use_defaults" ;;
        *)
            echo "Unknown command: $command" >&2
            echo ""
            show_help
            return 1
            ;;
    esac
}

main "$@"
