#!/bin/bash

# Git worktree and symlink management script — Linux
# Usage: git-worktree <command> [-y]
#   -y  Accept all defaults without prompting (still prompts for required values)

set -e

find_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.bare" ]]; then echo "$current_dir"; return 0; fi
        # Skip .git check when inside a .bare directory — bare repos can contain
        # a .git subdir (e.g. created by GitKraken), which is not the worktree root.
        if [[ -d "$current_dir/.git" ]] && [[ "$(basename "$current_dir")" != ".bare" ]]; then
            echo "$current_dir"; return 0
        fi
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
        read -rp "$prompt (Y/n): " response
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

    local dotglob_was_set=false
    shopt -q dotglob && dotglob_was_set=true
    shopt -s dotglob
    local fail_count=0
    local found_any=false
    for item in "$shared_dir"/*; do
        [[ -e "$item" ]] || continue
        found_any=true
        local item_name link_path
        item_name="$(basename "$item")"
        link_path="$PWD/$item_name"
        if [[ -e "$link_path" ]] || [[ -L "$link_path" ]]; then
            echo "⚠ Skipping '$item_name' - already exists"
            continue
        fi
        if ! ln -s "$item" "$link_path" 2>/dev/null; then
            fail_count=$((fail_count + 1))
            echo "⚠ Error creating symlink for '$item_name'"
            continue
        fi
        echo "✓ Created symlink: $item_name"
    done
    [[ "$dotglob_was_set" == true ]] || shopt -u dotglob
    [[ "$found_any" == false ]] && echo "No items found in $shared_dir"

    if [[ "$fail_count" -gt 0 ]]; then
        echo ""
        echo "⚠ Done with $fail_count failed symlink(s)."
    else
        echo ""
        echo "✓ Done! All shared items have been symlinked."
    fi
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

# branch_exists_local_or_remote <git_dir> <branch_name>
# Sets global _BRANCH_LOCATION to: "local", "remote", or "notfound"
branch_exists_local_or_remote() {
    local git_dir="$1" branch="$2"
    _BRANCH_LOCATION="notfound"

    if git -C "$git_dir" show-ref --quiet --verify "refs/heads/$branch" 2>/dev/null; then
        _BRANCH_LOCATION="local"
        return 0
    fi

    local remote
    remote="$(git -C "$git_dir" remote 2>/dev/null | head -1)"
    if [[ -z "$remote" ]]; then
        return 0
    fi

    if git -C "$git_dir" ls-remote --exit-code --heads "$remote" "$branch" \
           >/dev/null 2>/dev/null; then
        _BRANCH_LOCATION="remote"
    fi
    return 0
}

create_worktree_only() {
    local root_dir="$1" use_defaults="$2" flag_branch="$3" flag_worktree="$4"
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

    local worktree_path
    if [[ -n "$flag_worktree" ]]; then
        worktree_path="$flag_worktree"
    else
        read -rp "Enter worktree folder path: " worktree_path
        worktree_path="${worktree_path#"${worktree_path%%[![:space:]]*}"}"
        worktree_path="${worktree_path%"${worktree_path##*[![:space:]]}"}"
        if [[ -z "$worktree_path" ]]; then
            echo "Error: Worktree folder path is required" >&2; return 1
        fi
    fi
    worktree_path="${worktree_path/#\~/$HOME}"
    [[ "$worktree_path" != /* ]] && worktree_path="$root_dir/$worktree_path"
    [[ -n "$flag_worktree" ]] && echo "Worktree path: $worktree_path (from -w flag)"

    local branch_name
    if [[ -n "$flag_branch" ]]; then
        branch_name="$flag_branch"
        echo "Branch name: $branch_name (from -b flag)"
    elif [[ "$use_defaults" == true ]]; then
        branch_name="$(basename "$worktree_path")"
        echo "Branch name: $branch_name (default)"
    else
        read -rp "Enter branch name (default: folder name '$(basename "$worktree_path")'): " branch_name
        branch_name="${branch_name:-$(basename "$worktree_path")}"
    fi

    cd "$git_dir"
    branch_exists_local_or_remote "$git_dir" "$branch_name"

    local source_branch=""
    if [[ "$_BRANCH_LOCATION" == "notfound" ]]; then
        if [[ "$use_defaults" == true ]]; then
            source_branch="main"
            echo "Source branch: main (default)"
        else
            read -rp "Enter source branch (default: main): " source_branch
            source_branch="${source_branch:-main}"
        fi
    fi

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path:  $worktree_path"
    echo "  Branch:         $branch_name"
    [[ -n "$source_branch" ]] && echo "  Source Branch:  $source_branch"
    echo ""

    if [[ "$_BRANCH_LOCATION" == "local" ]]; then
        echo "✓ Branch '$branch_name' already exists locally"
    elif [[ "$_BRANCH_LOCATION" == "remote" ]]; then
        echo "Branch '$branch_name' exists on remote — will create local tracking branch"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?" "$use_defaults"; then
            echo "Cancelled." >&2; return 1
        fi
        branch_exists_local_or_remote "$git_dir" "$source_branch"
        if [[ "$_BRANCH_LOCATION" == "local" ]]; then
            echo "Creating branch '$branch_name' from '$source_branch'..."
            if ! git branch -- "$branch_name" "$source_branch"; then
                echo "Error: Failed to create branch '$branch_name'" >&2; return 1
            fi
            echo "✓ Branch created"
        elif [[ "$_BRANCH_LOCATION" == "remote" ]]; then
            local remote
            remote="$(git -C "$git_dir" remote | head -1)"
            echo "Source branch '$source_branch' found on remote — fetching..."
            if ! git fetch "$remote" "$source_branch"; then
                echo "Error: Failed to fetch source branch '$source_branch' from remote" >&2; return 1
            fi
            echo "Creating branch '$branch_name' from fetched '$source_branch'..."
            if ! git branch -- "$branch_name" FETCH_HEAD; then
                echo "Error: Failed to create branch '$branch_name'" >&2; return 1
            fi
            echo "✓ Branch created"
        else
            echo "Error: Source branch '$source_branch' does not exist locally or on remote" >&2; return 1
        fi
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    if [[ "$_BRANCH_LOCATION" == "remote" ]]; then
        local remote
        remote="$(git -C "$git_dir" remote | head -1)"
        if ! git worktree add --track -b "$branch_name" "$worktree_path" "$remote/$branch_name"; then
            echo "Error: Failed to create worktree at '$worktree_path'" >&2; return 1
        fi
    else
        if ! git worktree add "$worktree_path" -- "$branch_name"; then
            echo "Error: Failed to create worktree at '$worktree_path'" >&2; return 1
        fi
    fi
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
        read -rp "Enter shared folder path (default: <root/Shared>): " custom_shared_dir
    fi

    setup_shared_links "$root_dir" "$(resolve_shared_dir "$root_dir" "$custom_shared_dir")"

    echo ""
    echo "========================================="
    echo "✓ Symlink setup complete!"
    echo "========================================="
    echo ""
}

create_worktree_with_links() {
    local root_dir="$1" use_defaults="$2" flag_branch="$3" flag_worktree="$4"
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

    local worktree_path
    if [[ -n "$flag_worktree" ]]; then
        worktree_path="$flag_worktree"
    else
        read -rp "Enter worktree folder path: " worktree_path
        worktree_path="${worktree_path#"${worktree_path%%[![:space:]]*}"}"
        worktree_path="${worktree_path%"${worktree_path##*[![:space:]]}"}"
        if [[ -z "$worktree_path" ]]; then
            echo "Error: Worktree folder path is required" >&2; return 1
        fi
    fi
    worktree_path="${worktree_path/#\~/$HOME}"
    [[ "$worktree_path" != /* ]] && worktree_path="$root_dir/$worktree_path"
    [[ -n "$flag_worktree" ]] && echo "Worktree path: $worktree_path (from -w flag)"

    local branch_name
    if [[ -n "$flag_branch" ]]; then
        branch_name="$flag_branch"
        echo "Branch name: $branch_name (from -b flag)"
    elif [[ "$use_defaults" == true ]]; then
        branch_name="$(basename "$worktree_path")"
        echo "Branch name: $branch_name (default)"
    else
        read -rp "Enter branch name (default: folder name '$(basename "$worktree_path")'): " branch_name
        branch_name="${branch_name:-$(basename "$worktree_path")}"
    fi

    cd "$git_dir"
    branch_exists_local_or_remote "$git_dir" "$branch_name"

    local source_branch=""
    if [[ "$_BRANCH_LOCATION" == "notfound" ]]; then
        if [[ "$use_defaults" == true ]]; then
            source_branch="main"
            echo "Source branch: main (default)"
        else
            read -rp "Enter source branch (default: main): " source_branch
            source_branch="${source_branch:-main}"
        fi
    fi

    # Shared folder
    local custom_shared_dir
    if [[ "$use_defaults" == true ]]; then
        echo "Shared folder: <root/Shared> (default)"
        custom_shared_dir=""
    else
        read -rp "Enter shared folder path (default: <root/Shared>): " custom_shared_dir
    fi

    echo ""
    echo "Configuration:"
    echo "  Root Directory: $root_dir"
    echo "  Worktree Path:  $worktree_path"
    echo "  Branch:         $branch_name"
    [[ -n "$source_branch" ]] && echo "  Source Branch:  $source_branch"
    echo ""

    if [[ "$_BRANCH_LOCATION" == "local" ]]; then
        echo "✓ Branch '$branch_name' already exists locally"
    elif [[ "$_BRANCH_LOCATION" == "remote" ]]; then
        echo "Branch '$branch_name' exists on remote — will create local tracking branch"
    else
        echo "Branch '$branch_name' does not exist"
        if ! confirm "Create branch '$branch_name' from '$source_branch'?" "$use_defaults"; then
            echo "Cancelled." >&2; return 1
        fi
        branch_exists_local_or_remote "$git_dir" "$source_branch"
        if [[ "$_BRANCH_LOCATION" == "local" ]]; then
            echo "Creating branch '$branch_name' from '$source_branch'..."
            if ! git branch -- "$branch_name" "$source_branch"; then
                echo "Error: Failed to create branch '$branch_name'" >&2; return 1
            fi
            echo "✓ Branch created"
        elif [[ "$_BRANCH_LOCATION" == "remote" ]]; then
            local remote
            remote="$(git -C "$git_dir" remote | head -1)"
            echo "Source branch '$source_branch' found on remote — fetching..."
            if ! git fetch "$remote" "$source_branch"; then
                echo "Error: Failed to fetch source branch '$source_branch' from remote" >&2; return 1
            fi
            echo "Creating branch '$branch_name' from fetched '$source_branch'..."
            if ! git branch -- "$branch_name" FETCH_HEAD; then
                echo "Error: Failed to create branch '$branch_name'" >&2; return 1
            fi
            echo "✓ Branch created"
        else
            echo "Error: Source branch '$source_branch' does not exist locally or on remote" >&2; return 1
        fi
    fi

    echo ""
    echo "Creating worktree at $worktree_path..."
    if [[ "$_BRANCH_LOCATION" == "remote" ]]; then
        local remote
        remote="$(git -C "$git_dir" remote | head -1)"
        if ! git worktree add --track -b "$branch_name" "$worktree_path" "$remote/$branch_name"; then
            echo "Error: Failed to create worktree at '$worktree_path'" >&2; return 1
        fi
    else
        if ! git worktree add "$worktree_path" -- "$branch_name"; then
            echo "Error: Failed to create worktree at '$worktree_path'" >&2; return 1
        fi
    fi
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
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Options:"
    echo "  -y              Accept all defaults (still prompts for values with no default)"
    echo "  -w <path>       Worktree folder path (skips the worktree path prompt)"
    echo "  -b <branch>     Branch name (skips the branch name prompt)"
    echo ""
    echo "  -w and -b apply to worktree commands only (wt, all/setup/a)."
    echo "  Combined with -y, all prompts are suppressed."
    echo ""
    echo "Commands:"
    echo ""
    echo "  worktree, wt   Create a new git worktree"
    echo "  links, ln      Setup shared symlinks (custom path supported)"
    echo "  all, setup, a  Create worktree and setup symlinks"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") wt -w worktrees/feat -b feature/my-task"
    echo "  $(basename "$0") a -y -w worktrees/feat -b feature/auth"
    echo ""
}

main() {
    local root_dir command="" use_defaults=false
    local flag_branch="" flag_worktree=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y)
                use_defaults=true
                shift ;;
            -b)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: -b requires a branch name argument" >&2; return 1
                fi
                flag_branch="$2"
                shift 2 ;;
            -w)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: -w requires a worktree path argument" >&2; return 1
                fi
                flag_worktree="$2"
                shift 2 ;;
            -*)
                echo "Error: Unknown flag: $1" >&2; return 1 ;;
            *)
                [[ -z "$command" ]] && command="$1"
                shift ;;
        esac
    done

    root_dir="$(find_root)" || true
    if [[ -z "$root_dir" ]]; then
        echo "Error: Could not find repository root" >&2
        echo "Make sure you're inside a git repository (.git or .bare)" >&2
        return 1
    fi

    case "$command" in
        "")              show_help ;;
        worktree|wt)     create_worktree_only "$root_dir" "$use_defaults" "$flag_branch" "$flag_worktree" ;;
        links|ln)
            if [[ -n "$flag_branch" ]]; then
                echo "Warning: -b flag has no effect on the 'links'/'ln' command and will be ignored" >&2
            fi
            create_links_only "$root_dir" "$use_defaults" ;;
        all|setup|a)     create_worktree_with_links "$root_dir" "$use_defaults" "$flag_branch" "$flag_worktree" ;;
        *)
            echo "Unknown command: $command" >&2
            echo ""
            show_help
            return 1
            ;;
    esac
}

main "$@"
