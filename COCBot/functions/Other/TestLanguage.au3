; #FUNCTION# ====================================================================================================================
; Name ..........: TestLanguage
; Description ...: This function tests if the game is in english language
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........: Sardo (2015-06) , MHK2012 (2018-02)
; Modified ......: Hervidero(2015)
;
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func TestLanguage()
	If Not $g_bRunState Then Return
	; test the word "Attack!" on the Attack Button in the lower left corner. Right after a start a
	; popup, a tooltip or a loading animation can still cover the button, so the word is read up to
	; three times, clearing the screen in between, before the game is declared not in English.
	Local $sRead = ""
	For $i = 1 To 3
		$sRead = getOcrLanguage($aDetectLang[0], $aDetectLang[1])
		If StringLower(StringStripWS($sRead, 3)) = "english" Then
			SetLog("Language setting is English: Correct.", $COLOR_INFO)
			Return True
		EndIf
		SetDebugLog("TestLanguage: attempt " & $i & " read [" & $sRead & "] on the Attack button", $COLOR_DEBUG)
		; second opinion without the DLL OCR: the white pixels of the label compared to "Attack!"
		Local $fMatch = __AttackLabelMatch()
		SetDebugLog("TestLanguage: pixel match of the Attack! label " & Round($fMatch, 2), $COLOR_DEBUG)
		If $fMatch >= 0.75 Then
			SetLog("Language setting is English: Correct (Attack! button matched by pixels" & ($sRead = "" ? ", OCR read nothing" : "") & ").", $COLOR_INFO)
			Return True
		EndIf
		If Not $g_bRunState Then Return
		If $i < 3 Then
			ClearScreen()
			If _Sleep(1500) Then Return
			checkMainScreen(False)
			If _Sleep(500) Then Return
		EndIf
	Next
	SaveFailureImage("Language")
	; a black Attack button is a capture problem (emulator window partly off the screen without Background Mode), not
	; a language: the game was switched to English while it already was, a restart of CoC for nothing
	If __AttackButtonIsBlack() Then
		SetLog("Language check skipped: the Attack button is black in the screen capture, not a language problem", $COLOR_ERROR)
		Return
	EndIf
	If Not ChangeLanguage() Then
		SetLog("Language setting is Wrong: Change CoC language to English!", $COLOR_ERROR)
		btnStop()
	EndIf
EndFunc   ;==>TestLanguage

; Jaccard match (0..1) of the bright pixels at the Attack button label against the "Attack!" word
; as it is printed in English (12 rows x 71 px at 29,698 on the 860x732 screen), best of +-3 px.
Func __AttackLabelMatch()
	Local Const $sMask = "....######.......###.......###........................###.........###..|...########.....####......####........................###........####..|...########.....####......####.....####...............###........###...|...###.####.....######....######..#######....#######..###...###..###...|...###..###...#########.#########....#####..######....###..###...###...|..###...####..######....######........####..####......###.####....##...|..###...####....####......####.....#######..###.......#######.....##...|..##########....###.......###....#########..###.......#######.....#....|.###########....###.......###....###...###..###.......#######..........|.###########....###.......###....###...###..####......###.####.........|.###.....####...###.......###....#########..########..###..###...###...|####.....####...###.......###.....########....######..###...###..###..."
	Local $asMask = StringSplit($sMask, "|", $STR_NOCOUNT)
	Local Const $iX0 = 20, $iY0 = 694, $iW = 89, $iH = 19 ; probe box around the label
	_CaptureRegion()
	Local $asRows[$iH]
	For $y = 0 To $iH - 1
		$asRows[$y] = ""
		For $x = 0 To $iW - 1
			Local $iCol = Dec(_GetPixelColor($iX0 + $x, $iY0 + $y, False))
			Local $fLum = 0.3 * BitAND(BitShift($iCol, 16), 0xFF) + 0.59 * BitAND(BitShift($iCol, 8), 0xFF) + 0.11 * BitAND($iCol, 0xFF)
			$asRows[$y] &= ($fLum > 200 ? "#" : ".")
		Next
	Next
	Local $fBest = 0
	For $iDY = -3 To 3
		For $iDX = -3 To 3
			Local $iInter = 0, $iUnion = 0
			For $y = 0 To UBound($asMask) - 1
				For $x = 0 To StringLen($asMask[0]) - 1
					Local $bM = (StringMid($asMask[$y], $x + 1, 1) = "#")
					Local $iGY = $y + 4 + $iDY, $iGX = $x + 9 + $iDX ; mask origin (29,698) inside the box (20,694)
					Local $bG = ($iGY >= 0 And $iGY < $iH And $iGX >= 0 And $iGX < $iW And StringMid($asRows[$iGY], $iGX + 1, 1) = "#")
					If $bM And $bG Then $iInter += 1
					If $bM Or $bG Then $iUnion += 1
				Next
			Next
			If $iUnion > 0 And $iInter / $iUnion > $fBest Then $fBest = $iInter / $iUnion
		Next
	Next
	Return $fBest
