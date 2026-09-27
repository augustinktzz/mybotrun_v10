; #FUNCTION# ====================================================================================================================
; Name ..........: DropAttackSpells
; Description ...: Drops the spells ticked in the attack plan on the push, after the troops and the heroes.
; Syntax ........: DropAttackSpells([$iX = -1], [$iY = -1])
; Parameters ....: $iX, $iY             - where to drop, the heroes landing point when left out.
; Return values .: Number of spells dropped.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  algorithm_AllTroops and SmartFarm never used the brewed spells: PrepareAttack() kept
;                  their slots (the "Use ... Spell" boxes of the Attack Plan) but nothing ever selected
;                  them, so a full spell factory was carried into every raid and brought back unused.
;                  Lightning and Earthquake stay untouched while Smart Zap is on, it needs them for the
;                  drills.
; ===============================================================================================================================
#include-once

Func DropAttackSpells($iX = -1, $iY = -1)
	If Not $g_bRunState Then Return 0
	If $g_iMatchMode <> $DB And $g_iMatchMode <> $LB Then Return 0 ; CSV plans place their own spells

	If $iX < 0 Or $iY < 0 Then
		If $g_aiSpellDropPoint[0] > 0 Then ; where dropHeroes / dropCC really clicked
			$iX = $g_aiSpellDropPoint[0]
			$iY = $g_aiSpellDropPoint[1]
		ElseIf $g_aiDeployHeroesPosition[0] > 0 Then
			$iX = $g_aiDeployHeroesPosition[0]
			$iY = $g_aiDeployHeroesPosition[1]
		ElseIf $g_aiDeployCCPosition[0] > 0 Then
			$iX = $g_aiDeployCCPosition[0]
			$iY = $g_aiDeployCCPosition[1]
		Else
			SetDebugLog("Spells: no landing point known yet, none dropped", $COLOR_DEBUG)
			Return 0
		EndIf
	EndIf

	; the heroes land on the edge of the base, the push is a little further in
	$iX = Int($iX + (430 - $iX) * 0.25)
	$iY = Int($iY + (360 - $iY) * 0.25)

	; A fast three star can end the battle while the heroes are still going down. SelectDropTroop()
	; would then select nothing while the clicks below still landed, on the end of battle screen.
	If Not IsAttackPage() Then
		SetDebugLog("Spells: the battle is over, none dropped", $COLOR_DEBUG)
		Return 0
	EndIf

	Local $iDropped = 0
	For $i = 0 To UBound($g_avAttackTroops, 1) - 1
		If Not $g_bRunState Then ExitLoop
		If Not IsAttackPage() Then ExitLoop
		Local $iIndex = Number($g_avAttackTroops[$i][0])
		If $iIndex < $eLSpell Or $iIndex > $eOgSpell Then ContinueLoop
		If Not IsUnitUsed($g_iMatchMode, $iIndex) Then ContinueLoop
		If ($iIndex = $eLSpell Or $iIndex = $eESpell) And $g_bSmartZapEnable Then
			SetDebugLog("Keeping " & GetTroopName($iIndex) & " for Smart Zap", $COLOR_DEBUG)
			ContinueLoop
		EndIf
		Local $iCount = Number($g_avAttackTroops[$i][1])
		If $iCount < 1 Then ContinueLoop

		SetLog("Dropping " & $iCount & " " & GetTroopName($iIndex, $iCount) & " on the push", $COLOR_INFO)
		SelectDropTroop($i)
		If _Sleep($DELAYDROPCC1) Then ExitLoop
		For $k = 1 To $iCount
			If Not $g_bRunState Then ExitLoop 2
			AttackClick($iX + Random(-12, 12, 1), $iY + Random(-12, 12, 1), 1, 50, 0, "#0096")
			If _Sleep(400) Then ExitLoop 2
		Next
		$iDropped += $iCount
	Next

	If $iDropped > 0 Then SetLog("Dropped " & $iDropped & " spell(s)", $COLOR_SUCCESS)
	Return $iDropped
EndFunc   ;==>DropAttackSpells
