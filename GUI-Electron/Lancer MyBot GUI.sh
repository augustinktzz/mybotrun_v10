#!/usr/bin/env bash
# Lance MyBot GUI sous Linux (l'equivalent de "Lancer MyBot GUI.bat"). Au premier lancement, installe Electron
# (npm, Node.js 20 ou plus). Le bot tourne dans Wine : pour le piloter, il faut Wine et AutoIt dans le prefixe du bot
# (voir le README, section Linux). Les arguments sont passes au GUI, par exemple : ./"Lancer MyBot GUI.sh" --demo

set -e
cd "$(dirname "$(readlink -f "$0")")"

# Node.js installe dans le dossier personnel (sans droits administrateur), s'il existe
if [ -x "$HOME/.local/node/bin/node" ]; then
  export PATH="$HOME/.local/node/bin:$PATH"
fi

# Un terminal de VS Code exporte ELECTRON_RUN_AS_NODE=1 : Electron tournerait alors comme un simple Node, sans fenetre.
unset ELECTRON_RUN_AS_NODE

if [ ! -x node_modules/electron/dist/electron ]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "Node.js est introuvable. Installez Node.js 20 ou plus (https://nodejs.org) puis relancez ce fichier."
    exit 1
  fi
  major="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$major" -lt 20 ]; then
    echo "Node.js $(node --version) est trop ancien : il faut la version 20 ou plus (https://nodejs.org)."
    exit 1
  fi
  echo "Premier lancement : installation d'Electron, patientez..."
  npm ci --no-audit --no-fund || npm install --no-audit --no-fund
fi

exec node_modules/electron/dist/electron . "$@"
