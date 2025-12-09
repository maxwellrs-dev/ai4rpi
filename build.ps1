# build_tcc1.ps1 - Com detecção automática de compiladores

# --- Configurações de Caminhos Portáteis (Fallback) ---
$portablePdfLatex = 'C:\miktex-portable\texmfs\install\miktex\bin\x64\pdflatex.exe'
$portableBiber    = 'C:\miktex-portable\texmfs\install\miktex\bin\x64\biber.exe'

# --- Detecção do pdflatex ---
if (Get-Command "pdflatex" -ErrorAction SilentlyContinue) {
    $pdflatexCmd = "pdflatex"
    Write-Host "Info: Usando 'pdflatex' do sistema (PATH)." -ForegroundColor Gray
} elseif (Test-Path $portablePdfLatex) {
    $pdflatexCmd = $portablePdfLatex
    Write-Host "Info: 'pdflatex' não encontrado no PATH. Usando versão portável." -ForegroundColor Yellow
} else {
    Write-Host "ERRO: pdflatex não encontrado no sistema nem no caminho portável." -ForegroundColor Red
    Exit
}

# --- Detecção do biber ---
if (Get-Command "biber" -ErrorAction SilentlyContinue) {
    $biberCmd = "biber"
    Write-Host "Info: Usando 'biber' do sistema (PATH)." -ForegroundColor Gray
} elseif (Test-Path $portableBiber) {
    $biberCmd = $portableBiber
    Write-Host "Info: 'biber' não encontrado no PATH. Usando versão portável." -ForegroundColor Yellow
} else {
    Write-Host "ERRO: biber não encontrado no sistema nem no caminho portável." -ForegroundColor Red
    Exit
}

# --- Configurações do Projeto ---
# Caminho do arquivo .tex (mesmo diretório)
$texFile = "tcc1_maxwell.tex"
$rootDir = ".\"

# Pasta de build
$buildDir = ".\build"

# Criar pasta de build se não existir
if (-not (Test-Path -Path $buildDir)) {
    Write-Host "Criando pasta de build: $($buildDir)" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

# Extrair nome base do arquivo .tex
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($texFile)
$pdfFileName = $baseName + ".pdf"
$sourcePdfPath = Join-Path -Path $buildDir -ChildPath $pdfFileName
$destPdfPath = Join-Path -Path $rootDir -ChildPath $pdfFileName


# --- Etapas de compilação ---

# Rodar pdflatex (primeira vez)
Write-Host "Rodando pdflatex (1)..." -ForegroundColor Cyan
& $pdflatexCmd -interaction=nonstopmode -output-directory="$($buildDir)" $texFile

# Rodar biber
Write-Host "Rodando biber..." -ForegroundColor Cyan
& $biberCmd --input-directory="$($buildDir)" --output-directory="$($buildDir)" $baseName

# Rodar pdflatex mais duas vezes
Write-Host "Rodando pdflatex (2)..." -ForegroundColor Cyan
& $pdflatexCmd -interaction=nonstopmode -output-directory="$($buildDir)" $texFile

Write-Host "Rodando pdflatex (3)..." -ForegroundColor Cyan
& $pdflatexCmd -interaction=nonstopmode -output-directory="$($buildDir)" $texFile

# --- Mover o PDF final ---

Write-Host "Movendo PDF final para a pasta principal..." -ForegroundColor Cyan

if (Test-Path -Path $sourcePdfPath) {
    # Move o arquivo, sobrescrevendo se já existir na raiz
    Move-Item -Path $sourcePdfPath -Destination $destPdfPath -Force
    Write-Host "Concluído! O arquivo PDF final está em: $($destPdfPath)" -ForegroundColor Green -BackgroundColor Black
} else {
    Write-Host "Erro: O arquivo PDF não foi encontrado em $($sourcePdfPath)" -ForegroundColor Red
}

Write-Host "Arquivos auxiliares permanecem em: $($buildDir)" -ForegroundColor Green