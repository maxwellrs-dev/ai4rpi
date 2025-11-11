# Script mínimo: apenas chamadas sequenciais pdflatex -> biber -> pdflatex -> pdflatex
 #requires -Version 5.1

$pdflatex = 'C:\miktex-portable\texmfs\install\miktex\bin\x64\pdflatex.exe'
$biber = if (Test-Path 'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber-ms.exe') { 'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber-ms.exe' } else { 'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber.exe' }
$texFile = 'C:\gitclones\ai4rpi\tcc1_maxwell.tex'

if (-not (Test-Path $pdflatex)) { Write-Error 'pdflatex não encontrado'; exit 1 }
if (-not (Test-Path $biber)) { Write-Error 'biber não encontrado'; exit 1 }
if (-not (Test-Path $texFile)) { Write-Error 'Arquivo .tex não encontrado'; exit 1 }

$workDir = Split-Path $texFile -Parent
$base = Split-Path $texFile -LeafBase
Push-Location $workDir

& $pdflatex -interaction=nonstopmode -file-line-error $base
if ($LASTEXITCODE -ne 0) { Pop-Location; exit 1 }

& $biber $base
if ($LASTEXITCODE -ne 0) { Pop-Location; exit 1 }

& $pdflatex -interaction=nonstopmode -file-line-error $base
if ($LASTEXITCODE -ne 0) { Pop-Location; exit 1 }

& $pdflatex -interaction=nonstopmode -file-line-error $base
if ($LASTEXITCODE -ne 0) { Pop-Location; exit 1 }

Pop-Location
$pdf = Join-Path $workDir "$base.pdf"
if (Test-Path $pdf) { Write-Host "PDF gerado: $pdf" -ForegroundColor Green } else { Write-Warning 'PDF não encontrado.' }
exit 0
