'use strict';
// Armee : onglet "Train Army" du bot (Army, Timings/Boost, Train Order, Options).
// Cles : SaveConfig_600_52_1 / _52_2 (troupes, sorts, engins, armees rapides), _54 (ordre), _22 (boost), _641_1 (options).
(function () {
  const { opts, range, TROOPS, SPELLS, SIEGES, TRAIN_ORDER, SUPER_TROOPS, troopByShort } = window.U;

  const unitField = (id, label, def = '0') => ({ id, type: 'number', label, max: 999, compact: true, def });
  const TROOP_DEFAULTS = { Barb: '58', Arch: '115', Giant: '4', Gobl: '19', Wall: '4' }; // valeurs du GUI d'origine

  const composition = [
    {
      title: "Mode d'entraînement",
      icon: 'i-shield',
      wide: true,
      fields: [
        { id: 'other/ChkUseQTrain', type: 'radio', label: 'Entraîner', options: [['0', 'Armée personnalisée (ci-dessous)'], ['1', 'Entraînement rapide (onglet suivant)']], def: '0' },
        {
          type: 'row',
          fields: [
            { id: 'other/ChkTotalCampForced', type: 'toggle', label: 'Forcer la taille des camps', def: '1' },
            { id: 'other/ValueTotalCampForced', type: 'number', label: 'Places', max: 999, needs: ['other/ChkTotalCampForced'], def: '220' },
            { id: 'troop/fulltroop', type: 'number', label: 'Camp « plein » à partir de', suffix: '%', max: 100, def: '100' },
            { id: 'Spells/SpellFactory', type: 'select', label: 'Capacité de sorts', options: ['0', '2', '4', '6', '7', '8', '9', '10', '11'].map((v) => [v, v]), def: '0' },
          ],
        },
      ],
    },
    {
      title: 'Troupes élixir',
      icon: 'i-drop',
      wide: true,
      cols: 6,
      fields: TRAIN_ORDER.elixir.map((s) => unitField(`troop/${s}`, troopByShort[s].name, TROOP_DEFAULTS[s])),
    },
    {
      title: 'Troupes noires',
      icon: 'i-drop',
      wide: true,
      cols: 6,
      fields: TRAIN_ORDER.dark.map((s) => unitField(`troop/${s}`, troopByShort[s].name)),
    },
    {
      title: 'Super troupes',
      icon: 'i-bolt',
      wide: true,
      cols: 6,
      fields: TRAIN_ORDER.super.map((s) => unitField(`troop/${s}`, troopByShort[s].name)),
    },
    {
      title: 'Sorts',
      icon: 'i-flask',
      wide: true,
      cols: 6,
      fields: SPELLS.map(([short, , name]) => unitField(`Spells/${short}`, name)),
    },
    {
      title: 'Engins de siège',
      icon: 'i-castle',
      wide: true,
      cols: 6,
      fields: SIEGES.map(([short, name]) => unitField(`Siege/${short}`, name)),
    },
  ];

  // ------------------------------------------------------------------ entrainement rapide : 3 armees, 7 emplacements
  const troopOpts = [['-1', '—'], ...TROOPS.map((t, i) => [String(i), t[1]])];
  const spellOpts = [['-1', '—'], ...SPELLS.map((s, i) => [String(i), s[2]])];
  const quickArmy = (a) => ({
    title: `Armée ${a}`,
    icon: 'i-bolt',
    cols: 2,
    fields: [
      { id: `troop/QuickTrainArmy${a}`, type: 'toggle', label: 'Utiliser cette armée', wide: true, def: '0' },
      { id: `troop/UseInGameArmy_${a}`, type: 'toggle', label: "L'armée enregistrée dans le jeu", hint: "Sinon, la composition ci-dessous", wide: true, needs: [`troop/QuickTrainArmy${a}`], def: '0' },
      ...Array.from({ length: 7 }, (_, j) => ({
        type: 'row',
        label: `Troupe ${j + 1}`,
        fields: [
          { id: `QuickTroop/QuickTroopType_${a}_Slot_${j}`, type: 'select', options: troopOpts, needs: [`troop/QuickTrainArmy${a}`], def: '-1' },
          { id: `QuickTroop/QuickTroopQty_${a}_Slot_${j}`, type: 'number', label: '', max: 999, needs: [`troop/QuickTrainArmy${a}`, { id: `QuickTroop/QuickTroopType_${a}_Slot_${j}`, ne: '-1' }], def: '0' },
        ],
      })),
      ...Array.from({ length: 7 }, (_, j) => ({
        type: 'row',
        label: `Sort ${j + 1}`,
        fields: [
          { id: `QuickTroop/QuickSpellType_${a}_Slot_${j}`, type: 'select', options: spellOpts, needs: [`troop/QuickTrainArmy${a}`], def: '-1' },
          { id: `QuickTroop/QuickSpellQty_${a}_Slot_${j}`, type: 'number', label: '', max: 99, needs: [`troop/QuickTrainArmy${a}`, { id: `QuickTroop/QuickSpellType_${a}_Slot_${j}`, ne: '-1' }], def: '0' },
        ],
      })),
    ],
  });

  // ------------------------------------------------------------------ ordre d'entrainement (0 = vide, puis rang + 1)
  const troopOrderOpts = [['-1', '—'], ['0', '(vide)'], ...TROOPS.map((t, i) => [String(i + 1), t[1]])];
  const spellOrderOpts = [['-1', '—'], ['0', '(vide)'], ...SPELLS.map((s, i) => [String(i + 1), s[2]])];
  const order = [
    {
      title: 'Ordre des troupes',
      icon: 'i-list',
      wide: true,
      cols: 4,
      fields: [
        { id: 'troop/chkTroopOrder', type: 'toggle', label: 'Ordre personnalisé', hint: 'Laisser vide la fin de la liste', wide: true, def: '0' },
        ...TROOPS.map((_, z) => ({ id: `troop/cmbTroopOrder${z}`, type: 'select', label: `${z + 1}.`, options: troopOrderOpts, compact: true, needs: ['troop/chkTroopOrder'], def: '-1' })),
      ],
    },
    {
      title: 'Ordre des sorts',
      icon: 'i-list',
      wide: true,
      cols: 4,
      fields: [
        { id: 'Spells/chkSpellOrder', type: 'toggle', label: 'Ordre personnalisé', wide: true, def: '0' },
        ...SPELLS.map((_, z) => ({ id: `Spells/cmbSpellOrder${z}`, type: 'select', label: `${z + 1}.`, options: spellOrderOpts, compact: true, needs: ['Spells/chkSpellOrder'], def: '-1' })),
      ],
    },
  ];

  // ------------------------------------------------------------------ boost
  const boost = [
    {
      title: 'Boosts à gemmes',
      icon: 'i-gem',
      fields: [
        {
          type: 'info',
          warn: true,
          text: "Casernes, usines, atelier, héros et potions : le bot ne les enregistre jamais (pour ne pas dépenser de gemmes par surprise). Ils se règlent à chaque session dans le bot lui-même.",
        },
        { id: 'planned/BoostBarracksHours', type: 'hours', label: 'Heures où les boosts sont permis' },
      ],
    },
    {
      title: 'Super troupes',
      icon: 'i-bolt',
      fields: [
        { id: 'SuperTroopsBoost/SuperTroopsEnable', type: 'toggle', label: 'Booster des super troupes', def: '0' },
        ...[0, 1].map((i) => ({
          id: `SuperTroopsBoost/SuperTroopsIndex${i}`,
          type: 'select',
          label: `Super troupe ${i + 1}`,
          options: opts(['Aucune', ...SUPER_TROOPS.map((s) => troopByShort[s].name)]),
          needs: ['SuperTroopsBoost/SuperTroopsEnable'],
          def: '0',
        })),
        { id: 'SuperTroopsBoost/SkipSuperTroopsBoostOnHalt', type: 'toggle', label: 'Pas de boost en arrêt des attaques', needs: ['SuperTroopsBoost/SuperTroopsEnable'], def: '0' },
        { id: 'SuperTroopsBoost/SuperTroopsBoostUsePotionFirst', type: 'toggle', label: "Utiliser d'abord une potion de super", needs: ['SuperTroopsBoost/SuperTroopsEnable'], def: '0' },
      ],
    },
  ];

  // ------------------------------------------------------------------ options
  const closeTimes = range(2, 40);
  const options = [
    {
      title: 'Fermer pendant l’entraînement',
      icon: 'i-power',
      fields: [
        { id: 'other/chkCloseWaitEnable', type: 'toggle', label: 'Fermer le jeu en attendant l’armée', def: '1' },
        {
          type: 'row',
          label: 'Attaques consécutives avant fermeture',
          fields: [
            { id: 'other/AttackconsecutiveMin', type: 'number', label: 'De', max: 99, needs: ['other/chkCloseWaitEnable'], def: '1' },
            { id: 'other/AttackconsecutiveMax', type: 'number', label: 'À', max: 99, needs: ['other/chkCloseWaitEnable'], def: '2' },
          ],
        },
        {
          type: 'row',
          label: 'Durée de fermeture au hasard',
          fields: [
            { id: 'other/MinimumTimeToCloseMin', type: 'select', label: 'De (min)', options: closeTimes, needs: ['other/chkCloseWaitEnable'], def: '20' },
            { id: 'other/MinimumTimeToCloseMax', type: 'select', label: 'À (min)', options: closeTimes, needs: ['other/chkCloseWaitEnable'], def: '35' },
          ],
        },
        { id: 'other/chkCloseWaitTrain', type: 'toggle', label: 'Fermer même sans bouclier', hint: 'Option cachée du bot', needs: ['other/chkCloseWaitEnable'], def: '0' },
        { id: 'other/btnCloseWaitStop', type: 'toggle', label: "Fermer aussi l'émulateur", hint: 'Plus long à redémarrer', needs: ['other/chkCloseWaitEnable'], def: '0' },
        { id: 'other/btnCloseWaitSuspendComputer', type: 'toggle', label: "Mettre l'ordinateur en veille", needs: ['other/chkCloseWaitEnable'], def: '0' },
      ],
    },
    {
      title: 'Délais',
      icon: 'i-clock',
      fields: [
        { id: 'other/TrainITDelay', type: 'range', label: "Délai entre les clics d'entraînement", min: 1, max: 500, step: 1, suffix: 'ms', hint: 'Plus long si le PC est lent, ou pour un rythme plus humain', def: '100' },
        { id: 'other/chkAddIdleTime', type: 'toggle', label: "Délai aléatoire entre deux entraînements", hint: "Espace les ouvertures de la fenêtre d'entraînement", def: '0' },
        {
          type: 'row',
          hint: 'Cette version du bot enregistre ces deux durées mais ne les relit pas : il repart sur 5 à 60 s à chaque démarrage.',
          fields: [
            { id: 'other/txtAddDelayIdlePhaseTimeMin', type: 'number', label: 'Entre', suffix: 's', max: 999, needs: ['other/chkAddIdleTime'], def: '5' },
            { id: 'other/txtAddDelayIdlePhaseTimeMax', type: 'number', label: 'Et', suffix: 's', max: 999, needs: ['other/chkAddIdleTime'], def: '60' },
          ],
        },
      ],
    },
  ];

  // places des troupes et sorts, pour les totaux des armees rapides (affiches par le bot)
  const derive = (get) => {
    const out = {};
    for (const a of [1, 2, 3]) {
      let troops = 0;
      let spells = 0;
      for (let j = 0; j < 7; j++) {
        const t = Number(get(`QuickTroop/QuickTroopType_${a}_Slot_${j}`));
        if (t >= 0 && TROOPS[t]) troops += TROOPS[t][3] * Number(get(`QuickTroop/QuickTroopQty_${a}_Slot_${j}`) || 0);
        const s = Number(get(`QuickTroop/QuickSpellType_${a}_Slot_${j}`));
        if (s >= 0 && SPELLS[s]) spells += SPELLS[s][3] * Number(get(`QuickTroop/QuickSpellQty_${a}_Slot_${j}`) || 0);
      }
      out[`QuickTroop/TotalQuickTroop${a}`] = String(troops);
      out[`QuickTroop/TotalQuickSpell${a}`] = String(spells);
    }
    return out;
  };

  window.PAGES.army = {
    title: 'Armée',
    sub: "Composition de l'armée, entraînement rapide, ordre d'entraînement, boosts et options.",
    derive,
    tabs: [
      { id: 'composition', label: 'Composition', icon: 'i-shield', cards: composition },
      { id: 'quick', label: 'Entraînement rapide', icon: 'i-bolt', intro: "Jusqu'à 3 armées. Chaque emplacement = une unité et son nombre.", cards: [1, 2, 3].map(quickArmy) },
      { id: 'order', label: "Ordre d'entraînement", icon: 'i-list', cards: order },
      { id: 'boost', label: 'Boost', icon: 'i-gem', cards: boost },
      { id: 'options', label: 'Options', icon: 'i-sliders', cards: options },
    ],
  };
})();
