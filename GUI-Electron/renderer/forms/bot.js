'use strict';
// Bot : onglets Options, Android, Profils > changement de compte et Debug du bot.
// Cles : SaveConfig_600_35_1 (options), SaveConfig_Android, SaveConfig_600_35_2 (SwitchAccount.0N.ini), SaveConfig_Debug,
// SaveRegularConfig (threads, botDesignFlags) et SaveProfileConfig (profile.ini, commun a tous les profils).
(function () {
  const { opts, range } = window.U;

  // Distributors.au3 : nom, paquet, activite (le bot les ecrit ensemble dans [android])
  const DISTRIBUTORS = [
    ['Google', 'com.supercell.clashofclans', 'com.supercell.titan.GameApp'],
    ['Amazon', 'com.supercell.clashofclans.amazon', 'com.supercell.titan.amazon.GameAppAmazon'],
    ['Kunlun', 'com.supercell.clashofclans.kunlun', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Qihoo', 'com.supercell.clashofclans.qihoo', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Baidu', 'com.supercell.clashofclans.baidu', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['9game', 'com.supercell.clashofclans.uc', 'com.supercell.titan.kunlun.uc.GameAppKunlunUC'],
    ['Wandoujia/Downjoy', 'com.supercell.clashofclans.wdj', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Huawei', 'com.supercell.clashofclans.huawei', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['OPPO', 'com.supercell.clashofclans.nearme.gamecenter', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['VIVO', 'com.supercell.clashofclans.vivo', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Anzhi', 'com.supercell.clashofclans.anzhi', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Kaopu', 'com.supercell.clashofclans.ewan.kaopu', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Lenovo', 'com.supercell.clashofclans.lenovo', 'com.lenovo.lsf.gamesdk.ui.WelcomeActivity'],
    ['Guopan', 'com.supercell.clashofclans.guopan', 'com.flamingo.sdk.view.GPSplashActivity'],
    ['Xiaomi', 'com.supercell.clashofclans.mi', 'com.supercell.titan.kunlun.mi.GameAppKunlunXiaomi'],
    ['Haimawan', 'com.supercell.clashofclans.ewan.hm', 'cn.ewan.supersdk.activity.SplashActivity'],
    ['Leshi', 'com.supercell.clashofclans.ewan.leshi', 'cn.ewan.supersdk.activity.SplashActivity'],
    ['Microvirt', 'com.supercell.clashofclans.ewan.xyaz', 'cn.ewan.supersdk.activity.SplashActivity'],
    ['Yeshen', 'com.supercell.clashofclans.ewan.yeshen', 'cn.ewan.supersdk.activity.SplashActivity'],
    ['Aiyouxi', 'com.supercell.clashofclans.ewan.egame', 'cn.ewan.supersdk.activity.SplashActivity'],
    ['Tencent', 'com.tencent.tmgp.supercell.clashofclans', 'com.supercell.titan.tencent.GameAppTencent'],
    ['Ewan', 'com.supercell.clashofclans.ewan', 'com.supercell.titan.kunlun.GameAppKunlun'],
    ['Magic', 'cc.clashofmagic.s2', 'com.atrasis.main.GameMain'],
  ];

  // ------------------------------------------------------------------ options
  const options = [
    {
      title: 'Langue du bot',
      icon: 'i-book',
      fields: [{ id: 'other/language', type: 'select', label: 'Langue', source: 'languages', hint: 'Fichiers du dossier Languages ; pris en compte au prochain démarrage du bot', def: 'English' }],
    },
    {
      title: 'Au chargement du bot',
      icon: 'i-upload',
      fields: [
        { id: 'General/ChkDisableSplash', type: 'toggle', label: "Pas d'écran de démarrage", def: '0' },
        { id: 'General/ChkVersion', type: 'toggle', label: 'Chercher les mises à jour', def: '1' },
        {
          type: 'row',
          fields: [
            { id: 'deletefiles/DeleteLogs', type: 'toggle', label: 'Supprimer les journaux', def: '1' },
            { id: 'deletefiles/DeleteLogsDays', type: 'number', label: 'Après', suffix: 'jours', max: 999, needs: ['deletefiles/DeleteLogs'], def: '2' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'deletefiles/DeleteTemp', type: 'toggle', label: 'Supprimer les fichiers temporaires', def: '1' },
            { id: 'deletefiles/DeleteTempDays', type: 'number', label: 'Après', suffix: 'jours', max: 999, needs: ['deletefiles/DeleteTemp'], def: '5' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'deletefiles/DeleteLoots', type: 'toggle', label: 'Supprimer les captures de butin', def: '1' },
            { id: 'deletefiles/DeleteLootsDays', type: 'number', label: 'Après', suffix: 'jours', max: 999, needs: ['deletefiles/DeleteLoots'], def: '2' },
          ],
        },
      ],
    },
    {
      title: 'Au démarrage du bot',
      icon: 'i-play',
      fields: [
        {
          type: 'row',
          fields: [
            { id: 'general/AutoStart', type: 'toggle', label: 'Démarrer tout seul', hint: 'Comme un clic sur « Démarrer »', def: '0' },
            { id: 'general/AutoStartDelay', type: 'number', label: 'Après', suffix: 's', max: 999, needs: ['general/AutoStart'], def: '10' },
          ],
        },
        { id: 'General/ChkLanguage', type: 'toggle', label: 'Vérifier la langue du jeu (anglais)', def: '1' },
        { id: 'general/DisposeWindows', type: 'toggle', label: "Placer la fenêtre de l'émulateur", hint: 'Au démarrage du run ; une position vide garde la position actuelle', def: '0' },
        {
          type: 'row',
          label: 'Position',
          fields: [
            { id: 'other/WAOffsetX', type: 'number', label: 'X', min: -9999, needs: ['general/DisposeWindows'], def: '' },
            { id: 'other/WAOffsetY', type: 'number', label: 'Y', min: -9999, needs: ['general/DisposeWindows'], def: '' },
          ],
        },
      ],
    },
    {
      title: 'Processeur',
      icon: 'i-cpu',
      fields: [
        { id: 'profile:general/globalactivebotsallowed', type: 'number', label: 'Bots actifs en même temps', min: 1, max: 64, hint: 'Commun à tous les profils (profile.ini) ; par défaut le nombre de processeurs', def: '' },
        { id: 'profile:general/globalthreads', type: 'number', label: "Threads d'analyse d'image pour tous les bots", max: 64, hint: '0 = autant que de processeurs (profile.ini)', def: '0' },
        { id: 'general/threads', type: 'number', label: "Threads d'analyse d'image pour ce bot", max: 64, hint: '0 = autant que de processeurs', def: '0' },
      ],
    },
    {
      title: 'Arrière-plan',
      icon: 'i-window',
      fields: [
        { id: 'general/Background', type: 'toggle', label: 'Mode arrière-plan', hint: "L'émulateur peut être caché ou recouvert pendant le run", def: '1' },
      ],
    },
    {
      title: 'Avancé',
      icon: 'i-sliders',
      fields: [
        {
          type: 'row',
          fields: [
            { id: 'other/ChkAutoResume', type: 'toggle', label: 'Reprendre seul après une pause', def: '0' },
            { id: 'other/AutoResumeTime', type: 'number', label: 'Après', suffix: 'min', max: 999, needs: ['other/ChkAutoResume'], def: '5' },
          ],
        },
        { id: 'other/ChkDisableNotifications', type: 'toggle', label: 'Désactiver les bulles de notification Windows', def: 'False' },
        { id: 'other/UseRandomClick', type: 'toggle', label: 'Clics au hasard', hint: 'Position légèrement variable à chaque clic', def: '0' },
      ],
    },
    {
      title: 'Captures d’écran',
      icon: 'i-file',
      fields: [
        { id: 'other/ScreenshotType', type: 'toggle', label: 'Au format PNG', hint: 'JPG sinon', def: '0' },
        { id: 'other/ScreenshotHideName', type: 'toggle', label: 'Masquer le nom du village et du château', def: '1' },
      ],
    },
    {
      title: 'Autre appareil',
      icon: 'i-monitor',
      fields: [{ id: 'other/txtTimeWakeUp', type: 'number', label: 'Attendre avant de reprendre la main', suffix: 'min', scale: 60, max: 999, hint: 'Quand le compte est ouvert sur un autre appareil', def: '0' }],
    },
    {
      title: 'Autres options',
      icon: 'i-list',
      fields: [
        { id: 'other/ChkFixClanCastle', type: 'toggle', label: 'Forcer la détection du château de clan', def: '0' },
        { id: 'other/ChkSqlite', type: 'toggle', label: 'Statistiques dans une base SQLite', def: 'False' },
      ],
    },
  ];

  // ------------------------------------------------------------------ Android
  const android = [
    {
      title: 'Émulateur',
      icon: 'i-monitor',
      note: 'Les arguments de lancement (réglages de ce GUI, .bat) passent avant ces valeurs.',
      fields: [
        { id: 'android/emulator', type: 'select', label: 'Émulateur', options: [['', '—'], ['BlueStacks5', 'BlueStacks 5'], ['MEmu', 'MEmu'], ['Nox', 'Nox'], ['Generic', 'Generic (Android joint par ADB, Linux)']], def: '' },
        { id: 'android/instance', type: 'text', label: 'Instance', placeholder: 'Pie64, MEmu_1…', def: '' },
      ],
    },
    {
      title: 'Distributeur du jeu',
      icon: 'i-grid',
      fields: [
        { id: 'android/game.distributor', type: 'select', label: 'Version de Clash of Clans lancée', options: DISTRIBUTORS.map(([n]) => [n, n]), hint: 'Le paquet et l’activité Android sont écrits avec', def: 'Google' },
        { id: 'android/game.package', type: 'text', label: 'Paquet', readonly: true, def: 'com.supercell.clashofclans' },
      ],
    },
    {
      title: 'Délai de clic ajouté',
      icon: 'i-clock',
      fields: [{ id: 'android/click.additional.delay', type: 'range', label: 'Délai', min: 0, max: 100, step: 2, suffix: 'ms', hint: 'Plus long si le PC est lent, ou pour un rythme plus humain', def: '10' }],
    },
    {
      title: 'Options Android',
      icon: 'i-sliders',
      wide: true,
      cols: 2,
      fields: [
        { id: 'android/backgroundmode', type: 'select', label: "Capture d'écran en arrière-plan", options: opts(['Par défaut', 'WinAPI (Android DirectX requis)', 'ADB screencap']), def: '0' },
        { id: 'android/zoomoutmode', type: 'select', label: 'Dézoom', options: opts(['Par défaut', 'Script minitouch', 'Script dd', 'WinAPI', 'Mettre à jour shared_prefs']), def: '0' },
        { id: 'android/suspend.mode', type: 'select', label: "Suspendre / reprendre l'émulateur", options: [['0', 'Désactivé'], ['1', 'Pendant la recherche et l’attaque'], ['2', "À chaque analyse d'image"]], def: '1' },
        { id: 'android/adb.replace', type: 'select', label: 'ADB utilisé', options: opts(["Celui de l'émulateur", 'Celui de MyBot']), def: '0' },
        { id: 'android/adb.click.enabled', type: 'toggle', label: 'Clics via minitouch', on: '1', off: '0', def: '1' },
        { id: 'android/adb.click.drag.script', type: 'toggle', label: 'Clic-glisser précis via minitouch', on: '1', off: '0', def: '1' },
        { id: 'android/close', type: 'toggle', label: "Fermer l'émulateur avec le bot", on: '1', off: '0', def: '0' },
        { id: 'android/adb.dedicated.instance', type: 'toggle', label: 'Port ADB dédié', hint: 'Un démon ADB par bot et par instance', on: '1', off: '0', def: '0' },
        { id: 'android/shared_prefs.update', type: 'toggle', label: 'Mettre à jour shared_prefs', hint: 'Forcé à désactivé par cette version du bot', on: '1', off: '0', def: '0' },
        { id: 'android/reboot.hours', type: 'number', label: "Redémarrer l'émulateur toutes les", suffix: 'h', max: 999, hint: '0 = jamais', def: '24' },
      ],
    },
  ];

  // ------------------------------------------------------------------ changement de compte (SwitchAccount.0N.ini)
  const SW = 'switch#:SwitchAccount/';
  const accountRow = (i) => ({
    type: 'row',
    label: `Compte ${i}`,
    fields: [
      { id: `${SW}AccountNo.${i}`, type: 'toggle', label: 'Actif', needs: [`${SW}Enable`], def: '0' },
      { id: `${SW}ProfileName.${i}`, type: 'select', label: 'Profil', source: 'profiles', needs: [`${SW}Enable`, `${SW}AccountNo.${i}`], def: '' },
      { id: `${SW}DonateOnly.${i}`, type: 'toggle', label: 'Dons seulement', needs: [`${SW}Enable`, `${SW}AccountNo.${i}`], def: '0' },
    ],
  });
  const switchAccounts = [
    {
      title: 'Groupe de comptes',
      icon: 'i-users',
      note: "Un groupe = un fichier SwitchAccount.0N.ini. Le bot cherche le groupe qui contient le profil lancé ; il n'est pas enregistré dans config.ini.",
      fields: [
        { id: `${SW}Enable`, type: 'toggle', label: 'Changer de compte', def: '0' },
        { id: `${SW}TotalCocAccount`, type: 'select', label: 'Nombre de comptes', options: range(2, 8).map(([v, l]) => [String(Number(v) - 1), `${l} comptes`]), needs: [`${SW}Enable`], def: '1' },
        { type: 'radiokeys', label: 'Méthode', options: [[`${SW}SuperCellID`, 'Supercell ID'], [`${SW}SharedPrefs`, 'shared_prefs']], needs: [`${SW}Enable`] },
        { id: `${SW}DonateLikeCrazy`, type: 'toggle', label: 'Donner à fond', hint: 'Les comptes « dons seulement » donnent à chaque passage', needs: [`${SW}Enable`], def: '0' },
        { id: `${SW}CmbMaxInARow`, type: 'select', label: 'Attaques de suite avant de changer', options: range(1, 10).map(([v, l]) => [String(Number(v) - 1), l]), hint: 'Cette version du bot ne relit pas ce réglage (il le réécrit avec sa propre valeur)', needs: [`${SW}Enable`], def: '2' },
      ],
    },
    {
      title: 'Comptes',
      icon: 'i-list',
      fields: [1, 2, 3, 4, 5, 6, 7, 8].map(accountRow),
    },
    {
      title: 'Supercell ID (ce profil)',
      icon: 'i-badge',
      fields: [
        { id: 'ProfileSCID/OnlySCIDAccounts', type: 'toggle', label: 'Comptes Supercell ID seulement', def: '1' },
        { id: 'ProfileSCID/WhatSCIDAccount2Use', type: 'select', label: 'Compte à utiliser', options: range(1, 8).map(([v, l]) => [String(Number(v) - 1), `Compte ${l}`]), needs: ['ProfileSCID/OnlySCIDAccounts'], def: '0' },
      ],
    },
  ];

  // ------------------------------------------------------------------ debug
  const DEBUG = [
    ['debugsetlog', 'Messages'], ['debugAndroid', 'Android'], ['debugsetclick', 'Clics'], ['debugFunc', 'Fonctions'],
    ['debugocr', 'OCR'], ['debugimagesave', 'Images'], ['debugbuildingpos', 'Bâtiments'], ['debugtrain', 'Entraînement'],
    ['debugOCRDonate', 'Dons (en direct)'], ['debugAttackCSV', 'Attaque CSV'], ['debugmakeimgcsv', 'Image de l’attaque CSV'],
    ['disablezoomout', 'Désactiver le dézoom'], ['disablevillagecentering', 'Désactiver le centrage du village'],
    ['debugdeadbaseimage', 'Enregistrer les images de base morte'], ['DebugSmartZap', 'SmartZap'],
  ];
  const debug = [
    {
      title: 'Debug',
      icon: 'i-terminal',
      wide: true,
      cols: 3,
      note: 'Pour chercher un problème : le journal devient très bavard et le bot plus lent. Les boutons de test du bot ne sont pas repris ici.',
      fields: DEBUG.map(([key, label]) => ({ id: `debug/${key}`, type: 'toggle', label, compact: true, def: '0' })),
    },
  ];

  // le paquet et l'activite suivent le distributeur choisi (cmbCOCDistributors)
  const derive = (get, changed) => {
    if (!changed.has('android/game.distributor')) return {};
    const d = DISTRIBUTORS.find(([n]) => n === get('android/game.distributor'));
    return d ? { 'android/game.package': d[1], 'android/appActitivityName': d[2] } : {};
  };

  window.PAGES.bot = {
    title: 'Bot',
    sub: 'Options du bot, émulateur Android, changement de compte et debug.',
    derive,
    param: { label: 'Groupe de comptes', tab: 'switch', options: [1, 2, 3, 4, 5, 6, 7, 8].map((g) => [String(g), `Groupe ${g}`]) },
    tabs: [
      { id: 'options', label: 'Options', icon: 'i-sliders', cards: options },
      { id: 'android', label: 'Android', icon: 'i-monitor', cards: android },
      { id: 'switch', label: 'Changement de compte', icon: 'i-users', cards: switchAccounts },
      { id: 'debug', label: 'Debug', icon: 'i-terminal', cards: debug },
    ],
  };
})();
