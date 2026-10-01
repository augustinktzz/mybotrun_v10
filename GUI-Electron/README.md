# MyBot GUI (Electron)

L'interface de MyBot v12, en Electron. Le bot n'a plus de fenêtre à lui (l'ancien GUI AutoIt est retiré) : ce GUI
**lance et pilote** `MyBot.run.exe`, **suit ses journaux** en direct et **édite tous les réglages** du profil, comme le
faisait le GUI d'origine (sauf l'onglet À propos).

Pages : Tableau de bord · Journal (bot et attaques) · Village · Armée · Attaque · Stratégies · Notifications · Bot ·
Profils · Réglages. Thème sombre, clair ou celui de Windows, couleur d'accent au choix. Raccourcis : `Ctrl+1` à `Ctrl+9`
puis `Ctrl+0` pour les pages, `Ctrl+S` pour enregistrer.

| Page | Onglets du bot d'origine repris |
| --- | --- |
| Village | Divers (village principal, base des ouvriers, jeux de clan, capitale), Demandes et dons (toutes les unités, listes, planning, filtres), Améliorations (labo, labo étoilé, héros, familiers, équipements, bâtiments localisés, auto-amélioration, murs), Succès |
| Armée | Composition (troupes, sorts, engins), entraînement rapide (3 armées), ordre d'entraînement, boosts, options (fermeture pendant l'entraînement, délais) |
| Attaque | Base morte et base active (recherche, attaque standard / scriptée / SmartFarm, fin de combat, collecteurs), Bully, options (recherche, capacités des héros, planning, SmartZap, replay, ligue), ordre de déploiement |
| Stratégies | Charger, enregistrer et supprimer les fichiers de `Strategies\` (comme *Attack Plan › Strategies*) |
| Notifications | Telegram, Discord, statut Discord, alertes, horaires |
| Bot | Options (langue, chargement, démarrage, processeur, fenêtre, captures…), Android (distributeur, modes, ADB…), changement de compte (8 groupes), debug |
| Profils | Lancement (profil, émulateur, instance, options), profils trouvés, nouveau / copie / renommer / supprimer |

## Installer et lancer

Il faut [Node.js](https://nodejs.org) (version 20 ou plus) sur le PC, une seule fois.

1. Le GUI est livré avec le bot, dans son dossier `GUI-Electron\` : il trouve le bot tout seul (le dossier parent).
   Copié ailleurs, il faut lui indiquer le bot : **Réglages › Dossier du bot › Parcourir…**, et choisir le dossier
   qui contient `MyBot.run.exe` (ou `MyBot.run.au3`).
2. Double-cliquez `Lancer MyBot GUI.bat`, à la racine du bot ou dans `GUI-Electron\`. Au premier lancement il installe
   Electron (`npm ci`, une minute), puis il se relance en administrateur et ouvre la fenêtre.
3. Sans `MyBot.run.exe` (bot lancé depuis ses sources), le GUI lance `MyBot.run.au3` avec `AutoIt3.exe` 32 bits,
   celui de l'installation d'AutoIt (le bot refuse de tourner en 64 bits).
4. **Profils** : le profil, l'émulateur et l'instance (arguments du bot : `MyVillage BlueStacks5 Pie64`), et les
   options de lancement (`/hideandroid`, `/autostart`…). Le bot tourne toujours sans fenêtre : `/nogui` et `/minigui`
   n'existent plus (le bot les accepte encore et les ignore). Le contrôle anti-copie de la `MyBot.run.dll` d'origine
   exige une fenêtre « My Bot » avec la bannière d'origine : avec cette DLL, les recherches d'image sont refusées
   (`IMGLOC USE NOT ALLOWED IN COPYCATS`).
5. **Tableau de bord** : *Ouvrir le bot*, puis *Démarrer*. Le bot refuse de démarrer tant qu'il lui manque un fichier
   ou un prérequis (`lib\MyBot.run.dll`, .NET…) : le journal dit lequel.

En ligne de commande :

```
npm install
npm start          # le GUI, branché sur le vrai bot
npm run demo       # le GUI avec un bot simulé (aucun bot ni Windows nécessaire)
npm run dist       # un MyBot GUI.exe portable dans dist\
```

`renderer/index.html` s'ouvre aussi directement dans un navigateur : il passe alors en mode démo.

## Sous Linux

Le GUI tourne aussi sous Linux et y pilote le bot, qui tourne alors dans **Wine**. Sous Windows rien ne change : même
pont PowerShell, mêmes chemins, mêmes réglages par défaut.

Prérequis, une seule fois :

- **Node.js 20 ou plus.** Les dépôts d'Ubuntu / Linux Mint ne fournissent que la version 18 : prenez l'archive
  `linux-x64` de [nodejs.org](https://nodejs.org) et décompressez-la dans `~/.local/node` (le lanceur l'y trouve tout
  seul, sans droits administrateur).
- **Wine**, avec un préfixe 32 bits où sont installés **AutoIt** (`C:\Program Files\AutoIt3\AutoIt3.exe`) et le
  **.NET Framework 4.8** (`winetricks dotnet48` ; wine-mono ne sait pas faire tourner `MyBot.run.dll`). Le GUI cherche
  ce préfixe dans `$WINEPREFIX`, puis `~/.wine32`, puis `~/.wine`.
- Un **Android joignable par ADB** (émulateur d'Android Studio, Waydroid…) : l'émulateur **Generic** du bot.

Lancement : `./"Lancer MyBot GUI.sh"`, à la racine du bot ou dans `GUI-Electron/` (ou avec `--demo`). Au premier lancement il installe Electron.
Dans **Profils**, choisissez l'émulateur **Generic** et l'instance **Android**.

Ce qui change sous Linux, et seulement sous Linux :

| Quoi | Comment |
| --- | --- |
| Pont vers le bot | `bridge/MyBotBridge.au3`, lancé par `wine AutoIt3.exe` dans le préfixe du bot : même protocole que `MyBotBridge.ps1`. Un programme Linux ne peut pas envoyer de message aux fenêtres de Wine, un programme Wine le peut |
| Lancer le bot | `wine AutoIt3.exe MyBot.run.au3 <profil> Generic Android`, par le pont ; les chemins lui sont passés au format de Wine (`Z:\home\…`) |
| Dossier privé des profils | `%APPDATA%` de l'utilisateur Wine : `<préfixe>/drive_c/users/<vous>/AppData/Roaming/MyBot.run-Profiles` |
| Administrateur | Inutile : Wine ne filtre pas les messages entre programmes |

Depuis un terminal de VS Code, lancez le GUI avec le script : VS Code y exporte `ELECTRON_RUN_AS_NODE=1`, qui ferait
tourner Electron comme un simple Node, sans fenêtre ; le lanceur retire cette variable.

## Pourquoi en administrateur ?

Le bot tourne en administrateur (`#RequireAdmin`), et Windows jette les messages qu'un programme de niveau inférieur
envoie à sa fenêtre. Pour que *Démarrer / Pause / Arrêter / Fermer* arrivent au bot, le GUI doit être au même niveau,
comme MultiBot. Le `.bat` s'en charge, et l'exe fait par `npm run dist` le demande à Windows.

