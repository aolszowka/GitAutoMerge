#!/usr/bin/env pwsh
param(
    [string]$Base,
    [string]$Ours,
    [string]$Theirs,
    [string]$Merged,
    [string]$RelativePath
)

# --- Helper: find repo root by walking upward ---
function Get-RepoRoot {
    param([string]$Start)

    $dir = Get-Item -LiteralPath $Start
    if ($dir -isnot [System.IO.DirectoryInfo]) {
        $dir = $dir.Directory
    }

    while ($dir -ne $null) {
        if (Test-Path -LiteralPath (Join-Path $dir.FullName ".git")) {
            return $dir.FullName
        }
        $dir = $dir.Parent
    }

    return $null
}

# --- Helper: convert .gitignore pattern ? regex ---
function Convert-GitIgnorePatternToRegex {
    param([string]$Pattern)

    # Escape regex chars
    $escaped = [Regex]::Escape($Pattern)

    # Gitignore semantics
    $escaped = $escaped -replace "\\\*", ".*"
    $escaped = $escaped -replace "\\\?", "."
    $escaped = $escaped -replace "^\\/", "^"   # leading slash = repo root
    $escaped = $escaped -replace "\\/$", "(/.*)?$" # trailing slash = directory

    return "^$escaped$"
}

# --- Helper: load ignore patterns that we would be subjected to ---
function Load-GitIgnorePatterns {
    param(
        [string]$RepoRoot,
        [string]$RelativePath
    )

    $patterns = @()

    # Convert relative path to absolute
    $absolutePath = Join-Path $RepoRoot $RelativePath
    $dir = Split-Path $absolutePath -Parent

    # Walk upward until reaching repo root
    while ($dir -and ($dir -like "$RepoRoot*")) {

        $gitignore = Join-Path $dir ".gitignore"
        if (Test-Path -LiteralPath $gitignore) {
            foreach ($line in Get-Content -LiteralPath $gitignore) {
                $trim = $line.Trim()

                if ($trim -eq "" -or $trim.StartsWith("#")) {
                    continue
                }

                $patterns += Convert-GitIgnorePatternToRegex -Pattern $trim
            }
        }

        # Move up one directory
        $dir = Split-Path $dir -Parent
    }

    return $patterns
}

# --- MAIN EXECUTION ---
$logFile = [System.IO.Path]::Combine($PSScriptRoot, "gitignore-merge-driver-$([System.DateTime]::Now.ToString("yyyyMMddHHmm")).log")

"Start Time $([System.DateTime]::Now)" | Out-File -FilePath $logFile -Append
"1.1 [Args - `$Base] - $Base" | Out-File -FilePath $logFile -Append
"1.2 [Args - `$Ours] - $Ours" | Out-File -FilePath $logFile -Append
"1.3 [Args - `$Theirs] - $Theirs" | Out-File -FilePath $logFile -Append
"1.4 [Args - `$Merged] - $Merged" | Out-File -FilePath $logFile -Append
"1.5 [Args - `$RelativePath] - $RelativePath" | Out-File -FilePath $logFile -Append

"2.1 [Get-RepoRoot] - Start" | Out-File -FilePath $logFile -Append
$repoRoot = Get-RepoRoot -Start $PSScriptRoot
"2.2 [Get-RepoRoot] - Finish - [$repoRoot]" | Out-File -FilePath $logFile -Append

if (-not $repoRoot) {
    Write-Error "Could not determine repo root, refusing auto-merge"
    "Could not determine repo root, refusing auto-merge" | Out-File -FilePath $logFile -Append
    exit 1
}

"3.1 [Load-GitIgnorePatterns] - Start" | Out-File -FilePath $logFile -Append
$patterns = Load-GitIgnorePatterns -RepoRoot $repoRoot -RelativePath $RelativePath
"3.2 [Load-GitIgnorePatterns] - End" | Out-File -FilePath $logFile -Append

# Check if the file matches any ignore rule
$shouldAcceptTheirs = $false
foreach ($regex in $patterns) {
    "4.1 [Pattern Matching Attempt] - `$regex - [$regex]" | Out-File -FilePath $logFile -Append
    "4.2 [Pattern Matching Attempt] - `$RelativePath - [$RelativePath]" | Out-File -FilePath $logFile -Append
    if ($RelativePath -match $regex) {
        $shouldAcceptTheirs = $true
        "4.3 [Pattern Match Found] - `$regex - [$regex]" | Out-File -FilePath $logFile -Append
        break
    }
}

if ($shouldAcceptTheirs) {
    "5.1 [Accepting Theirs] `$Theirs [$Theirs] - `$Merged [$Merged]" | Out-File -FilePath $logFile -Append
    Copy-Item -LiteralPath $Theirs -Destination $Merged -Force
    exit 0
}

"6.1 [No Match Made] - Exiting" | Out-File -FilePath $logFile -Append
exit 1
