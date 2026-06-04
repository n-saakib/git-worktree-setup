# Git worktree and symlink management script -- Windows (PowerShell)
# Usage: git-worktree <command> [-y]
#   -y  Accept all defaults without prompting (still prompts for required values)
# Requires: Git for Windows, PowerShell 5+
# Note: Symlink creation requires Developer Mode or Administrator privileges

[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command = "",
    [switch]$y,
    [string]$BranchName = "",
    [string]$WorktreePath = ""
)

$UseDefaults = $y.IsPresent
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Confirm-Action {
    param([string]$Prompt, [bool]$Auto = $false)
    if ($Auto) { Write-Host "$Prompt (Y/n): Y"; return $true }
    while ($true) {
        $response = Read-Host "$Prompt (Y/n)"
        if ([string]::IsNullOrWhiteSpace($response)) { return $true }
        switch ($response.ToLower()) {
            { $_ -in "y","yes","ye" } { return $true }
            { $_ -in "n","no" }       { return $false }
            default { Write-Host "Please enter y/yes or n/no." }
        }
    }
}

function Find-Root {
    $current = (Get-Location).Path
    $root = (Split-Path $current -Qualifier) + "\"
    while ($current -ne $root) {
        if (Test-Path (Join-Path $current ".bare")) { return $current }
        # Skip .git check when inside a .bare directory -- bare repos can contain
        # a .git subdir (e.g. created by GitKraken), which is not the worktree root.
        if ((Test-Path (Join-Path $current ".git")) -and (Split-Path $current -Leaf) -ne ".bare") {
            return $current
        }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { return $null }
        $current = $parent
    }
    return $null
}

function Resolve-SharedDir {
    param([string]$RootDir, [string]$UserPath)
    if ([string]::IsNullOrWhiteSpace($UserPath)) { return Join-Path $RootDir "Shared" }
    if ([System.IO.Path]::IsPathRooted($UserPath)) { return $UserPath }
    return Join-Path $RootDir $UserPath
}

function Test-BranchExists {
    param([string]$GitDir, [string]$BranchName)

    Push-Location $GitDir
    try {
        $global:LASTEXITCODE = 0
        git show-ref --quiet --verify "refs/heads/$BranchName" 2>$null
        if ($LASTEXITCODE -eq 0) { return "local" }

        $remote = git remote 2>$null | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($remote)) { return "notfound" }

        $global:LASTEXITCODE = 0
        git ls-remote --exit-code --heads $remote $BranchName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return "remote" }
        return "notfound"
    } catch {
        return "notfound"
    } finally {
        Pop-Location
    }
}

function Setup-SharedLinks {
    param([string]$RootDir, [string]$SharedDir = "")
    if ([string]::IsNullOrWhiteSpace($SharedDir)) { $SharedDir = Join-Path $RootDir "Shared" }

    if (-not (Test-Path $SharedDir)) {
        Write-Host "Warning: Shared folder not found at $SharedDir"
        Write-Host "Skipping symlink setup"
        return
    }

    Write-Host "Setting up shared symlinks..."
    Write-Host "  Shared directory: $SharedDir"
    Write-Host "  Target directory: $(Get-Location)"
    Write-Host ""

    $items = @(Get-ChildItem -Path $SharedDir -Force)
    if ($items.Count -eq 0) {
        Write-Host "No items found in $SharedDir"
    }

    $failCount = 0
    foreach ($item in $items) {
        $linkPath = Join-Path (Get-Location) $item.Name
        $existingItem = $null
        if (Test-Path $linkPath) {
            $existingItem = $true
        } else {
            $parentItems = Get-ChildItem (Split-Path $linkPath -Parent) -Force -ErrorAction SilentlyContinue
            $existingItem = $parentItems | Where-Object { $_.Name -eq $item.Name }
        }
        if ($existingItem) {
            Write-Host "Warning: Skipping '$($item.Name)' - already exists"
            continue
        }
        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $item.FullName | Out-Null
            Write-Host "[OK] Created symlink: $($item.Name)"
        } catch {
            $failCount++
            Write-Host "Error creating symlink for '$($item.Name)': $_"
            Write-Host "Tip: Enable Developer Mode or run as Administrator."
        }
    }

    Write-Host ""
    if ($failCount -gt 0) {
        Write-Host "Warning: Done with $failCount failed symlink(s)."
    } else {
        Write-Host "[OK] Done! All shared items have been symlinked."
    }
}

