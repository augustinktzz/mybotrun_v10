; #FUNCTION# ====================================================================================================================
; Name ..........: ClickOkay
; Description ...: checks for window with "Okay" button, and clicks it
; Syntax ........: ClickOkay($FeatureName)
; Parameters ....: $FeatureName         - [optional] String with name of feature calling. Default is "Okay".
; ...............; $bCheckOneTime       - (optional) Boolean flag - only checks for Okay button once
; Return values .: Returns True if button found, if button not found, then returns False and sets @error = 1
; Author ........: MonkeyHunter (2015-12)
;~ ; Modified ......: TFKNazGul (12/11/2019)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func ClickOkay($FeatureName = "Okay", $bCheckOneTime = False)
	Local $i = 0
	Local $aiOkayButton
	If _Sleep($DELAYSPECIALCLICK1) Then Return False ; Wait for Okay button window
	While 1 ; Wait for window with Okay Button
		$aiOkayButton = findButton("Okay", Default, 1, True)
		If Not (IsArray($aiOkayButton) And UBound($aiOkayButton, 1) = 2) Then $aiOkayButton = FindGreenOkayButton(True) ; the templates miss the redrawn CoC 18.600 button
		If IsArray($aiOkayButton) And UBound($aiOkayButton, 1) = 2 Then
			PureClick($aiOkayButton[0], $aiOkayButton[1], 2, 100, "#0117") ; Click Okay Button
			ExitLoop
		Else
			SetDebugLog("Cannot Find Okay Button", $COLOR_ERROR)
		EndIf
		If $bCheckOneTime Then Return False ; enable external control of loop count or follow on actions, return false if not clicked
		If $i > 5 Then
			SetLog("Can not find button for " & $FeatureName & ", giving up", $COLOR_ERROR)
			SaveFailureImage("OkayButton_" & $FeatureName)
			SetError(1, @extended, False)
			Return
		EndIf
		$i += 1
		If _Sleep($DELAYSPECIALCLICK2) Then Return False ; improve pause button response
	WEnd
	Return True
EndFunc   ;==>ClickOkay

; #FUNCTION# ====================================================================================================================
; Name ..........: FindGreenOkayButton
; Description ...: Locates the big green "Okay" button of a CoC 18.600.5 popup by its colours, wherever the popup is
; Syntax ........: FindGreenOkayButton()
; Return values .: Array [x, y] to click, or 0 when no such button is on screen
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  The Okay templates predate the redrawn button, so the "star bonus", "upgrades finished while
;                  you were away" and similar windows were left open. Measured on live captures: the upper half
;                  of the button is a lime gradient (0xD4F480 down to 0xC6EB60, about 150 px wide and 25 px
;                  high), the lower half a darker green (0x6DBC1F), the label white. Popups are centred, so the
;                  scan covers the middle of the screen only, and a run narrower than a button is ignored.
; ===============================================================================================================================
; $bAllowPair: a green button with an orange Cancel on its left is a decision (quit the game, spend
; gems, surrender...). Callers that mean to confirm one pass True; checkObstacles, which closes
; whatever is in the way, keeps the default and leaves such a window alone. "Confirm Exit", which
; the Android back key raises on the main screen, is exactly that layout and its Okay quits CoC.
Func FindGreenOkayButton($bAllowPair = False)
	_CaptureRegion()

	; Every lime pixel is a candidate, not only the first one: the "Welcome Back Chief" window shows a
	; green check mark on each finished upgrade card, above the button, and stopping at that 1 px hit
	; used to leave the window open. A run that is not a button is skipped and the scan goes on.
	Local $iSkipUntilX = -1, $iSkipY = -1
	For $y = 300 To 700 Step 6
		For $x = 250 To 610 Step 6
			If $y = $iSkipY And $x <= $iSkipUntilX Then ContinueLoop
			If Not __IsLimeButton(_GetPixelColor($x, $y, False)) Then ContinueLoop

			; horizontal run through this lime pixel
			Local $iXL = $x, $iXR = $x
			While $iXL > 0 And __IsLimeButton(_GetPixelColor($iXL - 1, $y, False))
				$iXL -= 1
			WEnd
			While $iXR < $g_iGAME_WIDTH - 1 And __IsLimeButton(_GetPixelColor($iXR + 1, $y, False))
				$iXR += 1
			WEnd
			$iSkipUntilX = $iXR ; whatever this run is, do not test it again on this row
			$iSkipY = $y
			Local $iWidth = $iXR - $iXL + 1
			If $iWidth < 100 Or $iWidth > 240 Then
				SetDebugLog("FindGreenOkayButton: lime run of " & $iWidth & " px at " & $iXL & "," & $y & " is not a button", $COLOR_DEBUG)
				ContinueLoop
			EndIf
			Local $iXC = Int(($iXL + $iXR) / 2)

			; top edge of the lime band, the label sits about 30 px below it
			Local $iYT = $y
			While $iYT > 0 And __IsLimeButton(_GetPixelColor($iXC, $iYT - 1, False))
				$iYT -= 1
			WEnd

			; the light label, sampled across the middle of the button. "Okay" is pure white but the "Send"
			; of the reinforcement request is EFEFEF / E8EBE0, which a 240 floor rejected outright.
			Local $iWhite = 0
			For $yy = $iYT + 15 To $iYT + 50 Step 2
				For $xx = $iXC - 40 To $iXC + 40 Step 3
					Local $sCol = _GetPixelColor($xx, $yy, False)
					If StringLen($sCol) = 6 And Dec(StringMid($sCol, 1, 2)) > 215 And Dec(StringMid($sCol, 3, 2)) > 215 And Dec(StringMid($sCol, 5, 2)) > 215 Then $iWhite += 1
				Next
			Next
			If $iWhite < 8 Then
				SetDebugLog("FindGreenOkayButton: green band at " & $iXC & "," & $iYT & " carries no label (" & $iWhite & " white samples)", $COLOR_DEBUG)
				ContinueLoop
			EndIf

			; orange Cancel twin on the same row, to the left: 0xFFC670 on "Confirm Exit", 0xEFBE73 on
			; the reinforcement request, both about 180 px wide and 40 px left of the green one
			If Not $bAllowPair Then
				Local $iOrange = 0
				For $xx = $iXL - 250 To $iXL - 15 Step 3
					If $xx < 0 Then ContinueLoop
					Local $sCol = _GetPixelColor($xx, $iYT + 4, False)
					If StringLen($sCol) <> 6 Then ContinueLoop
					Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
					If $iR > 220 And $iG > 170 And $iG < 215 And $iB > 90 And $iB < 130 And $iR > $iG + 30 Then $iOrange += 1
				Next
				If $iOrange >= 25 Then
					SetLog("A Cancel / Okay choice is on screen, not confirming it blindly", $COLOR_INFO)
					SaveFailureImage("DecisionWindow")
					ContinueLoop
				EndIf
			EndIf

			Local $aButton[2] = [$iXC, $iYT + 30]
			SetDebugLog("FindGreenOkayButton: button at " & $aButton[0] & "," & $aButton[1] & " (" & $iWidth & " px wide)", $COLOR_DEBUG)
			Return $aButton
		Next
	Next
	Return 0
EndFunc   ;==>FindGreenOkayButton

; lime gradient of the upper half of the green buttons, 0xD4F480 down to 0xC6EB60
Func __IsLimeButton($sCol)
	If StringLen($sCol) <> 6 Then Return False
	Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
	Return ($iG >= 225 And $iR >= 185 And $iR <= 235 And $iB >= 80 And $iB <= 155 And $iG > $iR)
EndFunc   ;==>__IsLimeButton
