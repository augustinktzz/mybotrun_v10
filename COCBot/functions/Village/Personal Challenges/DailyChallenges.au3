; #FUNCTION# ====================================================================================================================
; Name ..........: DailyChallenges()
; Description ...: Daily Challenges
; Author ........: TripleM (04/2019), Demen (07/2019)
; Modified ......: Moebius14 (04-2024)
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: DailyChallenges()
; ===============================================================================================================================
#include-once

;[11:11:58 AM] Collecting Daily Rewards...
;[11:11:59 AM] Dragging back for more... [11:12:02 AM] Storage full. Cancelling to sell it
;[11:12:03 AM] Storage full. Cancelling to sell it


Func DailyChallenges()
	Local Static $asLastTimeChecked[8]
	If $g_bFirstStart Then $asLastTimeChecked[$g_iCurAccount] = ""

	checkMainScreen(False)
	Local $bGoldPass = False
	Local $bButton = __PassButtonRead($bGoldPass) ; shield button at the bottom left of the main screen

	; Check at least one pet upgrade is enabled
	Local $bUpgradePets = False
	For $i = 0 To $ePetCount - 1
		If $g_bUpgradePetsEnable[$i] Then
			$bUpgradePets = True
		EndIf
	Next

	Local $bCheckDiscount = $bGoldPass And ($g_bUpgradeKingEnable Or $g_bUpgradeQueenEnable Or $g_bUpgradePrinceEnable Or $g_bUpgradeWardenEnable Or $g_bUpgradeChampionEnable Or $g_bAutoUpgradeWallsEnable Or $bUpgradePets)

	If Not $g_bChkCollectRewards And Not $bCheckDiscount Then Return
	If Not $bButton Then ; nothing to click: say so once instead of walking into the open routine
		SetDebugLog("Season pass button not on screen, personal challenges skipped", $COLOR_DEBUG)
		Return
	EndIf
	Local $bRedSignal = __PassButtonHasBadge()

	If _DateIsValid($asLastTimeChecked[$g_iCurAccount]) Then
		Local $iLastCheck = _DateDiff('n', $asLastTimeChecked[$g_iCurAccount], _NowCalc()) ; elapse time from last check (minutes)
		SetDebugLog("LastCheck: " & $asLastTimeChecked[$g_iCurAccount] & ", Check DateCalc: " & $iLastCheck & ", $bRedSignal: " & $bRedSignal, $COLOR_DEBUG)
		; the parentheses used to sit around the whole comparison, so the test was always true and the
		; window was opened once per bot start only
		If $iLastCheck <= ($bRedSignal ? 180 : 360) Then Return ; A check each 3 hours or 6 hours [6*60 = 360]
	EndIf

	; Stamp the attempt whether it worked or not: a failure used to be retried on every single pass of
	; the bot, which is what filled the log with "Can't find button" over and over.
	$asLastTimeChecked[$g_iCurAccount] = _NowCalc()

	If OpenPersonalChallenges() Then
		CollectDailyRewards($bGoldPass)
		If $bCheckDiscount Then CheckDiscountPerks()

		If _Sleep(1000) Then Return
		ClosePersonalChallenges()
	EndIf
EndFunc   ;==>DailyChallenges

