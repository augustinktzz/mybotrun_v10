# MyBot GUI (Electron)

Modèle d'interface moderne pour MyBot v12, en Electron. Il ne remplace pas le bot : il **pilote** `MyBot.run.exe`
(le même que le `.bat`), **suit ses journaux** en direct et **édite tous les réglages** du profil, comme le GUI
d'origine (sauf l'onglet À propos).

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

1. Copiez le dossier `GUI-Electron` où vous voulez : sur le Bureau, ou **dans le dossier du bot** (il le trouve alors
   tout seul).
2. Double-cliquez `Lancer MyBot GUI.bat`. Au premier lancement il installe Electron (`npm install`, une minute),
   puis il se relance en administrateur et ouvre la fenêtre.
3. Si le GUI n'est pas dans le dossier du bot : **Réglages › Dossier du bot › Parcourir…**, et choisissez le dossier
   qui contient `MyBot.run.exe`.
4. **Profils** : le profil, l'émulateur et l'instance (mêmes arguments que le `.bat` : `MyVillage BlueStacks5 Pie64`),
   et les options de lancement (`/hideandroid`, `/minigui`, `/autostart`…).
5. **Tableau de bord** : *Ouvrir le bot*, puis *Démarrer*.

En ligne de commande :

```
npm install
npm start          # le GUI, branché sur le vrai bot
npm run demo       # le GUI avec un bot simulé (aucun bot ni Windows nécessaire)
npm run dist       # un MyBot GUI.exe portable dans dist\
```

`renderer/index.html` s'ouvre aussi directement dans un navigateur : il passe alors en mode démo.

## Pourquoi en administrateur ?

Le bot tourne en administrateur (`#RequireAdmin`), et Windows jette les messages qu'un programme de niveau inférieur
envoie à sa fenêtre. Pour que *Démarrer / Pause / Arrêter / Fermer* arrivent au bot, le GUI doit être au même niveau,
comme MultiBot. Le `.bat` s'en charge, et l'exe fait par `npm run dist` le demande à Windows.

## Comment il parle au bot

| Quoi | Comment |
| --- | --- |
| Ouvrir le bot | `MyBot.run.exe <profil> <émulateur> <instance> [/switches]`, comme le `.bat` et MultiBot |
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
GUI-Electron/
├─ main.js                 processus principal : fenêtre, IPC, journal, config.ini, état du bot
├─ preload.js              window.mybot, le seul accès de la page au reste
├─ lib/
│  ├─ bot.js               lancement du bot et commandes (via le pont PowerShell)
│  ├─ ini.js               lecture / écriture des .ini du bot (UTF-16 ou ANSI conservé)
│  ├─ log-tail.js          suivi des journaux (bot et attaques)
│  ├─ profile-store.js     fichiers du profil, profils, stratégies, listes du bot (scripts, langues)
│  └─ settings.js          réglages du GUI (%APPDATA%\MyBot GUI\settings.json)
├─ bridge/MyBotBridge.ps1  PostMessage vers la fenêtre du bot, réponse sur une fenêtre cachée
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

- Le pilotage (lancement, commandes, état) ne fonctionne que sous Windows ; ailleurs, le mode démo montre l'interface.
- Les compteurs du tableau de bord viennent du texte du journal : si le bot change ses messages, adaptez les
  expressions de `renderer/app.js` (`RE_REPORT`, `RE_LEAGUE`, `RE_SEARCH`).
- Les boutons d'action du bot d'origine (tests du debug, *Localiser* un bâtiment, ADB shell, Play Store…) ne sont pas
  repris : ils ont besoin du bot en marche. Les positions des bâtiments se localisent toujours dans le bot.
- Quelques réglages que le bot enregistre sans les relire (délai aléatoire de l'entraînement, attaques de suite avant
  de changer de compte, catégorie « Équipements » des jeux de clan) sont signalés sur leur carte.
