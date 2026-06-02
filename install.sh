#!/usr/bin/env bash

# Installs the git-worktree alias for Linux and macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS and pick the right script
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
        echo "For Windows, run install.ps1 instead." >&2
        exit 1
        ;;
esac

if [[ ! -f "$TARGET_SCRIPT" ]]; then
    echo "Error: Script not found at $TARGET_SCRIPT" >&2
    exit 1
fi

chmod +x "$TARGET_SCRIPT"

ALIAS_LINE="alias git-worktree='$TARGET_SCRIPT'"

# Determine which shell config files to update
SHELL_CONFIGS=()

# Always try to add to the current shell's config
CURRENT_SHELL="$(basename "$SHELL")"
case "$CURRENT_SHELL" in
    zsh)
        SHELL_CONFIGS+=("$HOME/.zshrc")
        # Also add to .zprofile for login shells on macOS
        if [[ "$OS" == "Darwin"* ]] && [[ -f "$HOME/.zprofile" ]]; then
            SHELL_CONFIGS+=("$HOME/.zprofile")
        fi
        ;;
    bash)
        if [[ "$OS" == "Darwin"* ]]; then
            # macOS bash uses .bash_profile for login shells
            SHELL_CONFIGS+=("$HOME/.bash_profile")
        fi
        SHELL_CONFIGS+=("$HOME/.bashrc")
        ;;
    *)
        # Fallback: try both
        SHELL_CONFIGS+=("$HOME/.bashrc" "$HOME/.zshrc")
        ;;
esac

INSTALLED=false

for config in "${SHELL_CONFIGS[@]}"; do
    # Skip if file doesn't exist and it's not .bashrc/.zshrc
    if [[ ! -f "$config" ]] && [[ "$config" != "$HOME/.bashrc" ]] && [[ "$config" != "$HOME/.zshrc" ]]; then
        continue
    fi

    # Check if alias already exists
    if grep -qF "alias git-worktree=" "$config" 2>/dev/null; then
        # Update existing alias
        if [[ "$OS" == "Darwin"* ]]; then
            sed -i '' "s|alias git-worktree=.*|$ALIAS_LINE|" "$config"
        else
            sed -i "s|alias git-worktree=.*|$ALIAS_LINE|" "$config"
        fi
        echo "✓ Updated alias in $config"
    else
        # Add new alias
        {
            echo ""
            echo "# Git worktree management tools"
            echo "$ALIAS_LINE"
        } >> "$config"
        echo "✓ Added alias to $config"
    fi
    INSTALLED=true
done

if [[ "$INSTALLED" == false ]]; then
    echo "Warning: No shell config files were updated." >&2
    echo "Manually add the following to your shell config:" >&2
    echo ""
    echo "  $ALIAS_LINE"
    echo ""
    exit 1
fi

echo ""
echo "Installation complete!"
echo ""
echo "To start using the alias in this session, run:"
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
