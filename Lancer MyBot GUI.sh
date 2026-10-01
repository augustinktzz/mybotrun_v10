#!/usr/bin/env bash
# Lance l'interface Electron du bot (dossier GUI-Electron), sous Linux. Voir GUI-Electron/README.md.
# Les arguments sont passes au GUI, par exemple : ./"Lancer MyBot GUI.sh" --demo
exec "$(dirname "$(readlink -f "$0")")/GUI-Electron/Lancer MyBot GUI.sh" "$@"
