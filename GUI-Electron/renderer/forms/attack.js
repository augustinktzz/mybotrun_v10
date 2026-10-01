'use strict';
// Attaque : onglet "Search & Attack" du bot (Base morte, Base active, Bully, Options) et l'ordre de deploiement.
// Cles : SaveConfig_600_26 (bully), _28 / _28_DB / _28_LB (recherche), _29* (attaque), _30* (fin de combat),
// _31 (collecteurs), _32 (ligue), _33 (ordre), _56 (SmartZap).
(function () {
  const { opts, range, TROOPS, SPELLS, HEROES } = window.U;

  const TH_LEVELS = opts(['4-6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16']);
  const levels = (max) => opts(['—', ...Array.from({ length: max }, (_, i) => `Niv. ${i + 1}`)]);
  const WEAK = [
    ['Mortar', 'Mortier', 17, '5'],
    ['WizTower', 'Tour de sorciers', 17, '4'],
    ['AirDefense', 'Défense antiaérienne', 15, '7'],
    ['XBow', 'Arc-X', 12, '4'],
    ['Inferno', "Tour de l'enfer", 10, '1'],
    ['Eagle', "Artillerie de l'aigle", 7, '2'],
    ['Scatter', 'Tour de pétards', 6, '1'],
    ['Monolith', 'Monolithe', 3, '1'],
  ];
  // cle de l'ini et nom de chaque sort dans l'onglet d'attaque (attack/DBLightSpell...)
  const ATTACK_SPELLS = [
    ['Light', 'Foudre'], ['Heal', 'Soin'], ['Rage', 'Rage'], ['Jump', 'Saut'], ['Freeze', 'Gel'], ['Clone', 'Clonage'],
    ['Invisibility', 'Invisibilité'], ['Recall', 'Rappel'], ['Revive', 'Revive'], ['Poison', 'Poison'], ['Earthquake', 'Séisme'],
    ['Haste', 'Hâte'], ['Skeleton', 'Squelettes'], ['Bat', 'Chauves-souris'], ['Og', 'Overgrowth'],
  ];

  // ------------------------------------------------------------------ recherche (base morte / active)
  function searchCards(P, enable) {
    const on = [enable];
    return [
      {
        title: 'Lancer la recherche si',
        icon: 'i-search',
        fields: [
          {
            type: 'row',
            fields: [
              { id: `search/Chk${P}SearchSearches`, type: 'toggle', label: 'Recherches', needs: on, def: P === 'DB' ? '1' : '0' },
              { id: `search/${P}EnableAfterCount`, type: 'number', label: 'De', max: 9999, needs: [...on, `search/Chk${P}SearchSearches`], def: '1' },
              { id: `search/${P}EnableBeforeCount`, type: 'number', label: 'À', max: 9999, needs: [...on, `search/Chk${P}SearchSearches`], def: '9999' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `search/Chk${P}SearchTropies`, type: 'toggle', label: 'Palier de ligue', hint: '1 à 36', needs: on, def: '0' },
              { id: `search/${P}EnableAfterTropies`, type: 'number', label: 'De', max: 36, needs: [...on, `search/Chk${P}SearchTropies`], def: '1' },
              { id: `search/${P}EnableBeforeTropies`, type: 'number', label: 'À', max: 36, needs: [...on, `search/Chk${P}SearchTropies`], def: '36' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `search/Chk${P}SearchCamps`, type: 'toggle', label: "Camps d'armée remplis", needs: on, def: '0' },
              { id: `search/${P}EnableAfterArmyCamps`, type: 'number', label: 'Au moins', suffix: '%', max: 100, needs: [...on, `search/Chk${P}SearchCamps`], def: '100' },
            ],
          },
        ],
      },
      {
        title: 'Attendre que soient prêts',
        icon: 'i-clock',
        cols: 2,
        fields: [
          ...HEROES.map(([short, name]) => ({ id: `attack/${P}${short}Wait`, type: 'toggle', label: name, needs: on, def: '0' })),
          { id: `attack/${P}NotWaitHeroes`, type: 'toggle', label: "Ne pas attendre un héros en amélioration", wide: true, needs: on, def: '0' },
          { id: `search/Chk${P}SpellsWait`, type: 'toggle', label: 'Les sorts', needs: on, def: '0' },
          { id: `search/Chk${P}MachineWait`, type: 'toggle', label: "L'engin de siège", needs: on, def: '0' },
          { id: `search/Chk${P}CastleWait`, type: 'toggle', label: 'Le château de clan (renforts demandés)', wide: true, needs: on, def: '0' },
        ],
      },
      {
        title: 'Filtres de butin',
        icon: 'i-coins',
        fields: [
          { id: `search/${P}MeetGE`, type: 'radio', label: 'Condition', options: opts(['Or ET élixir', 'Or OU élixir', 'Or + élixir']), needs: on, def: P === 'DB' ? '1' : '2' },
          {
            type: 'row',
            fields: [
              { id: `search/${P}searchGold`, type: 'number', label: 'Or min.', step: 10000, needs: [...on, { id: `search/${P}MeetGE`, ne: '2' }], def: '80000' },
              { id: `search/${P}searchElixir`, type: 'number', label: 'Élixir min.', step: 10000, needs: [...on, { id: `search/${P}MeetGE`, ne: '2' }], def: '80000' },
              { id: `search/${P}searchGoldPlusElixir`, type: 'number', label: 'Or + élixir min.', step: 10000, needs: [...on, { id: `search/${P}MeetGE`, eq: '2' }], def: '160000' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `search/${P}MeetDE`, type: 'toggle', label: 'Élixir noir', needs: on, def: '0' },
              { id: `search/${P}searchDark`, type: 'number', label: 'Min.', step: 500, needs: [...on, `search/${P}MeetDE`], def: '0' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `search/${P}MeetTrophy`, type: 'toggle', label: 'Palier de ligue de la cible', needs: on, def: '0' },
              { id: `search/${P}searchTrophy`, type: 'number', label: 'De', max: 36, needs: [...on, `search/${P}MeetTrophy`], def: '0' },
              { id: `search/${P}searchTrophyMax`, type: 'number', label: 'À', max: 36, needs: [...on, `search/${P}MeetTrophy`], def: '36' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `search/${P}MeetTH`, type: 'toggle', label: 'Hôtel de ville max.', needs: on, def: '0' },
              { id: `search/${P}THLevel`, type: 'select', label: 'Niveau', options: TH_LEVELS, needs: [...on, `search/${P}MeetTH`], def: '0' },
            ],
          },
          { id: `search/${P}MeetTHO`, type: 'toggle', label: 'Hôtel de ville à l’extérieur', needs: on, def: '0' },
          ...(P === 'DB'
            ? [
                {
                  type: 'row',
                  fields: [
                    { id: 'search/DBMeetDeadEagle', type: 'toggle', label: "Artillerie de l'aigle morte", hint: "Cherche une base avec l'aigle… et un butin mort", needs: on, def: '0' },
                    { id: 'search/DBMeetDeadEagleSearch', type: 'number', label: 'Pendant (recherches)', max: 999, needs: [...on, 'search/DBMeetDeadEagle'], def: '99' },
                  ],
                },
              ]
            : []),
          { id: `search/${P}MeetOne`, type: 'toggle', label: 'Une seule condition suffit', hint: 'Attaque dès que l’un des filtres est rempli', needs: on, def: '0' },
        ],
      },
      {
        title: 'Base faible (défenses max.)',
        icon: 'i-shield',
        cols: 2,
        fields: WEAK.map(([key, name, max, def]) => ({
          type: 'row',
          label: name,
          fields: [
            { id: `search/${P}Check${key}`, type: 'toggle', label: '', needs: on, def: '0' },
            { id: `search/${P}Weak${key}`, type: 'select', options: levels(max), needs: [...on, `search/${P}Check${key}`], def },
          ],
        })),
      },
    ];
  }

  // ------------------------------------------------------------------ attaque (base morte / active)
  function attackCards(P, enable) {
    const on = [enable];
    const algos = ['Attaque standard', 'Attaque scriptée (CSV)', 'Attaque SmartFarm'];
    const std = P === 'DB' ? 'DB' : 'LB'; // le bot ecrit DBStandardAlgorithm et LBStandardAlgorithm
    const sides = ['Un côté', 'Deux côtés', 'Trois côtés', 'Tous les côtés'];
    if (P === 'AB') sides.push("Côté de l'élixir noir", "Côté de l'hôtel de ville");
    const S = P === 'DB' ? 'DB' : 'AB';
    return [
      {
        title: 'Attaquer avec',
        icon: 'i-swords',
        fields: [
          { id: `attack/${P}AtkAlgorithm`, type: 'select', label: "Type d'attaque", options: opts(algos), needs: on, def: '0' },
          {
            id: `attack/${P}SelectTroop`,
            type: 'select',
            label: 'Troupes utilisées',
            options: opts(['Toutes les troupes', 'Troupes des casernes', 'Barbares seulement', 'Archères seulement', 'Barbares + archères', 'Barbares + gobelins', 'Archères + gobelins', 'Barbares + archères + géants', 'Barbares + archères + gobelins + géants', 'Barbares + archères + chevaucheurs', 'Barbares + archères + gargouilles']),
            needs: on,
            def: '0',
          },
          { type: 'info', text: 'Héros déployés :' },
          {
            type: 'row',
            fields: HEROES.map(([short, name, bit]) => ({ id: `attack/${P}${short}Atk`, type: 'toggle', label: name, on: String(bit), off: '0', needs: on, def: '0' })),
          },
          { id: `attack/${P}AtkUseWardenMode`, type: 'select', label: 'Mode du grand gardien', options: opts(['Au sol', 'Aérien', 'Par défaut']), needs: [...on, { id: `attack/${P}WardenAtk`, ne: '0' }], def: '2' },
          { id: `attack/${P}DropCC`, type: 'toggle', label: 'Déployer le château de clan', hint: "S'il contient des troupes", needs: on, def: '0' },
          { id: `attack/${P}UseSiegeMachine`, type: 'toggle', label: "Déployer l'engin de siège", hint: "Celui chargé dans le château, quel qu'il soit", needs: on, def: '1' },
          {
            id: `attack/${P}AtkUseSiege`,
            type: 'select',
            label: 'Engin à forcer',
            options: opts(['Château seulement', 'Démolisseur', 'Zeppelin de combat', 'Stone Slammer', 'Caserne de siège', 'Lance-bûches', 'Flame Flinger', 'Foreuse de combat', 'Lance-troupes', "N'importe lequel", 'Par défaut (recommandé)']),
            needs: on,
            def: '10',
          },
        ],
      },
      {
        title: 'Sorts',
        icon: 'i-flask',
        cols: 2,
        note: "Déposés sur la poussée, juste après les héros (attaques standard et SmartFarm). Foudre et séisme restent réservés si SmartZap est actif.",
        fields: ATTACK_SPELLS.map(([key, name]) => ({ id: `attack/${P}${key}Spell`, type: 'toggle', label: name, compact: true, needs: on, def: '0' })),
      },
      {
        title: 'Attaque standard',
        icon: 'i-target',
        fields: [
          { id: `attack/${std}StandardAlgorithm`, type: 'select', label: 'Ordre de déploiement prédéfini', options: opts(['Par défaut (toutes les troupes)', 'Barch / BAM / BAG', 'GiBarch']), hint: "Ou l'ordre personnalisé de l'onglet « Ordre de déploiement »", needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }], def: '0' },
          { id: `attack/${S}Deploy`, type: 'select', label: 'Attaquer sur', options: opts(sides), needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }], def: P === 'DB' ? '3' : '0' },
          { id: `attack/${S}SmartAttackRedArea`, type: 'toggle', label: 'Attaque intelligente : près de la ligne rouge', needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }], def: '1' },
          { id: `attack/${S}SmartAttackDeploy`, type: 'select', label: 'Vagues', options: opts(['Les côtés, puis les troupes', 'Les troupes, puis les côtés']), needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }, `attack/${S}SmartAttackRedArea`], def: P === 'DB' ? '0' : '1' },
          { type: 'info', text: 'Déposer près de :' },
          {
            type: 'row',
            fields: [
              { id: `attack/${S}SmartAttackGoldMine`, type: 'toggle', label: "Mines d'or", needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }, `attack/${S}SmartAttackRedArea`], def: '0' },
              { id: `attack/${S}SmartAttackElixirCollector`, type: 'toggle', label: "Extracteurs d'élixir", needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }, `attack/${S}SmartAttackRedArea`], def: '0' },
              { id: `attack/${S}SmartAttackDarkElixirDrill`, type: 'toggle', label: 'Foreuses', needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '0' }, `attack/${S}SmartAttackRedArea`], def: '0' },
            ],
          },
        ],
      },
      {
        title: 'Attaque scriptée (CSV)',
        icon: 'i-file',
        fields: [
          { id: `attack/Script${S}`, type: 'select', label: 'Script', source: 'scripts', hint: 'Fichiers du dossier CSV\\Attack', needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '1' }], def: 'Barch four fingers' },
          { id: `attack/RedlineRoutine${S}`, type: 'select', label: 'Ligne rouge', options: opts(['ImgLoc brute (par défaut)', 'ImgLoc points de dépôt', 'Ligne rouge originale', 'Bords extérieurs']), needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '1' }], def: '0' },
          { id: `attack/DroplineEdge${S}`, type: 'select', label: 'Ligne de dépôt', options: opts(['Coin extérieur fixe', 'Premier point de la ligne rouge', 'Ligne complète, coin extérieur fixe', 'Ligne complète, premier point', 'Pas de ligne de dépôt']), needs: [...on, { id: `attack/${P}AtkAlgorithm`, eq: '1' }], def: '0' },
        ],
      },
      ...(P === 'DB'
        ? [
            {
              title: 'Attaque SmartFarm',
              icon: 'i-coins',
              fields: [
                { id: 'SmartFarm/InsidePercentage', type: 'number', label: 'Ressources à l’intérieur', suffix: '%', max: 100, hint: "Au-delà : attaque d'un seul côté", needs: [...on, { id: 'attack/DBAtkAlgorithm', eq: '2' }], def: '65' },
                { id: 'SmartFarm/OutsidePercentage', type: 'number', label: 'Ressources à l’extérieur', suffix: '%', max: 100, hint: 'Au-delà : attaque des 4 côtés', needs: [...on, { id: 'attack/DBAtkAlgorithm', eq: '2' }], def: '80' },
                { id: 'SmartFarm/DebugSmartFarm', type: 'toggle', label: 'Debug SmartFarm', needs: on, def: 'False' },
              ],
            },
          ]
        : []),
    ];
  }

  // ------------------------------------------------------------------ fin de combat (base morte / active)
  function endBattleCards(P, enable) {
    const on = [enable];
    const cards = [
      {
        title: 'Quitter le combat',
        icon: 'i-flag',
        fields: [
          {
            type: 'row',
            fields: [
              { id: `endbattle/chk${P}TimeStopAtk`, type: 'toggle', label: 'Plus de nouveau butin depuis', needs: on, def: '1' },
              { id: `endbattle/txt${P}TimeStopAtk`, type: 'number', label: 'Secondes', max: 999, needs: [...on, `endbattle/chk${P}TimeStopAtk`], def: P === 'DB' ? '15' : '20' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `endbattle/chk${P}TimeStopAtk2`, type: 'toggle', label: 'Plus de nouveau butin depuis', needs: on, def: '0' },
              { id: `endbattle/txt${P}TimeStopAtk2`, type: 'number', label: 'Secondes', max: 999, needs: [...on, `endbattle/chk${P}TimeStopAtk2`], def: '7' },
            ],
          },
          {
            type: 'row',
            label: 'et ressources restantes sous',
            fields: [
              { id: `endbattle/txt${P}MinGoldStopAtk2`, type: 'number', label: 'Or', step: 500, needs: [...on, `endbattle/chk${P}TimeStopAtk2`], def: '1000' },
              { id: `endbattle/txt${P}MinElixirStopAtk2`, type: 'number', label: 'Élixir', step: 500, needs: [...on, `endbattle/chk${P}TimeStopAtk2`], def: '1000' },
              { id: `endbattle/txt${P}MinDarkElixirStopAtk2`, type: 'number', label: 'Élixir noir', step: 10, needs: [...on, `endbattle/chk${P}TimeStopAtk2`], def: '50' },
            ],
          },
          { id: `endbattle/chk${P}EndNoResources`, type: 'toggle', label: 'Plus aucune ressource à prendre', needs: on, def: '0' },
          { id: `endbattle/chk${P}EndOneStar`, type: 'toggle', label: 'Une étoile gagnée', needs: on, def: '0' },
          { id: `endbattle/chk${P}EndTwoStars`, type: 'toggle', label: 'Deux étoiles gagnées', needs: on, def: '0' },
          {
            type: 'row',
            fields: [
              { id: `endbattle/chk${P}PercentageHigher`, type: 'toggle', label: 'Destruction au-dessus de', needs: on, def: '0' },
              { id: `endbattle/txt${P}PercentageHigher`, type: 'number', label: '%', max: 100, needs: [...on, `endbattle/chk${P}PercentageHigher`], def: '50' },
            ],
          },
          {
            type: 'row',
            fields: [
              { id: `endbattle/chk${P}PercentageChange`, type: 'toggle', label: 'Destruction figée depuis', needs: on, def: '0' },
              { id: `endbattle/txt${P}PercentageChange`, type: 'number', label: 'Secondes', max: 999, needs: [...on, `endbattle/chk${P}PercentageChange`], def: '15' },
            ],
          },
        ],
      },
    ];
    if (P === 'AB') {
      cards.push({
        title: "Attaque côté élixir noir",
        icon: 'i-drop',
        note: "Actif quand « Attaquer sur » vaut « Côté de l'élixir noir » dans l'onglet Attaque.",
        fields: [
          {
            type: 'row',
            fields: [
              { id: 'endbattle/chkDESideEB', type: 'toggle', label: "Quand l'élixir noir restant est sous", needs: on, def: '0' },
              { id: 'endbattle/txtDELowEndMin', type: 'number', label: '%', max: 100, needs: [...on, 'endbattle/chkDESideEB'], def: '25' },
            ],
          },
          { id: 'endbattle/chkDisableOtherEBO', type: 'toggle', label: 'Ignorer les autres conditions de fin', needs: [...on, 'endbattle/chkDESideEB'], def: '0' },
          { id: 'endbattle/chkDEEndBk', type: 'toggle', label: 'Et le roi des barbares est faible', needs: [...on, 'endbattle/chkDESideEB'], def: '0' },
          { id: 'endbattle/chkDEEndAq', type: 'toggle', label: 'Et la reine des archères est faible', needs: [...on, 'endbattle/chkDESideEB'], def: '0' },
          { id: 'endbattle/chkDEEndOneStar', type: 'toggle', label: 'Et une étoile est gagnée', needs: [...on, 'endbattle/chkDESideEB'], def: '0' },
        ],
      });
    }
    return cards;
  }

  const collectors = [
    {
      title: 'Collecteurs',
      icon: 'i-coins',
      fields: [
        { id: 'search/chkDisableCollectorsFilter', type: 'toggle', label: 'Désactiver le filtre des collecteurs', hint: 'La base morte devient une autre recherche de base active', def: '0' },
        { id: 'search/chkSupercharge', type: 'toggle', label: 'Chercher aussi les collecteurs surchargés', def: '0' },
        { id: 'collectors/minmatches', type: 'select', label: 'Collecteurs requis', options: range(1, 7), def: '3' },
        { id: 'collectors/tolerance', type: 'range', label: 'Tolérance de toutes les images', min: -15, max: 15, step: 1, def: '0' },
      ],
    },
  ];

  const bully = [
    {
      title: 'Bully (hôtels de ville faibles)',
      icon: 'i-target',
      fields: [
        { id: 'search/BullyMode', type: 'toggle', label: 'Activer le mode Bully', hint: "Toutes les bases dont l'hôtel de ville est au plus au niveau choisi sont attaquées", def: '0' },
        { id: 'search/ATBullyMode', type: 'number', label: 'Après', suffix: 'recherches', max: 9999, needs: ['search/BullyMode'], def: '0' },
        { id: 'search/YourTH', type: 'select', label: 'Hôtel de ville max.', options: TH_LEVELS, needs: ['search/BullyMode'], def: '0' },
        { id: 'search/THBullyAttackMode', type: 'radio', label: 'Attaquer avec les réglages', options: opts(['Base morte', 'Base active']), needs: ['search/BullyMode'], def: '0' },
      ],
    },
  ];

  // ------------------------------------------------------------------ options
  const optSearch = [
    {
      title: 'Baisse des exigences',
      icon: 'i-down',
      fields: [
        { id: 'search/reduction', type: 'toggle', label: 'Baisser les minimums au fil des recherches', def: '0' },
        { id: 'search/reduceCount', type: 'number', label: 'Toutes les', suffix: 'recherches', max: 999, needs: ['search/reduction'], def: '20' },
        {
          type: 'row',
          label: 'Baisser à chaque fois de',
          fields: [
            { id: 'search/reduceGold', type: 'number', label: 'Or', step: 1000, needs: ['search/reduction'], def: '2000' },
            { id: 'search/reduceElixir', type: 'number', label: 'Élixir', step: 1000, needs: ['search/reduction'], def: '2000' },
            { id: 'search/reduceGoldPlusElixir', type: 'number', label: 'Or + élixir', step: 1000, needs: ['search/reduction'], def: '4000' },
            { id: 'search/reduceDark', type: 'number', label: 'Élixir noir', step: 10, needs: ['search/reduction'], def: '100' },
            { id: 'search/reduceTrophy', type: 'number', label: 'Ligue', max: 9, needs: ['search/reduction'], def: '2' },
          ],
        },
      ],
    },
    {
      title: 'Délai entre les villages',
      icon: 'i-clock',
      fields: [
        { id: 'other/VSDelay', type: 'range', label: 'Minimum', min: 0, max: 12, suffix: 's', def: '0' },
        { id: 'other/MaxVSDelay', type: 'range', label: 'Maximum (au hasard entre les deux)', min: 0, max: 15, suffix: 's', def: '4' },
      ],
    },
    {
      title: 'Recherche',
      icon: 'i-search',
      fields: [
        { id: 'general/attacknow', type: 'toggle', label: 'Bouton « Attaquer maintenant »', hint: 'À côté de « Suivant » pendant la recherche', def: '0' },
        { id: 'general/attacknowdelay', type: 'select', label: 'Temps de réaction ajouté', options: range(0, 5, (n) => `${n} s`), needs: ['general/attacknow'], def: '3' },
        {
          type: 'row',
          fields: [
            { id: 'search/ChkRestartSearchLimit', type: 'toggle', label: 'Revenir au village toutes les', def: '1' },
            { id: 'search/RestartSearchLimit', type: 'number', label: 'Recherches', max: 999, needs: ['search/ChkRestartSearchLimit'], def: '50' },
          ],
        },
        { id: 'search/RestartSearchPickupHero', type: 'toggle', label: 'Avant de chercher, relire le temps de soin des héros utilisés', hint: 'Option cachée du bot', def: '0' },
        { id: 'general/AlertSearch', type: 'toggle', label: 'M’alerter quand un village est trouvé', hint: 'Son et bulle Windows', def: '0' },
      ],
    },
  ];

  const ABILITY = opts(['Auto (zone rouge)', 'Minuté', 'Les deux']);
  const optAttack = [
    {
      title: 'Capacités des héros',
      icon: 'i-bolt',
      fields: HEROES.map(([short, name]) => ({
        type: 'row',
        label: name,
        fields: [
          { id: `attack/Activate${short}`, type: 'select', label: 'Capacité', options: ABILITY, def: '0' },
          { id: `attack/delayActivate${short}`, type: 'number', label: 'Après', suffix: 's', scale: 1000, max: 99, needs: [{ id: `attack/Activate${short}`, ne: '0' }], def: short === 'Warden' || short === 'Champion' ? '10000' : '9000' },
        ],
      })),
    },
    {
      title: "Planning d'attaque",
      icon: 'i-clock2',
      fields: [
        { id: 'planned/chkAttackPlannerEnable', type: 'toggle', label: 'Attaquer seulement selon ce planning', def: '0' },
        { id: 'planned/attackDays', type: 'days', label: 'Jours', needs: ['planned/chkAttackPlannerEnable'] },
        { id: 'planned/attackHours', type: 'hours', label: 'Heures', needs: ['planned/chkAttackPlannerEnable'] },
        { type: 'info', text: 'Hors planning, le bot continue de tourner et reprend quand le planning le permet. En plus :' },
        { id: 'planned/chkAttackPlannerCloseCoC', type: 'toggle', label: 'Fermer Clash of Clans', needs: ['planned/chkAttackPlannerEnable'], def: '0' },
        { id: 'planned/chkAttackPlannerCloseAll', type: 'toggle', label: "Fermer l'émulateur", needs: ['planned/chkAttackPlannerEnable'], def: '0' },
        { id: 'planned/chkAttackPlannerSuspendComputer', type: 'toggle', label: "Mettre l'ordinateur en veille", needs: ['planned/chkAttackPlannerEnable'], def: '0' },
        {
          type: 'row',
          fields: [
            { id: 'planned/chkAttackPlannerRandom', type: 'toggle', label: 'Pauses au hasard', needs: ['planned/chkAttackPlannerEnable'], def: '0' },
            { id: 'planned/cmbAttackPlannerRandom', type: 'select', label: 'Heures', options: range(1, 20, (h) => `${h} h`), needs: ['planned/chkAttackPlannerEnable', 'planned/chkAttackPlannerRandom'], def: '4' },
          ],
        },
        {
          type: 'row',
          fields: [
            { id: 'planned/chkAttackPlannerDayLimit', type: 'toggle', label: 'Limite par jour', hint: 'Nombre au hasard dans la plage', needs: ['planned/chkAttackPlannerEnable'], def: '0' },
            { id: 'planned/cmbAttackPlannerDayMin', type: 'number', label: 'De', max: 999, needs: ['planned/chkAttackPlannerEnable', 'planned/chkAttackPlannerDayLimit'], def: '12' },
            { id: 'planned/cmbAttackPlannerDayMax', type: 'number', label: 'À', max: 999, needs: ['planned/chkAttackPlannerEnable', 'planned/chkAttackPlannerDayLimit'], def: '15' },
          ],
        },
      ],
    },
    {
      title: 'Château de clan',
      icon: 'i-castle',
      fields: [
        { id: 'planned/DropCCEnable', type: 'toggle', label: 'Déployer le château seulement à ces heures', hint: 'Sans planning, il est toujours déployé', def: '0' },
        { id: 'planned/DropCCHours', type: 'hours', needs: ['planned/DropCCEnable'] },
      ],
    },
  ];

  const smartZap = [
    {
      title: 'SmartZap / NoobZap',
      icon: 'i-bolt',
      fields: [
        { type: 'info', text: "Foudroyer les foreuses d'élixir noir." },
        { id: 'SmartZap/UseSmartZap', type: 'toggle', label: 'Avec les sorts de foudre', def: '0' },
        { id: 'SmartZap/UseEarthQuakeZap', type: 'toggle', label: 'Avec le séisme du château de clan', def: '0' },
        { id: 'SmartZap/UseNoobZap', type: 'toggle', label: 'NoobZap', hint: 'Foudroie toutes les foreuses', def: '0' },
        { id: 'SmartZap/ZapDBOnly', type: 'toggle', label: 'Seulement sur les bases mortes', hint: 'Recommandé', def: '1' },
        { id: 'SmartZap/THSnipeSaveHeroes', type: 'toggle', label: "Pas de zap si les héros ont été déployés (snipe d'HDV)", def: '1' },
        { id: 'SmartZap/FTW', type: 'toggle', label: 'Viser la victoire', hint: 'Tente d’atteindre 50 % de destruction', def: '0' },
        { id: 'SmartZap/MinDE', type: 'number', label: 'Élixir noir minimum dans les foreuses', step: 50, def: '350' },
        { id: 'SmartZap/ExpectedDE', type: 'number', label: 'Gain attendu par foreuse (NoobZap)', step: 10, needs: ['SmartZap/UseNoobZap'], def: '320' },
      ],
    },
  ];

  const optEndBattle = [
    {
      title: 'Partager le replay',
      icon: 'i-send',
      fields: [
        { id: 'shareattack/ShareAttack', type: 'toggle', label: 'Partager les replays dans le chat du clan', def: '0' },
        {
          type: 'row',
          label: 'Si le butin dépasse',
          fields: [
            { id: 'shareattack/minGold', type: 'number', label: 'Or', step: 10000, needs: ['shareattack/ShareAttack'], def: '200000' },
            { id: 'shareattack/minElixir', type: 'number', label: 'Élixir', step: 10000, needs: ['shareattack/ShareAttack'], def: '200000' },
            { id: 'shareattack/minDark', type: 'number', label: 'Élixir noir', step: 100, needs: ['shareattack/ShareAttack'], def: '100' },
          ],
        },
        { id: 'shareattack/Message', type: 'textarea', label: 'Un message au hasard (un par ligne)', rows: 4, needs: ['shareattack/ShareAttack'], def: 'Nice|Good|Thanks|Wowwww' },
      ],
    },
    {
      title: 'Capture du butin',
      icon: 'i-file',
      fields: [
        { id: 'attack/TakeLootSnapShot', type: 'toggle', label: 'Enregistrer une capture du village attaqué', def: '0' },
        { id: 'attack/ScreenshotLootInfo', type: 'toggle', label: 'Butin dans le nom du fichier', needs: ['attack/TakeLootSnapShot'], def: '0' },
      ],
    },
  ];

  const HERO_ORDERS = [
    'Reine > Roi > Prince > Gardien > Championne',
    'Reine > Gardien > Prince > Roi > Championne',
    'Roi > Prince > Reine > Gardien > Championne',
    'Prince > Roi > Gardien > Reine > Championne',
    'Gardien > Roi > Reine > Prince > Championne',
    'Gardien > Prince > Reine > Roi > Championne',
    'Championne > Gardien > Reine > Roi > Prince',
    'Championne > Reine > Gardien > Prince > Roi',
  ];
  const league = [
    {
      title: 'Palier de ligue',
      icon: 'i-trophy',
      fields: [
        { type: 'info', text: "Depuis CoC 18.600, plus de trophées : la ligue est un palier de 1 (Squelette 1) à 36 (Légende I), lu sur le badge de l'écran principal." },
        { id: 'search/MaxTrophy', type: 'number', label: 'Palier de ligue max.', hint: 'Les conditions « ligue max » de Village › Divers arrêtent les attaques au-dessus (36 = jamais)', min: 1, max: 36, def: '36' },
        { id: 'search/TrophyRange', type: 'toggle', label: 'Perdre des trophées', hint: "Jusqu'à redescendre sous le minimum", def: '0' },
        { id: 'search/MinTrophy', type: 'number', label: 'Palier minimum', min: 1, max: 36, needs: ['search/TrophyRange'], def: '1' },
        { id: 'search/chkTrophyHeroes', type: 'toggle', label: 'Utiliser les héros pour perdre des trophées', needs: ['search/TrophyRange'], def: '0' },
        { id: 'search/cmbTrophyHeroesPriority', type: 'select', label: 'Ordre des héros', options: opts(HERO_ORDERS), needs: ['search/TrophyRange', 'search/chkTrophyHeroes'], def: '0' },
        { id: 'search/chkTrophyAtkDead', type: 'toggle', label: 'Attaquer une base morte trouvée pendant la descente', needs: ['search/TrophyRange'], def: '0' },
        { id: 'search/DTArmyMin', type: 'number', label: 'Armée prête au moins à', suffix: '%', max: 100, needs: ['search/TrophyRange', 'search/chkTrophyAtkDead'], def: '70' },
      ],
    },
  ];

  // ------------------------------------------------------------------ ordre de deploiement personnalise (48 positions)
  const DROP_ORDER_UNITS = [...TROOPS.map((t) => t[1]), 'Château de clan', 'Héros'];
  const dropOrderOpts = [['-1', '—'], ['0', '(vide)'], ...DROP_ORDER_UNITS.map((n, i) => [String(i + 1), n])];
  const dropOrder = [
    {
      title: 'Ordre de déploiement personnalisé',
      icon: 'i-list',
      wide: true,
      cols: 4,
      note: "Pour l'attaque standard seulement (bases mortes et actives), pas pour les scripts CSV.",
      fields: [
        { id: 'DropOrder/chkDropOrder', type: 'toggle', label: 'Utiliser cet ordre', wide: true, def: '0' },
        ...DROP_ORDER_UNITS.map((_, p) => ({ id: `DropOrder/cmbDropOrder${p}`, type: 'select', label: `${p + 1}.`, options: dropOrderOpts, compact: true, needs: ['DropOrder/chkDropOrder'], def: '-1' })),
      ],
    },
  ];

  window.PAGES.attack = {
    title: 'Attaque',
    sub: 'Recherche des villages, façon d’attaquer, fin de combat. Les types cochés (base morte, active, bully) sont utilisés.',
    tabs: [
      {
        id: 'db',
        label: 'Base morte',
        icon: 'i-skull',
        tabs: [
          { id: 'search', label: 'Recherche', intro: 'Base morte : collecteurs pleins, butin facile.', cards: [{ title: 'Base morte', icon: 'i-skull', fields: [{ id: 'search/DBcheck', type: 'toggle', label: 'Attaquer les bases mortes', def: '1' }] }, ...searchCards('DB', 'search/DBcheck')] },
          { id: 'attack', label: 'Attaque', cards: attackCards('DB', 'search/DBcheck') },
          { id: 'end', label: 'Fin de combat', cards: endBattleCards('DB', 'search/DBcheck') },
          { id: 'collectors', label: 'Collecteurs', cards: collectors },
        ],
      },
      {
        id: 'ab',
        label: 'Base active',
        icon: 'i-flame',
        tabs: [
          { id: 'search', label: 'Recherche', cards: [{ title: 'Base active', icon: 'i-flame', fields: [{ id: 'search/ABcheck', type: 'toggle', label: 'Attaquer les bases actives', def: '0' }] }, ...searchCards('AB', 'search/ABcheck')] },
          { id: 'attack', label: 'Attaque', cards: attackCards('AB', 'search/ABcheck') },
          { id: 'end', label: 'Fin de combat', cards: endBattleCards('AB', 'search/ABcheck') },
        ],
      },
      { id: 'bully', label: 'Bully', icon: 'i-target', cards: bully },
      {
        id: 'options',
        label: 'Options',
        icon: 'i-sliders',
        tabs: [
          { id: 'search', label: 'Recherche', cards: optSearch },
          { id: 'attack', label: 'Attaque', cards: optAttack },
          { id: 'smartzap', label: 'SmartZap', cards: smartZap },
          { id: 'end', label: 'Fin de combat', cards: optEndBattle },
          { id: 'league', label: 'Ligue', cards: league },
        ],
      },
      { id: 'droporder', label: 'Ordre de déploiement', icon: 'i-list', cards: dropOrder },
    ],
  };
})();
