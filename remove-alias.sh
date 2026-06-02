#!/usr/bin/env bash

# Removes the git-worktree alias from shell config files

set -e

OS="$(uname -s)"

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
        if [[ "$OS" == "Darwin"* ]] && [[ -f "$HOME/.bash_profile" ]]; then
            SHELL_CONFIGS+=("$HOME/.bash_profile")
        fi
        SHELL_CONFIGS+=("$HOME/.bashrc")
        ;;
    *)
        SHELL_CONFIGS+=("$HOME/.bashrc" "$HOME/.zshrc")
        ;;
esac

REMOVED=false

for config in "${SHELL_CONFIGS[@]}"; do
    [[ -f "$config" ]] || continue

    if grep -qF "alias git-worktree=" "$config" 2>/dev/null; then
        # Remove the comment line and alias line together
        if [[ "$OS" == "Darwin"* ]]; then
            sed -i '' '/^# Git worktree management tools$/d' "$config"
            sed -i '' '/^alias git-worktree=/d' "$config"
        else
            sed -i '/^# Git worktree management tools$/d' "$config"
            sed -i '/^alias git-worktree=/d' "$config"
        fi
        echo "✓ Removed alias from $config"
        REMOVED=true
    else
        echo "- No alias found in $config, skipping"
    fi
done

if [[ "$REMOVED" == false ]]; then
    echo "No alias found in any shell config file. Nothing to remove."
    exit 0
fi

echo ""
echo "Alias removed successfully!"
echo ""
echo "To apply in this session, run:"
for config in "${SHELL_CONFIGS[@]}"; do
    [[ -f "$config" ]] && echo "  source $config"
done
echo ""
echo "Or open a new terminal."
