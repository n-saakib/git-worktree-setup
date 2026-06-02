# Creates a shell alias for the git-worktree tool in Windows PowerShell
# Usage: .\setup-alias.ps1 [-y]
#   -y  Accept all defaults without prompting

param([switch]$y)

$UseDefaults = $y.IsPresent
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetScript = Join-Path $ScriptDir "add-git-worktree.ps1"

if (-not (Test-Path $TargetScript)) {
    Write-Error "Script not found at $TargetScript"
    exit 1
}
$TargetScript = (Resolve-Path $TargetScript).Path

# Ensure profile exists
if (-not (Test-Path $PROFILE)) {
    Write-Host "Creating PowerShell profile at $PROFILE..."
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

# Check if any function already wraps our script
$existingAlias = $null
if ($profileContent -match '(?m)^function (\S+)\s*\{[^}]*add-git-worktree\.ps1[^}]*\}') {
    $existingAlias = $Matches[1]
    Write-Host "i Found existing alias: '$existingAlias' -> add-git-worktree (in $PROFILE)"
}

$defaultAlias = if ($existingAlias) { $existingAlias } else { "gwt" }

# Prompt for alias name
if ($UseDefaults) {
    $aliasName = $defaultAlias
    Write-Host "Using alias: '$aliasName'"
} else {
    $userInput = Read-Host "Enter alias name (default: $defaultAlias)"
    $aliasName = if ([string]::IsNullOrWhiteSpace($userInput)) { $defaultAlias } else { $userInput }
}

# Check if the chosen alias is taken by something else
function Test-AliasTaken {
    param([string]$Name)
    # Check both PowerShell built-in aliases and profile functions
    $builtIn = Get-Alias $Name -ErrorAction SilentlyContinue
    if ($builtIn) { return "Built-in alias: $($builtIn.Definition)" }

    if ($profileContent -match "(?s)function $Name\s*\{") {
        $fnLine = ($profileContent -split "`n" | Where-Object { $_ -match "function $Name\s*" } | Select-Object -First 1).Trim()
        # Only flag as taken if it does NOT point to our script
        if ($profileContent -notmatch "add-git-worktree\.ps1") {
            return "Profile function: $fnLine"
        }
    }
    return $null
}

$conflict = Test-AliasTaken $aliasName
while ($conflict) {
    Write-Host "Warning: Alias '$aliasName' is already taken: $conflict"

    if ($UseDefaults) {
        Write-Error "Cannot use default alias '$aliasName' with -y -- it is already taken."
        exit 1
    }

    $userInput = Read-Host "Enter a different alias name"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        Write-Host "Alias name cannot be empty."
        $conflict = "placeholder"
        continue
    }
    $aliasName = $userInput
    $conflict = Test-AliasTaken $aliasName
}

$nl = [System.Environment]::NewLine
$functionBlock = $nl + "# Git worktree management tools" + $nl +
    "function $aliasName {" + $nl +
    ('    & "' + $TargetScript + '" @args') + $nl +
    "}"

if ($profileContent -match "(?s)# Git worktree management tools\s*function \S+ \{[^}]*\}") {
    $profileContent = $profileContent -replace '(?s)# Git worktree management tools\s*function \S+ \{[^}]*\}', $functionBlock.Trim()
    Set-Content $PROFILE $profileContent
    Write-Host "[OK] Updated alias in $PROFILE"
} else {
    Add-Content $PROFILE $functionBlock
    Write-Host "[OK] Added alias to $PROFILE"
}

Write-Host ""
Write-Host "Alias '$aliasName' created successfully!"
Write-Host ""
Write-Host "To activate in this session, run:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Or open a new PowerShell window."
Write-Host ""
Write-Host "Note: Symlink creation requires Developer Mode or Administrator privileges."
Write-Host ""
Write-Host "Usage:"
Write-Host "  $aliasName wt       - Create a worktree"
Write-Host "  $aliasName ln       - Setup shared symlinks"
Write-Host "  $aliasName a        - Create worktree + symlinks"
Write-Host "  $aliasName          - Show all commands"
