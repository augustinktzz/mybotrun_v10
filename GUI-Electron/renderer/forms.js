// Les pages de configuration, decrites en donnees : chaque champ est une cle de config.ini ("section/cle", celles de
// COCBot\functions\Config\saveConfig.au3). Pour ajouter une option au GUI, ajoutez une ligne ici : app.js construit la
// carte, lit la valeur et l'ecrit dans le profil.
//
// type    toggle | number | text | secret | select
// def     valeur quand la cle n'existe pas encore dans config.ini
// needs   cle(s) de bascule qui doivent etre cochees pour que le champ soit actif
window.FORMS = {
  village: [
    {
      title: 'Collecte',
      icon: 'i-coins',
      fields: [
        { id: 'other/chkCollect', type: 'toggle', label: 'Collecter mines, extracteurs et foreuses', def: '1' },
        { id: 'other/ChkTreasuryCollect', type: 'toggle', label: 'Vider la trésorerie du château de clan', def: '0' },
        { id: 'other/chkCleanYard', type: 'toggle', label: 'Retirer les obstacles', hint: 'Arbres, pierres, buissons', def: '0' },
        { id: 'other/ChkCollectAchievements', type: 'toggle', label: 'Récupérer les succès', def: '0' },
        { id: 'other/ChkCollectFreeMagicItems', type: 'toggle', label: 'Objets gratuits du marchand', def: '0' },
        { id: 'other/ChkCollectRewards', type: 'toggle', label: 'Récompenses du pass de saison', def: '0' },
      ],
    },
    {
      title: 'Dons et demandes',
      icon: 'i-gift',
      fields: [
        { id: 'donate/Doncheck', type: 'toggle', label: 'Donner des troupes au clan', def: '0' },
        { id: 'planned/RequestHoursEnable', type: 'toggle', label: 'Demander des renforts', def: '0' },
        { id: 'donate/txtRequest', type: 'text', label: 'Message de demande', placeholder: 'Troupes svp !', needs: ['planned/RequestHoursEnable'], def: '' },
      ],
    },
    {
      title: 'Murs',
      icon: 'i-wall',
      fields: [
        { id: 'upgrade/auto-wall', type: 'toggle', label: 'Améliorer les murs', hint: 'Par lots, avec le bouton « Améliorer plus »', def: '0' },
        { id: 'upgrade/minwallgold', type: 'number', label: 'Or à garder', step: 50000, needs: ['upgrade/auto-wall'], def: '0' },
        { id: 'upgrade/minwallelixir', type: 'number', label: 'Élixir à garder', step: 50000, needs: ['upgrade/auto-wall'], def: '0' },
      ],
    },
    {
      title: 'Base des ouvriers',
      icon: 'i-hammer',
      fields: [
        { id: 'other/ChkCollectBuildersBase', type: 'toggle', label: 'Collecter les ressources', def: '0' },
        { id: 'other/ChkCleanBBYard', type: 'toggle', label: 'Retirer les obstacles', def: '0' },
        { id: 'other/ChkEnableBBAttack', type: 'toggle', label: 'Attaquer sur la base des ouvriers', def: 'False' },
      ],
    },
  ],

  attack: [
    {
      title: 'Base morte',
      icon: 'i-skull',
      fields: [
        { id: 'search/DBcheck', type: 'toggle', label: 'Attaquer les bases mortes', def: '1' },
        {
          id: 'search/DBMeetGE',
          type: 'select',
          label: 'Condition sur le butin',
          options: [['0', 'Or ET élixir'], ['1', 'Or OU élixir'], ['2', 'Or + élixir']],
          needs: ['search/DBcheck'],
          def: '0',
        },
        { id: 'search/DBsearchGold', type: 'number', label: 'Or minimum', step: 10000, needs: ['search/DBcheck'], def: '80000' },
        { id: 'search/DBsearchElixir', type: 'number', label: 'Élixir minimum', step: 10000, needs: ['search/DBcheck'], def: '80000' },
        { id: 'search/DBsearchGoldPlusElixir', type: 'number', label: 'Or + élixir minimum', step: 10000, needs: ['search/DBcheck'], def: '160000' },
        { id: 'search/DBMeetDE', type: 'toggle', label: "Exiger de l'élixir noir", needs: ['search/DBcheck'], def: '0' },
        { id: 'search/DBsearchDark', type: 'number', label: 'Élixir noir minimum', step: 500, needs: ['search/DBcheck', 'search/DBMeetDE'], def: '0' },
      ],
    },
    {
      title: 'Base active',
      icon: 'i-flame',
      fields: [
        { id: 'search/ABcheck', type: 'toggle', label: 'Attaquer les bases actives', def: '0' },
        {
          id: 'search/ABMeetGE',
          type: 'select',
          label: 'Condition sur le butin',
          options: [['0', 'Or ET élixir'], ['1', 'Or OU élixir'], ['2', 'Or + élixir']],
          needs: ['search/ABcheck'],
          def: '0',
        },
        { id: 'search/ABsearchGold', type: 'number', label: 'Or minimum', step: 10000, needs: ['search/ABcheck'], def: '80000' },
        { id: 'search/ABsearchElixir', type: 'number', label: 'Élixir minimum', step: 10000, needs: ['search/ABcheck'], def: '80000' },
        { id: 'search/ABsearchGoldPlusElixir', type: 'number', label: 'Or + élixir minimum', step: 10000, needs: ['search/ABcheck'], def: '160000' },
        { id: 'search/ABMeetDE', type: 'toggle', label: "Exiger de l'élixir noir", needs: ['search/ABcheck'], def: '0' },
        { id: 'search/ABsearchDark', type: 'number', label: 'Élixir noir minimum', step: 500, needs: ['search/ABcheck', 'search/ABMeetDE'], def: '0' },
      ],
    },
  ],

  notify: [
    {
      title: 'Telegram',
      icon: 'i-send',
      fields: [
        { id: 'notify/TGEnabled', type: 'toggle', label: 'Activer Telegram', hint: 'Créez un bot avec @BotFather puis envoyez-lui /start', def: '0' },
        { id: 'notify/TGToken', type: 'secret', label: 'Jeton du bot', placeholder: '123456:ABC-DEF…', needs: ['notify/TGEnabled'], def: '' },
        { id: 'notify/TGUserID', type: 'text', label: 'Chat ID', hint: 'Rempli par le bot après /start', needs: ['notify/TGEnabled'], def: '' },
      ],
    },
    {
      title: 'Discord',
      icon: 'i-chat',
      fields: [
        { id: 'notify/DiscordEnabled', type: 'toggle', label: 'Activer Discord', def: '0' },
        { id: 'notify/DiscordWebhook', type: 'secret', label: 'URL du webhook', placeholder: 'https://discord.com/api/webhooks/…', needs: ['notify/DiscordEnabled'], def: '' },
        { id: 'notify/DiscordFullLog', type: 'toggle', label: 'Envoyer tout le journal', needs: ['notify/DiscordEnabled'], def: '0' },
      ],
    },
    {
      title: 'Statut Discord',
      icon: 'i-badge',
      note: 'Public : toute personne qui voit votre profil Discord voit que le bot tourne et vos ressources.',
      fields: [
        { id: 'notify/DiscordRPCEnable', type: 'toggle', label: 'Afficher le statut sur mon profil', def: '0' },
        { id: 'notify/DiscordRPCClientId', type: 'text', label: 'Application ID', needs: ['notify/DiscordRPCEnable'], def: '' },
        { id: 'notify/DiscordRPCButton', type: 'toggle', label: 'Bouton « Rejoindre le serveur »', needs: ['notify/DiscordRPCEnable'], def: '0' },
        { id: 'notify/DiscordRPCButtonUrl', type: 'text', label: "Lien d'invitation", placeholder: 'https://discord.gg/…', needs: ['notify/DiscordRPCEnable', 'notify/DiscordRPCButton'], def: '' },
      ],
    },
  ],
};
