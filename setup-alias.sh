#!/usr/bin/env bash

# Creates the git-worktree alias for Linux and macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS="$(uname -s)"
case "$OS" in
    Linux*)
        TARGET_SCRIPT="$SCRIPT_DIR/linux/add-git-worktree.sh"
        ;;
    Darwin*)
        TARGET_SCRIPT="$SCRIPT_DIR/mac/add-git-worktree.sh"
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

ALIAS_LINE="alias git-worktree='$TARGET_SCRIPT'"

SHELL_CONFIGS=()
CURRENT_SHELL="$(basename "$SHELL")"
case "$CURRENT_SHELL" in
    zsh)
        SHELL_CONFIGS+=("$HOME/.zshrc")
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
        SHELL_CONFIGS+=("$HOME/.bashrc" "$HOME/.zshrc")
        ;;
esac

ADDED=false

for config in "${SHELL_CONFIGS[@]}"; do
    if [[ ! -f "$config" ]] && [[ "$config" != "$HOME/.bashrc" ]] && [[ "$config" != "$HOME/.zshrc" ]]; then
        continue
    fi

    if grep -qF "alias git-worktree=" "$config" 2>/dev/null; then
        if [[ "$OS" == "Darwin"* ]]; then
            sed -i '' "s|alias git-worktree=.*|$ALIAS_LINE|" "$config"
        else
            sed -i "s|alias git-worktree=.*|$ALIAS_LINE|" "$config"
        fi
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
echo "Alias created successfully!"
echo ""
echo "To activate in this session, run:"
for config in "${SHELL_CONFIGS[@]}"; do
    [[ -f "$config" ]] && echo "  source $config"
done
echo ""
echo "Or open a new terminal."
echo ""
echo "Usage:"
echo "  git-worktree wt       - Create a worktree"
echo "  git-worktree ln       - Setup shared symlinks"
echo "  git-worktree a        - Create worktree + symlinks"
echo "  git-worktree          - Show all commands"
