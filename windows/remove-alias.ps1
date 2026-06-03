# Removes the git-worktree alias from the PowerShell profile
# Detects the alias by script path, regardless of what name it was given

if (-not (Test-Path $PROFILE)) {
    Write-Host "No PowerShell profile found at $PROFILE. Nothing to remove."
    exit 0
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if (-not ($profileContent -match 'add-git-worktree\.ps1')) {
    Write-Host "No git-worktree alias found in $PROFILE. Nothing to remove."
    exit 0
}

# Extract the alias name for the confirmation message
$aliasName = "unknown"
if ($profileContent -match '(?m)^function (\S+)') {
    # Find the function that contains our script reference
    $lines = $profileContent -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^function (\S+)') {
            $candidate = $Matches[1]
            # Check if this function block contains our script
            $block = ($lines[$i..([Math]::Min($i+5, $lines.Count-1))] -join "`n")
            if ($block -match 'add-git-worktree\.ps1') {
                $aliasName = $candidate
                break
            }
        }
    }
}

# Remove the comment + function block
$profileContent = $profileContent -replace '(?s)(?:\r?\n)?# Git worktree management tools\s*function \S+ \{.*?\n\}', ''

Set-Content $PROFILE $profileContent -Encoding UTF8
Write-Host "[OK] Removed alias '$aliasName' from $PROFILE"

Write-Host ""
Write-Host "Alias removed successfully!"
Write-Host ""
Write-Host "To apply in this session, run:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Or open a new PowerShell window."
