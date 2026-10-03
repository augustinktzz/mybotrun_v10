; #FUNCTION# ====================================================================================================================
; Name ..........: BuilderBaseReport()
; Description ...: Make Resources report of Builders Base
; Syntax ........: BuilderBaseReport()
; Parameters ....:
; Return values .: None
; Author ........: ProMac (05-2017)
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func BuilderBaseReport($bBypass = False, $bSetLog = True)
	ClearScreen("Defaut", False)
	If _Sleep($DELAYVILLAGEREPORT1) Then Return

	Switch $bBypass
		Case False
			If $bSetLog Then SetLog("Builder Base Report", $COLOR_INFO)
		Case True
			If $bSetLog Then SetLog("Updating Builder Base Resource Values", $COLOR_INFO)
		Case Else
			If $bSetLog Then SetLog("Builder Base Village Report Error, You have been a BAD programmer!", $COLOR_ERROR)
	EndSwitch

	If Not $bSetLog Then SetLog("Builder Base Village Report", $COLOR_INFO)

	getBuilderCount($bSetLog, True) ; update builder data
	If _Sleep($DELAYRESPOND) Then Return

	$g_aiCurrentLootBB[$eLootTrophyBB] = BBReadTrophies()
	$g_aiCurrentLootBB[$eLootGoldBB] = getResourcesMainScreen(705, 23)
	$g_aiCurrentLootBB[$eLootElixirBB] = getResourcesMainScreen(705, 72)
	If $bSetLog Then SetLog(" [G]: " & _NumberFormat($g_aiCurrentLootBB[$eLootGoldBB]) & " [E]: " & _NumberFormat($g_aiCurrentLootBB[$eLootElixirBB]) & " [T]: " & _NumberFormat($g_aiCurrentLootBB[$eLootTrophyBB]), $COLOR_SUCCESS)

	PicBBTrophies()

	If Not $bBypass Then ; update stats
		UpdateStats()
	EndIf

	If ProfileSwitchAccountEnabled() Then SwitchAccountVariablesReload("Save")
EndFunc   ;==>BuilderBaseReport

; The builder base counters roll from 0 up to their value for a second or two after the base is shown,
; and the trophies are the first thing read: one morning's log holds 0, 19, 915, 197, 1918 for a count
; near 1 900, while gold and elixir, read a moment later, were right every time. The 4 digits sit at
; x 74-103, y 88-98 in the 67-117 x 84-100 box, so the box is not at fault. Read until two reads in a
; row agree, or give the last one after 3 seconds.
Func BBReadTrophies()
	Local $sLast = "", $sNow = ""
	For $i = 1 To 8
		$sNow = StringRegExpReplace(__BBTrophyOcr(), "[^0-9]", "")
		If $sNow <> "" And $sNow = $sLast Then Return Number($sNow)
		$sLast = $sNow
		If _Sleep(400) Then Return Number($sNow)
	Next
	SetDebugLog("Builder base trophies did not settle, keeping the last read: " & $sNow, $COLOR_DEBUG)
	Return Number($sNow)
EndFunc   ;==>BBReadTrophies

; The DLL coc-ms font drops digits of the builder base trophy counter since CoC 18.600: on the 2 Oct log the
; very same captures were read '2318' -> 31 and '2294' -> 91 or 94 (27 reports), while the glyph OCR of
; imgcv\OCR\coc-ms, which only runs as a shadow check there (shadow.txt), read the 4 digits right every time
; and agrees with the DLL on gold and elixir. So that OCR answers here, the DLL stays the fallback.
Func __BBTrophyOcr()
	If Not CVOcrFontExists("coc-ms") Then Return getTrophyMainScreen(67, 84)
	_CaptureRegion2(67, 84, 117, 100) ; the 50x16 box of getTrophyMainScreen()
	Local $sRead = CVOcr($g_hHBitmap2, "coc-ms")
	SetDebugLog("BB trophies, CV ocr: '" & $sRead & "'", $COLOR_DEBUG)
	If StringRegExpReplace($sRead, "[^0-9]", "") = "" Then Return getTrophyMainScreen(67, 84)
	Return $sRead
EndFunc   ;==>__BBTrophyOcr

Func PicBBTrophies()
EndFunc   ;==>PicBBTrophies
