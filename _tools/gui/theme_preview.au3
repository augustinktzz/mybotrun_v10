; Preview of the dark theme: the window skeleton of the bot (header, left navigation, content, bottom bar)
; with sample controls, captured to theme_preview.png. No bot code, no game, no DLL.
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <GuiRichEdit.au3>
#include <FontConstants.au3>
#include <ColorConstants.au3>

#include "..\..\COCBot\GUI\MBR GUI Theme.au3"

Opt("GUIOnEventMode", 1)
Global Const $W = 582, $H = 715, $NAV = 110, $HEAD = 100, $BOTTOM = 135
Global $g_hWin = GUICreate("OttoBot theme preview", $W, $H, -1, -1, BitOR($WS_POPUP, $WS_BORDER, $WS_MINIMIZEBOX, $WS_SYSMENU))
GUISetOnEvent($GUI_EVENT_CLOSE, "Quit")
ThemeWindow($g_hWin, $g_iThemeChrome)
ThemeDwm($g_hWin)
_GDIPlus_Startup()

; header
Local $idHeader = GUICtrlCreatePic("", 0, 0, $W, $HEAD)
ThemeSetPicBitmap($idHeader, ThemeDrawHeader($W, $HEAD, @ScriptDir & "\..\..\Images\otto.png", "OttoBot", "v10.9.1  -  Clash of Clans"))

; left navigation
Global $aNav[5] = ["Log", "Village", "Attack", "Bot", "About"]
Global $aNavId[5]
For $i = 0 To 4
	$aNavId[$i] = GUICtrlCreatePic("", 8, $HEAD + 14 + $i * 44, $NAV - 16, 36)
	GUICtrlSetOnEvent(-1, "NavClick")
	GUICtrlSetCursor(-1, 0)
Next
Global $iActive = 1
NavPaint()

; content area: a child window like the tab children of the bot
Local $hContent = GUICreate("", $W - $NAV - 20, $H - $HEAD - $BOTTOM - 20, $NAV + 10, $HEAD + 10, BitOR($WS_CHILD, $WS_TABSTOP), -1, $g_hWin)
ThemeWindow($hContent)
GUICtrlCreateGroup("Collect resources", 10, 8, 200, 120)
GUICtrlCreateCheckbox("Collect Gold / Elixir", 22, 30, 170, 20)
GUICtrlSetState(-1, $GUI_CHECKED)
GUICtrlCreateCheckbox("Treasury", 22, 52, 170, 20)
GUICtrlCreateRadio("Every cycle", 22, 74, 90, 20)
GUICtrlSetState(-1, $GUI_CHECKED)
GUICtrlCreateRadio("When full", 116, 74, 80, 20)
GUICtrlCreateLabel("Min. gold to keep", 22, 100, 100, 18)
GUICtrlCreateInput("2000000", 122, 97, 70, 20)
GUICtrlCreateGroup("", -99, -99, 1, 1)
GUICtrlCreateGroup("Attack plan", 220, 8, 210, 120)
GUICtrlCreateLabel("Search for", 232, 30, 60, 18)
GUICtrlCreateCombo("Dead base", 292, 27, 120, 20)
GUICtrlSetData(-1, "Live base|Both")
GUICtrlCreateLabel("Siege machine", 232, 56, 80, 18)
GUICtrlCreateCombo("Default", 312, 53, 100, 20)
GUICtrlCreateCheckbox("Use siege machine", 232, 80, 170, 20)
GUICtrlSetState(-1, $GUI_CHECKED)
GUICtrlCreateLabel("Warning: king upgrade is enabled", 232, 102, 190, 18)
GUICtrlSetColor(-1, 0xF59E0B)
GUICtrlCreateGroup("", -99, -99, 1, 1)
GUICtrlCreateButton("Locate", 10, 140, 80, 26)
GUICtrlCreateButton("Reset", 96, 140, 80, 26)
; a log like the Log tab
Local $hLog = _GUICtrlRichEdit_Create($hContent, "", 10, 180, $W - $NAV - 40, 240, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_READONLY))
ThemeLogControl($hLog)
_GUICtrlRichEdit_SetFont($hLog, 8.5, $g_sThemeFont)
LogLine($hLog, "[19:32:33] Checking Upgrade Walls", $g_iThemeChromeText)
LogLine($hLog, "[19:32:34] Upgrading Wall using Elixir", $g_iThemeSuccess)
LogLine($hLog, "[19:32:35] No wall(s) level: 13 found.", $g_iThemeError)
LogLine($hLog, "[19:32:36] Builder menu: Wall line found (elixir), letting the game pick one", $g_iThemeInfo)
LogLine($hLog, "[19:32:38] Upgrading 4 walls at once for 8 000 000 elixir", $g_iThemeSuccess)
LogLine($hLog, "[19:32:40] CV ocr coc-ms: '7 028 173' (7 ms)", $g_iThemeDebug)
GUISetState(@SW_SHOW, $hContent)

