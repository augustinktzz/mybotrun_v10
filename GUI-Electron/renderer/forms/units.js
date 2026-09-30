'use strict';
// Les unites du jeu, dans l'ordre des enums du bot (MBR Global Variables.au3) : le rang sert de valeur dans config.ini
// (ordres d'entrainement, de deploiement, types des armees rapides...). Noms francais quand ils sont surs, anglais sinon.
(function () {
  // [nom court (cle troop/...), nom, pluriel sans espace (cles donate/chkDonate...), places]
  const TROOPS = [
    ['Barb', 'Barbare', 'Barbarians', 1],
    ['SBarb', 'Super barbare', 'SuperBarbarians', 5],
    ['Arch', 'Archère', 'Archers', 1],
    ['SArch', 'Super archère', 'SuperArchers', 12],
    ['Giant', 'Géant', 'Giants', 5],
    ['SGiant', 'Super géant', 'SuperGiants', 10],
    ['Gobl', 'Gobelin', 'Goblins', 1],
    ['SGobl', 'Gobelin furtif', 'SneakyGoblins', 3],
    ['Wall', 'Sapeur', 'WallBreakers', 2],
    ['SWall', 'Super sapeur', 'SuperWallBreakers', 8],
    ['Ball', 'Ballon', 'Balloons', 5],
    ['RBall', 'Ballon-fusée', 'RocketBalloons', 8],
    ['Wiza', 'Sorcier', 'Wizards', 4],
    ['SWiza', 'Super sorcier', 'SuperWizards', 10],
    ['Heal', 'Guérisseuse', 'Healers', 14],
    ['Drag', 'Dragon', 'Dragons', 20],
    ['SDrag', 'Super dragon', 'SuperDragons', 40],
    ['Pekk', 'P.E.K.K.A', 'Pekkas', 25],
    ['BabyD', 'Bébé dragon', 'BabyDragons', 10],
    ['InfernoD', "Dragon de l'enfer", 'InfernoDragons', 15],
    ['Mine', 'Mineur', 'Miners', 6],
    ['SMine', 'Super mineur', 'SuperMiners', 24],
    ['EDrag', 'Électro-dragon', 'ElectroDragons', 30],
    ['Yeti', 'Yéti', 'Yetis', 18],
    ['RDrag', 'Dragon Rider', 'DragonRiders', 25],
    ['ETitan', 'Electro Titan', 'ElectroTitans', 32],
    ['RootR', 'Root Rider', 'RootRiders', 20],
    ['Throw', 'Thrower', 'Throwers', 16],
    ['Mini', 'Gargouille', 'Minions', 2],
    ['SMini', 'Super gargouille', 'SuperMinions', 12],
    ['Hogs', 'Chevaucheur de cochon', 'HogRiders', 5],
    ['SHogs', 'Super chevaucheur de cochon', 'SuperHogRiders', 12],
    ['Valk', 'Valkyrie', 'Valkyries', 8],
    ['SValk', 'Super valkyrie', 'SuperValkyries', 20],
    ['Gole', 'Golem', 'Golems', 30],
    ['Witc', 'Sorcière', 'Witches', 12],
    ['SWitc', 'Super sorcière', 'SuperWitchs', 40],
    ['Lava', 'Molosse de lave', 'LavaHounds', 30],
    ['IceH', 'Molosse de glace', 'IceHounds', 40],
    ['Bowl', 'Bouliste', 'Bowlers', 6],
    ['SBowl', 'Super bouliste', 'SuperBowlers', 30],
    ['IceG', 'Golem de glace', 'IceGolems', 15],
    ['Hunt', 'Chasseuse de têtes', 'Headhunters', 6],
    ['AppWard', 'Apprenti gardien', 'ApprenticeWardens', 20],
    ['Druid', 'Druide', 'Druids', 16],
    ['Furn', 'Furnace', 'Furnaces', 18],
  ];
  // ordre de l'onglet d'entrainement du bot ($g_asTroopShortNamesTrain) : elixir, elixir noir, super troupes
  const TRAIN_ORDER = {
    elixir: ['Barb', 'Arch', 'Giant', 'Gobl', 'Wall', 'Ball', 'Wiza', 'Heal', 'Drag', 'Pekk', 'BabyD', 'Mine', 'EDrag', 'Yeti', 'RDrag', 'ETitan', 'RootR', 'Throw'],
    dark: ['Mini', 'Hogs', 'Valk', 'Gole', 'Witc', 'Lava', 'Bowl', 'IceG', 'Hunt', 'AppWard', 'Druid', 'Furn'],
    super: ['SBarb', 'SArch', 'SGiant', 'SGobl', 'SWall', 'RBall', 'SWiza', 'SDrag', 'InfernoD', 'SMine', 'SMini', 'SHogs', 'SValk', 'SWitc', 'IceH', 'SBowl'],
  };
  // [nom court (cle Spells/...), nom anglais (cles donate/...Spells, attack/...Spell), nom, places]
  const SPELLS = [
    ['LSpell', 'Lightning', 'Foudre', 1],
    ['HSpell', 'Heal', 'Soin', 2],
    ['RSpell', 'Rage', 'Rage', 2],
    ['JSpell', 'Jump', 'Saut', 2],
    ['FSpell', 'Freeze', 'Gel', 1],
    ['CSpell', 'Clone', 'Clonage', 3],
    ['ISpell', 'Invisibility', 'Invisibilité', 1],
    ['ReSpell', 'Recall', 'Rappel', 2],
    ['RvSpell', 'Revive', 'Revive', 2],
    ['PSpell', 'Poison', 'Poison', 1],
    ['ESpell', 'Earthquake', 'Séisme', 1],
    ['HaSpell', 'Haste', 'Hâte', 1],
    ['SkSpell', 'Skeleton', 'Squelettes', 1],
    ['BtSpell', 'Bat', 'Chauves-souris', 1],
    ['OgSpell', 'Overgrowth', 'Overgrowth', 2],
  ];
  // [nom court (cle Siege/...), nom]
  const SIEGES = [
    ['WallW', 'Démolisseur'],
    ['BattleB', 'Zeppelin de combat'],
    ['StoneS', 'Stone Slammer'],
    ['SiegeB', 'Caserne de siège'],
    ['LogL', 'Lance-bûches'],
    ['FlameF', 'Flame Flinger'],
    ['BattleD', 'Foreuse de combat'],
    ['TroopL', 'Lance-troupes'],
  ];
  // [nom court (cles upgrade/UpgradeKing, attack/DBKingAtk...), nom, bit de $g_aiAttackUseHeroes]
  const HEROES = [
    ['King', 'Roi des barbares', 1],
    ['Queen', 'Reine des archères', 2],
    ['Prince', 'Prince des gargouilles', 4],
    ['Warden', 'Grand gardien', 8],
    ['Champion', 'Championne royale', 16],
    ['Duke', 'Dragon Duke', 32],
  ];
  const PETS = [
    ['Lassi', 'L.A.S.S.I'],
    ['Owl', 'Electro Owl'],
    ['Yak', 'Mighty Yak'],
    ['Unicorn', 'Licorne'],
    ['Frosty', 'Frosty'],
    ['Diggy', 'Diggy'],
    ['Lizard', 'Poison Lizard'],
    ['Phoenix', 'Phénix'],
    ['Fox', 'Spirit Fox'],
    ['Jelly', 'Angry Jelly'],
    ['Sneezy', 'Sneezy'],
  ];
  // equipements de la forge ($g_asEquipmentOrderList) : [nom, heros]
  const EQUIPMENT = [
    ['Barbarian Puppet', 'King'], ['Rage Vial', 'King'], ['Earthquake Boots', 'King'], ['Vampstache', 'King'], ['Giant Gauntlet', 'King'],
    ['Spiky Ball', 'King'], ['Snake Bracelet', 'King'], ['Archer Puppet', 'Queen'], ['Invisibility Vial', 'Queen'], ['Giant Arrow', 'Queen'],
    ['Healer Puppet', 'Queen'], ['Frozen Arrow', 'Queen'], ['Magic Mirror', 'Queen'], ['Action Figure', 'Queen'], ['Henchmen Puppet', 'Prince'],
    ['Dark Orb', 'Prince'], ['Metal Pants', 'Prince'], ['Noble Iron', 'Prince'], ['Eternal Tome', 'Warden'], ['Life Gem', 'Warden'],
    ['Rage Gem', 'Warden'], ['Healing Tome', 'Warden'], ['Fireball', 'Warden'], ['Lavaloon Puppet', 'Warden'], ['Royal Gem', 'Champion'],
    ['Seeking Shield', 'Champion'], ['Hog Rider Puppet', 'Champion'], ['Haste Vial', 'Champion'], ['Rocket Spear', 'Champion'], ['Electro Boots', 'Champion'],
  ];
  // super troupes boostables ($g_asSuperTroopShortNames) ; SuperTroopsIndex = 0 aucune, puis rang + 1
  const SUPER_TROOPS = ['SBarb', 'SArch', 'SGobl', 'SWall', 'SGiant', 'RBall', 'SWiza', 'SDrag', 'InfernoD', 'SMini', 'SValk', 'SWitc', 'IceH', 'SBowl', 'SMine', 'SHogs'];

  const troopByShort = Object.fromEntries(TROOPS.map((t, i) => [t[0], { i, short: t[0], name: t[1], plural: t[2], space: t[3] }]));
  const heroName = Object.fromEntries(HEROES.map(([s, n]) => [s, n]));

  // ------------------------------------------------------------------ petits utilitaires pour les pages
  // options d'une liste : valeur = rang (+ start)
  const opts = (labels, start = 0) => labels.map((l, i) => [String(i + start), l]);
  const range = (a, b, fmt = (n) => String(n)) => Array.from({ length: b - a + 1 }, (_, k) => [String(a + k), fmt(a + k)]);
  const HOURS_24 = range(0, 23, (h) => `${String(h).padStart(2, '0')}:00`);

  window.U = {
    TROOPS,
    TRAIN_ORDER,
    SPELLS,
    SIEGES,
    HEROES,
    PETS,
    EQUIPMENT,
    SUPER_TROOPS,
    troopByShort,
    heroName,
    troopNames: TROOPS.map((t) => t[1]),
    spellNames: SPELLS.map((s) => s[2]),
    siegeNames: SIEGES.map((s) => s[1]),
    opts,
    range,
    HOURS_24,
  };
  window.PAGES = {};
})();