## Comment il parle au bot

| Quoi | Comment |
| --- | --- |
| Ouvrir le bot | `MyBot.run.exe <profil> <émulateur> <instance> [/switches]`, comme le `.bat` et MultiBot |
| Se déclarer comme interface | Le bot n'a pas de fenêtre : le GUI se déclare auprès de lui (code `0x1060`) tant qu'il démarre, puis une fois à chaque bot déjà ouvert qu'il retrouve (lancé par MultiBot, relancé par le Watchdog). Le bot n'attend pas cette déclaration : il tourne aussi sans le GUI, piloté par son API |
| Démarrer, pause, reprendre, arrêter, fermer | L'API fenêtre du bot, le message `MyBot.run/API/1.1` (`COCBot\functions\Other\ApiClient.au3`), envoyé par `bridge/MyBotBridge.ps1` |
| État (fermé, prêt, en cours, en pause) | La même API : le bot répond à la requête `0x00FF` avec ses bits d'état, sondé toutes les 2 s |
| Journal | Le fichier le plus récent de `Profiles\<profil>\Logs\`, lu au fil de l'eau |
| Ressources, ligue, recherches, attaques | Déduits des lignes du journal (`Village Report`, `[G]: … [GEM]: …`, `[League]:`, `Returning Home`) |
| Journal des attaques | `Profiles\<profil>\Logs\AttackLog-AAAA-MM.log`, le tableau des attaques du bot |
| Réglages | Les fichiers du profil, relus et réécrits sans toucher aux autres clés (voir ci-dessous) |
| Stratégies | `Strategies\*.ini` : une section `[preset]` avec les notes, puis les sections d'armée et d'attaque du profil |

Les réglages vivent dans plusieurs fichiers ; dans les pages, un champ s'écrit `fichier:section/clé` (`config` par défaut) :

| Alias | Fichier | Contenu |
| --- | --- | --- |
| `config` | `Profiles\<profil>\config.ini` (UTF-16) | presque tout |
| `building` | `Profiles\<profil>\building.ini` (UTF-16) | labo, bâtiments localisés |
| `clangames` | `Profiles\<profil>\clangames.ini` (UTF-16) | jeux de clan |
| `cgrewards` | `Profiles\<profil>\ClanGamesRewards.ini` | priorité des récompenses des jeux de clan |
| `profile` | `Profiles\profile.ini` | commun à tous les profils (bots en même temps, threads) |
| `switch1` à `switch8` | `Profiles\SwitchAccount.0N.ini` | groupes de changement de compte |

Le bot réécrit ses fichiers quand il enregistre (à la fermeture notamment) : le GUI refuse d'enregistrer tant que le bot
de ce profil est ouvert, sinon la modification serait perdue.

## Structure

```
GUI-Electron/             (dans le dossier du bot)
├─ main.js                 processus principal : fenêtre, IPC, journal, config.ini, état du bot
├─ preload.js              window.mybot, le seul accès de la page au reste
├─ lib/
│  ├─ bot.js               lancement du bot et commandes (via le pont PowerShell, ou AutoIt sous Linux)
│  ├─ ini.js               lecture / écriture des .ini du bot (UTF-16 ou ANSI conservé)
│  ├─ log-tail.js          suivi des journaux (bot et attaques)
│  ├─ platform.js          ce qui diffère sous Linux : Wine, chemins, %APPDATA%
│  ├─ profile-store.js     fichiers du profil, profils, stratégies, listes du bot (scripts, langues)
│  └─ settings.js          réglages du GUI (%APPDATA%\MyBot GUI\settings.json)
├─ bridge/MyBotBridge.ps1  PostMessage vers la fenêtre du bot, réponse sur une fenêtre cachée (Windows)
├─ bridge/MyBotBridge.au3  le même pont, en AutoIt, lancé dans Wine (Linux)
├─ Lancer MyBot GUI.bat    lanceur Windows ; Lancer MyBot GUI.sh : lanceur Linux
└─ renderer/
   ├─ index.html           la page et ses icônes
   ├─ styles.css           thème (variables CSS : couleurs, accent, sombre / clair)
   ├─ forms/               les pages de réglages, décrites en données
   │  ├─ units.js          troupes, sorts, engins, héros, familiers, équipements (noms et clés du bot)
   │  └─ village.js, army.js, attack.js, notify.js, bot.js
   ├─ form-engine.js       construit ces pages (onglets, cartes, champs), lit et enregistre les valeurs
   ├─ app.js               la logique de la page
   └─ demo.js              le bot simulé du mode démo