; CoC 18.600 redrew the season pass button of the main screen: it is the shield at x 124-197,
; y 646-715, light blue-grey inside, framed in gold while the Gold Pass is active. The Jun-2023
; probes read a single pixel at 149,691 expecting B7D0E4 or FDE575 and always found 86B1D2 there,
; which is why every pass logged "Can't find button". Counting the shield pixels instead survives
; the timer text, the red badge and both frame colours.
Func __PassButtonRead(ByRef $bGoldPass)
	$bGoldPass = False
	_CaptureRegion(124, 646, 198, 716)
	Local $iShield = 0, $iGold = 0
	For $x = 132 To 188 Step 2
		For $y = 652 To 704 Step 2
			Local $sCol = _GetPixelColor($x - 124, $y - 646, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iB > 140 And $iB >= $iG + 10 And $iG >= $iR + 5 And $iR > 90 Then $iShield += 1 ; pale blue shield
		Next
	Next
	For $x = 130 To 190 Step 2
		For $y = 650 To 662 Step 2
			Local $sCol = _GetPixelColor($x - 124, $y - 646, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 190 And $iG > 120 And $iG < 215 And $iB < 120 And $iR > $iB + 90 Then $iGold += 1 ; golden frame
		Next
	Next
	$bGoldPass = ($iGold >= 60)
	SetDebugLog("Season pass button: " & $iShield & " shield samples (>= 120 means found), " & $iGold & " golden frame samples (>= 60 means Gold Pass)", $COLOR_DEBUG)
	Return ($iShield >= 120)
EndFunc   ;==>__PassButtonRead

; The season pass window of CoC 18.600 fills the whole screen and carries a single red X at
; x 806-841, y 23-55 (488 red pixels there when it is open, none on the main screen or on the
; Events window). The Jun-2023 probe looked for that X at 827,130, where the window now shows
; the Pass Rewards / Perks / Hoggy Bank tab strip.
Func __PassWindowOpen()
	_CaptureRegion(800, 18, 846, 61)
	Local $iRed = 0
	For $x = 0 To 45
		For $y = 0 To 42
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 170 And $iG < 80 And $iB < 80 Then $iRed += 1
		Next
	Next
	SetDebugLog("Season pass window: " & $iRed & " red samples on the close button (>= 200 means open)", $COLOR_DEBUG)
	Return ($iRed >= 200)
EndFunc   ;==>__PassWindowOpen

; Red "n" badge pinned on the top right corner of the same button when something can be claimed.
Func __PassButtonHasBadge()
	_CaptureRegion(172, 642, 202, 672)
	Local $iRed = 0
	For $x = 0 To 29
		For $y = 0 To 29
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 150 And $iG < 90 And $iB < 90 And $iR > $iG + 80 Then $iRed += 1
		Next
	Next
	Return ($iRed >= 60)
EndFunc   ;==>__PassButtonHasBadge

Func OpenPersonalChallenges()
	SetLog("Opening personal challenges", $COLOR_INFO)
	Local $bGoldPass = False
	If Not __PassButtonRead($bGoldPass) Then
		SetLog("Season pass button not found on the main screen", $COLOR_ERROR)
		SaveFailureImage("PersonalChallengeButton")
		Return False
	EndIf
	Click(160, 680, 1, 120, "#0666")

	Local $counter = 0
	While Not __PassWindowOpen() ; test for the red X of the season pass window
		SetDebugLog("Wait for Personal Challenge Close Button to appear #" & $counter)
		If _Sleep($DELAYRUNBOT6) Then Return
		$counter += 1
		If $counter > 20 Then ; 20 rounds is plenty, and leaving a window open blocks everything else
			SetLog("Season pass window did not open", $COLOR_ERROR)
			SaveFailureImage("PersonalChallengeWindow")
			ClickAway("Right")
			Return False
		EndIf
	WEnd

	Local $OkayButton = decodeSingleCoord(FindImageInPlace2("OkayButton", $g_sImgOkayDailyChallenge, 370, 520 + $g_iMidOffsetY, 490, 590 + $g_iMidOffsetY, True))
	If IsArray($OkayButton) And UBound($OkayButton) = 2 Then
		SetDebugLog("Detected Okay Button", $COLOR_INFO)
		ClickP($OkayButton)
		If _Sleep(1000) Then Return
	EndIf

	Return True

EndFunc   ;==>OpenPersonalChallenges

; Season pass track of CoC 18.600, measured on live captures.
; A reward that can be claimed is a green card (0x208F23 to 0x20AC25); a claimed one is grey with a
; lighter green check mark, an unreached one light grey, a gold pass one locked in yellow. The free
; row runs at y 375-525 and the gold pass row at y 130-290, both from x 240 (the skin advert covers
; the left) to 858. The track scrolls sideways, about 350 px per drag. The window opens on the
; current progress and whatever is left to claim sits behind it, so the bot claims what it sees,
; drags the track to the right, looks again, and stops when the track no longer moves.
; A tap on a card either claims it at once or opens "Choose your reward!" with two option cards
; and a "Choose!" button under each (0xB2DB84 band, row y 565-580); the option is picked by the
; Village > Misc setting.
Func CollectDailyRewards($bGoldPass = False)

	If Not $g_bChkCollectRewards Then Return

	SetLog("Collecting Daily Rewards...")

	; The 18.600 window opens on the Pass Rewards tab already; clicking it again is harmless and puts
	; the bot back on it when the game remembered another tab.
	Click(325, 40, 1, 120, "Rewards tab")
	If _Sleep(1000) Then Return

	Local $iClaim = 0, $iFailed = 0, $iDrag = 0, $sLastView = ""
	For $iRound = 1 To 30
		If Not $g_bRunState Then Return
		Local $aCards = __PassGreenCards()
		If IsArray($aCards) Then
			For $i = 0 To UBound($aCards, 1) - 1
				If Not $g_bRunState Then Return
				If __PassClaimCard($aCards[$i][0], $aCards[$i][1]) Then
					$iClaim += 1
				Else
					$iFailed += 1
				EndIf
			Next
			If $iFailed >= 3 Then
				SetLog("Pass rewards: a card would not claim, leaving the rest for next time", $COLOR_ERROR)
				SaveFailureImage("PassRewardClaim")
				ExitLoop
			EndIf
			ContinueLoop ; same view again: the cards just claimed turn grey, anything else green is next
		EndIf
		; nothing to claim here: bring what came before into view
		Local $sView = __PassViewSignature()
		If $sView = $sLastView Then ExitLoop ; the drag moved nothing, this is the start of the track
		If $iDrag >= 12 Then ExitLoop ; far enough back, the rewards left to claim sit close to the progress
		$sLastView = $sView
		ClickDrag(400, 430, 750, 430, 600)
		$iDrag += 1
		If _Sleep(1200) Then Return
	Next
	SetLog($iClaim > 0 ? "Claimed " & $iClaim & " reward(s)!" : "Nothing to claim!", $COLOR_SUCCESS)
	If _Sleep(500) Then Return

EndFunc   ;==>CollectDailyRewards

; strong green of a claimable card
Func __IsCardGreen($sCol)
	If StringLen($sCol) <> 6 Then Return False
	Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
	Return ($iG >= 100 And $iR <= 70 And $iB <= 70 And $iG > 2 * $iR And $iG > 2 * $iB)
EndFunc   ;==>__IsCardGreen

; Centres [x, y] of the green cards on both rows, left to right, or 0. A column belongs to a card
; when enough of its samples are green; a run of such columns at least 40 px wide is a card (a card
; is about 150 px, 40 lets one half hidden behind the advert count too).
Func __PassGreenCards()
	_CaptureRegion(240, 130, 858, 526)
	Local $aCards[0][2]
	Local $aRows[2][2] = [[130, 290], [375, 525]]
	For $r = 0 To 1
		Local $iRunStart = -1
		For $x = 240 To 855 Step 5
			Local $iGreen = 0
			For $y = $aRows[$r][0] To $aRows[$r][1] Step 3
				If __IsCardGreen(_GetPixelColor($x - 240, $y - 130, False)) Then $iGreen += 1
			Next
			Local $bGreen = ($iGreen >= 6)
			If $bGreen And $iRunStart < 0 Then $iRunStart = $x
			If $iRunStart >= 0 And (Not $bGreen Or $x >= 855) Then
				Local $iRunEnd = ($bGreen ? $x : $x - 5)
				If $iRunEnd - $iRunStart >= 40 Then
					Local $aRow[1][2] = [[Int(($iRunStart + $iRunEnd) / 2), Int(($aRows[$r][0] + $aRows[$r][1]) / 2)]]
					_ArrayAdd($aCards, $aRow)
					SetDebugLog("Pass rewards: green card at x " & $iRunStart & "-" & $iRunEnd & " on the " & ($r = 0 ? "gold pass" : "free") & " row", $COLOR_DEBUG)
				EndIf
				$iRunStart = -1
			EndIf
		Next
	Next
	If UBound($aCards, 1) = 0 Then Return 0
	Return $aCards
EndFunc   ;==>__PassGreenCards

; a coarse fingerprint of the track area, to tell whether a drag moved it
Func __PassViewSignature()
	_CaptureRegion(250, 140, 850, 520)
	Local $s = ""
	For $y = 0 To 379 Step 40
		For $x = 0 To 599 Step 40
			$s &= _GetPixelColor($x, $y, False)
		Next
	Next
	Return $s
EndFunc   ;==>__PassViewSignature

; pale lime band of the "Choose!" buttons, 0xB2DB84
Func __IsChooseButton($sCol)
	If StringLen($sCol) <> 6 Then Return False
	Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
	Return ($iR >= 160 And $iR <= 200 And $iG >= 205 And $iG <= 232 And $iB >= 110 And $iB <= 155 And $iG > $iR + 20)
EndFunc   ;==>__IsChooseButton

; The two "Choose!" buttons of the reward choice, as [[x, y], [x, y]] left then right, or 0 when the
; choice is not on screen.
Func __PassChoiceButtons()
	_CaptureRegion(150, 560, 760, 600)
	Local $aBtn[0][2]
	For $y = 566 To 580 Step 4
		Local $x = 150
		While $x <= 758
			If __IsChooseButton(_GetPixelColor($x - 150, $y - 560, False)) Then
				Local $iXL = $x
				While $x <= 758 And __IsChooseButton(_GetPixelColor($x - 150, $y - 560, False))
					$x += 1
				WEnd
				If $x - $iXL >= 80 Then
					Local $iXC = Int(($iXL + $x) / 2), $bNew = True
					For $i = 0 To UBound($aBtn, 1) - 1
						If Abs($aBtn[$i][0] - $iXC) < 40 Then $bNew = False
					Next
					If $bNew Then
						Local $aRow[1][2] = [[$iXC, $y + 15]]
						_ArrayAdd($aBtn, $aRow)
					EndIf
				EndIf
			Else
				$x += 3
			EndIf
		WEnd
		If UBound($aBtn, 1) >= 2 Then ExitLoop
	Next
	If UBound($aBtn, 1) < 2 Then Return 0
	_ArraySort($aBtn)
	Return $aBtn
EndFunc   ;==>__PassChoiceButtons

; how much of an option card's picture is gold, elixir or dark elixir
Func __PassResourceScore($iXC)
	_CaptureRegion($iXC - 110, 240, $iXC + 110, 430)
	Local $iScore = 0
	For $y = 0 To 189 Step 3
		For $x = 0 To 219 Step 3
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 170 And $iB > 170 And $iG < 140 Then $iScore += 1 ; elixir pink
			If $iR > 200 And $iG > 150 And $iB < 90 Then $iScore += 1 ; gold
			If $iR < 90 And $iG < 60 And $iB > 70 And $iB > $iR + 20 Then $iScore += 1 ; dark elixir
		Next
	Next
	Return $iScore
EndFunc   ;==>__PassResourceScore

; index (0 left, 1 right) of the option to take, per the Village > Misc setting
Func __PassPickOption($aChoice)
	If $g_iPassRewardChoice = 2 Then Return 0
	Local $iLeft = __PassResourceScore($aChoice[0][0]), $iRight = __PassResourceScore($aChoice[1][0])
	SetDebugLog("Pass reward choice: resource score left " & $iLeft & ", right " & $iRight, $COLOR_DEBUG)
	Local $bLeftRes = ($iLeft >= 200), $bRightRes = ($iRight >= 200)
	If $bLeftRes = $bRightRes Then Return 0 ; both or neither: nothing to tell them apart, take the left one
	If $g_iPassRewardChoice = 0 Then Return ($bRightRes ? 1 : 0) ; resource first
	Return ($bRightRes ? 0 : 1) ; magic item first
EndFunc   ;==>__PassPickOption

; Cancel / Okay pair on screen ("storage full, sell it for gems?"): clicks Okay when $bAccept,
; Cancel otherwise. Returns True when such a pair was there.
Func __PassDecision($bAccept)
	Local $aOkay = FindGreenOkayButton(True)
	If Not IsArray($aOkay) Then Return False
	_CaptureRegion()
	Local $iOrange = 0, $iSum = 0
	For $x = $aOkay[0] - 320 To $aOkay[0] - 60 Step 3
		If $x < 0 Then ContinueLoop
		Local $sCol = _GetPixelColor($x, $aOkay[1] - 26, False)
		If StringLen($sCol) <> 6 Then ContinueLoop
		Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
		If $iR > 220 And $iG > 170 And $iG < 215 And $iB > 90 And $iB < 130 And $iR > $iG + 30 Then
			$iOrange += 1
			$iSum += $x
		EndIf
	Next
	If $iOrange < 25 Then Return False
	If $bAccept Then
		ClickP($aOkay, 1, 120, "Okay")
	Else
		Click(Int($iSum / $iOrange), $aOkay[1], 1, 120, "Cancel")
	EndIf
	Return True
EndFunc   ;==>__PassDecision

; Taps a green card and sees the claim through. True when something was claimed.
Func __PassClaimCard($iX, $iY)
	Click($iX, $iY, 1, 120, "Pass reward")
	If _Sleep(1500) Then Return False
	Local $aChoice = __PassChoiceButtons()
	If IsArray($aChoice) Then
		Local $iPick = __PassPickOption($aChoice)
		SetLog("Pass reward: two options offered, taking the " & ($iPick = 0 ? "left" : "right") & " one", $COLOR_INFO)
		Click($aChoice[$iPick][0], $aChoice[$iPick][1], 1, 120, "Choose")
		If _Sleep(1500) Then Return False
	EndIf
	If __PassDecision($g_bChkSellRewards) Then
		SetLog($g_bChkSellRewards ? "Selling extra reward for gems" : "Cancel. Not selling extra rewards.", $COLOR_SUCCESS)
		If _Sleep(1000) Then Return False
	EndIf
	If IsArray(__PassChoiceButtons()) Then ; still on the choice: the pick did not take, back out
		Click(786, 100, 1, 120, "close choice")
		If _Sleep(1000) Then Return False
		Return False
	EndIf
	SetLog("Pass reward claimed", $COLOR_SUCCESS)
	Return True
EndFunc   ;==>__PassClaimCard

Func CheckDiscountPerks()
	SetLog("Checking for builder boost...")
	If $g_bFirstStart Then $g_iBuilderBoostDiscount = 0

	Click(510, 40, 1, 120, "PerksTab") ; Pass Rewards | Perks | Hoggy Bank strip at the top of the window

	If _Sleep(1500) Then Return ; the tab colour test of the Jun-2023 window no longer applies, just wait

	; find builder boost rate %
	Local $sDiscount = getOcrAndCapture("coc-builderboost", 110, 277 + $g_iMidOffsetY, 100, 40, True)
	SetDebugLog("Builder boost OCR: " & $sDiscount)
	If StringInStr($sDiscount, "%") Then
		Local $aDiscount = StringSplit($sDiscount, "%", $STR_NOCOUNT)
		$g_iBuilderBoostDiscount = Number($aDiscount[0])
		SetLog($g_iBuilderBoostDiscount > 0 ? "Current Builder boost: " & $g_iBuilderBoostDiscount & "%" : "Keep working hard on challenges", $COLOR_SUCCESS)
		$g_iWallCost = $g_aiWallCost[$g_iCmbUpgradeWallsLevel] ; the cost of the level searched; the discount is applied where it is spent
		If ProfileSwitchAccountEnabled() Then SwitchAccountVariablesReload("Save")
	Else
		SetLog("Cannot read builder boost", $COLOR_ERROR)
	EndIf
EndFunc   ;==>CheckDiscountPerks

Func ClosePersonalChallenges()
	If $g_bDebugSetLog Then SetLog("Closing personal challenges", $COLOR_INFO)

	CloseWindow()

	Local $counter = 0
	While Not IsMainPage(1) ; test for Personal Challenge Close Button
		SetDebugLog("Wait for Personal Challenge Window to close #" & $counter)
		If _Sleep($DELAYRUNBOT6) Then ExitLoop
		$counter += 1
		If $counter > 40 Then ExitLoop
	WEnd

EndFunc   ;==>ClosePersonalChallenges
