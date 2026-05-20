# scripts/test-corpus.ps1
#
# Bulk-parse a directory of .au3 files against the tree-sitter-autoit grammar.
# Reports pass/fail counts and writes a triage list of files with errors.
#
# Usage:
#   .\scripts\test-corpus.ps1 -CorpusDir "C:\Program Files (x86)\AutoIt3\Examples"
#
# Optional:
#   -GrammarDir  default ..\tree-sitter-autoit (sibling repo to this one)
#   -OutputFile  default corpus-failures.txt in current directory
#   -MaxFiles    parse only first N files (smoke-test mode); 0 = no limit
#
# Notes
# - The grammar's parser is loaded by `npx tree-sitter parse` from GrammarDir,
#   so the script Push-Locations there for the duration of the run. No env
#   vars (CC, PATH) needed - those are only for `tree-sitter generate`/test.
# - We use --quiet to suppress the tree dump; exit code distinguishes
#   clean parses from files with ERROR/MISSING nodes.
# - A failing file gets a second, non-quiet parse to extract the first error
#   line for triage. That second pass is rare (only when failures exist),
#   so the overall cost stays roughly one tree-sitter invocation per file.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CorpusDir,

    # Resolved relative to this script's location ($PSScriptRoot is
    # scripts/, so ..\..\tree-sitter-autoit is the sibling repo).
    # Override on the command line if your layout differs.
    [string]$GrammarDir = (Join-Path $PSScriptRoot "..\..\tree-sitter-autoit"),

    [string]$OutputFile = "corpus-failures.txt",

    [int]$MaxFiles = 0
)

if (-not (Test-Path $CorpusDir)) {
    Write-Error "Corpus directory not found: $CorpusDir"
    exit 1
}

if (-not (Test-Path $GrammarDir)) {
    Write-Error "Grammar directory not found: $GrammarDir"
    exit 1
}

Write-Host "Scanning $CorpusDir for .au3 files..."
$files = Get-ChildItem -Path $CorpusDir -Recurse -File -Filter "*.au3" -ErrorAction SilentlyContinue
if ($MaxFiles -gt 0 -and $files.Count -gt $MaxFiles) {
    $files = $files | Select-Object -First $MaxFiles
    Write-Host "Limiting to first $MaxFiles files"
}
$total = $files.Count
Write-Host "Found $total .au3 files. Parsing..."

$failures = New-Object System.Collections.Generic.List[object]
$clean = 0
$i = 0
$startedAt = Get-Date

Push-Location $GrammarDir

try {
    foreach ($file in $files) {
        $i++
        if (($i % 200) -eq 0) {
            $elapsed = (Get-Date) - $startedAt
            $rate = [math]::Round($i / $elapsed.TotalSeconds, 1)
            Write-Host "  $i / $total  ($rate files/sec)"
        }

        # First pass: quiet, just check exit code.
        $null = npx tree-sitter parse --quiet $file.FullName 2>&1
        $exit = $LASTEXITCODE

        if ($exit -eq 0) {
            $clean++
        } else {
            # Second pass to extract first ERROR/MISSING line for triage.
            $output = npx tree-sitter parse $file.FullName 2>&1
            $firstErrorLine = ($output | Select-String "ERROR|MISSING" | Select-Object -First 1).Line
            if (-not $firstErrorLine) {
                # No tree-level ERROR/MISSING but exit nonzero - likely
                # encoding or read failure. Capture the first stderr line.
                $firstErrorLine = ($output | Select-Object -First 1).ToString().Trim()
            }

            $failures.Add([PSCustomObject]@{
                Path           = $file.FullName
                ExitCode       = $exit
                FirstErrorLine = $firstErrorLine
            })
        }
    }
} finally {
    Pop-Location
}

$elapsed = (Get-Date) - $startedAt
$passRate = if ($total -gt 0) { [math]::Round(($clean / $total) * 100, 2) } else { 0 }

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Total files: $total"
Write-Host "Clean parse: $clean"
Write-Host "With errors: $($failures.Count)"
Write-Host "Pass rate:   $passRate%"
Write-Host "Elapsed:     $([math]::Round($elapsed.TotalSeconds, 1))s"

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "=== First 20 failures ==="
    $failures | Select-Object -First 20 | ForEach-Object {
        Write-Host "  $($_.Path)"
        if ($_.FirstErrorLine) {
            Write-Host "    -> $($_.FirstErrorLine)"
        }
    }

    # Group failure signatures for triage.
    Write-Host ""
    Write-Host "=== Failure signatures (top 10) ==="
    $failures `
        | Where-Object { $_.FirstErrorLine } `
        | Group-Object { ($_.FirstErrorLine -replace '\d+', 'N') } `
        | Sort-Object Count -Descending `
        | Select-Object -First 10 `
        | ForEach-Object {
            Write-Host ("  [{0,4}] {1}" -f $_.Count, $_.Name)
        }

    $failures | ForEach-Object { "$($_.Path)`t$($_.FirstErrorLine)" } | Set-Content -Path $OutputFile -Encoding utf8
    Write-Host ""
    Write-Host "Full failure list written to: $OutputFile"
}
