# Git worktree and symlink management script — Windows (PowerShell)
# Requires: Git for Windows, PowerShell 5+
# Note: Creating symlinks requires Developer Mode enabled OR running as Administrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Confirm-Action {
    param([string]$Prompt)
    while ($true) {
        $response = Read-Host "$Prompt (Y/n)"
        if ([string]::IsNullOrWhiteSpace($response)) { return $true }
        switch ($response.ToLower()) {
            { $_ -in "y","yes","ye" } { return $true }
            { $_ -in "n","no" }       { return $false }
            default { Write-Host "Invalid response. Please enter y/yes/ye or n/no." }
        }
    }
}

function Find-Root {
    $current = (Get-Location).Path
    while ($current -ne (Split-Path $current -Qualifier) + "\") {
        if (Test-Path (Join-Path $current ".bare")) { return $current }
        if (Test-Path (Join-Path $current ".git"))  { return $current }
        $current = Split-Path $current -Parent
    }
    return $null
}

function Setup-SharedLinks {
    param(
        [string]$RootDir,
        [string]$SharedDir = ""
    )

    if ([string]::IsNullOrWhiteSpace($SharedDir)) {
        $SharedDir = Join-Path $RootDir "Shared"
    }

    if (-not (Test-Path $SharedDir)) {
        Write-Host "Warning: Shared folder not found at $SharedDir"
        Write-Host "Skipping symlink setup"
        return
    }

    Write-Host "Setting up shared symlinks..."
    Write-Host "  Root directory: $RootDir"
    Write-Host "  Shared directory: $SharedDir"
    Write-Host "  Current directory: $(Get-Location)"
    Write-Host ""

    $items = Get-ChildItem -Path $SharedDir -Force
    foreach ($item in $items) {
        $linkPath = Join-Path (Get-Location) $item.Name

        if (Test-Path $linkPath) {
            Write-Host "Warning: Skipping '$($item.Name)' - already exists"
            continue
        }

        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $item.FullName | Out-Null
            Write-Host "OK: Created symlink: $($item.Name)"
        } catch {
            Write-Host "Error: Failed to create symlink for '$($item.Name)': $_"
            Write-Host "Tip: Enable Developer Mode or run PowerShell as Administrator to create symlinks."
        }
    }

    Write-Host ""
    Write-Host "OK: Done! All shared items have been symlinked."
}

