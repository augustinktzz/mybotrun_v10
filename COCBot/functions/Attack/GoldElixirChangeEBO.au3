; #FUNCTION# ====================================================================================================================
; Name ..........: GoldElixirChangeEBO  (End Battle Options)
; Description ...: Checks if the gold/elixir changes , Returns True if changed.
; Syntax ........: GoldElixirChangeEBO()
; Parameters ....:
; Return values .: None
; Author ........:
; Modified ......: Sardo (06-2015), Fliegerfaust (01-2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:v
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: IsBattleRewardPopupOpen
; Description ...: True while the "Pick a Reward!" panel of CoC 18.600.5 covers the battle
; Syntax ........: IsBattleRewardPopupOpen()
; Return values .: True when the red banner is on screen
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  Measured on live captures: the banner spans real x 220-644 around y 128-178 and
;                  gives about 44 strictly red samples at this sampling rate, while the village, the
;                  attack window, the army window and the end of battle screen all give none. Reads
;                  the bitmap already captured by the caller, so it costs well under 200 samples.
; ===============================================================================================================================
Func IsBattleRewardPopupOpen()
	Local $iRed = 0
	For $x = 230 To 640 Step 20
		For $y = 128 To 176 Step 6
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) < 6 Then ContinueLoop
			If Dec(StringMid($sCol, 1, 2)) > 150 And Dec(StringMid($sCol, 3, 2)) < 70 And Dec(StringMid($sCol, 5, 2)) < 70 Then $iRed += 1
		Next
	Next
	Return ($iRed > 12)
EndFunc   ;==>IsBattleRewardPopupOpen

