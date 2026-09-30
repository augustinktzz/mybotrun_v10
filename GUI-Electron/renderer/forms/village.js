'use strict';
// Village : Divers, Demandes et dons, Ameliorations, Succes (onglet Village du bot, sans Notify qui a sa propre page).
// Cles : COCBot\functions\Config\saveConfig.au3 (SaveConfig_600_1, _6, _9, _11, _12, _13, _15, _16, _auto, _17,
// SaveBuildingConfig, SaveClanGamesConfig).
(function () {
  const { opts, range, TROOPS, SPELLS, SIEGES, HEROES, PETS, EQUIPMENT, HOURS_24 } = window.U;
  const TIMES = HOURS_24;

  // ------------------------------------------------------------------ Divers > Village principal
  const HALT_CONDITIONS = [
    'Or et élixir pleins et ligue max',
    '(Or et élixir) pleins ou ligue max',
    '(Or ou élixir) plein et ligue max',
    'Or ou élixir plein ou ligue max',
    'Or et élixir pleins',
    'Or, élixir ou élixir noir plein',
    'Or plein et ligue max',
    'Élixir plein et ligue max',
    'Or plein ou ligue max',
    'Élixir plein ou ligue max',
    'Or plein',
    'Élixir plein',
    'Palier de ligue max atteint',
    'Élixir noir plein',
    'Tous les réservoirs pleins (or + élixir + noir)',
    'Le bot tourne depuis…',
    'Maintenant (entraîner / donner seulement)',
    'Maintenant (donner seulement)',
    'Maintenant (rester en ligne seulement)',
    'Avec bouclier (entraîner / donner seulement)',
    'Avec bouclier (donner seulement)',
    'Avec bouclier (rester en ligne seulement)',
    'À une heure précise de la journée',
  ];
  const RESUME_LEAGUE = [0, 1, 2, 3, 6, 7, 8, 9, 12].map(String);
  const RESUME_GOLD = ['0', '1', '2', '3', '4', '5', '6', '8', '10', '14'];
  const RESUME_ELIXIR = ['0', '1', '2', '3', '4', '5', '7', '9', '11', '14'];

  const normalVillage = [
    {
      title: "Arrêt des attaques",
      icon: 'i-stop',
      fields: [
        { id: 'general/BotStop', type: 'toggle', label: 'Arrêter les attaques sous condition', hint: "Quand la condition est remplie, le bot fait l'action choisie", def: '0' },
        {
          type: 'row',
          fields: [
            {
              id: 'general/Command',
              type: 'select',
              label: 'Action',
              options: opts(['Suspendre les attaques', 'Arrêter le bot', 'Fermer le bot', 'Fermer CoC et le bot', 'Éteindre le PC', 'Mettre le PC en veille', 'Redémarrer le PC', 'Rester inactif']),
              needs: ['general/BotStop'],
              def: '0',
            },
            { id: 'general/Cond', type: 'select', label: 'Quand…', options: opts(HALT_CONDITIONS), needs: ['general/BotStop'], def: '0' },
          ],
        },
        {
          id: 'general/Hour',
          type: 'select',
          label: 'Durée',
          options: [['0', '—'], ...range(1, 24, (h) => `${h} heure${h > 1 ? 's' : ''}`)],
          needs: ['general/BotStop'],
          showIf: [{ id: 'general/Cond', eq: '15' }],
          def: '0',
        },
        {
          type: 'row',
          label: 'Horaires',
          showIf: [{ id: 'general/Cond', eq: '22' }],
          fields: [
            { id: 'general/CmbTimeStop', type: 'select', label: 'Arrêter à', options: TIMES, needs: ['general/BotStop'], def: '0' },
            { id: 'other/ResumeAttackTime', type: 'select', label: 'Reprendre à', options: TIMES, needs: ['general/BotStop'], def: '12' },
          ],
        },
        {
          type: 'row',
          label: 'Reprendre les attaques quand une ressource descend sous',
          hint: 'Après un arrêt pour réservoirs pleins',
          showIf: [{ id: 'general/Cond', ne: '22' }],
          fields: [
            { id: 'other/MinResumeAttackLoot_3', type: 'number', label: 'Ligue', max: 36, needs: ['general/BotStop', { id: 'general/Command', eq: '0' }, { id: 'general/Cond', in: RESUME_LEAGUE }], def: '0' },
            { id: 'other/MinResumeAttackLoot_0', type: 'number', label: 'Or', step: 10000, needs: ['general/BotStop', { id: 'general/Command', eq: '0' }, { id: 'general/Cond', in: RESUME_GOLD }], def: '0' },
            { id: 'other/MinResumeAttackLoot_1', type: 'number', label: 'Élixir', step: 10000, needs: ['general/BotStop', { id: 'general/Command', eq: '0' }, { id: 'general/Cond', in: RESUME_ELIXIR }], def: '0' },
            { id: 'other/MinResumeAttackLoot_2', type: 'number', label: 'Élixir noir', step: 1000, needs: ['general/BotStop', { id: 'general/Command', eq: '0' }, { id: 'general/Cond', in: ['13', '14'] }], def: '0' },
          ],
        },
        { id: 'general/CollectStarBonus', type: 'toggle', label: 'Attaquer quand le bonus de victoire est disponible', needs: ['general/BotStop', { id: 'general/Command', eq: '0' }], def: '0' },
      ],
    },
    {
      title: 'Ressources insuffisantes',
      icon: 'i-coins',
      fields: [
        { type: 'info', text: "Le bot se met en pause s'il manque de ressources, et reprend quand elles atteignent ces minimums." },
        {
          type: 'row',
          fields: [
            { id: 'other/minrestartgold', type: 'number', label: 'Or ≥', step: 10000, def: '50000' },
            { id: 'other/minrestartelixir', type: 'number', label: 'Élixir ≥', step: 10000, def: '50000' },
            { id: 'other/minrestartdark', type: 'number', label: 'Élixir noir ≥', step: 100, def: '500' },
          ],
        },
      ],
    },
    {
      title: 'Collecte et nettoyage',
      icon: 'i-coins',
      fields: [
        { id: 'other/chkCollect', type: 'toggle', label: 'Collecter les ressources et le chariot à butin', hint: "Mines d'or, extracteurs d'élixir, foreuses d'élixir noir, chariot", def: '1' },
        { id: 'other/chkCollectCartFirst', type: 'toggle', label: "Chariot à butin d'abord", needs: ['other/chkCollect'], def: '0' },
        {
          type: 'row',
          label: 'Collecter seulement si le réservoir est sous (0 = toujours)',
          fields: [
            { id: 'other/minCollectgold', type: 'number', label: 'Or', step: 10000, needs: ['other/chkCollect'], def: '0' },
            { id: 'other/minCollectelixir', type: 'number', label: 'Élixir', step: 10000, needs: ['other/chkCollect'], def: '0' },
            { id: 'other/minCollectdark', type: 'number', label: 'Élixir noir', step: 1000, needs: ['other/chkCollect'], def: '0' },
          ],
        },
        { id: 'other/chkTombstones', type: 'toggle', label: 'Retirer les tombes', hint: 'Après une attaque ennemie', def: '1' },
        { id: 'other/chkCleanYard', type: 'toggle', label: 'Retirer les obstacles', hint: 'Arbres, troncs, buissons…', def: '0' },
        { id: 'other/chkGemsBox', type: 'toggle', label: 'Retirer la boîte à gemmes', def: '0' },
        { id: 'other/ChkCollectAchievements', type: 'toggle', label: 'Récupérer les succès', def: '0' },
        { id: 'other/ChkCollectFreeMagicItems', type: 'toggle', label: 'Objets magiques gratuits du marchand', hint: 'HDV 8 minimum', def: '0' },
        { id: 'other/ChkCollectRewards', type: 'toggle', label: 'Récompenses des défis (pass de saison)', def: '0' },
        { id: 'other/ChkSellRewards', type: 'toggle', label: 'Vendre les objets en trop', needs: ['other/ChkCollectRewards'], def: '0' },
        {
          id: 'other/PassRewardChoice',
          type: 'select',
          label: 'Récompense au choix du pass',
          options: opts(["La ressource (or / élixir / noir)", "L'objet magique", "Toujours celle de gauche"]),
          needs: ['other/ChkCollectRewards'],
          def: '0',
        },
      ],
    },
    {
      title: 'Trésorerie du château de clan',
      icon: 'i-castle',
      fields: [
        { id: 'other/ChkTreasuryCollect', type: 'toggle', label: 'Vider la trésorerie', hint: 'Quand elle est pleine, ou quand un réservoir descend sous le minimum (0 = seulement pleine)', def: '0' },
        {
          type: 'row',
          fields: [
            { id: 'other/minTreasurygold', type: 'number', label: 'Or <', step: 50000, needs: ['other/ChkTreasuryCollect'], def: '0' },
            { id: 'other/minTreasuryelixir', type: 'number', label: 'Élixir <', step: 50000, needs: ['other/ChkTreasuryCollect'], def: '0' },
            { id: 'other/minTreasurydark', type: 'number', label: 'Élixir noir <', step: 1000, needs: ['other/ChkTreasuryCollect'], def: '0' },
          ],
        },
      ],
    },
    {
      title: 'Emplacements des bâtiments',
      icon: 'i-target',
      fields: [
        {
          type: 'info',
          text: "Hôtel de ville, château de clan, labo, animalerie, forge, hutte de l'apprenti : le bot les repère lui-même, ou avec les boutons « Localiser » de son onglet Divers (il faut cliquer dans le jeu). Les positions sont gardées dans building.ini.",
        },
      ],
    },
  ];

  // ------------------------------------------------------------------ Divers > Base des ouvriers
  const BB_TROOPS = [
    ['Barbarian', 'Barbare enragé'],
    ['Archer', 'Archère furtive'],
    ['BoxerGiant', 'Géant boxeur'],
    ['Minion', 'Gargouille bêta'],
    ['Bomber', 'Bombardier'],
    ['BabyDrag', 'Bébé dragon'],
    ['CannonCart', 'Cannon Cart'],
    ['Witch', 'Sorcière de la nuit'],
    ['DropShip', 'Drop Ship'],
    ['SuperPekka', 'Super P.E.K.K.A'],
    ['HogGlider', 'Hog Glider'],
    ['ElectroWizard', 'Electrofire Wizard'],
    ['BattleMachine', 'Machine de combat'],
  ];

  // delais en ms : le 5e choix est la valeur par defaut, +/- un pas par cran (cmbBBNextTroopDelay)
  const bbDelays = (base, step) => range(1, 9).map(([v]) => [String(base + (Number(v) - 5) * step), `${v}${v === '1' ? ' (rapide)' : v === '9' ? ' (lent)' : ''} · ${base + (Number(v) - 5) * step} ms`]);

  const builderBase = [
    {
      title: 'Collecter et activer',
      icon: 'i-coins',
      fields: [
        { id: 'other/ChkCollectBuildersBase', type: 'toggle', label: 'Collecter les ressources', hint: "Mines, collecteurs et chariot d'élixir", def: '0' },
        { id: 'other/ChkCleanBBYard', type: 'toggle', label: 'Retirer les obstacles', def: '0' },
        { id: 'other/ChkStartClockTowerBoost', type: 'toggle', label: "Activer l'accélération de la tour de l'horloge", hint: 'Ne dépense pas de gemmes', def: '0' },
        { id: 'other/ChkCTBoostBlderBz', type: 'toggle', label: 'Seulement quand le maître-bâtisseur travaille', needs: ['other/ChkStartClockTowerBoost'], def: '0' },
      ],
    },
    {
      title: 'Attaques de la base des ouvriers',
      icon: 'i-swords',
      fields: [
        { id: 'other/ChkEnableBBAttack', type: 'toggle', label: 'Attaquer', hint: "Avec l'armée déjà prête", def: 'False' },
        {
          id: 'other/iBBAttackCount',
          type: 'select',
          label: "Nombre d'attaques",
          options: opts(['Tant qu’il reste des étoiles', 'Aléatoire', ...range(1, 10).map(([, l]) => l)]),
          needs: ['other/ChkEnableBBAttack'],
          def: '6',
        },
        {
          type: 'row',
          fields: [
            { id: 'other/iBBNextTroopDelay', type: 'select', label: 'Délai entre troupes différentes', options: bbDelays(2000, 400), needs: ['other/ChkEnableBBAttack'], def: '2000' },
            { id: 'other/iBBSameTroopDelay', type: 'select', label: 'Délai entre troupes identiques', options: bbDelays(300, 60), needs: ['other/ChkEnableBBAttack'], def: '300' },
          ],
        },
        { id: 'other/ChkBBTrophyRange', type: 'toggle', label: 'Plage de trophées', needs: ['other/ChkEnableBBAttack'], def: 'False' },
        {
          type: 'row',
          fields: [
            { id: 'other/TxtBBTrophyLowerLimit', type: 'number', label: 'Arrêter sous', step: 50, needs: ['other/ChkEnableBBAttack', 'other/ChkBBTrophyRange'], def: '0' },
            { id: 'other/TxtBBTrophyUpperLimit', type: 'number', label: 'Perdre des trophées au-dessus de', step: 50, needs: ['other/ChkEnableBBAttack', 'other/ChkBBTrophyRange'], def: '5000' },
          ],
        },
        { id: 'other/ChkBBAttIfLootAvail', type: 'toggle', label: "Seulement s'il reste des étoiles à gagner", needs: ['other/ChkEnableBBAttack'], def: 'False' },
        { id: 'other/ChkBBHaltOnGoldFull', type: 'toggle', label: "S'arrêter si l'or est plein", needs: ['other/ChkEnableBBAttack'], def: 'False' },
        { id: 'other/ChkBBHaltOnElixirFull', type: 'toggle', label: "S'arrêter si l'élixir est plein", needs: ['other/ChkEnableBBAttack'], def: 'False' },
        { id: 'other/ChkBBWaitForMachine', type: 'toggle', label: 'Attendre la machine de combat', hint: "Pas d'attaque tant qu'elle est à terre", needs: ['other/ChkEnableBBAttack'], def: 'False' },
      ],
    },
    {
      title: 'Ordre de déploiement (base des ouvriers)',
      icon: 'i-list',
      fields: [
        { id: 'other/bBBDropOrderSet', type: 'toggle', label: 'Ordre personnalisé', hint: "Sinon l'ordre par défaut du bot", def: 'False' },
        {
          id: 'other/sBBDropOrder',
          type: 'pipeselects',
          count: BB_TROOPS.length,
          options: BB_TROOPS,
          needs: ['other/bBBDropOrderSet'],
          def: BB_TROOPS.map(([k]) => k).join('|'),
        },
      ],
    },
    {
      title: 'Améliorations suggérées',
      icon: 'i-hammer',
      fields: [
        { id: 'other/ChkBBSuggestedUpgrades', type: 'toggle', label: 'Suivre les améliorations suggérées', def: '0' },
        { id: 'other/ChkBBSuggestedUpgradesIgnoreGold', type: 'toggle', label: "Ignorer celles en or", needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
        { id: 'other/ChkBBSuggestedUpgradesIgnoreElixir', type: 'toggle', label: "Ignorer celles en élixir", needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
        { id: 'other/ChkBBSuggestedUpgradesIgnoreHall', type: 'toggle', label: 'Ignorer la salle des ouvriers', needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
        { id: 'other/ChkBBSuggestedUpgradesIgnoreWall', type: 'toggle', label: 'Ignorer les murs', needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
        { id: 'other/ChkBBSaveWallBuilder', type: 'toggle', label: 'Garder un ouvrier pour les murs', hint: 'Bâtiments, machine, hélico et nouveaux bâtiments seulement avec deux ouvriers libres', needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
        { id: 'other/ChkPlacingNewBuildings', type: 'toggle', label: 'Construire les bâtiments marqués « Nouveau »', needs: ['other/ChkBBSuggestedUpgrades'], def: '0' },
      ],
    },
    {
      title: 'Améliorations pour le contrôle B.O.B',
      icon: 'i-hammer',
      fields: [
        { id: 'other/chkDoubleCannonUpgrade', type: 'toggle', label: 'Double canon niveau 4', hint: 'Requis pour B.O.B niveau 2', def: 'False' },
        { id: 'other/chkArcherTowerUpgrade', type: 'toggle', label: "Tour d'archères niveau 6", hint: 'Requis pour B.O.B niveau 2', def: 'False' },
        { id: 'other/chkMultiMortarUpgrade', type: 'toggle', label: 'Multi-mortier niveau 8', hint: 'Requis pour B.O.B niveau 2', def: 'False' },
        { id: 'other/chkAnyDefUpgrade', type: 'toggle', label: 'Une défense au niveau 9', hint: 'Requis pour B.O.B niveau 4 (le canon est la moins chère)', def: 'False' },
        { id: 'other/chkBattleMachineUpgrade', type: 'toggle', label: 'Machine de combat niveau 35', hint: 'Requis pour B.O.B niveau 5 (machines cumulées ≥ 45)', def: 'False' },
        { id: 'other/chkBattlecopterUpgrade', type: 'toggle', label: 'Hélico de combat niveau 35', hint: 'Requis pour B.O.B niveau 5 (machines cumulées ≥ 45)', def: 'False' },
      ],
    },
  ];

  // ------------------------------------------------------------------ Divers > Jeux de clan (clangames.ini)
  const CG = 'clangames:clangames/';
  const CG_CATEGORIES = [
    ['ChkClanGamesLoot', 'EnabledCGLoot', 'Butin', ['Gold Challenge', 'Elixir Challenge', 'Dark Elixir Challenge', 'Gold Grab', 'Elixir Embezzlement', 'Dark Elixir Heist']],
    ['ChkClanGamesBattle', 'EnabledCGBattle', 'Combat', ['Star Collector', 'Lord of Destruction', 'Pile Of Victories', 'Hunt for Three Stars', 'Winning Streak', 'Slaying The Titans', 'No Heroics Allowed', 'No-Magic Zone', 'Scrappy 6s', 'Super 7s', 'Exciting 8s', 'Noble 9s', 'Terrific 10s', 'Exotic 11s', 'Triumphant 12s', 'Tremendous 13s', 'Formidable 14s', 'Attack Up', 'Clash of Legends', '3 Stars From Clan War', '3 Stars in 60 seconds', 'Deploy SuperTroops']],
    ['ChkClanGamesDestruction', 'EnabledCGDes', 'Destruction', ['Cannon', 'Archer Tower', 'Builder Hut', 'Mortar', 'Air Defenses', 'Wizard Tower', 'Air Sweepers', 'Tesla Towers', 'Bomb Towers', 'X-Bows', 'Inferno Towers', 'Eagle Artillery', 'Clan Castle', 'Gold Storage', 'Elixir Storage', 'Dark Elixir Storage', 'Gold Mine', 'Elixir Pump', 'Dark Elixir Drill', 'Laboratory', 'Spell Factory', 'Dark Spell Factory', 'Wall Whacker', 'Building Breakdown', 'Barbarian King Altars', 'Archer Queen Altars', 'Grand Warden Altars', 'Hero Level Hunter', 'King Level Hunter', 'Queen Level Hunter', 'Warden Level Hunter', 'Destroy ArmyCamp', 'ScatterShot', 'Champion Level Hunter']],
    ['ChkClanGamesAirTroop', 'EnabledCGAirTroop', 'Troupes aériennes', ['Balloon', 'Dragon', 'Baby Dragon', 'Electro Dragon', 'Dragon Rider', 'Minion', 'Lavahound', 'Rocket Balloon', 'Super Minion', 'Inferno Dragon', 'Ice Hound', 'Battle Blimp', 'Stone Slammer']],
    ['ChkClanGamesGroundTroop', 'EnabledCGGroundTroop', 'Troupes au sol', ['Archer', 'Barbarian', 'Giant', 'Goblin', 'WallBreaker', 'Wizard', 'Healer', 'HogRider', 'Miner', 'Pekka', 'Witch', 'Bowler', 'Valkyrie', 'Golem', 'Yeti', 'IceGolem', 'HeadHunters', 'SuperBarbarian', 'SuperArcher', 'SuperGiant', 'SneakyGoblin', 'SuperWallBreaker', 'SuperWizard', 'SuperValkyrie', 'SuperWitch', 'SuperBowler', 'Wall Wrecker', 'Siege Barrack', 'Log Launcher']],
    ['ChkClanGamesEquipment', 'EnabledCGEquipment', 'Équipements', ['Barbarian Puppet', 'Rage Vial', 'Earth Quake Boots', 'Vampstache', 'Giant Gauntlet', 'Spiky Ball', 'Archer Puppet', 'Invisibility Vial', 'Giant Arrow', 'Healer Puppet', 'Frozen Arrow', 'Magic Mirror', 'Henchmen Puppet', 'Dark Orb', 'Eternal Tome', 'Life Gem', 'Rage Gem', 'Healing Tome', 'Fireball', 'Royal Gem', 'Lavaloon Puppet', 'Seeking Shield', 'Hog Rider Puppet', 'Haste Vial', 'Rocket Spear', 'Electro Boots']],
    ['ChkClanGamesMiscellaneous', 'EnabledCGMisc', 'Divers', ['Gardening Exercise', 'Donate Spells', 'Helping Hand']],
    ['ChkClanGamesSpell', 'EnabledCGSpell', 'Sorts', ['Lightning', 'Heal', 'Rage', 'Jump', 'Freeze', 'Clone', 'Invisibility', 'Poison', 'Earthquake', 'Haste', 'Skeleton', 'Bat']],
    ['ChkClanGamesBBBattle', 'EnabledBBBattle', 'Combat (base des ouvriers)', ['BB Star Master', 'BB Victories', 'BB Star Timed', 'BB Destruction']],
    ['ChkClanGamesBBDestruction', 'EnabledBBDestruction', 'Destruction (base des ouvriers)', ['Air Bomb', 'BB Building', 'BuilderHall', 'BB Cannon', 'Clock Tower', 'Double Cannon', 'Fire Crackers', 'Gem Mine', 'Giant Cannon', 'Guard Post', 'Mega Tesla', 'Multi Mortar', 'Roaster', 'Star Laboratory', 'Wall WipeOut', 'Crusher', 'Archer Tower', 'Lava Launcher', 'Otto OutPost', 'Xbow Explosion', 'Healing Hut']],
    ['ChkClanGamesBBTroops', 'EnabledBBTroops', 'Troupes (base des ouvriers)', ['Raged Barbarian', 'Sneaky Archer', 'Boxer Giant', 'Beta Minion', 'Bomber', 'Baby Dragon', 'Cannon Cart', 'Night Witch', 'Drop Ship', 'Super Pekka', 'Hog Glider', 'ElectroFire Wizard']],
  ];

  const REWARDS = [
    ['BookOfEverything', 'Livre de tout', 10], ['BookOfHero', 'Livre des héros', 10], ['BookOfFighting', 'Livre du combat', 10],
    ['BookOfBuilding', 'Livre de construction', 10], ['BookOfSpell', 'Livre des sorts', 10], ['Gems', 'Gemmes', 20],
    ['RuneOfGold', "Rune d'or", 30], ['RuneOfElixir', "Rune d'élixir", 30], ['RuneOfDarkElixir', "Rune d'élixir noir", 30],
    ['RuneOfBuilderGold', "Rune d'or (ouvriers)", 30], ['RuneOfBuilderElixir', "Rune d'élixir (ouvriers)", 30], ['Shovel', 'Pelle', 40],
    ['FullBookOfEverything', 'Livre de tout (inventaire plein)', 50], ['FullBookOfHero', 'Livre des héros (plein)', 50],
    ['FullBookOfFighting', 'Livre du combat (plein)', 50], ['FullBookOfBuilding', 'Livre de construction (plein)', 50],
    ['FullBookOfSpell', 'Livre des sorts (plein)', 50], ['FullRuneOfGold', "Rune d'or (pleine)", 60], ['FullRuneOfElixir', "Rune d'élixir (pleine)", 60],
    ['FullRuneOfDarkElixir', "Rune d'élixir noir (pleine)", 60], ['FullRuneOfBuilderGold', "Rune d'or ouvriers (pleine)", 60],
    ['FullRuneOfBuilderElixir', "Rune d'élixir ouvriers (pleine)", 60], ['FullShovel', 'Pelle (pleine)', 70], ['FullWallRing', 'Anneau de mur (plein)', 70],
    ['WallRing', 'Anneau de mur', 70], ['PotBuilder', 'Potion de constructeur', 80], ['PotResearch', 'Potion de recherche', 80],
    ['PotClock', 'Potion de tour de l’horloge', 80], ['PotBoost', "Potion d'entraînement", 80], ['PotHero', 'Potion de héros', 80],
    ['PotResources', 'Potion de ressources', 80], ['PotPower', 'Potion de puissance', 80], ['PotSuper', 'Potion de super', 80],
    ['FullPotBuilder', 'Potion de constructeur (pleine)', 90], ['FullPotResearch', 'Potion de recherche (pleine)', 90],
    ['FullPotClock', 'Potion d’horloge (pleine)', 90], ['FullPotBoost', "Potion d'entraînement (pleine)", 90], ['FullPotHero', 'Potion de héros (pleine)', 90],
    ['FullPotResources', 'Potion de ressources (pleine)', 90], ['FullPotPower', 'Potion de puissance (pleine)', 90], ['FullPotSuper', 'Potion de super (pleine)', 90],
  ];

  const clanGames = [
    {
      title: 'Jeux de clan',
      icon: 'i-flag',
      fields: [
        { id: `${CG}ChkClanGamesEnabled`, type: 'toggle', label: 'Faire les défis des jeux de clan', def: '0' },
        {
          type: 'radiokeys',
          label: 'Défis acceptés',
          options: [[`${CG}ChkClanGamesAllTimes`, 'Tous'], [`${CG}ChkClanGamesNoOneDay`, 'Sauf ceux d’un jour']],
          needs: [`${CG}ChkClanGamesEnabled`],
        },
        {
          type: 'radiokeys',
          label: 'Priorité',
          options: [[`${CG}SearchBBEventFirst`, "Base des ouvriers d'abord"], [`${CG}SearchMainEventFirst`, "Village principal d'abord"], [`${CG}SearchBothVillages`, 'Les deux']],
          needs: [`${CG}ChkClanGamesEnabled`],
        },
        { id: `${CG}ChkClanGamesSort`, type: 'toggle', label: 'Trier les défis', needs: [`${CG}ChkClanGamesEnabled`], def: '1' },
        {
          id: `${CG}ClanGamesSortBy`,
          type: 'select',
          label: 'Tri',
          options: opts(['Difficulté la plus basse', 'Temps le plus court', 'Temps le plus long', 'Moins de points', 'Plus de points']),
          needs: [`${CG}ChkClanGamesEnabled`, `${CG}ChkClanGamesSort`],
          def: '0',
        },
        { id: `${CG}ChkForceBBAttackOnClanGames`, type: 'toggle', label: 'Toujours forcer l’attaque de la base des ouvriers', hint: 'Ignore trophées, butin et attente de la machine', needs: [`${CG}ChkClanGamesEnabled`], def: '1' },
        { id: `${CG}ChkForceAttackOnClanGamesWhenHalt`, type: 'toggle', label: 'Attaquer même en arrêt des attaques', hint: "Si un défi est en cours (pas pour l'arrêt du bot ou la fermeture)", needs: [`${CG}ChkClanGamesEnabled`], def: '0' },
        { id: `${CG}ChkClanGamesPurgeAny`, type: 'toggle', label: 'Purger un défi si aucun ne convient', needs: [`${CG}ChkClanGamesEnabled`], def: '1' },
        { id: `${CG}ChkClanGamesStopBeforeReachAndPurge`, type: 'toggle', label: 'S’arrêter avant la limite et seulement purger', hint: '300 points avant la fin, sauf le dernier jour', needs: [`${CG}ChkClanGamesEnabled`], def: '1' },
        { id: `${CG}ChkClanGamesCollectRewards`, type: 'toggle', label: 'Récupérer les récompenses à la fin', hint: 'Dans l’ordre de priorité de la carte Récompenses', needs: [`${CG}ChkClanGamesEnabled`], def: '0' },
        { id: 'clangames:debug/CGDebug', type: 'toggle', label: 'Debug des jeux de clan', def: '0' },
        { id: 'clangames:debug/CGDebugEvents', type: 'toggle', label: 'Capturer la fenêtre des défis', def: '0' },
      ],
    },
    ...CG_CATEGORIES.map(([enable, list, label, items]) => ({
      title: label,
      icon: 'i-list',
      note: enable === 'ChkClanGamesEquipment' ? "Cette version du bot ne relit pas la case « Équipements » au démarrage (ligne commentée dans readConfig) : la liste est enregistrée, la case doit aussi être cochée dans le bot." : undefined,
      fields: [
        { id: `${CG}${enable}`, type: 'toggle', label: `Défis « ${label} »`, needs: [`${CG}ChkClanGamesEnabled`], def: '0' },
        { id: `${CG}${list}`, type: 'flags', items, needs: [`${CG}ChkClanGamesEnabled`, `${CG}${enable}`], def: '0|'.repeat(items.length) },
      ],
    })),
    {
      title: 'Récompenses',
      icon: 'i-gift',
      wide: true,
      cols: 3,
      note: 'ClanGamesRewards.ini : 1 = pris en premier, 99 = en dernier ; même valeur = au hasard dans le groupe.',
      fields: REWARDS.map(([key, label, def]) => ({ id: `cgrewards:Rewards/${key}`, type: 'number', label, min: 1, max: 99, def: String(def) })),
    },
  ];

  // ------------------------------------------------------------------ Divers > Capitale de clan
  const clanCapital = [
    {
      title: 'Capitale de clan',
      icon: 'i-castle',
      fields: [{ id: 'ClanCapital/ChkCollectCCGold', type: 'toggle', label: "Collecter l'or de la capitale", def: 'False' }],
    },
    {
      title: "Forge (or de la capitale)",
      icon: 'i-hammer',
      fields: [
        {
          type: 'row',
          fields: [
            { id: 'ClanCapital/ChkEnableForgeGold', type: 'toggle', label: "Utiliser l'or", def: 'False' },
            { id: 'ClanCapital/cmdGoldSaveMin', type: 'number', label: 'Garder', step: 10000, needs: ['ClanCapital/ChkEnableForgeGold'], def: '150000' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'ClanCapital/ChkEnableForgeElix', type: 'toggle', label: "Utiliser l'élixir", def: 'False' },
            { id: 'ClanCapital/cmdElixSaveMin', type: 'number', label: 'Garder', step: 10000, needs: ['ClanCapital/ChkEnableForgeElix'], def: '1000' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'ClanCapital/ChkEnableForgeDE', type: 'toggle', label: "Utiliser l'élixir noir", def: 'False' },
            { id: 'ClanCapital/cmdDarkSaveMin', type: 'number', label: 'Garder', step: 1000, needs: ['ClanCapital/ChkEnableForgeDE'], def: '1000' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'ClanCapital/ChkEnableForgeBBGold', type: 'toggle', label: "Utiliser l'or des ouvriers", def: 'False' },
            { id: 'ClanCapital/cmdBBGoldSaveMin', type: 'number', label: 'Garder', step: 10000, needs: ['ClanCapital/ChkEnableForgeBBGold'], def: '1000' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'ClanCapital/ChkEnableForgeBBElix', type: 'toggle', label: "Utiliser l'élixir des ouvriers", def: 'False' },
            { id: 'ClanCapital/cmdBBElixSaveMin', type: 'number', label: 'Garder', step: 10000, needs: ['ClanCapital/ChkEnableForgeBBElix'], def: '1000' },
          ],
        },
        { id: 'ClanCapital/ChkEnableSmartUse', type: 'toggle', label: 'Utilisation intelligente', hint: 'Les ressources par ordre de valeur, sinon par type', def: 'False' },
        { id: 'ClanCapital/ForgeUseBuilder', type: 'select', label: 'Ouvriers pour la forge', options: [['0', 'Auto'], ...range(1, 4)], def: '0' },
      ],
    },
    {
      title: 'Amélioration automatique',
      icon: 'i-hammer',
      fields: [
        { id: 'ClanCapital/AutoUpgradeCC', type: 'toggle', label: 'Améliorer la capitale', def: 'False' },
        { id: 'ClanCapital/ChkAutoUpgradeCCPriorArmy', type: 'toggle', label: "Priorité à l'armée", hint: "Camps, casernes, cour de la forteresse, réserve et usine de sorts", needs: ['ClanCapital/AutoUpgradeCC'], def: 'False' },
        { id: 'ClanCapital/ChkAutoUpgradeCCIgnore', type: 'toggle', label: 'Ignorer les décorations', hint: 'Bosquets, arbres, forêts, campements…', needs: ['ClanCapital/AutoUpgradeCC'], def: 'False' },
        { id: 'ClanCapital/ChkAutoUpgradeCCWallIgnore', type: 'toggle', label: 'Ignorer les murs', needs: ['ClanCapital/AutoUpgradeCC'], def: 'False' },
      ],
    },
  ];

  // ------------------------------------------------------------------ Demandes et dons
  const troopList = TROOPS.map((t) => t[1]);
  const request = [
    {
      title: 'Demande de renforts',
      icon: 'i-castle',
      fields: [
        { id: 'planned/RequestHoursEnable', type: 'toggle', label: 'Demander des troupes / sorts', def: '0' },
        { id: 'donate/txtRequest', type: 'text', label: 'Message', placeholder: 'Anything please', needs: ['planned/RequestHoursEnable'], def: '' },
        { type: 'info', text: 'Demander quand il manque :' },
        {
          type: 'row',
          fields: [
            { id: 'donate/RequestType_Troop', type: 'toggle', label: 'Troupes', needs: ['planned/RequestHoursEnable'], def: '0' },
            { id: 'donate/RequestType_Spell', type: 'toggle', label: 'Sorts', needs: ['planned/RequestHoursEnable'], def: '0' },
            { id: 'donate/RequestType_Siege', type: 'toggle', label: 'Engin de siège', needs: ['planned/RequestHoursEnable'], def: '0' },
          ],
        },
        {
          type: 'row',
          label: 'Ne pas demander si déjà reçu au moins',
          hint: '0 (ou 40+ / 2+) : château plein voulu',
          fields: [
            { id: 'donate/RequestCountCC_Troop', type: 'number', label: 'Troupes (places)', max: 99, needs: ['planned/RequestHoursEnable', 'donate/RequestType_Troop'], def: '0' },
            { id: 'donate/RequestCountCC_Spell', type: 'number', label: 'Sorts', max: 9, needs: ['planned/RequestHoursEnable', 'donate/RequestType_Spell'], def: '0' },
          ],
        },
        { id: 'planned/RequestHours', type: 'hours', label: 'Seulement pendant ces heures', needs: ['planned/RequestHoursEnable'] },
      ],
    },
    {
      title: 'Garder seulement dans le château',
      icon: 'i-shield',
      fields: [
        { type: 'info', text: 'Les autres unités reçues sont retirées du château.' },
        ...[0, 1, 2].map((i) => ({
          type: 'row',
          label: `Troupe ${i + 1}`,
          fields: [
            { id: `donate/cmbClanCastleTroop${i}`, type: 'select', label: 'Type', options: opts(['Toutes', ...troopList]), def: '0' },
            { id: `donate/txtClanCastleTroop${i}`, type: 'number', label: 'Si moins de', max: 50, def: '0' },
          ],
        })),
        {
          type: 'row',
          label: 'Sorts',
          fields: [0, 1, 2].map((i) => ({ id: `donate/cmbClanCastleSpell${i}`, type: 'select', label: `Sort ${i + 1}`, options: opts(['Tous', ...SPELLS.map((s) => s[2])]), def: '0' })),
        },
        {
          type: 'row',
          label: 'Engins de siège',
          fields: [0, 1].map((i) => ({ id: `donate/cmbClanCastleSiege${i}`, type: 'select', label: `Engin ${i + 1}`, options: opts(['Tous', ...SIEGES.map((s) => s[1])]), def: '0' })),
        },
      ],
    },
  ];

  // une carte par unite a donner : dons actives, a tous, mots-cles, liste noire
  const donateCard = (iniName, label) => ({
    title: label,
    icon: 'i-gift',
    fields: [
      {
        type: 'row',
        fields: [
          { id: `donate/chkDonate${iniName}`, type: 'toggle', label: 'Donner', needs: ['donate/Doncheck'], def: '0' },
          { id: `donate/chkDonateAll${iniName}`, type: 'toggle', label: 'À tous', hint: 'Sans mot-clé', needs: ['donate/Doncheck', `donate/chkDonate${iniName}`], def: '0' },
        ],
      },
      { id: `donate/txtDonate${iniName}`, type: 'textarea', label: 'Mots-clés (un par ligne)', rows: 3, needs: ['donate/Doncheck', `donate/chkDonate${iniName}`], def: '' },
      { id: `donate/txtBlacklist${iniName}`, type: 'textarea', label: 'Liste noire', rows: 2, needs: ['donate/Doncheck', `donate/chkDonate${iniName}`], def: '' },
    ],
  });

  const donateGeneral = [
    {
      title: 'Dons',
      icon: 'i-gift',
      fields: [
        { id: 'donate/Doncheck', type: 'toggle', label: 'Donner des troupes au clan', hint: 'Coupe tous les dons ci-dessous', def: '1' },
        { type: 'info', text: 'Alphabets reconnus en plus dans les demandes :' },
        {
          type: 'row',
          fields: [
            { id: 'donate/chkExtraAlphabets', type: 'toggle', label: 'Cyrillique', needs: ['donate/Doncheck'], def: '0' },
            { id: 'donate/chkExtraChinese', type: 'toggle', label: 'Chinois', needs: ['donate/Doncheck'], def: '0' },
            { id: 'donate/chkExtraKorean', type: 'toggle', label: 'Coréen', needs: ['donate/Doncheck'], def: '0' },
            { id: 'donate/chkExtraPersian', type: 'toggle', label: 'Persan', needs: ['donate/Doncheck'], def: '0' },
          ],
        },
      ],
    },
    {
      title: 'Liste noire générale',
      icon: 'i-x',
      fields: [{ id: 'donate/txtBlacklist', type: 'textarea', label: 'Ne jamais donner si la demande contient', rows: 5, needs: ['donate/Doncheck'], def: 'clan war|war|cw' }],
    },
    ...['A', 'B'].map((ab) => ({
      title: `Don personnalisé ${ab}`,
      icon: 'i-gift',
      fields: [
        {
          type: 'row',
          fields: [
            { id: `donate/chkDonateCustom${ab}`, type: 'toggle', label: 'Donner', needs: ['donate/Doncheck'], def: '0' },
            { id: `donate/chkDonateAllCustom${ab}`, type: 'toggle', label: 'À tous', needs: ['donate/Doncheck', `donate/chkDonateCustom${ab}`], def: '0' },
          ],
        },
        ...[1, 2, 3].map((n) => ({
          type: 'row',
          label: `${n}.`,
          fields: [
            { id: `donate/cmbDonateCustom${ab}${n}`, type: 'select', label: 'Troupe', options: opts([...troopList, 'Rien']), needs: ['donate/Doncheck', `donate/chkDonateCustom${ab}`] },
            { id: `donate/txtDonateCustom${ab}${n}`, type: 'number', label: 'Nombre', max: 9, needs: ['donate/Doncheck', `donate/chkDonateCustom${ab}`] },
          ],
        })),
        { id: `donate/txtDonateCustom${ab}`, type: 'textarea', label: 'Mots-clés', rows: 2, needs: ['donate/Doncheck', `donate/chkDonateCustom${ab}`], def: '' },
        { id: `donate/txtBlacklistCustom${ab}`, type: 'textarea', label: 'Liste noire', rows: 2, needs: ['donate/Doncheck', `donate/chkDonateCustom${ab}`], def: '' },
      ],
    })),
  ];
  // valeurs par defaut du bot pour les dons personnalises (readConfig)
  const CUSTOM_DEFAULTS = { A1: ['12', '2'], A2: ['2', '3'], A3: ['0', '1'], B1: ['18', '3'], B2: ['9', '13'], B3: ['25', '5'] };
  for (const card of donateGeneral) {
    for (const f of card.fields) {
      if (f.type !== 'row') continue;
      for (const sub of f.fields) {
        const m = /Custom([AB])(\d)$/.exec(sub.id ?? '');
        if (m) sub.def = CUSTOM_DEFAULTS[m[1] + m[2]][sub.type === 'select' ? 0 : 1];
      }
    }
  }

  const byShort = (list) => list.map((s) => TROOPS.find((t) => t[0] === s));
  const { elixir, dark, super: supers } = window.U.TRAIN_ORDER;
  const donateTabs = [
    { id: 'donate-general', label: 'Général', cards: donateGeneral },
    { id: 'donate-elixir', label: 'Troupes élixir', cards: byShort(elixir).map((t) => donateCard(t[2], t[1])) },
    { id: 'donate-dark', label: 'Troupes noires', cards: byShort(dark).map((t) => donateCard(t[2], t[1])) },
    { id: 'donate-super', label: 'Super troupes', cards: byShort(supers).map((t) => donateCard(t[2], t[1])) },
    { id: 'donate-spells', label: 'Sorts', cards: SPELLS.map((s) => donateCard(`${s[1]}Spells`, s[2])) },
    { id: 'donate-sieges', label: 'Engins de siège', cards: SIEGES.map((s) => donateCard(s[0], s[1])) },
  ];

  const donateSchedule = [
    {
      title: 'Planning des dons',
      icon: 'i-clock2',
      fields: [
        { id: 'planned/DonateHoursEnable', type: 'toggle', label: 'Donner seulement pendant ces heures', def: '0' },
        { id: 'planned/DonateHours', type: 'hours', needs: ['planned/DonateHoursEnable'] },
      ],
    },
    {
      title: 'Filtre des membres',
      icon: 'i-users',
      fields: [
        {
          id: 'donate/cmbFilterDonationsCC',
          type: 'select',
          label: 'À qui donner',
          options: opts(['À tous, sans filtre', 'À tous, et capturer les images des membres', 'Seulement aux membres de la liste blanche', 'À tous sauf ceux de la liste noire']),
          def: '0',
        },
        { type: 'info', text: 'Les images des membres sont rangées dans le dossier du profil : déplacez-les dans les dossiers White ou Black List.' },
      ],
    },
    {
      title: 'Équilibre dons / reçus',
      icon: 'i-activity',
      fields: [
        { id: 'donate/BalanceCC', type: 'toggle', label: 'Équilibrer ce qui est donné et reçu', def: '0' },
        {
          type: 'row',
          fields: [
            { id: 'donate/BalanceCCDonated', type: 'select', label: 'Donné', options: opts(['1', '2', '3', '4', '5']), needs: ['donate/BalanceCC'], def: '1' },
            { id: 'donate/BalanceCCReceived', type: 'select', label: 'Reçu', options: opts(['1', '2', '3', '4', '5']), needs: ['donate/BalanceCC'], def: '1' },
          ],
        },
        { id: 'donate/CheckDonateOften', type: 'toggle', label: 'Vérifier les demandes souvent', def: '0' },
      ],
    },
  ];

  // ------------------------------------------------------------------ Ameliorations
  const LAB_ITEMS = ['N’importe laquelle', 'Barbare', 'Archère', 'Géant', 'Gobelin', 'Sapeur', 'Ballon', 'Sorcier', 'Guérisseuse', 'Dragon', 'P.E.K.K.A', 'Bébé dragon', 'Mineur', 'Électro-dragon', 'Yéti', 'Dragon Rider', 'Electro Titan', 'Root Rider', 'Thrower', 'Sort de foudre', 'Sort de soin', 'Sort de rage', 'Sort de saut', 'Sort de gel', 'Sort de clonage', "Sort d'invisibilité", 'Sort de rappel', 'Revive Spell', 'Sort de poison', 'Sort de séisme', 'Sort de hâte', 'Sort de squelettes', 'Sort de chauves-souris', 'Overgrowth Spell', 'Gargouille', 'Chevaucheur de cochon', 'Valkyrie', 'Golem', 'Sorcière', 'Molosse de lave', 'Bouliste', 'Golem de glace', 'Chasseuse de têtes', 'Apprenti gardien', 'Druide', 'Furnace', 'Démolisseur', 'Zeppelin de combat', 'Stone Slammer', 'Caserne de siège', 'Lance-bûches', 'Flame Flinger', 'Foreuse de combat', 'Lance-troupes'];
  const STAR_LAB_ITEMS = ['N’importe laquelle', 'Barbare enragé', 'Archère furtive', 'Géant boxeur', 'Gargouille bêta', 'Bombardier', 'Bébé dragon', 'Cannon Cart', 'Sorcière de la nuit', 'Drop Ship', 'Super P.E.K.K.A', 'Hog Glider', 'Electrofire Wizard'];
  const ASSIST = opts(['Ne pas utiliser', 'La plus longue', 'La plus courte']);

  const laboratory = [
    {
      title: 'Laboratoire',
      icon: 'i-flask',
      fields: [
        { id: 'upgrade/upgradetroops', type: 'toggle', label: 'Lancer les recherches automatiquement', def: '0' },
        { id: 'upgrade/upgradetroopname', type: 'select', label: 'Prochaine recherche', options: opts(LAB_ITEMS), hint: 'Les troupes et sorts noirs passent avant les héros', needs: ['upgrade/upgradetroops'], def: '0' },
        { id: 'upgrade/IsChkLabAssistant', type: 'select', label: "Assistant de labo", options: ASSIST, needs: ['upgrade/upgradetroops'], def: '0' },
      ],
    },
    {
      title: 'Laboratoire stellaire',
      icon: 'i-star',
      fields: [
        { id: 'upgrade/upgradestartroops', type: 'toggle', label: 'Lancer les recherches automatiquement', def: '0' },
        { id: 'upgrade/upgradestartroopname', type: 'select', label: 'Prochaine recherche', options: opts(STAR_LAB_ITEMS), needs: ['upgrade/upgradestartroops'], def: '0' },
      ],
    },
  ];

  const heroes = [
    {
      title: 'Héros',
      icon: 'i-trophy',
      fields: [
        { type: 'info', text: "Améliorer les héros dès que les ressources le permettent. « Répéter » relance l'amélioration suivante." },
        ...HEROES.map(([short, name]) => ({
          type: 'row',
          label: name,
          fields: [
            { id: `upgrade/Upgrade${short}`, type: 'toggle', label: 'Améliorer', def: '0' },
            { id: `upgrade/RepUpgrade${short}`, type: 'toggle', label: 'Répéter', needs: [`upgrade/Upgrade${short}`], def: '0' },
          ],
        })),
        { id: 'upgrade/HeroReservedBuilder', type: 'select', label: 'Ouvriers réservés aux héros', options: opts(['—', '0', '1', '2', '3', '4', '5']), def: '0' },
      ],
    },
    {
      title: 'Familiers',
      icon: 'i-star',
      cols: 2,
      fields: [
        { type: 'info', text: "Améliorer les familiers à l'animalerie quand l'élixir noir suffit.", wide: true },
        ...PETS.map(([short, name]) => ({ id: `upgrade/UpgradePet[${short}]`, type: 'toggle', label: name, def: '0' })),
      ],
    },
    {
      title: 'Équipements (forge)',
      icon: 'i-hammer',
      wide: true,
      cols: 3,
      fields: [
        { id: 'upgrade/ChkUpgradeEquipment', type: 'toggle', label: 'Améliorer les équipements', wide: true, def: '0' },
        { id: 'upgrade/ChkFinishCurrentEquipmentFirst', type: 'toggle', label: "Finir l'équipement en cours d'abord", hint: "Tout ce qui est en cours est terminé avant de passer au suivant (HDV / forge requis)", wide: true, needs: ['upgrade/ChkUpgradeEquipment'], def: '1' },
        { type: 'info', text: 'Ordre des améliorations : cochez les positions utilisées et choisissez un équipement pour chacune.', wide: true },
        ...EQUIPMENT.map((_, z) => ({
          type: 'row',
          label: `${z + 1}.`,
          fields: [
            { id: `upgrade/ChkEquipment${z}`, type: 'toggle', label: '', needs: ['upgrade/ChkUpgradeEquipment'], def: '0' },
            { id: `upgrade/cmbEquipmentOrder${z}`, type: 'select', options: [['-1', '—'], ...EQUIPMENT.map(([n, hero], i) => [String(i), `${n} (${window.U.heroName[hero].split(' ')[0]})`])], needs: ['upgrade/ChkUpgradeEquipment', `upgrade/ChkEquipment${z}`], def: '-1' },
          ],
        })),
      ],
    },
  ];

  const UPGRADE_SLOTS = 14; // $g_iUpgradeSlots
  const buildings = [
    {
      title: 'Bâtiments localisés',
      icon: 'i-hammer',
      wide: true,
      cols: 2,
      note: "Les bâtiments se localisent dans le bot (bouton de la ligne, puis clic dans le jeu). Ici : activer ou non chaque amélioration enregistrée, et la répéter.",
      fields: Array.from({ length: UPGRADE_SLOTS }, (_, i) => ({
        type: 'row',
        label: `Emplacement ${i + 1}`,
        fields: [
          { id: `building:upgrade/upgradename${i}`, type: 'text', label: 'Bâtiment', placeholder: 'vide', readonly: true, def: '' },
          { id: `building:upgrade/upgradechk${i}`, type: 'toggle', label: 'Améliorer', def: '0' },
          { id: `building:upgrade/upgraderepeat${i}`, type: 'toggle', label: 'Répéter', needs: [`building:upgrade/upgradechk${i}`], def: '0' },
        ],
      })),
    },
    {
      title: 'Ressources à garder',
      icon: 'i-coins',
      fields: [
        { type: 'info', text: 'Une amélioration de bâtiment ne part que si ces minimums restent en réserve.' },
        {
          type: 'row',
          fields: [
            { id: 'upgrade/minupgrgold', type: 'number', label: 'Or', step: 10000, def: '150000' },
            { id: 'upgrade/minupgrelixir', type: 'number', label: 'Élixir', step: 10000, def: '1000' },
            { id: 'upgrade/minupgrdark', type: 'number', label: 'Élixir noir', step: 1000, def: '1000' },
          ],
        },
      ],
    },
  ];

  const IGNORE = ['Hôtel de ville', "Arme de l'hôtel de ville", 'Roi des barbares', 'Reine des archères', 'Prince des gargouilles', 'Grand gardien', 'Championne royale', 'Château de clan', 'Laboratoire', 'Murs', 'Caserne', 'Caserne noire', 'Usine de sorts', 'Usine de sorts noirs', "Mine d'or", "Extracteur d'élixir", "Foreuse d'élixir noir"];
  const autoUpgrade = [
    {
      title: 'Amélioration automatique',
      icon: 'i-bolt',
      fields: [
        { id: 'Auto Upgrade/AutoUpgradeEnabled', type: 'toggle', label: 'Améliorer automatiquement', hint: 'Suit les suggestions de la hutte du maître-bâtisseur', def: 'False' },
        { id: 'Auto Upgrade/IsChkAppBuilder', type: 'select', label: "Apprenti bâtisseur", options: ASSIST, needs: ['Auto Upgrade/AutoUpgradeEnabled'], def: '0' },
        {
          type: 'row',
          label: 'Garder après avoir lancé une amélioration',
          fields: [
            { id: 'Auto Upgrade/SmartMinGold', type: 'number', label: 'Or', step: 10000, needs: ['Auto Upgrade/AutoUpgradeEnabled'], def: '150000' },
            { id: 'Auto Upgrade/SmartMinElixir', type: 'number', label: 'Élixir', step: 10000, needs: ['Auto Upgrade/AutoUpgradeEnabled'], def: '1000' },
            { id: 'Auto Upgrade/SmartMinDark', type: 'number', label: 'Élixir noir', step: 1000, needs: ['Auto Upgrade/AutoUpgradeEnabled'], def: '1000' },
          ],
        },
        {
          type: 'row',
          fields: ['Ignorer les améliorations en or', "Ignorer celles en élixir", "Ignorer celles en élixir noir"].map((label, i) => ({
            id: `Auto Upgrade/ChkResourcesToIgnore[${i}]`,
            type: 'toggle',
            label,
            needs: ['Auto Upgrade/AutoUpgradeEnabled'],
            def: '0',
          })),
        },
      ],
    },
    {
      title: 'Améliorations à ignorer',
      icon: 'i-x',
      cols: 2,
      fields: IGNORE.map((label, i) => ({ id: `Auto Upgrade/ChkUpgradesToIgnore[${i}]`, type: 'toggle', label, needs: ['Auto Upgrade/AutoUpgradeEnabled'], def: '0' })),
    },
  ];

  const walls = [
    {
      title: 'Murs',
      icon: 'i-wall',
      fields: [
        { id: 'upgrade/auto-wall', type: 'toggle', label: 'Améliorer les murs', hint: "Par lots, avec « Améliorer plus » : autant que le butin le permet", def: '0' },
        {
          id: 'upgrade/use-storage',
          type: 'radio',
          label: 'Payer avec',
          options: opts(["L'or", "L'élixir", "L'élixir, puis l'or"]),
          needs: ['upgrade/auto-wall'],
          def: '0',
        },
        { id: 'upgrade/savebldr', type: 'toggle', label: 'Garder un ouvrier pour les murs', needs: ['upgrade/auto-wall'], def: '0' },
        { id: 'upgrade/walllvl', type: 'select', label: 'Niveau des murs à chercher', options: range(4, 18).map(([, l], i) => [String(i), `Niveau ${l}`]), needs: ['upgrade/auto-wall'], def: '6' },
        {
          type: 'row',
          label: 'Ressources à garder',
          fields: [
            { id: 'upgrade/minwallgold', type: 'number', label: 'Or', step: 50000, needs: ['upgrade/auto-wall'], def: '0' },
            { id: 'upgrade/minwallelixir', type: 'number', label: 'Élixir', step: 50000, needs: ['upgrade/auto-wall'], def: '0' },
          ],
        },
      ],
    },
    {
      title: 'Compteur de murs',
      icon: 'i-list',
      cols: 4,
      fields: [
        { type: 'info', text: 'Nombre de murs de chaque niveau dans votre village.', wide: true },
        ...Array.from({ length: 16 }, (_, k) => k + 4).map((lvl) => ({ id: `Walls/Wall${String(lvl).padStart(2, '0')}`, type: 'number', label: `Niv. ${lvl}`, compact: true, def: '0' })),
      ],
    },
  ];

  // ------------------------------------------------------------------ Succes
  const achievements = [
    {
      title: 'Défense passive (succès « Incassable »)',
      icon: 'i-shield',
      fields: [
        { id: 'Unbreakable/chkUnbreakable', type: 'toggle', label: 'Activer le mode Incassable', hint: "Laisse le village se faire attaquer en gardant les ressources entre deux seuils", def: '0' },
        { id: 'Unbreakable/UnbreakableWait', type: 'number', label: "Attente entre deux vérifications", suffix: 'min', max: 60, needs: ['Unbreakable/chkUnbreakable'], def: '5' },
        {
          type: 'row',
          label: 'Minimum',
          fields: [
            { id: 'Unbreakable/minUnBrkgold', type: 'number', label: 'Or', step: 10000, needs: ['Unbreakable/chkUnbreakable'], def: '50000' },
            { id: 'Unbreakable/minUnBrkelixir', type: 'number', label: 'Élixir', step: 10000, needs: ['Unbreakable/chkUnbreakable'], def: '50000' },
            { id: 'Unbreakable/minUnBrkdark', type: 'number', label: 'Élixir noir', step: 1000, needs: ['Unbreakable/chkUnbreakable'], def: '5000' },
          ],
        },
        {
          type: 'row',
          label: 'Maximum',
          fields: [
            { id: 'Unbreakable/maxUnBrkgold', type: 'number', label: 'Or', step: 10000, needs: ['Unbreakable/chkUnbreakable'], def: '600000' },
            { id: 'Unbreakable/maxUnBrkelixir', type: 'number', label: 'Élixir', step: 10000, needs: ['Unbreakable/chkUnbreakable'], def: '600000' },
            { id: 'Unbreakable/maxUnBrkdark', type: 'number', label: 'Élixir noir', step: 1000, needs: ['Unbreakable/chkUnbreakable'], def: '10000' },
          ],
        },
      ],
    },
  ];

  window.PAGES.village = {
    title: 'Village',
    sub: 'Ce que le bot fait entre deux attaques. Réglages du profil (config.ini, building.ini, clangames.ini).',
    tabs: [
      {
        id: 'misc',
        label: 'Divers',
        icon: 'i-home',
        tabs: [
          { id: 'normal', label: 'Village principal', cards: normalVillage },
          { id: 'bb', label: 'Base des ouvriers', cards: builderBase },
          { id: 'cg', label: 'Jeux de clan', cards: clanGames },
          { id: 'capital', label: 'Capitale de clan', cards: clanCapital },
        ],
      },
      {
        id: 'donate',
        label: 'Demandes et dons',
        icon: 'i-gift',
        tabs: [{ id: 'request', label: 'Demande', cards: request }, ...donateTabs, { id: 'schedule', label: 'Planning et filtres', cards: donateSchedule }],
      },
      {
        id: 'upgrade',
        label: 'Améliorations',
        icon: 'i-hammer',
        tabs: [
          { id: 'lab', label: 'Laboratoire', cards: laboratory },
          { id: 'heroes', label: 'Héros, familiers, équipements', cards: heroes },
          { id: 'buildings', label: 'Bâtiments', cards: buildings },
          { id: 'auto', label: 'Automatique', cards: autoUpgrade },
          { id: 'walls', label: 'Murs', cards: walls },
        ],
      },
      { id: 'achievements', label: 'Succès', icon: 'i-trophy', cards: achievements },
    ],
  };
})();
