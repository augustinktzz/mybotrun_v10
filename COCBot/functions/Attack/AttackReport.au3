; #FUNCTION# ====================================================================================================================
; Name ..........: AttackReport
; Description ...: This function will report the loot from the last Attack: gold, elixir, dark elixir and trophies.
;                  It will also update the statistics to the GUI (Last Attack).
; Syntax ........: AttackReport()
; Parameters ....: None
; Return values .: None
; Author ........: Hervidero (02-2015), Sardo (05-2015), Hervidero (12-2015)
; Modified ......: Sardo (05-2015), Hervidero (05-2015), Knowjack (07-2015), MikeD (04-2021)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func AttackReport()
	Static $iBonusLast = 0 ; last attack Bonus percentage
	Local $g_asLeagueDetailsShort = ""
	Local $iCount

	$iCount = 0 ; Reset loop counter
	While _CheckPixel($aEndFightSceneAvl, True) = False ; check for light gold pixle in the Gold ribbon in End of Attack Scene before reading values
		$iCount += 1
		If _Sleep($DELAYATTACKREPORT1) Then Return
		SetDebugLog("Waiting Attack Report Ready, " & ($iCount / 2) & " Seconds.", $COLOR_DEBUG)
		If $iCount > 30 Then ExitLoop ; wait 30*500ms = 15 seconds max for the window to render
	WEnd
	If $iCount > 30 Then SetLog("End of Attack scene slow to appear, attack values my not be correct", $COLOR_INFO)

	$iCount = 0 ; reset loop counter
	; CoC 18.600.5 moved the loot rows down: the gold digits now occupy real y 332 to 348
	; (x 358 to 449), so reading at y 319 caught only their top edge and this loop always
	; ran its full 20 rounds, burning 10 seconds after every single battle.
	While getResourcesLoot(320, 299 + $g_iMidOffsetY) = "" ; check for gold value to be non-zero before reading other values as a secondary timer to make sure all values are available
		$iCount += 1
		If _Sleep($DELAYATTACKREPORT1) Then Return
		SetDebugLog("Waiting Attack Report Ready, " & ($iCount / 2) & " Seconds.", $COLOR_DEBUG)
		If $iCount > 20 Then ExitLoop ; wait 20*500ms = 10 seconds max before we have call the OCR read an error
	WEnd
	If $iCount > 20 Then SetLog("End of Attack scene read gold error, attack values my not be correct", $COLOR_INFO)

	;HArchH: Subtracted 5 pixels from each getResourcesLoot call "x" value, 12 for DE.
	;G was 290, is 285
	;E was 290, is 285
	;DE was 365, is 353
	If __EndScreenHasDarkElixir() Then ; the dark elixir row only exists when the base had a dark elixir storage
		; Rows measured on a CoC 18.600.5 end of battle screen: gold at real y 332-348,
		; elixir at 373-389, dark elixir at 414-430, all starting around x 355.
		$g_iStatsLastAttack[$eLootGold] = getResourcesLoot(320, 299 + $g_iMidOffsetY)
		If _Sleep($DELAYATTACKREPORT2) Then Return
		$g_iStatsLastAttack[$eLootElixir] = getResourcesLoot(320, 340 + $g_iMidOffsetY)
		If _Sleep($DELAYATTACKREPORT2) Then Return
		$g_iStatsLastAttack[$eLootDarkElixir] = getResourcesLoot(320, 381 + $g_iMidOffsetY) ; same wide box as the two rows above: the digits start at x 387 and a 85 px box from 400 cut the first one
		If _Sleep($DELAYATTACKREPORT2) Then Return
		$g_iStatsLastAttack[$eLootTrophy] = 0 ; CoC 18.600 shows no trophy line on the end screen any more
		; no "[T]: 0" here: it read as "no trophy won" after a won battle, the league tier is logged below
		SetLog("Loot: [G]: " & _NumberFormat($g_iStatsLastAttack[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsLastAttack[$eLootElixir]) & " [DE]: " & _NumberFormat($g_iStatsLastAttack[$eLootDarkElixir]), $COLOR_SUCCESS)
	Else
		; Same rows as the branch above, without the dark elixir line
		$g_iStatsLastAttack[$eLootGold] = getResourcesLoot(320, 299 + $g_iMidOffsetY)
		If _Sleep($DELAYATTACKREPORT2) Then Return
		$g_iStatsLastAttack[$eLootElixir] = getResourcesLoot(320, 340 + $g_iMidOffsetY)
		If _Sleep($DELAYATTACKREPORT2) Then Return
		$g_iStatsLastAttack[$eLootTrophy] = 0 ; CoC 18.600 shows no trophy line on the end screen any more
		$g_iStatsLastAttack[$eLootDarkElixir] = ""
		SetLog("Loot: [G]: " & _NumberFormat($g_iStatsLastAttack[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsLastAttack[$eLootElixir]), $COLOR_SUCCESS)
	EndIf

	; The reward cards picked during the battle are paid straight into the storages and never
	; appear on the end of battle screen, so the lines above report the raid loot alone. Add
	; what PickBattleReward() read on the cards, and keep both figures in the log so the raid
	; loot stays readable next to the total.
	If $g_iBattleRewardGold > 0 Or $g_iBattleRewardElixir > 0 Then
		$g_iStatsLastAttack[$eLootGold] = Number($g_iStatsLastAttack[$eLootGold]) + $g_iBattleRewardGold
		$g_iStatsLastAttack[$eLootElixir] = Number($g_iStatsLastAttack[$eLootElixir]) + $g_iBattleRewardElixir
		SetLog("Battle rewards: [G]: " & _NumberFormat($g_iBattleRewardGold) & " [E]: " & _NumberFormat($g_iBattleRewardElixir), $COLOR_SUCCESS)
		SetLog("Total with rewards: [G]: " & _NumberFormat($g_iStatsLastAttack[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsLastAttack[$eLootElixir]), $COLOR_SUCCESS)
	EndIf

	If $g_iStatsLastAttack[$eLootTrophy] >= 0 Then
		$iBonusLast = Number(getResourcesBonusPerc(578, 309 + $g_iMidOffsetY))
		Local $iCheckBonusLast = StringTrimRight($iBonusLast, 1)
		If $iBonusLast > 100 And $iCheckBonusLast = 7 Then ; If % is detected as 7.
			If $g_bDebugImageSave Then SaveDebugImage("AttackReport", True)
			Local $Loop = 0
			While ($iBonusLast > 100 And $iCheckBonusLast = 7)
				If $Loop = 20 Then
					If $iBonusLast > 100 And $iCheckBonusLast = 7 Then $iBonusLast = StringTrimRight($iBonusLast, 1)
					ExitLoop
				EndIf
				$iBonusLast = Number(getResourcesBonusPerc(578, 309 + $g_iMidOffsetY))
				$iCheckBonusLast = StringTrimRight($iBonusLast, 1)
				$Loop += 1
				If _Sleep(250) Then Return
			WEnd
		EndIf
		If $iBonusLast > 0 Then
			SetLog("Bonus Percentage: " & $iBonusLast & "%")
			Local $iCalcMaxBonus = 0, $iCalcMaxBonusDark = 0

			Local $bIsEvent = IsStreakEvent()

			If _ColorCheck(_GetPixelColor($aAtkRprtDECheck2[0], $aAtkRprtDECheck2[1], True), Hex($aAtkRprtDECheck2[2], 6), $aAtkRprtDECheck2[3]) Then
				If _Sleep($DELAYATTACKREPORT2) Then Return
				$g_iStatsBonusLast[$eLootGold] = getResourcesBonus(590, 340 + $g_iMidOffsetY)
				$g_iStatsBonusLast[$eLootGold] = StringReplace($g_iStatsBonusLast[$eLootGold], "+", "")
				If _Sleep($DELAYATTACKREPORT2) Then Return
				$g_iStatsBonusLast[$eLootElixir] = getResourcesBonus(590, 371 + $g_iMidOffsetY)
				$g_iStatsBonusLast[$eLootElixir] = StringReplace($g_iStatsBonusLast[$eLootElixir], "+", "")
				If _Sleep($DELAYATTACKREPORT2) Then Return
				$g_iStatsBonusLast[$eLootDarkElixir] = getResourcesBonus(621, 402 + $g_iMidOffsetY)
				$g_iStatsBonusLast[$eLootDarkElixir] = StringReplace($g_iStatsBonusLast[$eLootDarkElixir], "+", "")

				If $iBonusLast = 100 Then
					$iCalcMaxBonus = $g_iStatsBonusLast[$eLootGold]
					If $bIsEvent Then $iCalcMaxBonus = Ceiling($iCalcMaxBonus * (100 / $iBonusLast))
					SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]) & " [DE]: " & _NumberFormat($g_iStatsBonusLast[$eLootDarkElixir]), $COLOR_SUCCESS)
				Else
					If $bIsEvent Then
						$iCalcMaxBonus = $g_iStatsBonusLast[$eLootGold]
						$iCalcMaxBonus = Ceiling($iCalcMaxBonus * (100 / $iBonusLast))
						SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]) & " [DE]: " & _NumberFormat($g_iStatsBonusLast[$eLootDarkElixir]), $COLOR_SUCCESS)
					Else
						$iCalcMaxBonus = Ceiling($g_iStatsBonusLast[$eLootGold] / ($iBonusLast / 100))
						$iCalcMaxBonusDark = Ceiling($g_iStatsBonusLast[$eLootDarkElixir] / ($iBonusLast / 100))
						SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " out of " & _NumberFormat($iCalcMaxBonus) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]) & " out of " & _NumberFormat($iCalcMaxBonus) & " [DE]: " & _NumberFormat($g_iStatsBonusLast[$eLootDarkElixir]) & " out of " & _NumberFormat($iCalcMaxBonusDark), $COLOR_SUCCESS)
					EndIf
				EndIf
			Else
				If _Sleep($DELAYATTACKREPORT2) Then Return
				$g_iStatsBonusLast[$eLootGold] = getResourcesBonus(590, 340 + $g_iMidOffsetY)
				$g_iStatsBonusLast[$eLootGold] = StringReplace($g_iStatsBonusLast[$eLootGold], "+", "")
				If _Sleep($DELAYATTACKREPORT2) Then Return
				$g_iStatsBonusLast[$eLootElixir] = getResourcesBonus(590, 371 + $g_iMidOffsetY)
				$g_iStatsBonusLast[$eLootElixir] = StringReplace($g_iStatsBonusLast[$eLootElixir], "+", "")
				$g_iStatsBonusLast[$eLootDarkElixir] = 0

				If $iBonusLast = 100 Then
					$iCalcMaxBonus = $g_iStatsBonusLast[$eLootGold]
					If $bIsEvent Then $iCalcMaxBonus = Ceiling($iCalcMaxBonus * (100 / $iBonusLast))
					SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]), $COLOR_SUCCESS)
				Else
					If $bIsEvent Then
						$iCalcMaxBonus = $g_iStatsBonusLast[$eLootGold]
						$iCalcMaxBonus = Ceiling($iCalcMaxBonus * (100 / $iBonusLast))
						SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]), $COLOR_SUCCESS)
					Else
						$iCalcMaxBonus = Ceiling($g_iStatsBonusLast[$eLootGold] / ($iBonusLast / 100))
						SetLog("Bonus [G]: " & _NumberFormat($g_iStatsBonusLast[$eLootGold]) & " out of " & _NumberFormat($iCalcMaxBonus) & " [E]: " & _NumberFormat($g_iStatsBonusLast[$eLootElixir]) & " out of " & _NumberFormat($iCalcMaxBonus), $COLOR_SUCCESS)
					EndIf
				EndIf
			EndIf
		Else
			SetLog("No Bonus")
		EndIf
		; CoC 18.600: the league is the tier read on the badge, no longer derived from the loot bonus table
		$g_asLeagueDetailsShort = LeagueTierShort($g_aiCurrentLoot[$eLootTrophy])
		SetLog("League: " & LeagueTierName($g_aiCurrentLoot[$eLootTrophy]))
	Else
		$g_iStatsBonusLast[$eLootGold] = 0
		$g_iStatsBonusLast[$eLootElixir] = 0
		$g_iStatsBonusLast[$eLootDarkElixir] = 0
		$g_asLeagueDetailsShort = "--"
	EndIf

	; check stars earned
	; CoC 18.600 end screen: three big stars behind the "Total damage" banner, an earned one is filled
	; silver-white (D7DFEC), an empty one is a dark shadow. Each is sampled on a small grid of its lower
	; body (below the damage text, above the ribbon): left 330,178 / middle 430,176 / right 530,178.
	Local $starsearned = 0
	_CaptureRegion(280, 150, 580, 210)
	If __StarEarned($aWonOneStarAtkRprt[0], $aWonOneStarAtkRprt[1]) Then $starsearned += 1
	If __StarEarned($aWonTwoStarAtkRprt[0], $aWonTwoStarAtkRprt[1]) Then $starsearned += 1
	If __StarEarned($aWonThreeStarAtkRprt[0], $aWonThreeStarAtkRprt[1]) Then $starsearned += 1
	SetLog("Stars earned: " & $starsearned)

	Local $AtkLogTxt
	$g_iStatsBonusLast[$eLootGold] = $g_iStatsBonusLast[$eLootGold] / 1000

	$AtkLogTxt = "| " & String($g_iCurAccount + 1) & "|" & _NowTime(4) & "|"
	$AtkLogTxt &= StringFormat("%6d", $g_aiCurrentLoot[$eLootTrophy]) & "|"
	$AtkLogTxt &= StringFormat("%3d", $g_iSearchCount) & "|"
	$AtkLogTxt &= StringFormat("%2d", $g_iSidesAttack) & "|"
	$AtkLogTxt &= StringFormat("%7d", $g_iStatsLastAttack[$eLootGold]) & "|"
	$AtkLogTxt &= StringFormat("%7d", $g_iStatsLastAttack[$eLootElixir]) & "|"
	$AtkLogTxt &= StringFormat("%5d", $g_iStatsLastAttack[$eLootDarkElixir]) & "|"
	$AtkLogTxt &= "  -|" ; TR: no trophy count on the CoC 18.600 end screen, the league is in the L. column
	$AtkLogTxt &= StringFormat("%2d", $starsearned) & "|"
	$AtkLogTxt &= StringFormat("%3d", $g_iPercentageDamage) & "|"
	$AtkLogTxt &= StringFormat("%5d", $g_iStatsBonusLast[$eLootGold]) & "k|"
	;$AtkLogTxt &= StringFormat("%4d", $g_iStatsBonusLast[$eLootElixir]) & "k|"
	$AtkLogTxt &= StringFormat("%4d", $g_iStatsBonusLast[$eLootDarkElixir]) & "|"
	$AtkLogTxt &= $g_asLeagueDetailsShort & "|"

	$g_iStatsBonusLast[$eLootGold] = $g_iStatsBonusLast[$eLootGold] * 1000

	; Stats Attack
	$g_sTotalDamage = $g_iPercentageDamage
	$g_sAttacksides = $g_iSidesAttack
	$g_sLootGold = $g_iStatsLastAttack[$eLootGold]
	$g_sLootElixir = $g_iStatsLastAttack[$eLootElixir]
	$g_sLootDE = $g_iStatsLastAttack[$eLootDarkElixir]
	$g_sLeague = $g_asLeagueDetailsShort
	$g_sBonusGold = $g_iStatsBonusLast[$eLootGold]
	$g_sBonusElixir = $g_iStatsBonusLast[$eLootElixir]
	$g_sBonusDE = $g_iStatsBonusLast[$eLootDarkElixir]
	$g_sStarsEarned = $starsearned

	Local $AtkLogTxtExtend
	$AtkLogTxtExtend = "|"
	$AtkLogTxtExtend &= $g_CurrentCampUtilization & "/" & $g_iTotalCampSpace & "|"
	If Int($g_iStatsLastAttack[$eLootTrophy]) >= 0 Then
		SetAtkLog($AtkLogTxt, $AtkLogTxtExtend, $COLOR_BLACK)
	Else
		SetAtkLog($AtkLogTxt, $AtkLogTxtExtend, $COLOR_ERROR)
	EndIf

	; rename or delete zombie
	If $g_bDebugDeadBaseImage Then
		setZombie($g_iStatsLastAttack[$eLootElixir])
	EndIf

	; Share Replay
	If $g_bShareAttackEnable Then
		If (Number($g_iStatsLastAttack[$eLootGold]) >= Number($g_iShareMinGold)) And (Number($g_iStatsLastAttack[$eLootElixir]) >= Number($g_iShareMinElixir)) And (Number($g_iStatsLastAttack[$eLootDarkElixir]) >= Number($g_iShareMinDark)) Then
			SetLog("Reached minimum Loot values. Share Replay")
			$g_bShareAttackEnableNow = True
		Else
			SetLog("Below minimum Loot values. No Share Replay")
			$g_bShareAttackEnableNow = False
		EndIf
	EndIf

	If $g_iFirstAttack = 0 Then $g_iFirstAttack = 1
	$g_iStatsTotalGain[$eLootGold] += $g_iStatsLastAttack[$eLootGold] + $g_iStatsBonusLast[$eLootGold]
	$g_aiTotalGoldGain[$g_iMatchMode] += $g_iStatsLastAttack[$eLootGold] + $g_iStatsBonusLast[$eLootGold]
	$g_iStatsTotalGain[$eLootElixir] += $g_iStatsLastAttack[$eLootElixir] + $g_iStatsBonusLast[$eLootElixir]
	$g_aiTotalElixirGain[$g_iMatchMode] += $g_iStatsLastAttack[$eLootElixir] + $g_iStatsBonusLast[$eLootElixir]
	If $g_iStatsStartedWith[$eLootDarkElixir] <> "" Then
		$g_iStatsTotalGain[$eLootDarkElixir] += $g_iStatsLastAttack[$eLootDarkElixir] + $g_iStatsBonusLast[$eLootDarkElixir]
		$g_aiTotalDarkGain[$g_iMatchMode] += $g_iStatsLastAttack[$eLootDarkElixir] + $g_iStatsBonusLast[$eLootDarkElixir]
	EndIf
	$g_iStatsTotalGain[$eLootTrophy] += $g_iStatsLastAttack[$eLootTrophy]
	$g_aiTotalTrophyGain[$g_iMatchMode] += $g_iStatsLastAttack[$eLootTrophy]
	$g_aiAttackedVillageCount[$g_iMatchMode] += 1
	UpdateStats()
	UpdateSDataBase()
	If ProfileSwitchAccountEnabled() Then
		SetSwitchAccLog(" - Acc. " & $g_iCurAccount + 1 & ", Attack: " & $g_aiAttackedCount)
	EndIf
	$g_iActualTrainSkip = 0
	$g_iPercentageDamage = 0
	$g_iBattleRewardGold = 0
	$g_iBattleRewardElixir = 0
	$g_bBattleRewardTaken = False
	$g_iBattleRewardScans = 0
	$g_iSidesAttack = 0

