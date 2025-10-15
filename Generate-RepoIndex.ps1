<#
.SYNOPSIS
    Generates an index.json file for a documentation or code repository.

.DESCRIPTION
    Scans a directory recursively and builds a structured JSON object
    mapping folder names to their contained files.
    Designed for use as a knowledge index for a custom GPT or documentation system.

.PARAMETER RootPath
    The root folder of your repository.

.PARAMETER OutputPath
    Path to save the generated index.json file (defaults to root folder).

.EXAMPLE
    .\Generate-RepoIndex.ps1 -RootPath "C:\Git\PowerPacks-GPT"
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RootPath = $PSScriptRoot,

    [string]$OutputPath = "$RootPath\index.json"
)

Write-Host "🔍 Scanning repository: $RootPath" -ForegroundColor Cyan

# Collect all files except common junk
$files = Get-ChildItem -Path $RootPath -File -Recurse |
    Where-Object { $_.Extension -in '.md', '.ps1', '.json' }

# Create ordered hashtable to preserve folder hierarchy
$repoIndex = [ordered]@{}

foreach ($file in $files) {
    # Relative path (for JSON)
    $relativePath = $file.FullName.Substring($RootPath.Length + 1) -replace '\\', '/'

    # Folder name (top-level directory under root)
    $folder = ($relativePath -split '/')[0]

    if (-not $repoIndex.Contains($folder)) {
        $repoIndex[$folder] = [ordered]@{}
    }

    # Add file entry without extension as key
    $key = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $repoIndex[$folder][$key] = $relativePath
}

# Convert to JSON (pretty format)
$json = $repoIndex | ConvertTo-Json -Depth 5 -Compress:$false

# Save file
$json | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "✅ index.json created at: $OutputPath" -ForegroundColor Green
