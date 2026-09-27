; #FUNCTION# ====================================================================================================================
; Name ..........: dropCC
; Description ...: Drops Clan Castle troops, given the slot and x, y coordinates.
; Syntax ........: dropCC($x, $y, $slot)
; Parameters ....: $x                   - X location.
;                  $y                   - Y location.
;                  $slot                - CC location in troop menu
; Return values .: None
; Author ........:
; Modified ......: Sardo (12-2015) KnowJack (06-2015)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func dropCC($iX, $iY, $iCCSlot) ;Drop clan castle

	; That one slot holds either the clan castle troops or the siege machine that carries them, and the
	; two have their own switch in the attack plan, so the right one has to be read here.
	Local $iSlotUnit = ($iCCSlot >= 0 And $iCCSlot < UBound($g_avAttackTroops, 1)) ? Number($g_avAttackTroops[$iCCSlot][0]) : -1
	Local $bIsSiege = ($iSlotUnit >= $eWallW And $iSlotUnit <= $eTroopL)
	Local $test = ($g_iMatchMode <> $DB And $g_iMatchMode <> $LB) Or ($bIsSiege ? $g_abAttackUseSiegeMachine[$g_iMatchMode] : $g_abAttackDropCC[$g_iMatchMode])
	If $iCCSlot <> -1 And Not $test Then SetDebugLog(($bIsSiege ? "Siege machine" : "Clan castle") & " not enabled for this attack, slot left alone", $COLOR_DEBUG)

	If $iCCSlot <> -1 And $test Then
		If $g_bPlannedDropCCHoursEnable = True Then
			Local $hour = StringSplit(_NowTime(4), ":", $STR_NOCOUNT)
			If $g_abPlannedDropCCHours[$hour[0]] = False Then
				SetLog("Drop CC not Planned, Skipped..", $COLOR_SUCCESS)
				Return ; exit func if no planned donate checkmarks
			EndIf
		EndIf


		;standard attack
		If $g_bUseCCBalanced = True Then
			If Number($g_iTroopsReceived) <> 0 Then
				If Number(Number($g_iTroopsDonated) / Number($g_iTroopsReceived)) >= (Number($g_iCCDonated) / Number($g_iCCReceived)) Then
					SetLog("Dropping Siege/Clan Castle, donated (" & $g_iTroopsDonated & ") / received (" & $g_iTroopsReceived & ") >= " & $g_iCCDonated & "/" & $g_iCCReceived, $COLOR_INFO)
					SelectDropTroop($iCCSlot)
					If _Sleep($DELAYDROPCC1) Then Return
					AttackClick($iX, $iY, 1, 50, 0, "#0087")
					__RememberSpellDropPoint($iX, $iY)
				Else
					SetLog("No Dropping Siege/Clan Castle, donated  (" & $g_iTroopsDonated & ") / received (" & $g_iTroopsReceived & ") < " & $g_iCCDonated & "/" & $g_iCCReceived, $COLOR_INFO)
				EndIf
			Else
				If Number(Number($g_iTroopsDonated) / 1) >= (Number($g_iCCDonated) / Number($g_iCCReceived)) Then
					SetLog("Dropping Siege/Clan Castle, donated (" & $g_iTroopsDonated & ") / received (" & $g_iTroopsReceived & ") >= " & $g_iCCDonated & "/" & $g_iCCReceived, $COLOR_INFO)
					SelectDropTroop($iCCSlot)
					If _Sleep($DELAYDROPCC1) Then Return
					AttackClick($iX, $iY, 1, 50, 0, "#0089")
					__RememberSpellDropPoint($iX, $iY)
				Else
					SetLog("No Dropping Siege/Clan Castle, donated  (" & $g_iTroopsDonated & ") / received (" & $g_iTroopsReceived & ") < " & $g_iCCDonated & "/" & $g_iCCReceived, $COLOR_INFO)
				EndIf
			EndIf
		Else
			SetLog("Dropping Siege/Clan Castle", $COLOR_INFO)
			SelectDropTroop($iCCSlot)
			If _Sleep($DELAYDROPCC1) Then Return
			AttackClick($iX, $iY, 1, 50, 0, "#0091")
			__RememberSpellDropPoint($iX, $iY)
		EndIf
	EndIf

EndFunc   ;==>dropCC

; The spells of the attack plan follow the heroes; when no hero is dropped the clan castle
; troops are the push, so their landing point is kept as a fallback (dropHeroes overwrites it).
Func __RememberSpellDropPoint($iX, $iY)
	If $g_aiSpellDropPoint[0] = -1 Then
		$g_aiSpellDropPoint[0] = $iX
		$g_aiSpellDropPoint[1] = $iY
	EndIf
EndFunc   ;==>__RememberSpellDropPoint
