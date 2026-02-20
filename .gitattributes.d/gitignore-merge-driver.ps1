#!/usr/bin/env pwsh
param(
    [string]$Base,
    [string]$Ours,
    [string]$Theirs,
    [string]$Merged
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

# --- Helper: convert .gitignore pattern → regex ---
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

# --- Helper: load all ignore patterns ---
function Load-GitIgnorePatterns {
    param([string]$RepoRoot)

    $patterns = @()

    # .gitignore files anywhere in repo
    $gitignoreFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter ".gitignore"

    foreach ($file in $gitignoreFiles) {
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $trim = $line.Trim()

            if ($trim -eq "" -or $trim.StartsWith("#")) {
                continue
            }

            $patterns += Convert-GitIgnorePatternToRegex -Pattern $trim
        }
    }

    return $patterns
}

# --- MAIN EXECUTION ---

$repoRoot = Get-RepoRoot -Start $Ours
if (-not $repoRoot) {
    Write-Error "Could not determine repo root, refusing auto-merge"
    exit 1
}

$patterns = Load-GitIgnorePatterns -RepoRoot $repoRoot

# Compute repo-relative path of the file being merged
$relativePath = Resolve-Path -LiteralPath $Ours |
ForEach-Object { $_.Path.Substring($repoRoot.Length).TrimStart("\", "/") }

# Normalize to forward slashes for gitignore semantics
$relativePath = $relativePath -replace "\\", "/"

# Check if the file matches any ignore rule
$shouldAcceptTheirs = $false
foreach ($regex in $patterns) {
    if ($relativePath -match $regex) {
        $shouldAcceptTheirs = $true
        break
    }
}

if ($shouldAcceptTheirs) {
    Copy-Item -LiteralPath $Theirs -Destination $Merged -Force
    exit 0
}

exit 1