```

## Ajouter une option

Les pages Village, Armée, Attaque, Notifications et Bot sont générées depuis `renderer/forms/*.js`. Une option = une
ligne avec sa clé (les noms sont ceux de `COCBot\functions\Config\saveConfig.au3`, la valeur par défaut celle de
`readConfig.au3`) :

```js
{ id: 'other/chkCollect', type: 'toggle', label: 'Collecter mines, extracteurs et foreuses', def: '1' },
{ id: 'upgrade/minwallgold', type: 'number', label: 'Or à garder', step: 50000, needs: ['upgrade/auto-wall'] },
{ id: 'clangames:clangames/ChkClanGamesEnabled', type: 'toggle', label: 'Faire les défis', def: '0' },
```

Types : `toggle`, `bit`, `number`, `text`, `secret`, `textarea`, `select` (avec `options` ou `source` : une liste du
bot), `radio`, `radiokeys`, `hours`, `days`, `flags`, `range`, `pipeselects`, plus `row` (plusieurs champs sur une
ligne) et `info` ; le détail est en tête de `renderer/form-engine.js`. `needs` grise le champ tant que ses conditions
ne sont pas remplies. Une carte = `{ title, icon, fields }` ; une page = `{ title, sub, tabs: [{ id, label, cards }] }`,
un onglet peut avoir ses propres sous-onglets (`tabs`).

## Limites du modèle

- Le pilotage (lancement, commandes, état) fonctionne sous Windows, et sous Linux avec le bot dans Wine (voir *Sous
  Linux*) ; ailleurs, le mode démo montre l'interface.
- Les compteurs du tableau de bord viennent du texte du journal : si le bot change ses messages, adaptez les
  expressions de `renderer/app.js` (`RE_REPORT`, `RE_LEAGUE`, `RE_SEARCH`).
- Les boutons d'action de l'ancien GUI du bot (tests du debug, *Localiser* un bâtiment, ADB shell, Play Store…) ne sont
  pas repris : ils ont besoin du bot en marche. Les bâtiments se localisent pendant le run, et le bot garde leurs
  positions (il enregistre son profil en quittant). Quand il ne trouve pas un bâtiment tout seul, il ouvre encore la
  petite boîte de dialogue qui demande de cliquer dessus dans l'émulateur.
- Le bot n'a plus de fenêtre du tout (le code de l'ancien GUI, `COCBot\GUI\`, est supprimé) : plus d'émulateur intégré
  dans le bot, ni de bouclier sur l'émulateur. *Placer la fenêtre de l'émulateur* (page Bot) le met à une position fixe.
- Quelques réglages que le bot enregistre sans les relire (délai aléatoire de l'entraînement, attaques de suite avant
  de changer de compte, catégorie « Équipements » des jeux de clan) sont signalés sur leur carte.