; #FUNCTION# ====================================================================================================================
; Name ..........: PickBattleReward
; Description ...: Takes the resource card of the CoC 18.600.5 in battle reward panel
; Syntax ........: PickBattleReward()
; Return values .: True when a card was clicked
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  Three cards sit at real x 200, 432 and 663, their icon filling roughly the centre
;                  of each card between y 305 and 395. Gold reads as bright yellow and elixir as
;                  magenta (measured 0xF615FF, 230 hits on the elixir card against 18 and 0 on the
;                  two troop cards). Gold is preferred, elixir is taken when no gold is offered,
;                  dark elixir when neither is.
;                  The reward order is random, so the card is identified by its icon, never by rank.
; ===============================================================================================================================
Func PickBattleReward()
	Local $aiCardX[3] = [200, 432, 663]
	Local $aiGold[3] = [0, 0, 0], $aiElixir[3] = [0, 0, 0], $aiDark[3] = [0, 0, 0]

	; The red banner is on screen before the three cards have finished sliding in, and the logs
	; showed the icon scan running on half drawn cards (all counts at zero, or a lone 2 to 8).
	; Give the animation a moment and use a fresh capture, the caller's one is already stale.
	If _Sleep(900) Then Return False
	_CaptureRegion()

	For $i = 0 To 2
		For $x = $aiCardX[$i] - 45 To $aiCardX[$i] + 45 Step 6
			For $y = 305 To 395 Step 6
				Local $sCol = _GetPixelColor($x, $y, False)
				If StringLen($sCol) < 6 Then ContinueLoop
				Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
				If $iR > 200 And $iG > 140 And $iG < 235 And $iB < 110 Then $aiGold[$i] += 1
				If $iR > 150 And $iG < 120 And $iB > 150 Then $aiElixir[$i] += 1
				; dark elixir drop: the dark purple measured on the end of battle screen (__EndScreenHasDarkElixir)
				If $iR > 40 And $iR < 140 And $iG > 25 And $iG < 115 And $iB > 55 And $iB < 150 And $iB > $iG + 15 And $iR > $iG + 5 Then $aiDark[$i] += 1
			Next
		Next
	Next
	SetDebugLog("Battle reward cards, gold: " & $aiGold[0] & "/" & $aiGold[1] & "/" & $aiGold[2] & _
			", elixir: " & $aiElixir[0] & "/" & $aiElixir[1] & "/" & $aiElixir[2] & _
			", dark: " & $aiDark[0] & "/" & $aiDark[1] & "/" & $aiDark[2], $COLOR_DEBUG)

	; Gold first, then elixir. A card needs a clear majority to avoid the faint tints the
	; troop artwork carries, the elixir card measured 230 against 18 on its best rival.
	Local $iBest = -1, $sWhat = ""
	For $i = 0 To 2
		If $aiGold[$i] >= 25 And ($iBest = -1 Or $aiGold[$i] > $aiGold[$iBest]) Then
			$iBest = $i
			$sWhat = "gold"
		EndIf
	Next
	If $iBest = -1 Then
		For $i = 0 To 2
			If $aiElixir[$i] >= 25 And ($iBest = -1 Or $aiElixir[$i] > $aiElixir[$iBest]) Then
				$iBest = $i
				$sWhat = "elixir"
			EndIf
		Next
	EndIf

	; Dark elixir when neither gold nor elixir is offered (2 Oct, 22:33: three scans of a panel read
	; "gold: 1/0/0, elixir: 0/0/0" and nothing was taken). No dark elixir card was captured yet, so the
	; bar is the one of the end screen drop (>= 60 purple samples) and the card must beat both others
	; twice over: purple troop artwork (witch, minion) must not be taken for it.
	If $iBest = -1 Then
		For $i = 0 To 2
			If $aiDark[$i] < 60 Then ContinueLoop
			Local $bClear = True
			For $j = 0 To 2
				If $j <> $i And $aiDark[$j] * 2 > $aiDark[$i] Then $bClear = False
			Next
			If $bClear Then
				$iBest = $i
				$sWhat = "dark elixir"
			EndIf
		Next
	EndIf

	If $iBest = -1 Then
		SetLog("Battle reward offered no gold, elixir or dark elixir, leaving it", $COLOR_INFO)
		Return False
	EndIf

	; The amount is printed across the icon in the very font and size the end of battle report
	; uses: "254 588" measured 91x16 pixels on the card against 90x17 on the report screen, so
	; the loot OCR reads it unchanged. It is centred on the card, hence the fixed 68 pixel
	; offset, and it has to be read before the click because the panel closes straight after.
	Local $sAmount = getResourcesLoot($aiCardX[$iBest] - 68, 383)
	Local $iAmount = Number(StringRegExpReplace($sAmount, "[^0-9]", ""))
	; A card never pays less than a few thousand, anything smaller is a glyph caught on a moving card.
	; Dark elixir pays about a hundred times less, it is only logged (the battle stats add gold and elixir).
	If $sWhat = "dark elixir" Then
		If $iAmount >= 10 And $iAmount < 50000 Then
			SetLog("Taking the dark elixir battle reward: " & _NumberFormat($iAmount), $COLOR_SUCCESS)
		Else
			SetLog("Taking the dark elixir battle reward, amount unreadable [" & $sAmount & "]", $COLOR_INFO)
		EndIf
	ElseIf $iAmount >= 1000 And $iAmount < 2000000 Then
		If $sWhat = "gold" Then
			$g_iBattleRewardGold += $iAmount
		Else
			$g_iBattleRewardElixir += $iAmount
		EndIf
		SetLog("Taking the " & $sWhat & " battle reward: " & _NumberFormat($iAmount), $COLOR_SUCCESS)
	Else
		SetLog("Taking the " & $sWhat & " battle reward, amount unreadable [" & $sAmount & "]", $COLOR_INFO)
	EndIf
	Click($aiCardX[$iBest], 380, 1, 120, "#0152")
	If _Sleep(1500) Then Return False
	Return True
EndFunc   ;==>PickBattleReward

