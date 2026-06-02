# git-worktree

A cross-platform CLI tool to create and manage [Git worktrees](https://git-scm.com/docs/git-worktree) with automatic shared symlink setup. Works with both standard Git repositories (`.git`) and bare repository setups (`.bare`).

---

## Contents

- [Why](#why)
- [Features](#features)
- [Installation](#installation)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
- [Uninstall](#uninstall)
- [Commands](#commands)
- [Flags](#flags)
- [Usage Examples](#usage-examples)
- [How It Works](#how-it-works)
- [Project Structure](#project-structure)
- [Requirements](#requirements)

---

## Why

Working across multiple branches simultaneously in Git typically requires either stashing changes, juggling `git checkout`, or duplicating the repo. Git worktrees solve this — but setting one up correctly (creating the branch, linking shared config/tooling, and putting the worktree in the right place) involves multiple steps.

This tool wraps that workflow into a single interactive command that works from anywhere inside your repo.

---

## Features

- **Create a worktree** — prompts for path, branch name, and source branch; creates the branch if it doesn't exist
- **Setup shared symlinks** — links everything in a `Shared/` folder (or a custom path) into the current directory, including dotfiles like `.claude`
- **Do both at once** — create a worktree and immediately symlink shared files into it
- **Works from anywhere** — auto-detects repo root by walking up to find `.bare` or `.git`
- **Bare repo aware** — designed for monorepo setups with a `.bare` directory
- **Cross-platform** — separate scripts for Linux, macOS, and Windows
- **Customisable alias** — choose your own alias name at setup (default: `gwt`)
- **Non-interactive mode** — `-y` flag accepts all defaults, only prompting for required values

---

## Installation

### Linux

```bash
git clone <repo-url> git-worktree-setup
cd git-worktree-setup
./setup-alias.sh
source ~/.bashrc
```

Detects your shell (bash/zsh), prompts for an alias name (default: `gwt`), checks for conflicts, and adds the alias to your shell config.

To skip the alias prompt and use the default:

```bash
./setup-alias.sh -y
```

### macOS

```bash
git clone <repo-url> git-worktree-setup
cd git-worktree-setup
./setup-alias.sh
source ~/.zshrc   # or ~/.bash_profile if using bash
```

Detects whether you're on macOS and adds the alias to `.zshrc` (default since Catalina) or `.bash_profile`. The macOS script uses `#!/usr/bin/env bash` to pick up Homebrew bash if available, and is safe on system bash (3.2).

### Windows

Open PowerShell and run:

```powershell
git clone <repo-url> git-worktree-setup
cd git-worktree-setup\windows
powershell -ExecutionPolicy Bypass -File .\setup-alias.ps1
. $PROFILE
```

Prompts for an alias name (default: `gwt`), checks for conflicts with existing aliases, and adds a function to your PowerShell profile.

To use defaults silently:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-alias.ps1 -y
```

> **Why `-ExecutionPolicy Bypass`?** Windows blocks unsigned PowerShell scripts by default. The bypass flag allows running this script for the current invocation only — it does not change your system policy.
>
> Alternatively you can use the provided `.bat` wrappers which handle this automatically:
> ```
> windows\setup-alias.bat
> windows\setup-alias.bat -y
> ```
>
> Or allow signed local scripts permanently (once):
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
> After that you can run `.\setup-alias.ps1` directly.

> **Note:** Creating symlinks on Windows requires either **Developer Mode** enabled (`Settings > System > Developer Mode`) or running PowerShell **as Administrator**.

---

## Uninstall

To remove the alias from your shell config. The script detects the alias by the script path, so it works regardless of what name you gave it.

**Linux / macOS:**
```bash
./remove-alias.sh
source ~/.bashrc   # or ~/.zshrc
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File .\windows\remove-alias.ps1
. $PROFILE
```

This removes the alias/function and its comment from your shell config. The scripts themselves are not deleted.

---

## Commands

All commands are invoked via your chosen alias (default: `gwt`).

| Command | Short form | Description |
|---|---|---|
| `gwt worktree` | `gwt wt` | Create a new git worktree only |
| `gwt links` | `gwt ln` | Setup shared symlinks only |
| `gwt all` | `gwt a` | Create worktree and setup symlinks |
| `gwt setup` | `gwt a` | Alias for `all` |
| `gwt` | | Show help |

---

## Flags

### `-y` — accept defaults

Available on both `setup-alias` and the worktree commands.

| Value | Has default? | Behaviour with `-y` |
|---|---|---|
| Alias name | `gwt` | Uses `gwt`, no prompt |
| Branch name | folder name | Uses folder name, no prompt |
| Source branch | `main` | Uses `main`, no prompt |
| Shared folder | `<root/Shared>` | Uses `Shared/`, no prompt |
| Branch creation | yes | Auto-confirms, no prompt |
| Worktree path | **none** | Still prompts — required |

```bash
gwt a -y                   # prompts only for worktree path
gwt wt -y                  # prompts only for worktree path
gwt ln -y                  # no prompts at all
./setup-alias.sh -y        # uses alias 'gwt' with no prompt
```

---

## Usage Examples

### Setup: choose a custom alias

```
$ ./setup-alias.sh

Enter alias name (default: gwt): wt
✓ Added alias to ~/.bashrc

Alias 'wt' created successfully!
```

### Setup: alias already taken

```
$ ./setup-alias.sh

Enter alias name (default: gwt): ls
⚠ Alias 'ls' is already taken in ~/.bashrc:
  alias ls='ls --color=auto'
Enter a different alias name: wt
✓ Added alias to ~/.bashrc
```

### Create a worktree with symlinks (interactive)

```
$ gwt a

=========================================
  Git Worktree Creation + Symlinks
=========================================

Enter worktree folder path: worktrees/feature-auth
Enter branch name (default: folder name 'feature-auth'):
Enter source branch (default: main):
Enter shared folder path (default: <root/Shared>):

Configuration:
  Root Directory: /projects/my-repo
  Worktree Path:  /projects/my-repo/worktrees/feature-auth
  Branch:         feature-auth
  Source Branch:  main

Branch 'feature-auth' does not exist
Create branch 'feature-auth' from 'main'? (Y/n):
Creating branch 'feature-auth' from 'main'...
✓ Branch created

Creating worktree at /projects/my-repo/worktrees/feature-auth...
✓ Worktree created

Setting up shared symlinks...
✓ Created symlink: .claude
✓ Created symlink: node_modules
✓ Done! All shared items have been symlinked.

=========================================
✓ Worktree creation + symlinks complete!
=========================================
  /projects/my-repo/worktrees/feature-auth
```

### Create a worktree with symlinks (non-interactive)

```
$ gwt a -y

Enter worktree folder path: worktrees/feature-auth
Branch name: feature-auth (default)
Source branch: main (default)
Shared folder: <root/Shared> (default)

Configuration:
  Root Directory: /projects/my-repo
  Worktree Path:  /projects/my-repo/worktrees/feature-auth
  Branch:         feature-auth
  Source Branch:  main

Branch 'feature-auth' does not exist
Create branch 'feature-auth' from 'main'? (Y/n): Y
✓ Branch created

Creating worktree at /projects/my-repo/worktrees/feature-auth...
✓ Worktree created
...
✓ Worktree creation + symlinks complete!
```

### Setup symlinks with a custom path

```
$ gwt ln

Enter shared folder path (default: <root/Shared>): config/shared

Setting up shared symlinks...
✓ Created symlink: .env
✓ Created symlink: secrets.json
✓ Done! All shared items have been symlinked.
```

Relative paths are resolved from the repository root. Absolute paths are used as-is.

---

## How It Works

### Repository Detection

The script walks up from the current directory looking for `.bare` (bare repo monorepo setup) or `.git` (standard repo). This means it works from **any subdirectory or worktree** — no need to be at the root.

```
/projects/my-repo/
├── .bare/              ← detected as repo root
├── Shared/             ← symlink source
│   ├── .claude
│   └── node_modules
└── worktrees/
    ├── main/
    └── feature-auth/   ← run gwt from here, it still works
```

### Shared Symlinks

The `Shared/` folder at the repo root holds files and directories that should be available in every worktree (e.g. shared tooling config, `node_modules`, `.claude` settings). Running `gwt ln` from inside a worktree symlinks each item into that worktree's directory.

- Dotfiles (`.claude`, `.env`, etc.) are included
- Items that already exist are skipped, not overwritten
- A custom path can be specified instead of `Shared/`

### Alias Detection

`remove-alias` finds the alias by scanning for the script path (`add-git-worktree.sh`) in your shell config — not by alias name. This means it correctly removes the alias even if you renamed it.

Similarly, `setup-alias` detects an existing alias pointing to the script and shows you its name before prompting for a new one.

### Y/N Prompts

All confirmation prompts default to **yes** — press Enter to accept.

| Input | Result |
|---|---|
| *(empty)* | Yes |
| `y`, `Y`, `yes`, `YES`, `ye` | Yes |
| `n`, `N`, `no`, `NO` | No |

---

## Project Structure

```
git-worktree-setup/
├── setup-alias.sh               # Linux & macOS: creates shell alias
├── remove-alias.sh              # Linux & macOS: removes shell alias
├── linux/
│   └── add-git-worktree.sh     # Linux script
├── mac/
│   └── add-git-worktree.sh     # macOS script (bash 3.2 safe)
└── windows/
    ├── add-git-worktree.ps1    # Windows PowerShell script
    ├── setup-alias.ps1         # Windows: creates PowerShell alias
    ├── setup-alias.bat         # Wrapper — runs setup-alias.ps1 without execution policy issues
    ├── remove-alias.ps1        # Windows: removes PowerShell alias
    └── remove-alias.bat        # Wrapper — runs remove-alias.ps1 without execution policy issues
```

### Platform Differences

| | Linux | macOS | Windows |
|---|---|---|---|
| Script type | Bash | Bash | PowerShell |
| Lowercase conversion | `${var,,}` | `tr '[:upper:]' '[:lower:]'` | `.ToLower()` |
| Dotfile glob | `shopt -s dotglob` | `.[!.]*` pattern | `Get-ChildItem -Force` |
| Symlinks | `ln -s` | `ln -s` | `New-Item -ItemType SymbolicLink` |
| Shebang | `#!/bin/bash` | `#!/usr/bin/env bash` | N/A |

---

## Requirements

### Linux / macOS
- Bash (any version; macOS Catalina+ uses zsh by default but `setup-alias.sh` handles this)
- Git 2.5+

### Windows
- PowerShell 5+
- Git for Windows
- Developer Mode **or** Administrator privileges (for symlink creation)
