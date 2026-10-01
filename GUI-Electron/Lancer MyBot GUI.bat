@echo off
rem Lance MyBot GUI. Au premier lancement, installe Electron (npm install, Node.js requis : https://nodejs.org).
rem Le GUI se relance en administrateur, comme le bot : sinon Windows bloque les commandes qu'il envoie au bot.

cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  set "MYBOT_GUI_BAT=%~f0"
  powershell -NoProfile -Command "Start-Process -FilePath $env:MYBOT_GUI_BAT -Verb RunAs"
  exit /b
)

if not exist "node_modules\electron\dist\electron.exe" (
  where npm >nul 2>&1
  if errorlevel 1 (
    echo Node.js est introuvable. Installez-le depuis https://nodejs.org puis relancez ce fichier.
    pause
    exit /b 1
  )
  echo Premier lancement : installation d'Electron, patientez...
  rem npm ci repart de zero : un node_modules copie depuis Linux contient un Electron pour Linux
  call npm ci --no-audit --no-fund
  if errorlevel 1 call npm install --no-audit --no-fund
  if not exist "node_modules\electron\dist\electron.exe" (
    pause
    exit /b 1
  )
)

start "" "%~dp0node_modules\electron\dist\electron.exe" "%~dp0."
