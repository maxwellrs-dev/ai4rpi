#requires -Version 5.1

<#
Compila o TCC com pdflatex + biber + pdflatex (duas vezes), usando os executáveis
MiKTeX portáteis informados e o arquivo principal em C:\gitclones\ai4rpi.

Passos:
 1) pdflatex (1/3)
 2) biber
 3) pdflatex (2/3)
 4) pdflatex (3/3)

Saída esperada: tcc1_maxwell.pdf no mesmo diretório do .tex
#>

$pdflatex = 'C:\miktex-portable\texmfs\install\miktex\bin\x64\pdflatex.exe'
# Preferir biber-ms.exe; se ausente, usar biber.exe
$biberCandidates = @(
    'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber.exe',
    'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber.exe'
)
$biber = $null
foreach ($cand in $biberCandidates) { if (Test-Path -LiteralPath $cand) { $biber = $cand; break } }
$texFile  = 'C:\gitclones\ai4rpi\tcc1_maxwell.tex'

function Assert-Path([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
    throw "Caminho nao encontrado para ${Label}: $Path"
    }
}

function Invoke-Step([scriptblock]$Action, [string]$Name) {
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Action
    $code = $LASTEXITCODE
    if ($code -ne 0) {
    throw "$Name falhou com codigo $code."
    }
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [int]$TimeoutMs = 120000,
        [string]$Name = 'processo'
    )
    Write-Host "==> $Name" -ForegroundColor Cyan
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = [string]::Join(' ', $Arguments)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    if (-not $proc.WaitForExit($TimeoutMs)) {
        try { $proc.Kill() } catch {}
        throw "$Name excedeu o tempo limite (${TimeoutMs}ms)."
    }
    if ($proc.ExitCode -ne 0) {
        $err = $proc.StandardError.ReadToEnd()
        if (-not $err) { $err = $proc.StandardOutput.ReadToEnd() }
        throw "$Name encerrou com codigo $($proc.ExitCode). Saida: $err"
    }
}

try {
    Write-Host "DEBUG: asserting paths" -ForegroundColor DarkGray
    Assert-Path $pdflatex 'pdflatex'
    Assert-Path $biber 'biber'
    Assert-Path $texFile 'arquivo .tex'

    Write-Host "DEBUG: computing paths" -ForegroundColor DarkGray
    $workDir = [System.IO.Path]::GetDirectoryName($texFile)
    $base    = [System.IO.Path]::GetFileNameWithoutExtension($texFile)

    Write-Host "DEBUG: push-location -> $workDir" -ForegroundColor DarkGray
    Push-Location -Path $workDir
    try {
        Write-Host "DEBUG: invoking pdflatex 1" -ForegroundColor DarkGray
        Invoke-Step { & $pdflatex -interaction=nonstopmode -file-line-error -halt-on-error $base } 'pdflatex (1/3)'
        Write-Host "DEBUG: invoking $([System.IO.Path]::GetFileName($biber)) (with log and timeout)" -ForegroundColor DarkGray
        $biberLog   = Join-Path $workDir "$base.biber.log"
        $biberCache = Join-Path $workDir ".biber-cache"
        New-Item -ItemType Directory -Force -Path $biberCache | Out-Null
        Invoke-ProcessWithTimeout -FilePath $biber -Arguments @(
            "--logfile","`"$biberLog`"",
            "--debug",
            "--trace",
            "--cache","`"$biberCache`"",
            "$base"
        ) -TimeoutMs 180000 -Name 'biber'
        Write-Host "DEBUG: invoking pdflatex 2" -ForegroundColor DarkGray
        Invoke-Step { & $pdflatex -interaction=nonstopmode -file-line-error -halt-on-error $base } 'pdflatex (2/3)'
        Write-Host "DEBUG: invoking pdflatex 3" -ForegroundColor DarkGray
        Invoke-Step { & $pdflatex -interaction=nonstopmode -file-line-error -halt-on-error $base } 'pdflatex (3/3)'

        $pdf = Join-Path $workDir "$base.pdf"
        if (Test-Path -LiteralPath $pdf) {
            Write-Host "PDF gerado: $pdf" -ForegroundColor Green
        } else {
            Write-Warning "Compilacao finalizou, mas o PDF nao foi encontrado: $pdf"
        }
    }
    finally {
        Pop-Location | Out-Null
    }
}
catch {
    Write-Error $_
    try {
        $workDir = Split-Path -LiteralPath $texFile -Parent
        $base    = [System.IO.Path]::GetFileNameWithoutExtension($texFile)
        $logPdf  = Join-Path $workDir "$base.log"
        $logBib  = Join-Path $workDir "$base.blg"
        if (Test-Path -LiteralPath $logPdf) {
            Write-Host "Log pdflatex: $logPdf" -ForegroundColor Yellow
        }
        if (Test-Path -LiteralPath $logBib) {
            Write-Host "Log biber:    $logBib" -ForegroundColor Yellow
        }
    } catch { }
    exit 1
}
exit 0
