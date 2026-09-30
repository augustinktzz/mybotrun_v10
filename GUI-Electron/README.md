# MyBot GUI (Electron)

Modèle d'interface moderne pour MyBot v12, en Electron. Il ne remplace pas le bot : il **pilote** `MyBot.run.exe`
(le même que le `.bat`), **suit son journal** en direct et **édite le `config.ini`** du profil.

Pages : Tableau de bord · Journal · Village · Attaque · Notifications · Profils · Réglages. Thème sombre, clair ou
celui de Windows, couleur d'accent au choix. Raccourcis : `Ctrl+1` à `Ctrl+7` pour les pages, `Ctrl+S` pour enregistrer.

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
| Réglages Village / Attaque / Notifications | `Profiles\<profil>\config.ini` (UTF-16, relu et réécrit sans toucher aux autres clés) |

Le bot réécrit tout `config.ini` quand il enregistre (à la fermeture notamment) : le GUI refuse d'enregistrer tant que
le bot de ce profil est ouvert, sinon la modification serait perdue.

## Structure

```
GUI-Electron/
├─ main.js                 processus principal : fenêtre, IPC, journal, config.ini, état du bot
├─ preload.js              window.mybot, le seul accès de la page au reste
├─ lib/
│  ├─ bot.js               lancement du bot et commandes (via le pont PowerShell)
│  ├─ ini.js               lecture / écriture des .ini du bot (UTF-16 ou ANSI conservé)
│  ├─ log-tail.js          suivi du journal
│  └─ settings.js          réglages du GUI (%APPDATA%\MyBot GUI\settings.json)
├─ bridge/MyBotBridge.ps1  PostMessage vers la fenêtre du bot, réponse sur une fenêtre cachée
└─ renderer/
   ├─ index.html           la page et ses icônes
   ├─ styles.css           thème (variables CSS : couleurs, accent, sombre / clair)
   ├─ forms.js             les pages de configuration, décrites en données
   ├─ app.js               la logique de la page
   └─ demo.js              le bot simulé du mode démo
```

## Ajouter une option

Les pages Village, Attaque et Notifications sont générées depuis `renderer/forms.js`. Une option = une ligne avec sa
clé de `config.ini` (les noms sont ceux de `COCBot\functions\Config\saveConfig.au3`) :

```js
{ id: 'other/chkCollect', type: 'toggle', label: 'Collecter mines, extracteurs et foreuses', def: '1' },
{ id: 'upgrade/minwallgold', type: 'number', label: 'Or à garder', step: 50000, needs: ['upgrade/auto-wall'] },
```

Types : `toggle`, `number`, `text`, `secret`, `select` (avec `options`). `needs` grise le champ tant que les bascules
citées sont décochées. Une nouvelle carte = un nouvel objet `{ title, icon, fields }`.

## Limites du modèle

- Le pilotage (lancement, commandes, état) ne fonctionne que sous Windows ; ailleurs, le mode démo montre l'interface.
- Les compteurs du tableau de bord viennent du texte du journal : si le bot change ses messages, adaptez les
  expressions de `renderer/app.js` (`RE_REPORT`, `RE_LEAGUE`, `RE_SEARCH`).
- Seule une partie des réglages est reprise (collecte, dons, murs, base des ouvriers, filtres de recherche,
  notifications) ; l'armée, les stratégies et le reste se règlent toujours dans le bot.