; bottom bar
Local $hBottom = GUICreate("", $W - $NAV, $BOTTOM, $NAV, $H - $BOTTOM, BitOR($WS_CHILD, $WS_TABSTOP), -1, $g_hWin)
ThemeWindow($hBottom)
Local $idStart = GUICtrlCreatePic("", 12, 12, 100, 36)
ThemeSetPicBitmap($idStart, ThemeDrawButton("Start Bot", 100, 36, $g_iThemeAccent, 0xFFFFFF, True, 8, $g_iThemeBg))
GUICtrlSetCursor(-1, 0)
Local $idPause = GUICtrlCreatePic("", 120, 12, 90, 36)
ThemeSetPicBitmap($idPause, ThemeDrawButton("Pause", 90, 36, 0xE5E7EB, $g_iThemeText, False, 8, $g_iThemeBg))
GUICtrlSetCursor(-1, 0)
Local $idPhoto = GUICtrlCreatePic("", 12, 56, 60, 30)
ThemeSetPicBitmap($idPhoto, ThemeDrawButton("Photo", 60, 30, 0xE5E7EB, $g_iThemeText, False, 8, $g_iThemeBg))
Local $idHide = GUICtrlCreatePic("", 78, 56, 60, 30)
ThemeSetPicBitmap($idHide, ThemeDrawButton("Hide", 60, 30, 0xE5E7EB, $g_iThemeText, False, 8, $g_iThemeBg))
Local $idDock = GUICtrlCreatePic("", 144, 56, 66, 30)
ThemeSetPicBitmap($idDock, ThemeDrawButton("Dock", 66, 30, 0xE5E7EB, $g_iThemeText, False, 8, $g_iThemeBg))
GUICtrlCreateLabel("Gold  7 028 173      Elixir  9 571 221      DE  154 442", 12, 98, 320, 18)
GUICtrlSetColor(-1, $g_iThemeMutedDark)
GUICtrlCreateLabel("League 13", 340, 98, 80, 18)
GUICtrlSetColor(-1, $g_iThemeMutedDark)
GUISetState(@SW_SHOW, $hBottom)

GUISetState(@SW_SHOW, $g_hWin)
ThemeFixGroups($g_hWin)
Sleep(1500)
_ScreenCapture_CaptureWnd(@ScriptDir & "\theme_preview.png", $g_hWin)
Sleep(200)
Quit()

Func Quit()
	_GDIPlus_Shutdown()
	Exit
EndFunc

Func NavClick()
	For $i = 0 To 4
		If @GUI_CtrlId = $aNavId[$i] Then $iActive = $i
	Next
	NavPaint()
EndFunc

Func NavPaint()
	For $i = 0 To 4
		ThemeSetPicBitmap($aNavId[$i], ThemeDrawNavPill($aNav[$i], $NAV - 16, 36, $i = $iActive))
	Next
EndFunc

Func LogLine($hRE, $sText, $iColor)
	_GUICtrlRichEdit_SetSel($hRE, -1, -1)
	_GUICtrlRichEdit_SetCharColor($hRE, __ThemeColorRef($iColor))
	_GUICtrlRichEdit_AppendText($hRE, $sText & @CRLF)
EndFunc