; #FUNCTION# ====================================================================================================================
; Name ..........: HandleBattleReward
; Description ...: Detects the in battle reward panel and takes one card per panel
; Syntax ........: HandleBattleReward()
; Return values .: True while the panel covers the screen
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  The panel shows twice per battle, around 33% and 77% destruction, and stays a
;                  few seconds after a card has been taken as well as when it only offers troops
;                  and nothing is worth clicking. $g_bBattleRewardTaken keeps a single panel from
;                  being picked, and counted, twice, and is cleared as soon as the panel is gone.
; ===============================================================================================================================
Func HandleBattleReward()
	If Not IsBattleRewardPopupOpen() Then
		$g_bBattleRewardTaken = False
		$g_iBattleRewardScans = 0
		Return False
	EndIf
	If Not $g_bBattleRewardTaken Then
		; A scan that finds no card yet (still animating) or no resource card is retried on the
		; next loop while the panel is up; after three scans the panel is left alone for good.
		$g_iBattleRewardScans += 1
		If PickBattleReward() Or $g_iBattleRewardScans >= 3 Then $g_bBattleRewardTaken = True
	EndIf
	Return True
EndFunc   ;==>HandleBattleReward

Func GoldElixirChangeEBO()
	Local $Gold1, $Gold2
	Local $GoldChange, $ElixirChange
	Local $Elixir1, $Elixir2
	Local $DarkElixir1, $DarkElixir2
	Local $DarkElixirChange
	Local $Trophies
	Local $txtDiff
	Local $exitOneStar = 0, $exitTwoStars = 0
	Local $Damage, $CurDamage
	$g_iDarkLow = 0

	; The reward panel blanks out the loot readings below, and the empty values used to be
	; read as "nothing changed any more", which ended the attack around 33% destruction.
	; Take the reward and report the battle as still running so the attack carries on.
	_CaptureRegion()
	If HandleBattleReward() Then Return True

	;READ RESOURCES n.1
	$Gold1 = getGoldVillageSearch(48, 69 + 7)
	$Elixir1 = getElixirVillageSearch(48, 69 + 29 + 7)
	$Damage = getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY)
	If Number($Damage) > Number($g_iPercentageDamage) Then $g_iPercentageDamage = Number($Damage)
	; CoC 18.600 dropped the trophy line that used to reveal a dark elixir row below it, so the
	; dark elixir drop icon is checked directly, as the search screen already does
	$Trophies = ""
	If _CheckPixel($aAtkHasDarkElixir, $g_bCapturePixel, Default, "HasDarkElixir1") Then
		If _Sleep($DELAYGOLDELIXIRCHANGEEBO1) Then Return
		$DarkElixir1 = getDarkElixirVillageSearch(48, 69 + 57 + 7)
	Else
		$DarkElixir1 = ""
	EndIf

	;CALCULATE WHICH TIMER TO USE
	Local $x = $g_aiStopAtkNoLoot1Time[$g_iMatchMode] * 1000, $y = $g_aiStopAtkNoLoot2Time[$g_iMatchMode] * 1000, $z, $w = $g_aiStopAtkPctNoChangeTime[$g_iMatchMode] * 1000
	; A wait of 0 s is a profile saved before its settings were read (GUI profile-repair.js puts 20 / 15 / 7
	; back): every check then lasted the 1.5 s between two reads ("Wait: 0" on the 2 Oct 22:33 log) and a
	; troop walking between two storages for 2 s ended the battle at 61% with gold and elixir still coming.
	If $x <= 0 Then $x = ($g_iMatchMode = $DB ? 15000 : 20000)
	If $y <= 0 Then $y = 7000
	If Number($Gold1) < $g_aiStopAtkNoLoot2MinGold[$g_iMatchMode] And _
			Number($Elixir1) < $g_aiStopAtkNoLoot2MinElixir[$g_iMatchMode] And _
			Number($DarkElixir1) < $g_aiStopAtkNoLoot2MinDark[$g_iMatchMode] And _
			$g_abStopAtkNoLoot2Enable[$g_iMatchMode] Then

		$z = $y
	ElseIf $Damage <> "" And $g_abStopAtkPctNoChangeEnable[$g_iMatchMode] Then
		$z = $w
	Else
		If $g_abStopAtkNoLoot1Enable[$g_iMatchMode] Then
			$z = $x
		Else
			$z = AttackRemainingTime()
		EndIf
	EndIf

	;CALCULATE TWO STARS REACH
	If $g_abStopAtkTwoStars[$g_iMatchMode] And _CheckPixel($aWonTwoStar, True) Then
		SetLog("Two Star Reach, exit", $COLOR_SUCCESS)
		$exitTwoStars = 1
		$z = 0
	EndIf

	;CALCULATE ONE STARS REACH
	If $g_abStopAtkOneStar[$g_iMatchMode] And _CheckPixel($aWonOneStar, True) Then
		SetLog("One Star Reach, exit", $COLOR_SUCCESS)
		$exitOneStar = 1
		$z = 0
	EndIf

	; Early Check if Percentage is alreay higher than set
	If $g_abStopAtkPctHigherEnable[$g_iMatchMode] And Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY)) > Number($g_aiStopAtkPctHigherAmt[$g_iMatchMode]) Then
		SetLog("Overall Damage above " & Number($g_aiStopAtkPctHigherAmt[$g_iMatchMode]), $COLOR_SUCCESS)
		$g_iPercentageDamage = Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY))
		$z = 0
	EndIf

	Local $NoResourceOCR = False
	Local $bRewardPanel = False
	Local $ExitNoLootChange = ($g_abStopAtkNoLoot1Enable[$g_iMatchMode] Or $g_abStopAtkNoLoot2Enable[$g_iMatchMode] Or $g_abStopAtkNoResources[$g_iMatchMode])

	;MAIN LOOP
	Local $iBegin = __TimerInit()

	Local $iSuspendAndroidTimeOffset = SuspendAndroidTime()
	SetDebugLog("GoldElixirChangeEBO: Start waiting for battle end, Wait: " & $z & ", Offset: " & $iSuspendAndroidTimeOffset)

	Local $iTime = 0
	Local $bOneLoop = True
	While $bOneLoop Or ($iTime < $z And $z > 0 And $iTime >= 0)
		$bOneLoop = False
		;HEALTH HEROES
		CheckHeroesHealth()

		;DE SPECIAL END EARLY
		If $g_iMatchMode = $LB And $g_aiAttackStdDropSides[$LB] = 4 And $g_bDESideEndEnable Then
			If $g_bDropQueen Or $g_bDropKing Then DELow()
			If $g_iDarkLow = 1 Then ExitLoop
		EndIf
		If $g_bCheckKingPower Or $g_bCheckQueenPower Or $g_iDarkLow = 2 Then
			If _Sleep($DELAYGOLDELIXIRCHANGEEBO1) Then Return
		Else
			If _Sleep($DELAYGOLDELIXIRCHANGEEBO2) Then Return
		EndIf

		;--> Read Ressources #2
		; The reward panel dims the whole screen: the loot digits drop from 43 white samples
		; to zero, so the OCR below returns nothing and the empty values used to be taken as
		; "the loot stopped changing", ending the attack around 33% destruction. This check
		; belongs inside the loop, the panel appears while it is already running.
		_CaptureRegion()
		$bRewardPanel = HandleBattleReward()

		$Gold2 = getGoldVillageSearch(48, 69 + 7)
		If $Gold2 = "" Then
			If _Sleep($DELAYGOLDELIXIRCHANGEEBO1) Then Return
			$Gold2 = getGoldVillageSearch(48, 69 + 7)
		EndIf
		$Elixir2 = getElixirVillageSearch(48, 69 + 29 + 7)
		CheckHeroesHealth()
		If _CheckPixel($aAtkHasDarkElixir, $g_bCapturePixel, Default, "HasDarkElixir2") Then ; dark elixir drop icon, the trophy line is gone since CoC 18.600
			If _Sleep($DELAYGOLDELIXIRCHANGEEBO1) Then Return
			$DarkElixir2 = getDarkElixirVillageSearch(48, 69 + 57 + 7)
		Else
			$DarkElixir2 = ""
		EndIf
		$CurDamage = getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY)
		;--> Read Ressources #2

		CheckHeroesHealth()

		;WRITE LOG
		$txtDiff = Round(($z - (__TimerDiff($iBegin) - SuspendAndroidTime() + $iSuspendAndroidTimeOffset)) / 1000, 0)
		If Number($txtDiff) < 0 Then
			$txtDiff = "0s"
		Else
			Local $m = Int($txtDiff / 60)
			Local $s = $txtDiff - $m * 60
			$txtDiff = ""
			If $m > 0 Then $txtDiff = $m & "m "
			$txtDiff &= $s & "s"
		EndIf
		; The panel dims the whole screen, so the three reads above come back empty while it is
		; up. Without this guard a panel offering only troops, which is left on screen, is read
		; as "the loot stopped changing" and the battle is ended around 33% destruction.
		$NoResourceOCR = Not $bRewardPanel And StringLen($Gold2) = 0 And StringLen($Elixir2) = 0 And StringLen($DarkElixir2) = 0
		If $NoResourceOCR Then
			SetLog("Exit now, [G]: " & $Gold2 & " [E]: " & $Elixir2 & " [DE]: " & $DarkElixir2 & " [%]: " & $CurDamage, $COLOR_INFO)
		Else
			If $g_bDebugSetLog Then
				SetDebugLog("Exit in " & $txtDiff & ", [G]: " & $Gold2 & " [E]: " & $Elixir2 & " [DE]: " & $DarkElixir2 & " [%]: " & $CurDamage & ", Suspend-Time: " & $g_iSuspendAndroidTime & ", Suspend-Count: " & $g_iSuspendAndroidTimeCount & ", Offset: " & $iSuspendAndroidTimeOffset, $COLOR_INFO)
			Else
				SetLog("Exit in " & $txtDiff & ", [G]: " & $Gold2 & " [E]: " & $Elixir2 & " [DE]: " & $DarkElixir2 & " [%]: " & $CurDamage, $COLOR_INFO)
			EndIf
		EndIf

		If Number($CurDamage) > Number($g_iPercentageDamage) Then $g_iPercentageDamage = Number($CurDamage)

		If Number($CurDamage) >= 92 Then

			If $g_iKingSlot >= 11 Or $g_iQueenSlot >= 11 Or $g_iPrinceSlot >= 11 Or $g_iWardenSlot >= 11 Or $g_iChampionSlot >= 11 Or $g_iDukeSlot >= 11 Then
				If Not $g_bDraggedAttackBar Then DragAttackBar($g_iTotalAttackSlot, False) ; drag forward
			Else
				If $g_iKingSlot >= 0 Or $g_iQueenSlot >= 0 Or $g_iPrinceSlot >= 0 Or $g_iWardenSlot >= 0 Or $g_iChampionSlot >= 0 Or $g_iDukeSlot >= 0 Then
					If $g_bDraggedAttackBar Then DragAttackBar($g_iTotalAttackSlot, True) ; return drag
				EndIf
			EndIf

			If ($g_bCheckKingPower Or $g_bCheckQueenPower Or $g_bCheckPrincePower Or $g_bCheckWardenPower Or $g_bCheckChampionPower Or $g_bCheckDukePower) Then
				If $g_bCheckKingPower And $g_iActivateKing = 0 Then
					SetLog("Activating King's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iKingSlot) ;If King was not activated: Boost King before Battle ends with a 3 Star
					$g_bCheckKingPower = False
				EndIf
				If $g_bCheckQueenPower And $g_iActivateQueen = 0 Then
					SetLog("Activating Queen's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iQueenSlot) ;If Queen was not activated: Boost Queen before Battle ends with a 3 Star
					$g_bCheckQueenPower = False
				EndIf
				If $g_bCheckPrincePower And $g_iActivatePrince = 0 Then
					SetLog("Activating Prince's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iPrinceSlot) ;If Prince was not activated: Boost Prince before Battle ends with a 3 Star
					$g_bCheckPrincePower = False
				EndIf
				If $g_bCheckWardenPower And $g_iActivateWarden = 0 Then
					SetLog("Activating Warden's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iWardenSlot) ;If Queen was not activated: Boost Queen before Battle ends with a 3 Star
					$g_bCheckWardenPower = False
				EndIf
				If $g_bCheckChampionPower And $g_iActivateChampion = 0 Then
					SetLog("Activating Royal Champion's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iChampionSlot) ;If Champion was not activated: Boost Champion before Battle ends with a 3 Star
					$g_bCheckChampionPower = False
				EndIf
				If $g_bCheckDukePower And $g_iActivateDuke = 0 Then
					SetLog("Activating Dragon Duke's ability to restore some health before leaving with a 3 Star", $COLOR_INFO)
					If IsAttackPage() Then SelectDropTroop($g_iDukeSlot) ;If Duke was not activated: Boost Duke before Battle ends with a 3 Star
					$g_bCheckDukePower = False
				EndIf
			EndIf
		EndIf


		;CALCULATE RESOURCE CHANGES
		If $Gold2 <> "" Or $Elixir2 <> "" Or $DarkElixir2 <> "" Then
			$GoldChange = $Gold2
			$ElixirChange = $Elixir2
			$DarkElixirChange = $DarkElixir2
		EndIf

		;EXIT IF RESOURCES = 0
		If $g_abStopAtkNoResources[$g_iMatchMode] And Number($Gold2) = 0 And Number($Elixir2) = 0 And Number($DarkElixir2) = 0 Then
			SetLog("Gold & Elixir & DE = 0, end battle ", $COLOR_SUCCESS)
			If _Sleep($DELAYGOLDELIXIRCHANGEEBO2) Then Return
			ExitLoop
		EndIf

		;EXIT IF TWO STARS REACH
		If $g_abStopAtkTwoStars[$g_iMatchMode] And _CheckPixel($aWonTwoStar, True) Then
			SetLog("Two Star Reach, exit", $COLOR_SUCCESS)
			$exitTwoStars = 1
			ExitLoop
		EndIf

		;EXIT IF ONE STARS REACH
		If $g_abStopAtkOneStar[$g_iMatchMode] And _CheckPixel($aWonOneStar, True) Then
			SetLog("One Star Reach, exit", $COLOR_SUCCESS)
			$exitOneStar = 1
			ExitLoop
		EndIf

		;EXIT LOOP IF RESOURCES = "" ... battle end (dark elixir still shown means the battle goes on)
		If $DarkElixir2 = "" And getGoldVillageSearch(48, 69 + 7) = "" And getElixirVillageSearch(48, 69 + 29 + 7) = "" Then
			ExitLoop
		EndIf

		If $g_abStopAtkPctHigherEnable[$g_iMatchMode] And Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY)) > Number($g_aiStopAtkPctHigherAmt[$g_iMatchMode]) Then
			SetLog("Overall Damage above " & Number($g_aiStopAtkPctHigherAmt[$g_iMatchMode]) & ", exit", $COLOR_SUCCESS)
			$g_iPercentageDamage = Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY))
			ExitLoop
		EndIf

		;RETURN IF RESOURCES CHANGE DETECTED
		If ($g_abStopAtkNoLoot1Enable[$g_iMatchMode] Or $g_abStopAtkNoLoot2Enable[$g_iMatchMode]) And ($Gold1 <> $Gold2 Or $Elixir1 <> $Elixir2 Or $DarkElixir1 <> $DarkElixir2) Then
			SetLog("Gold & Elixir & DE change detected, waiting...", $COLOR_SUCCESS)
			Return True
		EndIf

		;RETURN IF DAMAGE CHANGE DETECTED
		If $g_abStopAtkPctNoChangeEnable[$g_iMatchMode] And (Number($Damage) <> Number($CurDamage)) Then
			SetLog("Overall Damage Percentage change detected, waiting...", $COLOR_SUCCESS)
			$g_iPercentageDamage = Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY))
			Return True
		EndIf

		$iTime = __TimerDiff($iBegin) - SuspendAndroidTime() + $iSuspendAndroidTimeOffset
	WEnd ; END MAIN LOOP

	;Priority Check... Exit To protect Hero Health
	If $g_iMatchMode = $LB And $g_aiAttackStdDropSides[$LB] = 4 And $g_bDESideEndEnable And $g_iDarkLow = 1 Then
		SetLog("Returning Now -DE-", $COLOR_SUCCESS)
		Return False
	EndIf

	;FIRST CHECK... EXIT FOR ONE STAR REACH
	If $g_abStopAtkOneStar[$g_iMatchMode] And $exitOneStar = 1 Then
		If _Sleep($DELAYGOLDELIXIRCHANGEEBO2) Then Return
		Return False
	EndIf

	;SECOND CHECK... EXIT FOR TWO STARS REACH
	If $g_abStopAtkTwoStars[$g_iMatchMode] And $exitTwoStars = 1 Then
		If _Sleep($DELAYGOLDELIXIRCHANGEEBO2) Then Return
		Return False
	EndIf

	;THIRD CHECK... IF VALUES= "" REREAD AND RETURN FALSE IF = ""
	If ($NoResourceOCR = True) Then
		SetLog("Battle has finished", $COLOR_SUCCESS)
		Return False ;end battle
	EndIf

	If $g_abStopAtkPctHigherEnable[$g_iMatchMode] And Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY)) > Number($g_aiStopAtkPctHigherAmt[$g_iMatchMode]) Then
		$g_iPercentageDamage = Number(getOcrOverAllDamage(780, 527 + $g_iBottomOffsetY))
		Return False
	EndIf

	;FOURTH CHECK... IF RESOURCES = 0 THEN EXIT
	If $g_abStopAtkNoResources[$g_iMatchMode] And $NoResourceOCR = False And Number($Gold2) = 0 And Number($Elixir2) = 0 And Number($DarkElixir2) = 0 Then
		SetLog("Gold & Elixir & DE = 0, end battle ", $COLOR_SUCCESS)
		If _Sleep($DELAYGOLDELIXIRCHANGEEBO2) Then Return
		Return False
	EndIf

	If $g_abStopAtkPctNoChangeEnable[$g_iMatchMode] And Number($Damage) = Number($CurDamage) Then
		SetLog("No Overall Damage Percentage change detected, exit", $COLOR_SUCCESS)
		Return False
	EndIf


	;FIFTH CHECK... IF VALUES NOT CHANGED  RETURN FALSE ELSE RETURN TRUE
	If (Number($Gold1) = Number($Gold2) And Number($Elixir1) = Number($Elixir2) And Number($DarkElixir1) = Number($DarkElixir2)) Then
		If $g_abStopAtkNoLoot1Enable[$g_iMatchMode] Or $g_abStopAtkNoLoot2Enable[$g_iMatchMode] Then
			SetLog("Gold & Elixir & DE no change detected, exit", $COLOR_SUCCESS)
			Return False
		Else
			SetLog("Gold & Elixir & DE no change detected, waiting...", $COLOR_SUCCESS)
		EndIf
	Else
		If $g_bDebugSetLog Then
			SetDebugLog("Gold1: " & Number($Gold1) & "  Gold2: " & Number($Gold2), $COLOR_DEBUG)
			SetDebugLog("Elixir1: " & Number($Elixir1) & "  Elixir2: " & Number($Elixir2), $COLOR_DEBUG)
			SetDebugLog("Dark Elixir1: " & Number($DarkElixir1) & "  Dark Elixir2: " & Number($DarkElixir2), $COLOR_DEBUG)
		EndIf
	EndIf

	Return True

EndFunc   ;==>GoldElixirChangeEBO
