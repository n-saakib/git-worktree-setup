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
- [Commands](#commands)
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

---

## Installation

### Linux

```bash
git clone <repo-url> repo-tools
cd repo-tools
./install.sh
source ~/.bashrc
```

The installer detects your shell (bash/zsh), adds the `git-worktree` alias to the appropriate config file, and makes the script executable.

### macOS

```bash
git clone <repo-url> repo-tools
cd repo-tools
./install.sh
source ~/.zshrc   # or ~/.bash_profile if using bash
```

The installer detects whether you're on macOS and adds the alias to `.zshrc` (default shell since Catalina) or `.bash_profile`. The macOS script uses `#!/usr/bin/env bash` to pick up Homebrew bash if available, and is safe on the system bash (3.2).

### Windows

Open PowerShell and run:

```powershell
git clone <repo-url> repo-tools
cd repo-tools\windows
.\install.ps1
. $PROFILE
```

This adds a `git-worktree` function to your PowerShell profile.

> **Note:** Creating symlinks on Windows requires either **Developer Mode** enabled (`Settings > System > Developer Mode`) or running PowerShell **as Administrator**.

---

## Commands

All commands are available via the `git-worktree` alias.

| Command | Short form | Description |
|---|---|---|
| `git-worktree worktree` | `git-worktree wt` | Create a new git worktree only |
| `git-worktree links` | `git-worktree ln` | Setup shared symlinks only |
| `git-worktree all` | `git-worktree a` | Create worktree and setup symlinks |
| `git-worktree setup` | `git-worktree a` | Alias for `all` |
| `git-worktree` | | Show help |

---

## Usage Examples

### Create a worktree with shared symlinks (recommended)

```
$ git-worktree a

=========================================
  Git Worktree Creation + Symlinks
=========================================

Enter worktree folder path: worktrees/feature-auth
Enter branch name to use (leave empty to use folder name):
Using folder name as branch name: feature-auth
Enter source branch name (leave empty to use 'main'):
Using 'main' as source branch
Enter shared folder path (leave empty to use '<root/Shared>'):

Configuration:
  Root Directory: /projects/my-repo
  Worktree Path:  /projects/my-repo/worktrees/feature-auth
  Branch Name:    feature-auth
  Source Branch:  main

Branch 'feature-auth' does not exist
Create branch 'feature-auth' from 'main'? (Y/n):
Creating branch 'feature-auth' from 'main'...
✓ Branch created successfully

Creating worktree at /projects/my-repo/worktrees/feature-auth...
✓ Worktree created successfully

Setting up shared symlinks...
✓ Created symlink: .claude
✓ Created symlink: node_modules
✓ Done! All shared items have been symlinked.

=========================================
✓ Worktree creation + symlinks complete!
=========================================
```

---

### Create a worktree without symlinks

```
$ git-worktree wt

Enter worktree folder path: worktrees/bugfix-login
Enter branch name to use (leave empty to use folder name): bugfix-login
Enter source branch name (leave empty to use 'main'): develop

Configuration:
  Root Directory: /projects/my-repo
  Worktree Path:  /projects/my-repo/worktrees/bugfix-login
  Branch Name:    bugfix-login
  Source Branch:  develop

Branch 'bugfix-login' does not exist
Create branch 'bugfix-login' from 'develop'? (Y/n):
Creating branch 'bugfix-login' from 'develop'...
✓ Branch created successfully

Creating worktree at /projects/my-repo/worktrees/bugfix-login...
✓ Worktree created successfully

=========================================
✓ Worktree creation complete!
=========================================
```

---

### Setup symlinks in an existing worktree

```
$ cd worktrees/feature-auth
$ git-worktree ln

Enter shared folder path (leave empty to use '<root/Shared>'):

Setting up shared symlinks...
✓ Created symlink: .claude
✓ Created symlink: node_modules
✓ Done! All shared items have been symlinked.

=========================================
✓ Symlink setup complete!
=========================================
```

---

### Use a custom shared folder path

```
$ git-worktree ln

Enter shared folder path (leave empty to use '<root/Shared>'): config/shared

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
    └── feature-auth/   ← run git-worktree from here, it still works
```

### Shared Symlinks

The `Shared/` folder at the repo root holds files and directories that should be available in every worktree (e.g. shared tooling config, `node_modules`, `.claude` settings). Running `git-worktree ln` from inside a worktree symlinks each item into that worktree's directory.

- Dotfiles (`.claude`, `.env`, etc.) are included
- Items that already exist are skipped, not overwritten
- A custom path can be specified instead of `Shared/`

### Y/N Prompts

All confirmation prompts default to **yes** — press Enter to accept. The following inputs are accepted:

| Input | Result |
|---|---|
| *(empty)* | Yes |
| `y`, `Y`, `yes`, `YES`, `ye` | Yes |
| `n`, `N`, `no`, `NO` | No |

---

## Project Structure

```
repo-tools/
├── install.sh                    # Linux & macOS installer (auto-detects OS + shell)
├── linux/
│   └── add-git-worktree.sh      # Linux script
├── mac/
│   └── add-git-worktree.sh      # macOS script (bash 3.2 safe)
└── windows/
    ├── add-git-worktree.ps1     # Windows PowerShell script
    └── install.ps1              # Windows installer
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
- Bash (any version; macOS Catalina+ uses zsh by default but the installer handles this)
- Git 2.5+

### Windows
- PowerShell 5+
- Git for Windows
- Developer Mode **or** Administrator privileges (for symlink creation)
