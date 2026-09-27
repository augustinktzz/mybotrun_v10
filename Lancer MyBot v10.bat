@echo off
rem Lance la version compilee de MyBot v10.10.4 (MyBot.run.exe), aucune installation d'AutoIt requise.
rem Le chemin est relatif au dossier de ce fichier : le dossier peut etre copie n'importe ou.
rem Arguments : <nom du profil> <emulateur> <instance>. Ajouter /autostart pour demarrer le run tout seul.

cd /d "%~dp0"
start "" "%~dp0MyBot.run.exe" MyVillage BlueStacks5 Pie64
