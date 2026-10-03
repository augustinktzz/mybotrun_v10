; #FUNCTION# ====================================================================================================================
; Name ..........: UpdateStats
; Description ...: This function will update the statistics in the GUI.
; Syntax ........: UpdateStats()
; Parameters ....: None
; Return values .: None
; Author ........: kaganus (06-2015)
; Modified ......: CodeSlinger69 (01-2017), Fliegerfaust (02-2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......:
; ===============================================================================================================================
#include-once

Global $ResetStats = 0

Func UpdateStats($bForceUpdate = False)
	; old values
	Static $s_iOldSmartZapGain = 0, $s_iOldNumLSpellsUsed = 0, $s_iOldNumEQSpellsUsed = 0
	Static $topgoldloot = 0, $topelixirloot = 0, $topdarkloot = 0, $topTrophyloot = 0
	Static $bDonateTroopsStatsChanged = False, $bDonateSpellsStatsChanged = False, $bDonateSiegeStatsChanged = False
	Static $iOldFreeBuilderCount, $iOldTotalBuilderCount, $iOldGemAmount ; builder and gem amounts
	Static $iOldCurrentLoot[$eLootCount] ; current stats
	Static $iOldTotalLoot[$eLootCount] ; total stats
	Static $iOldLastLoot[$eLootCount] ; loot and trophy gain from last raid
	Static $iOldLastBonus[$eLootCount] ; bonus loot from last raid
	Static $iOldSkippedVillageCount, $iOldDroppedTrophyCount ; skipped village and dropped trophy counts
	Static $iOldCostGoldWall, $iOldCostElixirWall, $iOldCostGoldBuilding, $iOldCostElixirBuilding, $iOldCostDElixirBuilding, $iOldCostDElixirHero, $iOldCostElixirWarden ; wall, building and hero upgrade costs
	Static $iOldNbrOfWallsUppedGold, $iOldNbrOfWallsUppedElixir, $iOldNbrOfBuildingsUppedGold, $iOldNbrOfBuildingsUppedElixir, $iOldNbrOfBuildingsUppedDElixir, $iOldNbrOfHeroesUpped, $iOldNbrOfWardenUpped ; number of wall, building, hero upgrades with gold, elixir, delixir
	Static $iOldSearchCost, $iOldTrainCostElixir, $iOldTrainCostDElixir, $iOldTrainCostGold ; search and train troops cost
	Static $iOldNbrOfOoS ; number of Out of Sync occurred
	Static $iOldNbrOfTHSnipeFails, $iOldNbrOfTHSnipeSuccess ; number of fails and success while TH Sniping
	Static $iOldGoldFromMines, $iOldElixirFromCollectors, $iOldDElixirFromDrills ; number of resources gain by collecting mines, collectors, drills
	Static $iOldAttackedCount, $iOldAttackedVillageCount[$g_iModeCount + 1] ; number of attack villages for DB, LB, TB, TS
	Static $iOldTotalGoldGain[$g_iModeCount + 1], $iOldTotalElixirGain[$g_iModeCount + 1], $iOldTotalDarkGain[$g_iModeCount + 1], $iOldTotalTrophyGain[$g_iModeCount + 1] ; total resource gains for DB, LB, TB, TS
	Static $iOldNbrOfDetectedMines[$g_iModeCount + 1], $iOldNbrOfDetectedCollectors[$g_iModeCount + 1], $iOldNbrOfDetectedDrills[$g_iModeCount + 1] ; number of mines, collectors, drills detected for DB, LB, TB
	Static $sOldClanGamesScore, $sOldClanGameTimeRemaining
	; Builder Base old values
	Static $iOldCurrentLootBB[$eLootCountBB] ; current stats

	If $bForceUpdate Then
		; reset old values to force update
		$s_iOldSmartZapGain = 0
		$s_iOldNumLSpellsUsed = 0
		$s_iOldNumEQSpellsUsed = 0
		$topgoldloot = 0
		$topelixirloot = 0
		$topdarkloot = 0
		$topTrophyloot = 0
		$bDonateTroopsStatsChanged = True
		$bDonateSpellsStatsChanged = True
		$bDonateSiegeStatsChanged = True
		$iOldFreeBuilderCount = 0
		$iOldTotalBuilderCount = 0
		$iOldGemAmount = 0 ; builder and gem amounts
		UpdateStats_ClearArray($iOldCurrentLoot) ; current stats
		UpdateStats_ClearArray($iOldTotalLoot) ; total stats
		UpdateStats_ClearArray($iOldLastLoot) ; loot and trophy gain from last raid
		UpdateStats_ClearArray($iOldLastBonus) ; bonus loot from last raid
		$iOldSkippedVillageCount = 0
		$iOldDroppedTrophyCount = 0 ; skipped village and dropped trophy counts
		$iOldCostGoldWall = 0
		$iOldCostElixirWall = 0
		$iOldCostGoldBuilding = 0
		$iOldCostElixirBuilding = 0
		$iOldCostDElixirBuilding = 0
		$iOldCostDElixirHero = 0 ; wall, building and hero upgrade costs
		$iOldCostElixirWarden = 0
		$iOldNbrOfWallsUppedGold = 0
		$iOldNbrOfWallsUppedElixir = 0
		$iOldNbrOfBuildingsUppedGold = 0
		$iOldNbrOfBuildingsUppedElixir = 0
		$iOldNbrOfBuildingsUppedDElixir = 0
		$iOldNbrOfHeroesUpped = 0 ; number of wall, building, hero upgrades with gold, elixir, delixir
		$iOldNbrOfWardenUpped = 0
		$iOldSearchCost = 0
		$iOldTrainCostElixir = 0
		$iOldTrainCostDElixir = 0 ; search and train troops cost
		$iOldTrainCostGold = 0 ; Build Sieges
		$iOldNbrOfOoS = 0 ; number of Out of Sync occurred
		$iOldNbrOfTHSnipeFails = 0
		$iOldNbrOfTHSnipeSuccess = 0 ; number of fails and success while TH Sniping
		$iOldGoldFromMines = 0
		$iOldElixirFromCollectors = 0
		$iOldDElixirFromDrills = 0 ; number of resources gain by collecting mines, collectors, drills
		$iOldAttackedCount = 0
		UpdateStats_ClearArray($iOldAttackedVillageCount) ; number of attack villages for DB, LB, TB, TS
		UpdateStats_ClearArray($iOldTotalGoldGain)
		UpdateStats_ClearArray($iOldTotalElixirGain)
		UpdateStats_ClearArray($iOldTotalDarkGain)
		UpdateStats_ClearArray($iOldTotalTrophyGain) ; total resource gains for DB, LB, TB, TS
		UpdateStats_ClearArray($iOldNbrOfDetectedMines)
		UpdateStats_ClearArray($iOldNbrOfDetectedCollectors)
		UpdateStats_ClearArray($iOldNbrOfDetectedDrills) ; number of mines, collectors, drills detected for DB, LB, TB
		; Builder Base old values
		UpdateStats_ClearArray($iOldCurrentLootBB) ; current stats
	EndIf

	If $g_iFirstRun = 1 Then
		;GUICtrlSetState($g_hLblResultStatsTemp, $GUI_HIDE)

		$g_iStatsStartedWith[$eLootGold] = $g_aiCurrentLoot[$eLootGold]
		$g_iStatsStartedWith[$eLootElixir] = $g_aiCurrentLoot[$eLootElixir]
		$g_iStatsStartedWith[$eLootDarkElixir] = $g_aiCurrentLoot[$eLootDarkElixir]
		$g_iStatsStartedWith[$eLootTrophy] = $g_aiCurrentLoot[$eLootTrophy]
		$iOldCurrentLoot[$eLootGold] = $g_aiCurrentLoot[$eLootGold]
		$iOldCurrentLoot[$eLootElixir] = $g_aiCurrentLoot[$eLootElixir]
		If $g_iStatsStartedWith[$eLootDarkElixir] <> "" Then
			$iOldCurrentLoot[$eLootDarkElixir] = $g_aiCurrentLoot[$eLootDarkElixir]
		EndIf
		$iOldCurrentLoot[$eLootTrophy] = $g_aiCurrentLoot[$eLootTrophy]
		$iOldGemAmount = $g_iGemAmount
		$iOldFreeBuilderCount = $g_iFreeBuilderCount
		$iOldTotalBuilderCount = $g_iTotalBuilderCount
		$g_iFirstRun = 0
		UpdateStatsManagedMyBotHost() ; send update to the managing processes (API)
		Return
	EndIf

	Local $bStatsUpdated = False

	If $g_iFirstAttack = 1 Then $g_iFirstAttack = 2

	If Number($g_iStatsLastAttack[$eLootGold]) > Number($topgoldloot) Then
		$bStatsUpdated = True
		$topgoldloot = $g_iStatsLastAttack[$eLootGold]
	EndIf

	If Number($g_iStatsLastAttack[$eLootElixir]) > Number($topelixirloot) Then
		$bStatsUpdated = True
		$topelixirloot = $g_iStatsLastAttack[$eLootElixir]
	EndIf

	If Number($g_iStatsLastAttack[$eLootDarkElixir]) > Number($topdarkloot) Then
		$bStatsUpdated = True
		$topdarkloot = $g_iStatsLastAttack[$eLootDarkElixir]
	EndIf

	If Number($g_iStatsLastAttack[$eLootTrophy]) > Number($topTrophyloot) Then
		$bStatsUpdated = True
		$topTrophyloot = $g_iStatsLastAttack[$eLootTrophy]
	EndIf

	If $ResetStats = 1 Then
		$bStatsUpdated = True

	EndIf

	If $iOldFreeBuilderCount <> $g_iFreeBuilderCount Or $iOldTotalBuilderCount <> $g_iTotalBuilderCount Then
		$bStatsUpdated = True
		$iOldFreeBuilderCount = $g_iFreeBuilderCount
		$iOldTotalBuilderCount = $g_iTotalBuilderCount
	EndIf

	If $iOldGemAmount <> $g_iGemAmount Then
		$bStatsUpdated = True
		$iOldGemAmount = $g_iGemAmount
	EndIf

	If $iOldCurrentLoot[$eLootGold] <> $g_aiCurrentLoot[$eLootGold] Then
		$bStatsUpdated = True
		$iOldCurrentLoot[$eLootGold] = $g_aiCurrentLoot[$eLootGold]
	EndIf

	If $iOldCurrentLoot[$eLootElixir] <> $g_aiCurrentLoot[$eLootElixir] Then
		$bStatsUpdated = True
		$iOldCurrentLoot[$eLootElixir] = $g_aiCurrentLoot[$eLootElixir]
	EndIf

	If $iOldCurrentLoot[$eLootDarkElixir] <> $g_aiCurrentLoot[$eLootDarkElixir] And $g_iStatsStartedWith[$eLootDarkElixir] <> "" Then
		$bStatsUpdated = True
		$iOldCurrentLoot[$eLootDarkElixir] = $g_aiCurrentLoot[$eLootDarkElixir]
	EndIf

	If $iOldCurrentLoot[$eLootTrophy] <> $g_aiCurrentLoot[$eLootTrophy] Then
		$bStatsUpdated = True
		$iOldCurrentLoot[$eLootTrophy] = $g_aiCurrentLoot[$eLootTrophy]
	EndIf

	If $iOldTotalLoot[$eLootGold] <> $g_iStatsTotalGain[$eLootGold] And ($g_iFirstAttack = 2 Or $ResetStats = 1) Then
		$bStatsUpdated = True
		$iOldTotalLoot[$eLootGold] = $g_iStatsTotalGain[$eLootGold]
	EndIf

	If $iOldTotalLoot[$eLootElixir] <> $g_iStatsTotalGain[$eLootElixir] And ($g_iFirstAttack = 2 Or $ResetStats = 1) Then
		$bStatsUpdated = True
		$iOldTotalLoot[$eLootElixir] = $g_iStatsTotalGain[$eLootElixir]
	EndIf

	If $iOldTotalLoot[$eLootDarkElixir] <> $g_iStatsTotalGain[$eLootDarkElixir] And (($g_iFirstAttack = 2 And $g_iStatsStartedWith[$eLootDarkElixir] <> "") Or $ResetStats = 1) Then
		$bStatsUpdated = True
		$iOldTotalLoot[$eLootDarkElixir] = $g_iStatsTotalGain[$eLootDarkElixir]
	EndIf

	If $iOldTotalLoot[$eLootTrophy] <> $g_iStatsTotalGain[$eLootTrophy] And ($g_iFirstAttack = 2 Or $ResetStats = 1) Then
		$bStatsUpdated = True
		$iOldTotalLoot[$eLootTrophy] = $g_iStatsTotalGain[$eLootTrophy]
	EndIf

	If $iOldLastLoot[$eLootGold] <> $g_iStatsLastAttack[$eLootGold] Then
		$bStatsUpdated = True
		$iOldLastLoot[$eLootGold] = $g_iStatsLastAttack[$eLootGold]
	EndIf

	If $iOldLastLoot[$eLootElixir] <> $g_iStatsLastAttack[$eLootElixir] Then
		$bStatsUpdated = True
		$iOldLastLoot[$eLootElixir] = $g_iStatsLastAttack[$eLootElixir]
	EndIf

	If $iOldLastLoot[$eLootDarkElixir] <> $g_iStatsLastAttack[$eLootDarkElixir] Then
		$bStatsUpdated = True
		$iOldLastLoot[$eLootDarkElixir] = $g_iStatsLastAttack[$eLootDarkElixir]
	EndIf

	If $iOldLastLoot[$eLootTrophy] <> $g_iStatsLastAttack[$eLootTrophy] Then
		$bStatsUpdated = True
		$iOldLastLoot[$eLootTrophy] = $g_iStatsLastAttack[$eLootTrophy]
	EndIf

	If $iOldLastBonus[$eLootGold] <> $g_iStatsBonusLast[$eLootGold] Then
		$bStatsUpdated = True
		$iOldLastBonus[$eLootGold] = $g_iStatsBonusLast[$eLootGold]
	EndIf

	If $iOldLastBonus[$eLootElixir] <> $g_iStatsBonusLast[$eLootElixir] Then
		$bStatsUpdated = True
		$iOldLastBonus[$eLootElixir] = $g_iStatsBonusLast[$eLootElixir]
	EndIf

	If $iOldLastBonus[$eLootDarkElixir] <> $g_iStatsBonusLast[$eLootDarkElixir] Then
		$bStatsUpdated = True
		$iOldLastBonus[$eLootDarkElixir] = $g_iStatsBonusLast[$eLootDarkElixir]
	EndIf

	If $iOldCostGoldWall <> $g_iCostGoldWall Then
		$bStatsUpdated = True
		$iOldCostGoldWall = $g_iCostGoldWall
	EndIf

	If $iOldCostElixirWall <> $g_iCostElixirWall Then
		$bStatsUpdated = True
		$iOldCostElixirWall = $g_iCostElixirWall
	EndIf

	If $iOldCostGoldBuilding <> $g_iCostGoldBuilding Then
		$bStatsUpdated = True
		$iOldCostGoldBuilding = $g_iCostGoldBuilding
	EndIf

	If $iOldCostElixirBuilding <> $g_iCostElixirBuilding Then
		$bStatsUpdated = True
		$iOldCostElixirBuilding = $g_iCostElixirBuilding
	EndIf

	If $iOldCostDElixirBuilding <> $g_iCostDElixirBuilding Then
		$bStatsUpdated = True
		$iOldCostDElixirBuilding = $g_iCostDElixirBuilding
	EndIf

	If $iOldCostDElixirHero <> $g_iCostDElixirHero Then
		$bStatsUpdated = True
		$iOldCostDElixirHero = $g_iCostDElixirHero
	EndIf

	If $iOldCostElixirWarden <> $g_iCostElixirWarden Then
		$bStatsUpdated = True
		$iOldCostElixirWarden = $g_iCostElixirWarden
	EndIf

	If $iOldSkippedVillageCount <> $g_iSkippedVillageCount Then
		$bStatsUpdated = True
		$iOldSkippedVillageCount = $g_iSkippedVillageCount
	EndIf

	If $iOldDroppedTrophyCount <> $g_iDroppedTrophyCount Then
		$bStatsUpdated = True
		$iOldDroppedTrophyCount = $g_iDroppedTrophyCount
	EndIf

	If $iOldNbrOfWallsUppedGold <> $g_iNbrOfWallsUppedGold Then
		$bStatsUpdated = True
		$iOldNbrOfWallsUppedGold = $g_iNbrOfWallsUppedGold
		WallsStatsMAJ()
	EndIf

	If $iOldNbrOfWallsUppedElixir <> $g_iNbrOfWallsUppedElixir Then
		$bStatsUpdated = True
		$iOldNbrOfWallsUppedElixir = $g_iNbrOfWallsUppedElixir
		WallsStatsMAJ()
	EndIf

	If $iOldNbrOfBuildingsUppedGold <> $g_iNbrOfBuildingsUppedGold Then
		$bStatsUpdated = True
		$iOldNbrOfBuildingsUppedGold = $g_iNbrOfBuildingsUppedGold
	EndIf

	If $iOldNbrOfBuildingsUppedElixir <> $g_iNbrOfBuildingsUppedElixir Then
		$bStatsUpdated = True
		$iOldNbrOfBuildingsUppedElixir = $g_iNbrOfBuildingsUppedElixir
	EndIf

	If $iOldNbrOfBuildingsUppedDElixir <> $g_iNbrOfBuildingsUppedDElixir Then
		$bStatsUpdated = True
		$iOldNbrOfBuildingsUppedDElixir = $g_iNbrOfBuildingsUppedDElixir
	EndIf

	If $iOldNbrOfHeroesUpped <> $g_iNbrOfHeroesUpped Then
		$bStatsUpdated = True
		$iOldNbrOfHeroesUpped = $g_iNbrOfHeroesUpped
	EndIf

	If $iOldNbrOfWardenUpped <> $g_iNbrOfwardenUpped Then
		$bStatsUpdated = True
		$iOldNbrOfWardenUpped = $g_iNbrOfWardenUpped
	EndIf

	If $iOldSearchCost <> $g_iSearchCost Then
		$bStatsUpdated = True
		$iOldSearchCost = $g_iSearchCost
	EndIf

	If $iOldTrainCostElixir <> $g_iTrainCostElixir Then
		$bStatsUpdated = True
		$iOldTrainCostElixir = $g_iTrainCostElixir
	EndIf

	If $iOldTrainCostDElixir <> $g_iTrainCostDElixir Then
		$bStatsUpdated = True
		$iOldTrainCostDElixir = $g_iTrainCostDElixir
	EndIf

	If $iOldTrainCostGold <> $g_iTrainCostGold Then
		$bStatsUpdated = True
		$iOldTrainCostGold = $g_iTrainCostGold
	EndIf

	If $iOldNbrOfOoS <> $g_iNbrOfOoS Then
		$bStatsUpdated = True
		$iOldNbrOfOoS = $g_iNbrOfOoS
	EndIf

	If $iOldGoldFromMines <> $g_iGoldFromMines Then
		$bStatsUpdated = True
		$iOldGoldFromMines = $g_iGoldFromMines
	EndIf

	If $iOldElixirFromCollectors <> $g_iElixirFromCollectors Then
		$bStatsUpdated = True
		$iOldElixirFromCollectors = $g_iElixirFromCollectors
	EndIf

	If $iOldDElixirFromDrills <> $g_iDElixirFromDrills Then
		$bStatsUpdated = True
		$iOldDElixirFromDrills = $g_iDElixirFromDrills
	EndIf

	For $i = 0 To $eTroopCount - 1
		If $g_aiDonateStatsTroops[$i][0] <> $g_aiDonateStatsTroops[$i][1] Then
			$bStatsUpdated = True
			If $g_aiDonateStatsTroops[$i][0] > $g_aiDonateStatsTroops[$i][1] Then
				$g_iTotalDonateStatsTroops += ($g_aiDonateStatsTroops[$i][0] - $g_aiDonateStatsTroops[$i][1])
				$g_iTotalDonateStatsTroopsXP += (($g_aiDonateStatsTroops[$i][0] - $g_aiDonateStatsTroops[$i][1]) * $g_aiTroopDonateXP[$i])
			EndIf
			$g_aiDonateStatsTroops[$i][1] = $g_aiDonateStatsTroops[$i][0]
			$bDonateTroopsStatsChanged = True
		EndIf
	Next
	If $bDonateTroopsStatsChanged Then
		$bStatsUpdated = True
		$bDonateTroopsStatsChanged = False
	EndIf

	For $i = 0 To $eSpellCount - 1
		If $g_aiDonateStatsSpells[$i][0] <> $g_aiDonateStatsSpells[$i][1] And $i <> $eSpellClone Then
			$bStatsUpdated = True
			If $g_aiDonateStatsSpells[$i][0] > $g_aiDonateStatsSpells[$i][1] Then
				$g_iTotalDonateStatsSpells += ($g_aiDonateStatsSpells[$i][0] - $g_aiDonateStatsSpells[$i][1])
				$g_iTotalDonateStatsSpellsXP += (($g_aiDonateStatsSpells[$i][0] - $g_aiDonateStatsSpells[$i][1]) * $g_aiSpellDonateXP[$i])
			EndIf
			$g_aiDonateStatsSpells[$i][1] = $g_aiDonateStatsSpells[$i][0]
			$bDonateSpellsStatsChanged = True
		EndIf
	Next

	If $bDonateSpellsStatsChanged Then
		$bStatsUpdated = True
		$bDonateSpellsStatsChanged = False
	EndIf

	For $i = 0 To $eSiegeMachineCount - 1
		If $g_aiDonateStatsSieges[$i][0] <> $g_aiDonateStatsSieges[$i][1] Then
			$bStatsUpdated = True
			If $g_aiDonateStatsSieges[$i][0] > $g_aiDonateStatsSieges[$i][1] Then
				$g_iTotalDonateStatsSiegeMachines += ($g_aiDonateStatsSieges[$i][0] - $g_aiDonateStatsSieges[$i][1])
				$g_iTotalDonateStatsSiegeMachinesXP += (($g_aiDonateStatsSieges[$i][0] - $g_aiDonateStatsSieges[$i][1]) * $g_aiSiegeMachineDonateXP[$i])
			EndIf
			$g_aiDonateStatsSieges[$i][1] = $g_aiDonateStatsSieges[$i][0]
			$bDonateSiegeStatsChanged = True
		EndIf
	Next

	If $bDonateSiegeStatsChanged Then
		$bStatsUpdated = True
		$bDonateSiegeStatsChanged = False
	EndIf

	If $s_iOldSmartZapGain <> $g_iSmartZapGain Then
		$bStatsUpdated = True
		$s_iOldSmartZapGain = $g_iSmartZapGain
	EndIf

	If $s_iOldNumLSpellsUsed <> $g_iNumLSpellsUsed Then
		$bStatsUpdated = True
		$s_iOldNumLSpellsUsed = $g_iNumLSpellsUsed
	EndIf

	If $s_iOldNumEQSpellsUsed <> $g_iNumEQSpellsUsed Then
		$bStatsUpdated = True
		$s_iOldNumEQSpellsUsed = $g_iNumEQSpellsUsed
	EndIf

	$g_aiAttackedCount = 0

	For $i = 0 To $g_iModeCount - 1

		If $iOldAttackedVillageCount[$i] <> $g_aiAttackedVillageCount[$i] Then
			$bStatsUpdated = True
			$iOldAttackedVillageCount[$i] = $g_aiAttackedVillageCount[$i]
		EndIf
		$g_aiAttackedCount += $g_aiAttackedVillageCount[$i]

		If $iOldTotalGoldGain[$i] <> $g_aiTotalGoldGain[$i] Then
			$bStatsUpdated = True
			$iOldTotalGoldGain[$i] = $g_aiTotalGoldGain[$i]
		EndIf

		If $iOldTotalElixirGain[$i] <> $g_aiTotalElixirGain[$i] Then
			$bStatsUpdated = True
			$iOldTotalElixirGain[$i] = $g_aiTotalElixirGain[$i]
		EndIf

		If $iOldTotalDarkGain[$i] <> $g_aiTotalDarkGain[$i] Then
			$bStatsUpdated = True
			$iOldTotalDarkGain[$i] = $g_aiTotalDarkGain[$i]
		EndIf

		If $iOldTotalTrophyGain[$i] <> $g_aiTotalTrophyGain[$i] Then
			$bStatsUpdated = True
			$iOldTotalTrophyGain[$i] = $g_aiTotalTrophyGain[$i]
		EndIf

	Next

	If $iOldAttackedCount <> $g_aiAttackedCount Then
		$bStatsUpdated = True
		$iOldAttackedCount = $g_aiAttackedCount
	EndIf

	For $i = 0 To $g_iModeCount - 1

		If $iOldNbrOfDetectedMines[$i] <> $g_aiNbrOfDetectedMines[$i] Then
			$bStatsUpdated = True
			$iOldNbrOfDetectedMines[$i] = $g_aiNbrOfDetectedMines[$i]
		EndIf

		If $iOldNbrOfDetectedCollectors[$i] <> $g_aiNbrOfDetectedCollectors[$i] Then
			$bStatsUpdated = True
			$iOldNbrOfDetectedCollectors[$i] = $g_aiNbrOfDetectedCollectors[$i]
		EndIf

		If $iOldNbrOfDetectedDrills[$i] <> $g_aiNbrOfDetectedDrills[$i] Then
			$bStatsUpdated = True
			$iOldNbrOfDetectedDrills[$i] = $g_aiNbrOfDetectedDrills[$i]
		EndIf

	Next

	If $g_iFirstAttack = 2 Then
		$bStatsUpdated = True

	EndIf

	If Number($g_iStatsLastAttack[$eLootGold]) > Number($topgoldloot) Then
		$bStatsUpdated = True
		$topgoldloot = $g_iStatsLastAttack[$eLootGold]
	EndIf

	If Number($g_iStatsLastAttack[$eLootElixir]) > Number($topelixirloot) Then
		$bStatsUpdated = True
		$topelixirloot = $g_iStatsLastAttack[$eLootElixir]
	EndIf

	If Number($g_iStatsLastAttack[$eLootDarkElixir]) > Number($topdarkloot) Then
		$bStatsUpdated = True
		$topdarkloot = $g_iStatsLastAttack[$eLootDarkElixir]
	EndIf

	If Number($g_iStatsLastAttack[$eLootTrophy]) > Number($topTrophyloot) Then
		$bStatsUpdated = True
		$topTrophyloot = $g_iStatsLastAttack[$eLootTrophy]
	EndIf

	If $g_sClanGamesTimeRemaining <> $sOldClanGameTimeRemaining Then
		$sOldClanGameTimeRemaining = $g_sClanGamesTimeRemaining
	EndIf

	If $g_sClanGamesScore <> $sOldClanGamesScore Then
		$sOldClanGamesScore = $g_sClanGamesScore
	EndIf

	; update Builder Base stats
	For $i = 0 To UBound($g_aiCurrentLootBB) - 1
		If $iOldCurrentLootBB[$i] <> $g_aiCurrentLootBB[$i] Then
			$bStatsUpdated = True
			$iOldCurrentLootBB[$i] = $g_aiCurrentLootBB[$i]
		EndIf
	Next


	If ProfileSwitchAccountEnabled() Then
		;village report
		Local $TempGemDisplay = $g_iGemAmount < 10000 ? $g_iGemAmount : Round($g_iGemAmount / 1000, 1)

		;gain stats
		SwitchAccountVariablesReload("UpdateStats")

		;Clan Capital

		;Builders Base

	EndIf

	If $ResetStats = 1 Then
		$ResetStats = 0
	EndIf

	If $bStatsUpdated Then UpdateStatsManagedMyBotHost() ; send update to the managing processes (API)

EndFunc   ;==>UpdateStats

Func ResetStats()
	$ResetStats = 1
	$g_iFirstAttack = 0
	$g_iTimePassed = 0
	$g_hTimerSinceStarted = __TimerInit()
	$g_iStatsStartedWith[$eLootGold] = $g_aiCurrentLoot[$eLootGold]
	$g_iStatsStartedWith[$eLootElixir] = $g_aiCurrentLoot[$eLootElixir]
	$g_iStatsStartedWith[$eLootDarkElixir] = $g_aiCurrentLoot[$eLootDarkElixir]
	$g_iStatsStartedWith[$eLootTrophy] = $g_aiCurrentLoot[$eLootTrophy]
	$g_iStatsTotalGain[$eLootGold] = 0
	$g_iStatsTotalGain[$eLootElixir] = 0
	$g_iStatsTotalGain[$eLootDarkElixir] = 0
	$g_iStatsTotalGain[$eLootTrophy] = 0
	$g_iStatsLastAttack[$eLootGold] = 0
	$g_iStatsLastAttack[$eLootElixir] = 0
	$g_iStatsLastAttack[$eLootDarkElixir] = 0
	$g_iStatsLastAttack[$eLootTrophy] = 0
	$g_iStatsBonusLast[$eLootGold] = 0
	$g_iStatsBonusLast[$eLootElixir] = 0
	$g_iStatsBonusLast[$eLootDarkElixir] = 0
	$g_iSkippedVillageCount = 0
	$g_iDroppedTrophyCount = 0
	$g_iCostGoldWall = 0
	$g_iCostElixirWall = 0
	$g_iCostGoldBuilding = 0
	$g_iCostElixirBuilding = 0
	$g_iCostDElixirBuilding = 0
	$g_iCostDElixirHero = 0
	$g_iCostElixirWarden = 0
	$g_iNbrOfWallsUppedGold = 0
	$g_iNbrOfWallsUppedElixir = 0
	$g_iNbrOfBuildingsUppedGold = 0
	$g_iNbrOfBuildingsUppedElixir = 0
	$g_iNbrOfBuildingsUppedDElixir = 0
	$g_iNbrOfHeroesUpped = 0
	$g_iNbrOfWardenUpped = 0
	$g_iSearchCost = 0
	$g_iTrainCostElixir = 0
	$g_iTrainCostDElixir = 0
	$g_iTrainCostGold = 0
	$g_iNbrOfOoS = 0
	$g_iGoldFromMines = 0
	$g_iElixirFromCollectors = 0
	$g_iDElixirFromDrills = 0
	$g_iSmartZapGain = 0
	$g_iNumLSpellsUsed = 0
	$g_iNumEQSpellsUsed = 0
	For $i = 0 To $g_iModeCount - 1
		$g_aiAttackedVillageCount[$i] = 0
		$g_aiTotalGoldGain[$i] = 0
		$g_aiTotalElixirGain[$i] = 0
		$g_aiTotalDarkGain[$i] = 0
		$g_aiTotalTrophyGain[$i] = 0
		$g_aiNbrOfDetectedMines[$i] = 0
		$g_aiNbrOfDetectedCollectors[$i] = 0
		$g_aiNbrOfDetectedDrills[$i] = 0
	Next

	For $i = 0 To $eTroopCount - 1
		$g_aiDonateStatsTroops[$i][0] = 0
	Next

	For $i = 0 To $eSpellCount - 1
		If $i <> $eSpellClone Then
			$g_aiDonateStatsSpells[$i][0] = 0
		EndIf
	Next

	For $i = 0 To $eSiegeMachineCount - 1
		$g_aiDonateStatsSieges[$i][0] = 0
	Next

	$g_iTotalDonateStatsTroops = 0
	$g_iTotalDonateStatsTroopsXP = 0
	$g_iTotalDonateStatsSpells = 0
	$g_iTotalDonateStatsSpellsXP = 0
	$g_iTotalDonateStatsSiegeMachines = 0
	$g_iTotalDonateStatsSiegeMachinesXP = 0
	If ProfileSwitchAccountEnabled() Then
		SwitchAccountVariablesReload("Reset")
		For $i = 0 To 7
			$g_aiRunTime[$i] = 0
		Next
	EndIf
	UpdateStats()
EndFunc   ;==>ResetStats

Func WallsStatsMAJ()
	; the walls UpgradeWall() just upgraded are of its working level: they move one level up in the counts, which
	; never go below zero when a count was not known (UpgradeWall.au3)
	WallCountUpgraded($g_iCmbUpgradeWallsLevel + 4, $g_iNbrOfWallsUpped)
	$g_iNbrOfWallsUpped = 0
	SaveConfig()
EndFunc   ;==>WallsStatsMAJ

Func UpdateStats_ClearArray(ByRef $a)
	For $i = 0 To UBound($a) - 1
		$a[$i] = 0
	Next
EndFunc   ;==>UpdateStats_ClearArray

