# Git worktree and symlink management script — Windows (PowerShell)
# Usage: git-worktree <command> [-y]
#   -y  Accept all defaults without prompting (still prompts for required values)
# Requires: Git for Windows, PowerShell 5+
# Note: Symlink creation requires Developer Mode or Administrator privileges

[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$Command = "",
    [switch]$y
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
        if (Test-Path (Join-Path $current ".git"))  { return $current }
        $current = Split-Path $current -Parent
    }
    return $null
}

function Resolve-SharedDir {
    param([string]$RootDir, [string]$Input)
    if ([string]::IsNullOrWhiteSpace($Input)) { return Join-Path $RootDir "Shared" }
    if ([System.IO.Path]::IsPathRooted($Input)) { return $Input }
    return Join-Path $RootDir $Input
}

function Setup-SharedLinks {
    param([string]$RootDir, [string]$SharedDir = "")
    if ([string]::IsNullOrWhiteSpace($SharedDir)) { $SharedDir = Join-Path $RootDir "Shared" }

    if (-not (Test-Path $SharedDir)) {
        Write-Host "Warning: Shared folder not found at $SharedDir. Skipping."
        return
    }

    Write-Host "Setting up shared symlinks..."
    Write-Host "  Shared directory: $SharedDir"
    Write-Host "  Target directory: $(Get-Location)"
    Write-Host ""

    foreach ($item in (Get-ChildItem -Path $SharedDir -Force)) {
        $linkPath = Join-Path (Get-Location) $item.Name
        if (Test-Path $linkPath) {
            Write-Host "Warning: Skipping '$($item.Name)' - already exists"
            continue
        }
        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $item.FullName | Out-Null
            Write-Host "✓ Created symlink: $($item.Name)"
        } catch {
            Write-Host "Error creating symlink for '$($item.Name)': $_"
            Write-Host "Tip: Enable Developer Mode or run as Administrator."
        }
    }

    Write-Host ""
    Write-Host "✓ Done! All shared items have been symlinked."
}

function Create-WorktreeOnly {
    param([string]$RootDir)

    $bareDir = Join-Path $RootDir ".bare"
    $gitDir  = if (Test-Path $bareDir) { $bareDir } else { Join-Path $RootDir ".git" }
    if (-not (Test-Path $gitDir)) { Write-Error "Git directory not found"; return }

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation"
    Write-Host "========================================="
    Write-Host ""

    # Worktree path — no default, always prompt
    $worktreePath = Read-Host "Enter worktree folder path"
    if ([string]::IsNullOrWhiteSpace($worktreePath)) { Write-Error "Worktree path is required"; return }
    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) { $worktreePath = Join-Path $RootDir $worktreePath }

    $folderName = Split-Path $worktreePath -Leaf

    # Branch name
    $branchName = if ($UseDefaults) {
        Write-Host "Branch name: $folderName (default)"; $folderName
    } else {
        $v = Read-Host "Enter branch name (default: folder name '$folderName')"
        if ([string]::IsNullOrWhiteSpace($v)) { $folderName } else { $v }
    }

    # Source branch
    $sourceBranch = if ($UseDefaults) {
        Write-Host "Source branch: main (default)"; "main"
    } else {
        $v = Read-Host "Enter source branch (default: main)"
        if ([string]::IsNullOrWhiteSpace($v)) { "main" } else { $v }
    }

    Write-Host ""
    Write-Host "Configuration:"
    Write-Host "  Root Directory: $RootDir"
    Write-Host "  Worktree Path:  $worktreePath"
    Write-Host "  Branch:         $branchName"
    Write-Host "  Source Branch:  $sourceBranch"
    Write-Host ""

    Push-Location $gitDir
    try {
        git show-ref --quiet --verify "refs/heads/$branchName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Branch '$branchName' already exists"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?" $UseDefaults)) {
                Write-Host "Cancelled."; return
            }
            git show-ref --quiet --verify "refs/heads/$sourceBranch" 2>$null
            if ($LASTEXITCODE -ne 0) { Write-Error "Source branch '$sourceBranch' does not exist"; return }
            Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
            git branch $branchName $sourceBranch
            Write-Host "✓ Branch created"
        }
        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        git worktree add $worktreePath $branchName
        Write-Host "✓ Worktree created"
    } finally { Pop-Location }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "✓ Worktree creation complete!"
    Write-Host "========================================="
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Create-LinksOnly {
    param([string]$RootDir)

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
    Write-Host "✓ Symlink setup complete!"
    Write-Host "========================================="
    Write-Host ""
}

