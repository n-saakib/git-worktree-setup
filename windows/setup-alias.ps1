# Creates a shell alias for the git-worktree tool in Windows PowerShell
# Usage: .\setup-alias.ps1 [-y]
#   -y  Accept all defaults without prompting

param([switch]$y)

$UseDefaults = $y.IsPresent
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetScript = Join-Path $ScriptDir "add-git-worktree.ps1"

if (-not (Test-Path $TargetScript)) {
    Write-Host "Error: Script not found at $TargetScript"
    exit 1
}
$TargetScript = (Resolve-Path $TargetScript).Path

# Ensure profile exists
if (-not (Test-Path $PROFILE)) {
    Write-Host "Creating PowerShell profile at $PROFILE..."
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($null -eq $profileContent) { $profileContent = "" }

# Check if any function already wraps our script
$existingAlias = $null
if ($profileContent -match '(?s)# Git worktree management tools\s*function (\S+)\s*\{.*?\n\}') {
    $matchedBlock = $Matches[0]
    if ($matchedBlock -match 'add-git-worktree\.ps1') {
        $existingAlias = $Matches[1]
        Write-Host "Found existing alias: '$existingAlias' -> add-git-worktree (in $PROFILE)"
    }
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

    $escapedName = [regex]::Escape($Name)
    if ($profileContent -match "(?s)(function $escapedName\s*\{.*?\n\})") {
        $matchedBlock = $Matches[1]
        # Only flag as taken if it does NOT point to our script
        if ($matchedBlock -notmatch "add-git-worktree\.ps1") {
            return "Profile function: $Name"
        }
    }
    return $null
}

$conflict = Test-AliasTaken $aliasName
while ($conflict) {
    Write-Host "Warning: Alias '$aliasName' is already taken: $conflict"

    if ($UseDefaults) {
        Write-Host "Error: Cannot use default alias '$aliasName' with -y -- it is already taken."
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

if ($profileContent -match '(?s)# Git worktree management tools\s*function \S+ \{.*?\n\}') {
    $profileContent = [regex]::Replace($profileContent, '(?s)# Git worktree management tools\s*function \S+ \{.*?\n\}', { param($m) $functionBlock.Trim() })
    Set-Content $PROFILE $profileContent -Encoding UTF8
    Write-Host "[OK] Updated alias in $PROFILE"
} else {
    Add-Content $PROFILE $functionBlock -Encoding UTF8
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

# --- Git Bash setup ---
Write-Host ""
$bashExe = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bashExe) {
    foreach ($p in @("C:\Program Files\Git\bin\bash.exe", "C:\Program Files (x86)\Git\bin\bash.exe")) {
        if (Test-Path $p) { $bashExe = $p; break }
    }
}

if ($bashExe) {
    Write-Host "Git Bash detected."

    $setupGitBash = if ($UseDefaults) {
        Write-Host "Setting up Git Bash alias: yes (default)"
        $true
    } else {
        $r = Read-Host "Also set up alias for Git Bash? (Y/n)"
        [string]::IsNullOrWhiteSpace($r) -or $r.ToLower() -in @("y","yes","ye")
    }

    if ($setupGitBash) {
        $repoRoot     = Split-Path -Parent $ScriptDir
        $linuxScript  = Join-Path $repoRoot "linux\add-git-worktree.sh"

        if (-not (Test-Path $linuxScript)) {
            Write-Host "Warning: linux\add-git-worktree.sh not found -- skipping Git Bash setup"
        } else {
            # Convert Windows path to Git Bash path: C:\foo\bar -> /c/foo/bar
            $gitBashPath = (Resolve-Path $linuxScript).Path
            if ($gitBashPath -match '^([A-Za-z]):(.*)') {
                $gitBashPath = '/' + $Matches[1].ToLower() + ($Matches[2] -replace '\\', '/')
            }

            $bashRcPath = Join-Path $HOME ".bashrc"

            $bashRcContent = if (Test-Path $bashRcPath) {
                [System.IO.File]::ReadAllText($bashRcPath)
            } else { "" }

            # Detect existing alias pointing to our script
            $existingBashAlias = $null
            if ($bashRcContent -match "alias ([^\s=]+)='[^']*add-git-worktree\.sh'") {
                $existingBashAlias = $Matches[1]
                Write-Host "Found existing Git Bash alias: '$existingBashAlias' -> add-git-worktree (in $bashRcPath)"
            }

            $defaultBashAlias = if ($existingBashAlias) { $existingBashAlias } else { $aliasName }

            $bashAliasName = if ($UseDefaults) {
                Write-Host "Using Git Bash alias: '$defaultBashAlias'"
                $defaultBashAlias
            } else {
                $v = Read-Host "Enter Git Bash alias name (default: $defaultBashAlias)"
                if ([string]::IsNullOrWhiteSpace($v)) { $defaultBashAlias } else { $v }
            }

            # Check for conflict (taken by something other than our script)
            $bashConflict = $null
            $escapedName  = [regex]::Escape($bashAliasName)
            if ($bashRcContent -match "alias $escapedName=" -and
                $bashRcContent -notmatch "alias $escapedName='[^']*add-git-worktree\.sh'") {
                $bashConflict = "already defined in $bashRcPath"
            }

            while ($bashConflict) {
                Write-Host "Warning: Alias '$bashAliasName' is already taken: $bashConflict"
                if ($UseDefaults) {
                    Write-Host "Error: Cannot use alias '$bashAliasName' with -y -- it is already taken."
                    $bashAliasName = $null; break
                }
                $v = Read-Host "Enter a different Git Bash alias name"
                if ([string]::IsNullOrWhiteSpace($v)) { Write-Host "Alias name cannot be empty."; continue }
                $bashAliasName = $v
                $escapedName   = [regex]::Escape($bashAliasName)
                $bashConflict  = if ($bashRcContent -match "alias $escapedName=" -and
                                     $bashRcContent -notmatch "alias $escapedName='[^']*add-git-worktree\.sh'") {
                    "already defined in $bashRcPath"
                } else { $null }
            }

            if ($bashAliasName) {
                $aliasLine = "alias $bashAliasName='$gitBashPath'"

                if ($bashRcContent -match "alias [^\s=]+='[^']*add-git-worktree\.sh'") {
                    $bashRcContent = [regex]::Replace(
                        $bashRcContent,
                        "alias [^\s=]+='[^']*add-git-worktree\.sh'",
                        $aliasLine
                    )
                    [System.IO.File]::WriteAllText($bashRcPath, $bashRcContent, [System.Text.Encoding]::UTF8)
                    Write-Host "[OK] Updated Git Bash alias in $bashRcPath"
                } else {
                    $addition = "`n# Git worktree management tools`n$aliasLine`n"
                    [System.IO.File]::AppendAllText($bashRcPath, $addition, [System.Text.Encoding]::UTF8)
                    Write-Host "[OK] Added Git Bash alias to $bashRcPath"
                }

                Write-Host ""
                Write-Host "Git Bash alias '$bashAliasName' created successfully!"
                Write-Host "To activate in Git Bash, run: source ~/.bashrc"
            }
        }
    }
}
