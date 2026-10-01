'use strict';
// Notifications : Village > Notify du bot (SaveConfig_600_18 et _19), section [notify] de config.ini.
(function () {
  const ALERTS = [
    ['AlertPBVMFound', 'Village trouvé', 'Quand la recherche trouve une cible'],
    ['AlertPBLastRaid', 'Dernier raid en image', 'Capture du résultat'],
    ['AlertPBLastRaidTxt', 'Dernier raid en texte', 'Butin, trophées, durée'],
    ['AlertBBRaid', 'Raid de la base des ouvriers', ''],
    ['AlertPBCampFull', "Camps d'armée pleins", ''],
    ['AlertPBVillage', 'Rapport du village', 'Ressources et état'],
    ['AlertPBLastAttack', 'Alerte dernière attaque', ''],
    ['AlertPBWallUpgrade', 'Amélioration des murs', ''],
    ['AlertBuilderIdle', 'Ouvrier inactif', ''],
    ['AlertLaboratoryIdle', 'Laboratoire inactif', ''],
    ['AlertSmartWaitTime', 'Attente intelligente', "Durée d'attente de l'armée"],
    ['AlertPBVBreak', 'Pause', 'Le jeu impose une pause'],
    ['AlertPBOtherDevice', 'Autre appareil', 'Le compte est ouvert ailleurs'],
    ['AlertPBOOS', 'Erreur : désynchronisé', ''],
    ['AlertPBMaintenance', 'Maintenance', ''],
    ['AlertPBBAN', 'Bannissement', ''],
    ['AlertPBUpdate', 'Mise à jour du bot', ''],
  ];

  const services = [
    {
      title: 'Telegram',
      icon: 'i-send',
      fields: [
        { id: 'notify/TGEnabled', type: 'toggle', label: 'Activer Telegram', def: '0' },
        { id: 'notify/TGToken', type: 'secret', label: 'Jeton du bot', placeholder: '123456:ABC-DEF…', hint: 'Donné par @BotFather', needs: ['notify/TGEnabled'], def: '' },
        { id: 'notify/TGUserID', type: 'text', label: 'ID du chat', placeholder: 'Trouvé automatiquement', hint: 'Le bot le retrouve seul après votre premier message ; à vider si vous changez de chat', needs: ['notify/TGEnabled'], def: '' },
      ],
    },
    {
      title: 'Discord',
      icon: 'i-chat',
      fields: [
        { id: 'notify/DiscordEnabled', type: 'toggle', label: 'Activer Discord', def: '0' },
        { id: 'notify/DiscordWebhook', type: 'secret', label: 'Webhook', placeholder: 'https://discord.com/api/webhooks/…', needs: ['notify/DiscordEnabled'], def: '' },
        { id: 'notify/DiscordFullLog', type: 'toggle', label: 'Tout le journal vers Discord', hint: 'Chaque ligne du journal du bot', needs: ['notify/DiscordEnabled'], def: '0' },
      ],
    },
    {
      title: 'Statut Discord (Rich Presence)',
      icon: 'i-activity',
      fields: [
        { id: 'notify/DiscordRPCEnable', type: 'toggle', label: 'Afficher le statut du bot sur mon profil Discord', hint: "L'application Discord doit tourner sur ce PC", def: '0' },
        { id: 'notify/DiscordRPCClientId', type: 'text', label: "ID de l'application Discord", placeholder: 'Application du portail développeur', needs: ['notify/DiscordRPCEnable'], def: '' },
        { id: 'notify/DiscordRPCButton', type: 'toggle', label: 'Bouton lien', needs: ['notify/DiscordRPCEnable'], def: '1' },
        { id: 'notify/DiscordRPCButtonUrl', type: 'text', label: 'Adresse du bouton', needs: ['notify/DiscordRPCEnable', 'notify/DiscordRPCButton'], def: 'https://discord.gg/mdE5m5QPEF' },
      ],
    },
    {
      title: 'Général',
      icon: 'i-sliders',
      fields: [
        { id: 'notify/Origin', type: 'text', label: 'Origine', hint: 'Nom affiché en tête des messages (le profil par défaut)', def: '' },
        { id: 'notify/PBRemote', type: 'toggle', label: 'Contrôle à distance', hint: 'Commandes envoyées au bot depuis Telegram (START, STOP, PAUSE…)', def: '0' },
      ],
    },
  ];

  const alerts = [
    {
      title: 'Alertes envoyées',
      icon: 'i-bell',
      wide: true,
      cols: 3,
      fields: ALERTS.map(([key, label, hint]) => ({ id: `notify/${key}`, type: 'toggle', label, hint: hint || undefined, def: '0' })),
    },
  ];

  const schedule = [
    {
      title: 'Plages horaires',
      icon: 'i-clock',
      fields: [
        { id: 'notify/NotifyHoursEnable', type: 'toggle', label: 'Seulement à ces heures', def: '0' },
        { id: 'notify/NotifyHours', type: 'hours', needs: ['notify/NotifyHoursEnable'], style: 'num' },
        { id: 'notify/NotifyWeekDaysEnable', type: 'toggle', label: 'Seulement ces jours', def: '0' },
        { id: 'notify/NotifyWeekDays', type: 'days', needs: ['notify/NotifyWeekDaysEnable'], style: 'num' },
      ],
    },
  ];

  window.PAGES.notify = {
    title: 'Notifications',
    sub: 'Messages envoyés par le bot sur Telegram et Discord.',
    tabs: [
      { id: 'services', label: 'Services', icon: 'i-send', cards: services },
      { id: 'alerts', label: 'Alertes', icon: 'i-bell', cards: alerts },
      { id: 'schedule', label: 'Horaires', icon: 'i-clock', cards: schedule },
    ],
  };
})();