function Create-WorktreeOnly {
    param([string]$RootDir)

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation"
    Write-Host "========================================="
    Write-Host ""

    $bareDir = Join-Path $RootDir ".bare"
    $gitDir = if (Test-Path $bareDir) { $bareDir } else { Join-Path $RootDir ".git" }

    if (-not (Test-Path $gitDir)) {
        Write-Error "Git directory not found"
        return
    }

    $worktreePath = Read-Host "Enter worktree folder path"
    if ([string]::IsNullOrWhiteSpace($worktreePath)) {
        Write-Error "Worktree folder path is required"
        return
    }

    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) {
        $worktreePath = Join-Path $RootDir $worktreePath
    }

    $branchName = Read-Host "Enter branch name to use (leave empty to use folder name)"
    if ([string]::IsNullOrWhiteSpace($branchName)) {
        $branchName = Split-Path $worktreePath -Leaf
        Write-Host "Using folder name as branch name: $branchName"
    }

    $sourceBranch = Read-Host "Enter source branch name (leave empty to use 'main')"
    if ([string]::IsNullOrWhiteSpace($sourceBranch)) {
        $sourceBranch = "main"
        Write-Host "Using 'main' as source branch"
    }

    Write-Host ""
    Write-Host "Configuration:"
    Write-Host "  Root Directory: $RootDir"
    Write-Host "  Worktree Path: $worktreePath"
    Write-Host "  Branch Name: $branchName"
    Write-Host "  Source Branch: $sourceBranch"
    Write-Host ""

    Push-Location $gitDir
    try {
        $branchExists = git show-ref --quiet --verify "refs/heads/$branchName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: Branch '$branchName' already exists"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?")) {
                Write-Host "Cancelled. Branch not created."
                return
            }

            $sourceExists = git show-ref --quiet --verify "refs/heads/$sourceBranch" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Source branch '$sourceBranch' does not exist"
                return
            }

            Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
            git branch $branchName $sourceBranch
            Write-Host "OK: Branch created successfully"
        }

        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        git worktree add $worktreePath $branchName
        Write-Host "OK: Worktree created successfully"
    } finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "OK: Worktree creation complete!"
    Write-Host "========================================="
    Write-Host "You are now in the worktree directory:"
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Create-LinksOnly {
    param([string]$RootDir)

    Write-Host "========================================="
    Write-Host "  Setup Shared Symlinks"
    Write-Host "========================================="
    Write-Host ""

    $customSharedDir = Read-Host "Enter shared folder path (leave empty to use '<root/Shared>')"

    if ([string]::IsNullOrWhiteSpace($customSharedDir)) {
        Setup-SharedLinks -RootDir $RootDir
    } else {
        if (-not [System.IO.Path]::IsPathRooted($customSharedDir)) {
            $customSharedDir = Join-Path $RootDir $customSharedDir
        }
        Setup-SharedLinks -RootDir $RootDir -SharedDir $customSharedDir
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "OK: Symlink setup complete!"
    Write-Host "========================================="
    Write-Host ""
}

function Create-WorktreeWithLinks {
    param([string]$RootDir)

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation + Symlinks"
    Write-Host "========================================="
    Write-Host ""

    $bareDir = Join-Path $RootDir ".bare"
    $gitDir = if (Test-Path $bareDir) { $bareDir } else { Join-Path $RootDir ".git" }

    if (-not (Test-Path $gitDir)) {
        Write-Error "Git directory not found"
        return
    }

    $worktreePath = Read-Host "Enter worktree folder path"
    if ([string]::IsNullOrWhiteSpace($worktreePath)) {
        Write-Error "Worktree folder path is required"
        return
    }

    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) {
        $worktreePath = Join-Path $RootDir $worktreePath
    }

    $branchName = Read-Host "Enter branch name to use (leave empty to use folder name)"
    if ([string]::IsNullOrWhiteSpace($branchName)) {
        $branchName = Split-Path $worktreePath -Leaf
        Write-Host "Using folder name as branch name: $branchName"
    }

    $sourceBranch = Read-Host "Enter source branch name (leave empty to use 'main')"
    if ([string]::IsNullOrWhiteSpace($sourceBranch)) {
        $sourceBranch = "main"
        Write-Host "Using 'main' as source branch"
    }

    $customSharedDir = Read-Host "Enter shared folder path (leave empty to use '<root/Shared>')"

    Write-Host ""
    Write-Host "Configuration:"
    Write-Host "  Root Directory: $RootDir"
    Write-Host "  Worktree Path: $worktreePath"
    Write-Host "  Branch Name: $branchName"
    Write-Host "  Source Branch: $sourceBranch"
    if (-not [string]::IsNullOrWhiteSpace($customSharedDir)) {
        Write-Host "  Shared Folder: $customSharedDir"
    }
    Write-Host ""

    Push-Location $gitDir
    try {
        git show-ref --quiet --verify "refs/heads/$branchName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: Branch '$branchName' already exists"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?")) {
                Write-Host "Cancelled. Branch not created."
                return
            }

            git show-ref --quiet --verify "refs/heads/$sourceBranch" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Source branch '$sourceBranch' does not exist"
                return
            }

            Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
            git branch $branchName $sourceBranch
            Write-Host "OK: Branch created successfully"
        }

        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        git worktree add $worktreePath $branchName
        Write-Host "OK: Worktree created successfully"
    } finally {
        Pop-Location
    }

    Write-Host ""
    Set-Location $worktreePath
    if ([string]::IsNullOrWhiteSpace($customSharedDir)) {
        Setup-SharedLinks -RootDir $RootDir
    } else {
        if (-not [System.IO.Path]::IsPathRooted($customSharedDir)) {
            $customSharedDir = Join-Path $RootDir $customSharedDir
        }
        Setup-SharedLinks -RootDir $RootDir -SharedDir $customSharedDir
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "OK: Worktree creation + symlinks complete!"
    Write-Host "========================================="
    Write-Host "You are now in the worktree directory:"
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Show-Help {
    Write-Host "Git Worktree Management Tool"
    Write-Host "============================="
    Write-Host ""
    Write-Host "Available commands:"
    Write-Host ""
    Write-Host "  Worktree only:"
    Write-Host "    git-worktree worktree     - Create a new git worktree"
    Write-Host "    git-worktree wt           - Shorthand for worktree"
    Write-Host ""
    Write-Host "  Symlinks only:"
    Write-Host "    git-worktree links        - Setup shared symlinks (with custom path option)"
    Write-Host "    git-worktree ln           - Shorthand for links"
    Write-Host ""
    Write-Host "  Both:"
    Write-Host "    git-worktree all          - Create worktree and setup symlinks"
    Write-Host "    git-worktree setup        - Alias for 'all'"
    Write-Host "    git-worktree a            - Shorthand for 'all'"
    Write-Host ""
}

# Main entry point
$rootDir = Find-Root
if ($null -eq $rootDir) {
    Write-Error "Could not find repository root. Make sure you're inside a git repository (with .git or .bare folder)."
    exit 1
}

if ($args.Count -eq 0) {
    Show-Help
    exit 0
}

switch ($args[0]) {
    { $_ -in "worktree","wt" }    { Create-WorktreeOnly $rootDir }
    { $_ -in "links","ln" }       { Create-LinksOnly $rootDir }
    { $_ -in "all","setup","a" }  { Create-WorktreeWithLinks $rootDir }
    default {
        Write-Host "Unknown command: $($args[0])"
        Write-Host ""
        Write-Host "Available commands:"
        Write-Host "  worktree, wt  - Create worktree only"
        Write-Host "  links, ln     - Setup symlinks only"
        Write-Host "  all, setup, a - Create worktree and symlinks"
        Write-Host ""
        Write-Host "Run with no arguments to see full help"
        exit 1
    }
}
