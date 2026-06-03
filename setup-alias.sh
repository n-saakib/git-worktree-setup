#!/usr/bin/env bash

# Creates a shell alias for the git-worktree tool
# Usage: ./setup-alias.sh [-y]
#   -y  Accept all defaults without prompting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USE_DEFAULTS=false

for arg in "$@"; do
    [[ "$arg" == "-y" ]] && USE_DEFAULTS=true
done

# Resolve target script for this OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  TARGET_SCRIPT="$SCRIPT_DIR/linux/add-git-worktree.sh" ;;
    Darwin*) TARGET_SCRIPT="$SCRIPT_DIR/mac/add-git-worktree.sh" ;;
    MINGW*|MSYS*)
        echo "Git Bash detected. setup-alias.sh does not run on Windows." >&2
        echo "To set up the alias (including for Git Bash), run from PowerShell or Command Prompt:" >&2
        echo "" >&2
        echo "  cd $(cygpath -w "$SCRIPT_DIR")\\windows" >&2
        echo "  setup-alias.bat" >&2
        echo "" >&2
        echo "The Windows installer will detect Git Bash and set up the alias in ~/.bashrc automatically." >&2
        exit 1
        ;;
    *)
        echo "Unsupported OS: $OS" >&2
        echo "For Windows, run windows/setup-alias.ps1 instead." >&2
        exit 1
        ;;
esac

if [[ ! -f "$TARGET_SCRIPT" ]]; then
    echo "Error: Script not found at $TARGET_SCRIPT" >&2
    exit 1
fi

chmod +x "$TARGET_SCRIPT"

# Determine which shell config files to check
SHELL_CONFIGS=()
CURRENT_SHELL="$(basename "$SHELL")"
case "$CURRENT_SHELL" in
    zsh)
        SHELL_CONFIGS+=("${ZDOTDIR:-$HOME}/.zshrc")
        if [[ "$OS" == "Darwin"* ]] && [[ -f "$HOME/.zprofile" ]]; then
            SHELL_CONFIGS+=("$HOME/.zprofile")
        fi
        ;;
    bash)
        if [[ "$OS" == "Darwin"* ]]; then
            SHELL_CONFIGS+=("$HOME/.bash_profile")
        fi
        SHELL_CONFIGS+=("$HOME/.bashrc")
        ;;
    *)
        SHELL_CONFIGS+=("$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc")
        ;;
esac

# Check if any alias already points to our script
EXISTING_ALIAS=""
EXISTING_CONFIG=""
for config in "${SHELL_CONFIGS[@]}"; do
    [[ -f "$config" ]] || continue
    found_line=$(grep -E "^alias [^=]+='.*add-git-worktree\.sh'" "$config" 2>/dev/null | head -1 | tr -d '\r' || true)
    if [[ -n "$found_line" ]]; then
        EXISTING_ALIAS="$(echo "$found_line" | sed "s/^alias \([^=]*\)=.*/\1/")"
        EXISTING_CONFIG="$config"
        echo "Found existing alias: '$EXISTING_ALIAS' → add-git-worktree (in $config)"
        break
    fi
done

# Determine default alias name
DEFAULT_ALIAS="${EXISTING_ALIAS:-gwt}"

# Prompt for alias name
if [[ "$USE_DEFAULTS" == true ]]; then
    ALIAS_NAME="$DEFAULT_ALIAS"
    echo "Using alias: '$ALIAS_NAME'"
else
    read -p "Enter alias name (default: $DEFAULT_ALIAS): " ALIAS_NAME
    ALIAS_NAME="${ALIAS_NAME:-$DEFAULT_ALIAS}"
fi

# Check if the chosen alias name is taken by something else
check_alias_taken() {
    local name="$1"
    for config in "${SHELL_CONFIGS[@]}"; do
        [[ -f "$config" ]] || continue
        if grep -qF "alias ${name}=" "$config" 2>/dev/null; then
            local existing_def
            existing_def="$(grep -F "alias ${name}=" "$config" | head -1 | tr -d '\r')"
            if ! echo "$existing_def" | grep -q "add-git-worktree\.sh"; then
                echo "$config|$existing_def"
                return 0
            fi
        fi
    done
    return 1
}

conflict="$(check_alias_taken "$ALIAS_NAME" || true)"
while [[ -n "$conflict" ]]; do
    conflict_config="${conflict%%|*}"
    conflict_def="${conflict##*|}"
    echo "⚠ Alias '$ALIAS_NAME' is already taken in $conflict_config:"
    echo "  $conflict_def"

    if [[ "$USE_DEFAULTS" == true ]]; then
        echo "Error: Cannot use default alias '$ALIAS_NAME' with -y — it is already taken." >&2
        exit 1
    fi

    read -p "Enter a different alias name: " ALIAS_NAME
    if [[ -z "$ALIAS_NAME" ]]; then
        echo "Alias name cannot be empty."
        conflict="placeholder"
        continue
    fi
    conflict="$(check_alias_taken "$ALIAS_NAME" || true)"
done

ALIAS_LINE="alias $ALIAS_NAME='$TARGET_SCRIPT'"
ADDED=false

for config in "${SHELL_CONFIGS[@]}"; do
    if [[ ! -f "$config" ]] && [[ "$config" != "$HOME/.bashrc" ]] && [[ "$config" != "${ZDOTDIR:-$HOME}/.zshrc" ]]; then
        continue
    fi

    if grep -qE "^alias [^=]+='.*add-git-worktree\.sh'" "$config" 2>/dev/null; then
        # Update existing alias: delete old line, then append new one
        if [[ "$OS" == "Darwin"* ]]; then
            sed -i '' "/^alias [^=]*='.*add-git-worktree\.sh'/d" "$config"
        else
            sed -i "/^alias [^=]*='.*add-git-worktree\.sh'\r\?$/d" "$config"
        fi
        echo "$ALIAS_LINE" >> "$config"
        echo "✓ Updated alias in $config"
    else
        {
            echo ""
            echo "# Git worktree management tools"
            echo "$ALIAS_LINE"
        } >> "$config"
        echo "✓ Added alias to $config"
    fi
    ADDED=true
done

if [[ "$ADDED" == false ]]; then
    echo "Warning: No shell config files were updated." >&2
    echo "Manually add the following to your shell config:" >&2
    echo ""
    echo "  $ALIAS_LINE"
    echo ""
    exit 1
fi

echo ""
echo "Alias '$ALIAS_NAME' created successfully!"
echo ""
echo "To activate in this session, run:"
for config in "${SHELL_CONFIGS[@]}"; do
    [[ -f "$config" ]] && echo "  source $config"
done
echo ""
echo "Or open a new terminal."
echo ""
echo "Usage:"
echo "  $ALIAS_NAME wt       - Create a worktree"
echo "  $ALIAS_NAME ln       - Setup shared symlinks"
echo "  $ALIAS_NAME a        - Create worktree + symlinks"
echo "  $ALIAS_NAME          - Show all commands"
