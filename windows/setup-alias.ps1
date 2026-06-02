# Creates the git-worktree alias for Windows PowerShell
# Run this script once to add the alias to your PowerShell profile

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetScript = Join-Path $ScriptDir "add-git-worktree.ps1"

if (-not (Test-Path $TargetScript)) {
    Write-Error "Script not found at $TargetScript"
    exit 1
}

$TargetScript = (Resolve-Path $TargetScript).Path

$FunctionBlock = @"

# Git worktree management tools
function git-worktree {
    & "$TargetScript" @args
}
"@

if (-not (Test-Path $PROFILE)) {
    Write-Host "Creating PowerShell profile at $PROFILE..."
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -match "function git-worktree") {
    $profileContent = $profileContent -replace '(?s)# Git worktree management tools\s*function git-worktree \{[^}]*\}', $FunctionBlock.Trim()
    Set-Content $PROFILE $profileContent
    Write-Host "✓ Updated git-worktree function in $PROFILE"
} else {
    Add-Content $PROFILE $FunctionBlock
    Write-Host "✓ Added git-worktree function to $PROFILE"
}

Write-Host ""
Write-Host "Alias created successfully!"
Write-Host ""
Write-Host "To activate in this session, run:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Or open a new PowerShell window."
Write-Host ""
Write-Host "Note: Symlink creation on Windows requires either:"
Write-Host "  - Developer Mode enabled (Settings > System > Developer Mode)"
Write-Host "  - Running PowerShell as Administrator"
Write-Host ""
Write-Host "Usage:"
Write-Host "  git-worktree wt       - Create a worktree"
Write-Host "  git-worktree ln       - Setup shared symlinks"
Write-Host "  git-worktree a        - Create worktree + symlinks"
Write-Host "  git-worktree          - Show all commands"
