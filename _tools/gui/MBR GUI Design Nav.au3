; #FUNCTION# ====================================================================================================================
; Name ..........: MBR GUI Design Nav
; Description ...: The left navigation of the main window: five rounded pills drawn with the theme, one per main tab.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  The native tab control ($g_hTabMain) is kept, hidden: all the code that reads the current tab
;                  (GUICtrlRead($g_hTabMain), tabMain()) keeps working. A pill selects the tab with TCM_SETCURSEL and
;                  calls tabMain() itself, because _GUICtrlTab_ClickTab() moves the real mouse to click on the tab,
;                  which a hidden control cannot receive. ThemeNavSelect() replaces those calls.
; ===============================================================================================================================
#include-once

Global $g_hPicHeader = 0
Global $g_aiNavPics[5] = [0, 0, 0, 0, 0]
Global $g_asNavNames[5] = ["Log", "Village", "Attack Plan", "Bot", "About Us"]
Global $g_iNavPillWidth = 94, $g_iNavPillHeight = 36, $g_iNavPillPitch = 44

; creates the pills in the current window at $x, $y (first pill), $w wide
Func ThemeNavCreate($x, $y, $w)
	$g_asNavNames[0] = GetTranslatedFileIni("MBR Main GUI", "Tab_01", "Log")
	$g_asNavNames[1] = GetTranslatedFileIni("MBR Main GUI", "Tab_02", "Village")
	$g_asNavNames[2] = GetTranslatedFileIni("MBR Main GUI", "Tab_03", "Attack Plan")
	$g_asNavNames[3] = GetTranslatedFileIni("MBR Main GUI", "Tab_04", "Bot")
	$g_asNavNames[4] = GetTranslatedFileIni("MBR Main GUI", "Tab_05", "About Us")
	$g_iNavPillWidth = $w
	For $i = 0 To 4
		$g_aiNavPics[$i] = GUICtrlCreatePic("", $x, $y + $i * $g_iNavPillPitch, $w, $g_iNavPillHeight)
		GUICtrlSetOnEvent(-1, "ThemeNavClick")
		GUICtrlSetCursor(-1, 0)
	Next
	ThemeNavPaint()
EndFunc   ;==>ThemeNavCreate

; redraws the pills from the tab really selected
Func ThemeNavPaint()
	If $g_aiNavPics[0] = 0 Then Return
	Local $iActive = ($g_hTabMain <> 0) ? Number(GUICtrlRead($g_hTabMain)) : 0
	For $i = 0 To 4
		ThemeSetPicBitmap($g_aiNavPics[$i], ThemeDrawNavPill($g_asNavNames[$i], $g_iNavPillWidth, $g_iNavPillHeight, $i = $iActive))
	Next
EndFunc   ;==>ThemeNavPaint

; selects a main tab the way a click on its pill does (used instead of _GUICtrlTab_ClickTab on the hidden control)
Func ThemeNavSelect($iIndex)
	If $g_hTabMain = 0 Then Return
	_GUICtrlTab_SetCurSel($g_hTabMain, $iIndex)
	tabMain()
	ThemeNavPaint()
EndFunc   ;==>ThemeNavSelect

Func ThemeNavClick()
	For $i = 0 To 4
		If @GUI_CtrlId = $g_aiNavPics[$i] Then
			ThemeNavSelect($i)
			Return
		EndIf
	Next
EndFunc   ;==>ThemeNavClick
