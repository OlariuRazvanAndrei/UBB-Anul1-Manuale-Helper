@echo off
chcp 65001 >nul
setlocal

REM ================== CONFIGURARE ==================
REM Folderul cu materiile:
set "FACULTATE=%USERPROFILE%\Documents\Facultate"

REM Lista materiilor. Fiecare materie: sursa (din Facultate)^|folder in repo^|prefix nume
REM Materiile se separa prin ;  (fara spatii in jurul lui ; si |)
set "MATERII=Analiza matematica\Recapitulare|semestrul-1\analiza|analiza;Logica computationala\Recapitulare|semestrul-1\logica-computationala|logica"
REM =================================================

cd /d "%~dp0"
if not exist ".git" (echo Repo-ul nu e initializat. Ruleaza intai init.bat. & pause & exit /b 1)

echo Caut PDF-uri noi sau modificate...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); iex $s.Substring($s.LastIndexOf('#PS_' + 'START'))"
if errorlevel 1 (echo Eroare la copiere. & pause & exit /b 1)

git add -A
git diff --cached --quiet && (echo. & echo Nicio schimbare. Nu fac nimic. & pause & exit /b 0)

echo.
echo ===== Schimbari =====
git status --short
echo.

for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "AZI=%%d"
set "MSG=Update manuale %AZI%"
set "INPUT="
set /p "INPUT=Mesaj commit [Enter = %MSG%]: "
if defined INPUT set "MSG=%INPUT%"

git commit -m "%MSG%" || (echo Commit esuat. & pause & exit /b 1)
git push || (echo Push esuat. Verifica conexiunea / gh auth status. & pause & exit /b 1)

echo.
echo Gata! Daca ai adaugat manuale noi, cere-i lui Claude sa regenereze README-ul.
pause
exit /b 0

#PS_START
$ErrorActionPreference = 'Stop'
function Get-Slug([string]$n) {
  $n = $n.Normalize([Text.NormalizationForm]::FormD)
  $n = -join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
  $n = ($n.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
  if ($n -match '^(\d+)(-.*)?$') { $n = ('{0:D2}' -f [int]$matches[1]) + $matches[2] }
  return $n
}
$repo = (Get-Location).Path
$copiate = 0
foreach ($m in ($env:MATERII -split ';')) {
  if (-not $m.Trim()) { continue }
  $p = $m.Split('|')
  $src = Join-Path $env:FACULTATE $p[0].Trim()
  $dst = Join-Path $repo $p[1].Trim()
  $pre = $p[2].Trim()
  if (-not (Test-Path -LiteralPath $src)) { Write-Host "ATENTIE: nu exista $src"; continue }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  foreach ($f in (Get-ChildItem -LiteralPath $src -Filter *.pdf -File)) {
    $nume = "$pre-" + (Get-Slug $f.BaseName) + '.pdf'
    $tinta = Join-Path $dst $nume
    $nou = -not (Test-Path -LiteralPath $tinta)
    if ($nou -or (Get-FileHash -LiteralPath $f.FullName).Hash -ne (Get-FileHash -LiteralPath $tinta).Hash) {
      if ($f.Length -gt 100MB) { Write-Host "SARIT (peste 100 MB, GitHub il refuza): $($f.Name)"; continue }
      if ($f.Length -gt 50MB) { Write-Host "ATENTIE: $($f.Name) are peste 50 MB" }
      Copy-Item -LiteralPath $f.FullName -Destination $tinta -Force
      if ($nou) { Write-Host "NOU       $nume" } else { Write-Host "MODIFICAT $nume" }
      $copiate++
    }
  }
}
Write-Host "Fisiere copiate: $copiate"