function Create-WorktreeOnly {
    param([string]$RootDir, [bool]$UseDefaults = $false, [string]$FlagBranch = "", [string]$FlagWorktree = "")

    # For bare repos: run git commands from inside .bare (it IS the repo).
    # For standard repos: run from the root (parent of .git), not inside .git\.
    $bareDir = Join-Path $RootDir ".bare"
    $gitDir  = if (Test-Path $bareDir) { $bareDir } else { $RootDir }
    if (-not (Test-Path $gitDir)) { Write-Host "Error: Git directory not found"; return }

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation"
    Write-Host "========================================="
    Write-Host ""

    $worktreePath = if (-not [string]::IsNullOrWhiteSpace($FlagWorktree)) {
        Write-Host "Worktree path: $FlagWorktree (from -WorktreePath flag)"
        $FlagWorktree
    } else {
        $v = Read-Host "Enter worktree folder path"
        $v.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($worktreePath)) { Write-Host "Error: Worktree folder path is required"; return }
    if ($worktreePath.StartsWith("~")) { $worktreePath = $worktreePath -replace '^~', $HOME }
    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) { $worktreePath = Join-Path $RootDir $worktreePath }

    $folderName = Split-Path $worktreePath -Leaf
    $branchName = if (-not [string]::IsNullOrWhiteSpace($FlagBranch)) {
        Write-Host "Branch name: $FlagBranch (from -BranchName flag)"
        $FlagBranch
    } elseif ($UseDefaults) {
        Write-Host "Branch name: $folderName (default)"; $folderName
    } else {
        $v = Read-Host "Enter branch name (default: folder name '$folderName')"
        if ([string]::IsNullOrWhiteSpace($v)) { $folderName } else { $v }
    }

    Push-Location $gitDir
    try {
        $branchLocation = Test-BranchExists $gitDir $branchName

        $sourceBranch = ""
        if ($branchLocation -eq "notfound") {
            $sourceBranch = if ($UseDefaults) {
                Write-Host "Source branch: main (default)"; "main"
            } else {
                $v = Read-Host "Enter source branch (default: main)"
                if ([string]::IsNullOrWhiteSpace($v)) { "main" } else { $v }
            }
        }

        Write-Host ""
        Write-Host "Configuration:"
        Write-Host "  Root Directory: $RootDir"
        Write-Host "  Worktree Path:  $worktreePath"
        Write-Host "  Branch:         $branchName"
        if (-not [string]::IsNullOrWhiteSpace($sourceBranch)) { Write-Host "  Source Branch:  $sourceBranch" }
        Write-Host ""

        if ($branchLocation -eq "local") {
            Write-Host "[OK] Branch '$branchName' already exists locally"
        } elseif ($branchLocation -eq "remote") {
            Write-Host "Branch '$branchName' exists on remote -- will create local tracking branch"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?" $UseDefaults)) {
                Write-Host "Cancelled."; return
            }
            $srcLocation = Test-BranchExists $gitDir $sourceBranch
            if ($srcLocation -eq "local") {
                Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
                git branch -- "$branchName" "$sourceBranch"
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create branch '$branchName'"; return }
                Write-Host "[OK] Branch created"
            } elseif ($srcLocation -eq "remote") {
                $remote = git remote 2>$null | Select-Object -First 1
                Write-Host "Source branch '$sourceBranch' found on remote -- fetching..."
                git fetch $remote $sourceBranch
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to fetch source branch '$sourceBranch' from remote"; return }
                Write-Host "Creating branch '$branchName' from fetched '$sourceBranch'..."
                git branch -- "$branchName" FETCH_HEAD
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create branch '$branchName'"; return }
                Write-Host "[OK] Branch created"
            } else {
                Write-Host "Error: Source branch '$sourceBranch' does not exist locally or on remote"
                return
            }
        }
        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        if ($branchLocation -eq "remote") {
            $remote = git remote 2>$null | Select-Object -First 1
            git worktree add --track -b "$branchName" "$worktreePath" "$remote/$branchName"
            if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create worktree at '$worktreePath'"; return }
        } else {
            git worktree add "$worktreePath" -- "$branchName"
            if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create worktree at '$worktreePath'"; return }
        }
        Write-Host "[OK] Worktree created"
    } finally { Pop-Location }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "[OK] Worktree creation complete!"
    Write-Host "========================================="
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Create-LinksOnly {
    param([string]$RootDir, [bool]$UseDefaults = $false)

    Write-Host "========================================="
    Write-Host "  Setup Shared Symlinks"
    Write-Host "========================================="
    Write-Host ""

    $customSharedDir = if ($UseDefaults) {
        Write-Host "Shared folder: <root/Shared> (default)"; ""
    } else {
        Read-Host "Enter shared folder path (default: <root/Shared>)"
    }

    Setup-SharedLinks -RootDir $RootDir -SharedDir (Resolve-SharedDir $RootDir $customSharedDir)

    Write-Host ""
    Write-Host "========================================="
    Write-Host "[OK] Symlink setup complete!"
    Write-Host "========================================="
    Write-Host ""
}