EndFunc   ;==>__AttackLabelMatch

; True when the probe box of the Attack button label is (almost) all black in the capture
Func __AttackButtonIsBlack()
	Local Const $iX0 = 20, $iY0 = 694, $iW = 89, $iH = 19 ; same box as __AttackLabelMatch
	_CaptureRegion()
	Local $iLit = 0
	For $y = 0 To $iH - 1 Step 2
		For $x = 0 To $iW - 1 Step 2
			Local $iCol = Dec(_GetPixelColor($iX0 + $x, $iY0 + $y, False))
			If BitAND(BitShift($iCol, 16), 0xFF) + BitAND(BitShift($iCol, 8), 0xFF) + BitAND($iCol, 0xFF) > 60 Then $iLit += 1
		Next
	Next
	Return $iLit < 20 ; out of 450 samples
EndFunc   ;==>__AttackButtonIsBlack

Func ChangeLanguage()
	SetLog("Change Language To English", $COLOR_INFO)

	If IsMainPage() Then Click($aButtonSetting[0], $aButtonSetting[1], 1, 120, "Click Setting")
	If _Sleep(500) Then Return False

	For $i = 0 To 20 ; Checking Green Language Button continuously in 20sec
		If _ColorCheck(_GetPixelColor($aButtonLanguage[0], $aButtonLanguage[1], True), Hex($aButtonLanguage[2], 6), $aButtonLanguage[3]) Then ;	Green
			Click($aButtonLanguage[0], $aButtonLanguage[1], 1, 1000) ; Click Language Button
			SetLog("   1. Click Language Button")
			If _Sleep(200) Then Return False
			ExitLoop
		EndIf
		If $i = 20 Then Return False
		If _Sleep(900) Then Return False
	Next

	For $i = 0 To 20 ; Checking Language List continuously in 20sec
		If _ColorCheck(_GetPixelColor($aListLanguage[0], $aListLanguage[1], True), Hex($aListLanguage[2], 6), $aListLanguage[3]) Then ;	Green
			ClickDrag(Random(370, 375, 1), Random(170, 175, 1), Random(370, 375, 1), Random(590, 595, 1), 200)
			If _Sleep(200) Then Return False
			ClickDrag(Random(370, 375, 1), Random(170, 175, 1), Random(370, 375, 1), Random(380, 385, 1), 200)
			If _Sleep(900) Then Return False
			If _ColorCheck(_GetPixelColor($aEnglishLanguage[0], $aEnglishLanguage[1], True), Hex($aEnglishLanguage[2], 6), $aEnglishLanguage[3]) Then ;	Grey
				Click($aEnglishLanguage[0], $aEnglishLanguage[1], 1, 1000) ; Click Language Button
				SetLog("   2. Click English Language")
				If _Sleep(300) Then Return False
				ExitLoop
			EndIf
		EndIf
		If $i = 20 Then Return False
		If _Sleep(900) Then Return False
	Next

	For $i = 0 To 10 ; Checking OKAY Button continuously in 10sec
		If _ColorCheck(_GetPixelColor($aLanguageOkay[0], $aLanguageOkay[1], True), Hex($aLanguageOkay[2], 6), $aLanguageOkay[3]) Then
			If _Sleep(250) Then Return False
			Click($aLanguageOkay[0], $aLanguageOkay[1], 1, 120, "Click OKAY")
			SetLog("   3. Click OKAY")
			SetLog("Please wait for loading CoC...!")
			waitMainScreen()
			Return True
		EndIf
		If $i = 10 Then Return False
		If _Sleep(900) Then Return False
	Next

	Return False
EndFunc   ;==>ChangeLanguage