EndFunc   ;==>AttackReport

Func IsStreakEvent()
	Local $offColors[3][3] = [[0xFFFFFF, 12, 7], [0x000000, 23, 0], [0x000000, 12, 12]] ; 2nd pixel White Color, 3rd pixel Black right edge of cross, 4th pixel Black bottom edge of cross
	Local $WhiteCross = _MultiPixelSearch(623, 295, 655, 310, 1, 1, Hex(0x000000, 6), $offColors, 30) ; first black pixel on side of cross
	SetDebugLog("Pixel Color #1: " & _GetPixelColor(627, 295, True) & ", #2: " & _GetPixelColor(639, 302, True) & ", #3: " & _GetPixelColor(650, 295, True) & ", #4: " & _GetPixelColor(639, 307, True), $COLOR_DEBUG)
	If IsArray($WhiteCross) Then Return True
	Return False
EndFunc   ;==>IsStreakEvent

; True when the 5x5 sample grid (step 4) around the point is mostly white: an earned star of the
; CoC 18.600 end screen. Yellow ribbon and green text fail the whiteness test (min channel > 180).
; Reads the last capture (absolute screen coordinates).
Func __StarEarned($iX, $iY)
	Local $iWhite = 0
	For $dy = -8 To 8 Step 4
		For $dx = -8 To 8 Step 4
			Local $sCol = _GetPixelColor($iX + $dx - 280, $iY + $dy - 150, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 180 And $iG > 180 And $iB > 180 Then $iWhite += 1
		Next
	Next
	SetDebugLog("Star at " & $iX & "," & $iY & ": " & $iWhite & "/25 white samples", $COLOR_DEBUG)
	Return $iWhite >= 15
EndFunc   ;==>__StarEarned

; True when the end of battle screen shows a dark elixir row. The three "You got" icons stand at x 478:
; gold coin (y 336), elixir drop (y 378) and the dark purple dark elixir drop (y 414-430). Counting the
; purple samples of that last icon tells the row apart: a base without dark elixir storage has none.
; Measured on live end screens: 152 to 239 samples when the row is there, 0 to 3 when it is not.
Func __EndScreenHasDarkElixir()
	_CaptureRegion(465, 408, 495, 432)
	Local $iPurple = 0
	For $y = 0 To 24
		For $x = 0 To 30
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 40 And $iR < 140 And $iG > 25 And $iG < 115 And $iB > 55 And $iB < 150 And $iB > $iG + 15 And $iR > $iG + 5 Then $iPurple += 1
		Next
	Next
	SetDebugLog("End screen dark elixir drop: " & $iPurple & " purple samples (>= 60 means the row is there)", $COLOR_DEBUG)
	Return ($iPurple >= 60)
EndFunc   ;==>__EndScreenHasDarkElixir