function Create-WorktreeWithLinks {
    param([string]$RootDir, [bool]$UseDefaults = $false, [string]$FlagBranch = "", [string]$FlagWorktree = "")

    # For bare repos: run git commands from inside .bare (it IS the repo).
    # For standard repos: run from the root (parent of .git), not inside .git\.
    $bareDir = Join-Path $RootDir ".bare"
    $gitDir  = if (Test-Path $bareDir) { $bareDir } else { $RootDir }
    if (-not (Test-Path $gitDir)) { Write-Host "Error: Git directory not found"; return }

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation + Symlinks"
    Write-Host "========================================="
    Write-Host ""

    $worktreePath = if (-not [string]::IsNullOrWhiteSpace($FlagWorktree)) {
        Write-Host "Worktree path: $FlagWorktree (from -WorktreePath flag)"
        $FlagWorktree
    } else {
        $v = Read-Host "Enter worktree folder path"
        $v.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($worktreePath)) { Write-Host "Error: Worktree folder path is required"; return }
    if ($worktreePath.StartsWith("~")) { $worktreePath = $worktreePath -replace '^~', $HOME }
    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) { $worktreePath = Join-Path $RootDir $worktreePath }

    $folderName = Split-Path $worktreePath -Leaf
    $branchName = if (-not [string]::IsNullOrWhiteSpace($FlagBranch)) {
        Write-Host "Branch name: $FlagBranch (from -BranchName flag)"
        $FlagBranch
    } elseif ($UseDefaults) {
        Write-Host "Branch name: $folderName (default)"; $folderName
    } else {
        $v = Read-Host "Enter branch name (default: folder name '$folderName')"
        if ([string]::IsNullOrWhiteSpace($v)) { $folderName } else { $v }
    }

    Push-Location $gitDir
    try {
        $branchLocation = Test-BranchExists $gitDir $branchName

        $sourceBranch = ""
        if ($branchLocation -eq "notfound") {
            $sourceBranch = if ($UseDefaults) {
                Write-Host "Source branch: main (default)"; "main"
            } else {
                $v = Read-Host "Enter source branch (default: main)"
                if ([string]::IsNullOrWhiteSpace($v)) { "main" } else { $v }
            }
        }

        $customSharedDir = if ($UseDefaults) {
            Write-Host "Shared folder: <root/Shared> (default)"; ""
        } else {
            Read-Host "Enter shared folder path (default: <root/Shared>)"
        }

        Write-Host ""
        Write-Host "Configuration:"
        Write-Host "  Root Directory: $RootDir"
        Write-Host "  Worktree Path:  $worktreePath"
        Write-Host "  Branch:         $branchName"
        if (-not [string]::IsNullOrWhiteSpace($sourceBranch)) { Write-Host "  Source Branch:  $sourceBranch" }
        Write-Host ""

        if ($branchLocation -eq "local") {
            Write-Host "[OK] Branch '$branchName' already exists locally"
        } elseif ($branchLocation -eq "remote") {
            Write-Host "Branch '$branchName' exists on remote -- will create local tracking branch"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?" $UseDefaults)) {
                Write-Host "Cancelled."; return
            }
            $srcLocation = Test-BranchExists $gitDir $sourceBranch
            if ($srcLocation -eq "local") {
                Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
                git branch -- "$branchName" "$sourceBranch"
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create branch '$branchName'"; return }
                Write-Host "[OK] Branch created"
            } elseif ($srcLocation -eq "remote") {
                $remote = git remote 2>$null | Select-Object -First 1
                Write-Host "Source branch '$sourceBranch' found on remote -- fetching..."
                git fetch $remote $sourceBranch
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to fetch source branch '$sourceBranch' from remote"; return }
                Write-Host "Creating branch '$branchName' from fetched '$sourceBranch'..."
                git branch -- "$branchName" FETCH_HEAD
                if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create branch '$branchName'"; return }
                Write-Host "[OK] Branch created"
            } else {
                Write-Host "Error: Source branch '$sourceBranch' does not exist locally or on remote"
                return
            }
        }
        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        if ($branchLocation -eq "remote") {
            $remote = git remote 2>$null | Select-Object -First 1
            git worktree add --track -b "$branchName" "$worktreePath" "$remote/$branchName"
            if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create worktree at '$worktreePath'"; return }
        } else {
            git worktree add "$worktreePath" -- "$branchName"
            if ($LASTEXITCODE -ne 0) { Write-Host "Error: Failed to create worktree at '$worktreePath'"; return }
        }
        Write-Host "[OK] Worktree created"
    } finally { Pop-Location }

    Push-Location $worktreePath
    try {
        Setup-SharedLinks -RootDir $RootDir -SharedDir (Resolve-SharedDir $RootDir $customSharedDir)
    } finally { Pop-Location }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "[OK] Worktree creation + symlinks complete!"
    Write-Host "========================================="
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Show-Help {
    Write-Host "Git Worktree Management Tool"
    Write-Host "============================="
    Write-Host ""
    Write-Host "Usage: git-worktree <command> [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -y                   Accept all defaults (still prompts for values with no default)"
    Write-Host "  -WorktreePath <p>    Worktree folder path (skips the worktree path prompt)"
    Write-Host "  -BranchName <b>      Branch name (skips the branch name prompt)"
    Write-Host ""
    Write-Host "  -WorktreePath and -BranchName apply to worktree commands only (wt, all/setup/a)."
    Write-Host "  Combined with -y, all prompts are suppressed."
    Write-Host ""
    Write-Host "Commands:"
    Write-Host ""
    Write-Host "  worktree, wt   Create a new git worktree"
    Write-Host "  links, ln      Setup shared symlinks (custom path supported)"
    Write-Host "  all, setup, a  Create worktree and setup symlinks"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  git-worktree wt -WorktreePath worktrees/feat -BranchName feature/my-task"
    Write-Host "  git-worktree a -y -WorktreePath worktrees/feat -BranchName feature/auth"
    Write-Host ""
}

# Main
$rootDir = Find-Root
if ($null -eq $rootDir) {
    Write-Host "Error: Could not find repository root"
    Write-Host "Make sure you're inside a git repository (.git or .bare)"
    exit 1
}

switch ($Command) {
    ""                            { Show-Help }
    { $_ -in "worktree","wt" }   { Create-WorktreeOnly $rootDir $script:UseDefaults $script:BranchName $script:WorktreePath }
    { $_ -in "links","ln" }      {
        if (-not [string]::IsNullOrWhiteSpace($script:BranchName)) {
            Write-Host "Warning: -BranchName flag has no effect on the 'links'/'ln' command and will be ignored"
        }
        Create-LinksOnly $rootDir $script:UseDefaults
    }
    { $_ -in "all","setup","a" } { Create-WorktreeWithLinks $rootDir $script:UseDefaults $script:BranchName $script:WorktreePath }
    default {
        Write-Host "Unknown command: $Command"
        Write-Host ""
        Show-Help
        exit 1
    }
}