function Create-WorktreeWithLinks {
    param([string]$RootDir)

    $bareDir = Join-Path $RootDir ".bare"
    $gitDir  = if (Test-Path $bareDir) { $bareDir } else { Join-Path $RootDir ".git" }
    if (-not (Test-Path $gitDir)) { Write-Error "Git directory not found"; return }

    Write-Host "========================================="
    Write-Host "  Git Worktree Creation + Symlinks"
    Write-Host "========================================="
    Write-Host ""

    # Worktree path — no default, always prompt
    $worktreePath = Read-Host "Enter worktree folder path"
    if ([string]::IsNullOrWhiteSpace($worktreePath)) { Write-Error "Worktree path is required"; return }
    if (-not [System.IO.Path]::IsPathRooted($worktreePath)) { $worktreePath = Join-Path $RootDir $worktreePath }

    $folderName = Split-Path $worktreePath -Leaf

    $branchName = if ($UseDefaults) {
        Write-Host "Branch name: $folderName (default)"; $folderName
    } else {
        $v = Read-Host "Enter branch name (default: folder name '$folderName')"
        if ([string]::IsNullOrWhiteSpace($v)) { $folderName } else { $v }
    }

    $sourceBranch = if ($UseDefaults) {
        Write-Host "Source branch: main (default)"; "main"
    } else {
        $v = Read-Host "Enter source branch (default: main)"
        if ([string]::IsNullOrWhiteSpace($v)) { "main" } else { $v }
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
    Write-Host "  Source Branch:  $sourceBranch"
    Write-Host ""

    Push-Location $gitDir
    try {
        git show-ref --quiet --verify "refs/heads/$branchName" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Branch '$branchName' already exists"
        } else {
            Write-Host "Branch '$branchName' does not exist"
            if (-not (Confirm-Action "Create branch '$branchName' from '$sourceBranch'?" $UseDefaults)) {
                Write-Host "Cancelled."; return
            }
            git show-ref --quiet --verify "refs/heads/$sourceBranch" 2>$null
            if ($LASTEXITCODE -ne 0) { Write-Error "Source branch '$sourceBranch' does not exist"; return }
            Write-Host "Creating branch '$branchName' from '$sourceBranch'..."
            git branch $branchName $sourceBranch
            Write-Host "✓ Branch created"
        }
        Write-Host ""
        Write-Host "Creating worktree at $worktreePath..."
        git worktree add $worktreePath $branchName
        Write-Host "✓ Worktree created"
    } finally { Pop-Location }

    Set-Location $worktreePath
    Setup-SharedLinks -RootDir $RootDir -SharedDir (Resolve-SharedDir $RootDir $customSharedDir)

    Write-Host ""
    Write-Host "========================================="
    Write-Host "✓ Worktree creation + symlinks complete!"
    Write-Host "========================================="
    Write-Host "  $worktreePath"
    Write-Host ""
}

function Show-Help {
    Write-Host "Git Worktree Management Tool"
    Write-Host "============================="
    Write-Host ""
    Write-Host "Usage: git-worktree <command> [-y]"
    Write-Host ""
    Write-Host "  -y  Accept all defaults (still prompts for values with no default)"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host ""
    Write-Host "  worktree, wt   Create a new git worktree"
    Write-Host "  links, ln      Setup shared symlinks (custom path supported)"
    Write-Host "  all, setup, a  Create worktree and setup symlinks"
    Write-Host ""
}

# Main
$rootDir = Find-Root
if ($null -eq $rootDir) {
    Write-Error "Could not find repository root. Make sure you're inside a git repository (.git or .bare)."
    exit 1
}

switch ($Command) {
    ""                            { Show-Help }
    { $_ -in "worktree","wt" }   { Create-WorktreeOnly $rootDir }
    { $_ -in "links","ln" }      { Create-LinksOnly $rootDir }
    { $_ -in "all","setup","a" } { Create-WorktreeWithLinks $rootDir }
    default {
        Write-Host "Unknown command: $Command"
        Write-Host ""
        Show-Help
        exit 1
    }
}
