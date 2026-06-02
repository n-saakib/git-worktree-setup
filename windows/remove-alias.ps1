# Removes the git-worktree alias from the PowerShell profile

if (-not (Test-Path $PROFILE)) {
    Write-Host "No PowerShell profile found at $PROFILE. Nothing to remove."
    exit 0
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if (-not ($profileContent -match "function git-worktree")) {
    Write-Host "No git-worktree alias found in $PROFILE. Nothing to remove."
    exit 0
}

# Remove the comment line, function block, and surrounding blank line
$profileContent = $profileContent -replace '(?s)\r?\n# Git worktree management tools\r?\nfunction git-worktree \{[^}]*\}', ''

Set-Content $PROFILE $profileContent
Write-Host "✓ Removed git-worktree function from $PROFILE"

Write-Host ""
Write-Host "Alias removed successfully!"
Write-Host ""
Write-Host "To apply in this session, run:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Or open a new PowerShell window."
