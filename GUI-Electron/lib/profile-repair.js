// Repairs a profile saved by MyBot 12.0.0 / 12.0.1 before its settings were read.
//
// Those versions wrote a new profile (and a profile without config.ini) from the declared values of the bot's globals
// instead of the defaults of readConfig.au3: no minimum loot, end of battle at 0 s / 0 %, no siege machine, no donate
// or request hour, the Pass, achievements and free magic items collected, wall level 0... The bot then read these
// values back as the user's choice. The table below is exact: it was produced by the bot's own code, saveConfig() with
// the declared globals against readConfig() on a profile that has no file.
//
// A setting is reset to its default only while it still holds the value of that bug: anything the user changed since
// is kept. Settings the user really wants at such a value can be kept with `keep` ("section/key").
const fs = require('node:fs');
const path = require('node:path');
const ini = require('./ini');

const FILES = { config: 'config.ini', clangames: 'clangames.ini' };

// [file, "section/key", value written by the bug, default]
const TABLE = [
  ['config', 'attack/ABAtkUseSiege', '0', '10'],
  ['config', 'attack/ABAtkUseWardenMode', '0', '2'],
  ['config', 'attack/ABChampionWait', '', '0'],
  ['config', 'attack/ABDeploy', '3', '0'],
  ['config', 'attack/ABKingWait', '', '0'],
  ['config', 'attack/ABPrinceWait', '', '0'],
  ['config', 'attack/ABQueenWait', '', '0'],
  ['config', 'attack/ABSmartAttackDeploy', '0', '1'],
  ['config', 'attack/ABWardenWait', '', '0'],
  ['config', 'attack/DBAtkUseSiege', '0', '10'],
  ['config', 'attack/DBAtkUseWardenMode', '0', '2'],
  ['config', 'attack/DBChampionWait', '', '0'],
  ['config', 'attack/DBKingWait', '', '0'],
  ['config', 'attack/DBPrinceWait', '', '0'],
  ['config', 'attack/DBQueenWait', '', '0'],
  ['config', 'attack/DBWardenWait', '', '0'],
  ['config', 'attack/delayActivateChampion', '9000', '10000'],
  ['config', 'deletefiles/DeleteTempDays', '2', '5'],
  ['config', 'donate/BalanceCCDonated', '0', '1'],
  ['config', 'donate/BalanceCCReceived', '0', '1'],
  ['config', 'donate/chkDonateQueueOnly[0]', '0', '1'],
  ['config', 'donate/chkDonateQueueOnly[1]', '0', '1'],
  ['config', 'donate/chkDonateQueueOnly[2]', '0', '1'],
  ['config', 'donate/cmbClanCastleSiege0', '', '0'],
  ['config', 'donate/cmbClanCastleSiege1', '', '0'],
  ['config', 'donate/cmbClanCastleSpell0', '', '0'],
  ['config', 'donate/cmbClanCastleSpell1', '', '0'],
  ['config', 'donate/cmbClanCastleSpell2', '', '0'],
  ['config', 'donate/cmbClanCastleTroop0', '', '0'],
  ['config', 'donate/cmbClanCastleTroop1', '', '0'],
  ['config', 'donate/cmbClanCastleTroop2', '', '0'],
  ['config', 'donate/cmbDonateCustomA1', '0', '12'],
  ['config', 'donate/cmbDonateCustomA2', '0', '2'],
  ['config', 'donate/cmbDonateCustomB1', '0', '18'],
  ['config', 'donate/cmbDonateCustomB2', '0', '9'],
  ['config', 'donate/cmbDonateCustomB3', '0', '25'],
  ['config', 'donate/RequestType_Spell', '1', '0'],
  ['config', 'donate/RequestType_Troop', '1', '0'],
  ['config', 'donate/txtBlacklist', '', 'clan war|war|cw'],
  ['config', 'donate/txtClanCastleTroop0', '', '0'],
  ['config', 'donate/txtClanCastleTroop1', '', '0'],
  ['config', 'donate/txtClanCastleTroop2', '', '0'],
  ['config', 'donate/txtDonateCustomA1', '0', '2'],
  ['config', 'donate/txtDonateCustomA2', '0', '3'],
  ['config', 'donate/txtDonateCustomA3', '0', '1'],
  ['config', 'donate/txtDonateCustomB1', '0', '3'],
  ['config', 'donate/txtDonateCustomB2', '0', '13'],
  ['config', 'donate/txtDonateCustomB3', '0', '5'],
  ['config', 'endbattle/txtABMinDarkElixirStopAtk2', '0', '50'],
  ['config', 'endbattle/txtABMinElixirStopAtk2', '0', '1000'],
  ['config', 'endbattle/txtABMinGoldStopAtk2', '0', '1000'],
  ['config', 'endbattle/txtABPercentageChange', '0', '15'],
  ['config', 'endbattle/txtABPercentageHigher', '0', '50'],
  ['config', 'endbattle/txtABTimeStopAtk', '0', '20'],
  ['config', 'endbattle/txtABTimeStopAtk2', '0', '7'],
  ['config', 'endbattle/txtDBMinDarkElixirStopAtk2', '0', '50'],
  ['config', 'endbattle/txtDBMinElixirStopAtk2', '0', '1000'],
  ['config', 'endbattle/txtDBMinGoldStopAtk2', '0', '1000'],
  ['config', 'endbattle/txtDBPercentageChange', '0', '15'],
  ['config', 'endbattle/txtDBPercentageHigher', '0', '50'],
  ['config', 'endbattle/txtDBTimeStopAtk', '0', '15'],
  ['config', 'endbattle/txtDBTimeStopAtk2', '0', '7'],
  ['config', 'general/AlertSearch', '1', '0'],
  ['config', 'general/attacknowdelay', '0', '3'],
  ['config', 'general/Background', '0', '1'],
  ['config', 'notify/NotifyHours', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|', '1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|'],
  ['config', 'notify/NotifyWeekDays', '0|0|0|0|0|0|0|', '1|1|1|1|1|1|1|'],
  ['config', 'other/ChkCollectAchievements', '1', '0'],
  ['config', 'other/ChkCollectFreeMagicItems', '1', '0'],
  ['config', 'other/ChkCollectRewards', '1', '0'],
  ['config', 'other/ChkSellRewards', '1', '0'],
  ['config', 'other/ChkTotalCampForced', '0', '1'],
  ['config', 'other/iBBAttackCount', '1', '6'],
  ['config', 'other/MaxVSDelay', '0', '4'],
  ['config', 'other/minrestartelixir', '25000', '50000'],
  ['config', 'other/minrestartgold', '10000', '50000'],
  ['config', 'other/ResumeAttackTime', '0', '12'],
  ['config', 'other/txtTimeWakeUp', '120', '0'],
  ['config', 'other/ValueTotalCampForced', '200', '220'],
  ['config', 'planned/cmbAttackPlannerRandom', '0', '4'],
  ['config', 'planned/DonateHours', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|', '1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|'],
  ['config', 'planned/RequestHours', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|', '1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|'],
  ['config', 'ProfileSCID/OnlySCIDAccounts', '0', '1'],
  ['config', 'search/ABEnableAfterArmyCamps', '0', '100'],
  ['config', 'search/ABEnableAfterCount', '0', '1'],
  ['config', 'search/ABEnableAfterTropies', '0', '1'],
  ['config', 'search/ABEnableBeforeCount', '0', '9999'],
  ['config', 'search/ABEnableBeforeTropies', '0', '36'],
  ['config', 'search/ABMeetGE', '0', '2'],
  ['config', 'search/ABsearchElixir', '0', '80000'],
  ['config', 'search/ABsearchGold', '0', '80000'],
  ['config', 'search/ABsearchGoldPlusElixir', '0', '160000'],
  ['config', 'search/ABsearchTrophyMax', '99', '36'],
  ['config', 'search/ABWeakAirDefense', '0', '7'],
  ['config', 'search/ABWeakEagle', '0', '2'],
  ['config', 'search/ABWeakInferno', '0', '1'],
  ['config', 'search/ABWeakMonolith', '0', '1'],
  ['config', 'search/ABWeakScatter', '0', '1'],
  ['config', 'search/ABWeakXBow', '0', '4'],
  ['config', 'search/ATBullyMode', '150', '0'],
  ['config', 'search/ChkRestartSearchLimit', '0', '1'],
  ['config', 'search/DBEnableAfterArmyCamps', '0', '100'],
  ['config', 'search/DBEnableAfterCount', '0', '1'],
  ['config', 'search/DBEnableAfterTropies', '0', '1'],
  ['config', 'search/DBEnableBeforeCount', '0', '9999'],
  ['config', 'search/DBEnableBeforeTropies', '0', '36'],
  ['config', 'search/DBMeetDeadEagleSearch', '0', '99'],
  ['config', 'search/DBMeetGE', '0', '1'],
  ['config', 'search/DBsearchElixir', '0', '80000'],
  ['config', 'search/DBsearchGold', '0', '80000'],
  ['config', 'search/DBsearchGoldPlusElixir', '0', '160000'],
  ['config', 'search/DBsearchTrophyMax', '99', '36'],
  ['config', 'search/DBWeakAirDefense', '0', '7'],
  ['config', 'search/DBWeakEagle', '0', '2'],
  ['config', 'search/DBWeakInferno', '0', '1'],
  ['config', 'search/DBWeakMonolith', '0', '1'],
  ['config', 'search/DBWeakScatter', '0', '1'],
  ['config', 'search/DBWeakXBow', '0', '4'],
  ['config', 'search/MaxTrophy', '1200', '36'],
  ['config', 'search/MinTrophy', '800', '1'],
  ['config', 'search/RestartSearchLimit', '25', '50'],
  ['config', 'shareattack/minDark', '0', '100'],
  ['config', 'shareattack/minElixir', '300000', '200000'],
  ['config', 'shareattack/minGold', '300000', '200000'],
  ['config', 'SmartFarm/InsidePercentage', '0', '65'],
  ['config', 'SmartFarm/OutsidePercentage', '0', '80'],
  ['config', 'troop/QuickTrainArmy1', '1', '0'],
  ['config', 'troop/UseInGameArmy_1', '0', '1'],
  ['config', 'troop/UseInGameArmy_2', '0', '1'],
  ['config', 'troop/UseInGameArmy_3', '0', '1'],
  ['config', 'Unbreakable/maxUnBrkdark', '6000', '10000'],
  ['config', 'upgrade/walllvl', '0', '6'],
  ['clangames', 'clangames/ChkClanGamesPurgeAny', '0', '1'],
  ['clangames', 'clangames/ChkClanGamesStopBeforeReachAndPurge', '0', '1'],
  ['clangames', 'clangames/EnabledBBBattle', '||||', '0|0|0|0|'],
  ['clangames', 'clangames/EnabledBBDestruction', '|||||||||||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledBBTroops', '||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGAirTroop', '|||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGBattle', '||||||||||||||||||||||', '0|0|0|0||0|0|0||0|0|0||0|0|0||0|0|0||0|'],
  ['clangames', 'clangames/EnabledCGDes', '||||||||||||||||||||||||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGEquipment', '||||||||||||||||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGGroundTroop', '|||||||||||||||||||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGLoot', '||||||', '0|0|0|0|0|0|'],
  ['clangames', 'clangames/EnabledCGMisc', '|||', '0|0|0|'],
  ['clangames', 'clangames/EnabledCGSpell', '||||||||||||', '0|0|0|0|0|0|0|0|0|0|0|0|'],
];

// the bot writes booleans as 1/0, a profile edited elsewhere may hold True/False
const norm = (v) => {
  const s = String(v ?? '').trim();
  return /^true$/i.test(s) ? '1' : /^false$/i.test(s) ? '0' : s;
};

// what a repair would change in a profile folder: [{ file, id, current, value }]
function planRepair(profileDir, keep = []) {
  const kept = new Set(keep.map((id) => id.toLowerCase()));
  const changes = [];
  for (const [alias, file] of Object.entries(FILES)) {
    const full = path.join(profileDir, file);
    if (!fs.existsSync(full)) continue;
    const data = ini.readAll(full);
    for (const [f, id, broken, value] of TABLE) {
      if (f !== alias || kept.has(id.toLowerCase())) continue;
      const [section, key] = id.split('/');
      const current = data[section.toLowerCase()]?.[key.toLowerCase()];
      if (current === undefined) continue; // a missing key already gives the default
      if (norm(current) === norm(broken) && norm(current) !== norm(value)) changes.push({ file, id, current, value });
    }
  }
  return changes;
}

// writes the changes, after a copy of each file it touches (<file>.bak-<date>); returns the copies
function applyRepair(profileDir, changes) {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  const stamp = `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
  const backups = [];
  for (const file of new Set(changes.map((c) => c.file))) {
    const full = path.join(profileDir, file);
    const backup = `${full}.bak-${stamp}`;
    fs.copyFileSync(full, backup);
    backups.push(backup);
    ini.setValues(full, Object.fromEntries(changes.filter((c) => c.file === file).map((c) => [c.id, c.value])));
  }
  return backups;
}

module.exports = { planRepair, applyRepair, TABLE };
