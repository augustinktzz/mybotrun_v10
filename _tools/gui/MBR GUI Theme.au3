; #FUNCTION# ====================================================================================================================
; Name ..........: MBR GUI Theme
; Description ...: The look of the bot in one place: dark blue theme, font, drawn buttons, rounded window.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  ThemeWindow() is called for every window the bot creates (main window, bars, the 36 tab children
;                  through _GUICreate) before its controls exist: GUISetFont, GUISetBkColor, GUICtrlSetDefColor and
;                  GUICtrlSetDefBkColor then apply to every control created afterwards in that window. The layouts
;                  were drawn for the old 8 pt system font: Segoe UI at 8.5 pt has the same width, nothing moves.
;                  Buttons, navigation pills and the header are drawn with GDI+ into a bitmap shown by a Pic control
;                  (native buttons cannot be coloured once Windows visual styles are on).
;                  ThemeDwm() asks the Desktop Window Manager of Windows 11 for rounded corners and a caption colour
;                  (DwmSetWindowAttribute, attributes 33 to 36); older Windows ignore the calls.
; ===============================================================================================================================
#include-once
#include <GUIConstantsEx.au3>
#include <GDIPlus.au3>
#include <WinAPIGdi.au3>
#include <WinAPISysWin.au3>
#include <WinAPITheme.au3>
#include <WinAPIDlg.au3>
#include <GuiRichEdit.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

Global Const $g_sThemeFont = "Segoe UI"
Global Const $g_fThemeFontSize = 8.5
; palette: dark navy chrome (header, navigation), light content (the tab layouts were drawn for white), blue accent
Global Const $g_iThemeChrome = 0x0B1220 ; header, navigation, title bar
Global Const $g_iThemeChromeText = 0xE5E7EB ; text on the chrome
Global Const $g_iThemeBg = 0xFFFFFF ; content of the tabs and the bottom bar
Global Const $g_iThemeLogBg = 0x131C30 ; the logs, dark like a console
Global Const $g_iThemeNavIdle = 0x1E293B ; pills and buttons at rest
Global Const $g_iThemeNavHover = 0x273449
Global Const $g_iThemeAccent = 0x2563EB ; active pill, primary button, links
Global Const $g_iThemeAccentDark = 0x1D4ED8
Global Const $g_iThemeText = 0x1F2937 ; text on the content
Global Const $g_iThemeMuted = 0x94A3B8 ; secondary text on the chrome
Global Const $g_iThemeMutedDark = 0x6B7280 ; secondary text on the content
Global Const $g_iThemeLine = 0x24304A ; borders of the window
; log colours on the dark log background
Global Const $g_iThemeSuccess = 0x4ADE80, $g_iThemeError = 0xF87171, $g_iThemeInfo = 0x60A5FA, $g_iThemeDebug = 0x94A3B8, $g_iThemeWarn = 0xFBBF24

Global $g_hThemeFontFamily = 0

; the default font and colours of a window (every control created afterwards in it)
Func ThemeWindow($hWnd, $iBg = $g_iThemeBg)
	If $hWnd = 0 Then Return
	GUISetFont($g_fThemeFontSize, 400, 0, $g_sThemeFont, $hWnd)
	GUISetBkColor($iBg, $hWnd)
	GUICtrlSetDefColor(($iBg = $g_iThemeChrome) ? $g_iThemeChromeText : $g_iThemeText, $hWnd)
	GUICtrlSetDefBkColor($iBg, $hWnd)
EndFunc   ;==>ThemeWindow

; Windows 11: rounded corners, a caption in the chrome colour, a border in the line colour. Silently ignored before.
Func ThemeDwm($hWnd)
	If $hWnd = 0 Then Return
	Local Const $DWMWA_WINDOW_CORNER_PREFERENCE = 33, $DWMWCP_ROUND = 2
	Local Const $DWMWA_BORDER_COLOR = 34, $DWMWA_CAPTION_COLOR = 35, $DWMWA_TEXT_COLOR = 36
	DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", $DWMWA_WINDOW_CORNER_PREFERENCE, "dword*", $DWMWCP_ROUND, "dword", 4)
	DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", $DWMWA_CAPTION_COLOR, "dword*", __ThemeColorRef($g_iThemeChrome), "dword", 4)
	DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", $DWMWA_TEXT_COLOR, "dword*", __ThemeColorRef($g_iThemeChromeText), "dword", 4)
	DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", $DWMWA_BORDER_COLOR, "dword*", __ThemeColorRef($g_iThemeLine), "dword", 4)
EndFunc   ;==>ThemeDwm

; 0xRRGGBB -> COLORREF 0x00BBGGRR
Func __ThemeColorRef($iRGB)
	Return BitOR(BitShift(BitAND($iRGB, 0xFF0000), 16), BitAND($iRGB, 0x00FF00), BitShift(BitAND($iRGB, 0x0000FF), -16))
EndFunc   ;==>__ThemeColorRef

; a clickable link label: accent colour, hand cursor
Func ThemeLink($iCtrl = -1)
	GUICtrlSetColor($iCtrl, $g_iThemeAccent)
	GUICtrlSetCursor($iCtrl, 0)
EndFunc   ;==>ThemeLink

; ---------------------------------------------------------------------------------------------------------------------
; drawing (GDI+). Every ThemeDraw* returns a GDI HBITMAP for ThemeSetPicBitmap.
; ---------------------------------------------------------------------------------------------------------------------

Func __ThemeARGB($iRGB, $iAlpha = 0xFF)
	Return BitOR(BitShift($iAlpha, -24), BitAND($iRGB, 0xFFFFFF))
EndFunc   ;==>__ThemeARGB

Func __ThemeRoundPath($x, $y, $w, $h, $r)
	Local $hPath = _GDIPlus_PathCreate()
	Local $d = $r * 2
	_GDIPlus_PathAddArc($hPath, $x, $y, $d, $d, 180, 90)
	_GDIPlus_PathAddArc($hPath, $x + $w - $d, $y, $d, $d, 270, 90)
	_GDIPlus_PathAddArc($hPath, $x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
	_GDIPlus_PathAddArc($hPath, $x, $y + $h - $d, $d, $d, 90, 90)
	_GDIPlus_PathCloseFigure($hPath)
	Return $hPath
EndFunc   ;==>__ThemeRoundPath

Func __ThemeFont($fSize, $iStyle = 0)
	If $g_hThemeFontFamily = 0 Then $g_hThemeFontFamily = _GDIPlus_FontFamilyCreate($g_sThemeFont)
	Return _GDIPlus_FontCreate($g_hThemeFontFamily, $fSize, $iStyle)
EndFunc   ;==>__ThemeFont

; text centred (or left aligned when $bLeft) in a box
Func __ThemeText($hG, $sText, $x, $y, $w, $h, $iColor, $fSize, $iStyle = 0, $bLeft = False)
	Local $hFont = __ThemeFont($fSize, $iStyle)
	Local $hFormat = _GDIPlus_StringFormatCreate()
	_GDIPlus_StringFormatSetAlign($hFormat, $bLeft ? 0 : 1)
	_GDIPlus_StringFormatSetLineAlign($hFormat, 1)
	Local $hBrush = _GDIPlus_BrushCreateSolid(__ThemeARGB($iColor))
	Local $tLayout = _GDIPlus_RectFCreate($x, $y, $w, $h)
	_GDIPlus_GraphicsDrawStringEx($hG, $sText, $hFont, $tLayout, $hFormat, $hBrush)
	_GDIPlus_BrushDispose($hBrush)
	_GDIPlus_StringFormatDispose($hFormat)
	_GDIPlus_FontDispose($hFont)
EndFunc   ;==>__ThemeText

Func __ThemeGraphics(ByRef $hBitmap, $w, $h, $iBg)
	$hBitmap = _GDIPlus_BitmapCreateFromScan0($w, $h)
	Local $hG = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsSetSmoothingMode($hG, 4) ; antialias
	_GDIPlus_GraphicsSetTextRenderingHint($hG, 4) ; antialias grid fit
	_GDIPlus_GraphicsClear($hG, __ThemeARGB($iBg))
	Return $hG
EndFunc   ;==>__ThemeGraphics

Func __ThemeToHBitmap(ByRef $hG, ByRef $hBitmap)
	_GDIPlus_GraphicsDispose($hG)
	Local $hHBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
	_GDIPlus_BitmapDispose($hBitmap)
	Return $hHBitmap
EndFunc   ;==>__ThemeToHBitmap

; a rounded button: $bPrimary = accent colour and bold text, otherwise the idle colour
Func ThemeDrawButton($sText, $w, $h, $iBg, $iFg, $bBold = False, $iRadius = 8, $iOuter = $g_iThemeChrome)
	Local $hBitmap
	Local $hG = __ThemeGraphics($hBitmap, $w, $h, $iOuter) ; $iOuter = the colour of the bar the button sits on (its corners)
	Local $hPath = __ThemeRoundPath(0.5, 0.5, $w - 1, $h - 1, $iRadius)
	Local $hBrush = _GDIPlus_BrushCreateSolid(__ThemeARGB($iBg))
	_GDIPlus_GraphicsFillPath($hG, $hPath, $hBrush)
	_GDIPlus_BrushDispose($hBrush)
	_GDIPlus_PathDispose($hPath)
	__ThemeText($hG, $sText, 0, 0, $w, $h, $iFg, 9, $bBold ? 1 : 0)
	Return __ThemeToHBitmap($hG, $hBitmap)
EndFunc   ;==>ThemeDrawButton

; a navigation pill of the left bar
Func ThemeDrawNavPill($sText, $w, $h, $bActive)
	Return ThemeDrawButton($sText, $w, $h, $bActive ? $g_iThemeAccent : $g_iThemeNavIdle, $bActive ? 0xFFFFFF : $g_iThemeChromeText, $bActive, Int($h / 2))
EndFunc   ;==>ThemeDrawNavPill

; the header: logo picture on the left, title and subtitle
Func ThemeDrawHeader($w, $h, $sLogoFile, $sTitle, $sSub)
	Local $hBitmap
	Local $hG = __ThemeGraphics($hBitmap, $w, $h, $g_iThemeChrome)
	; a soft blue glow behind the logo
	Local $hGlow = _GDIPlus_BrushCreateSolid(__ThemeARGB($g_iThemeAccent, 0x30))
	_GDIPlus_GraphicsFillEllipse($hG, 6, -10, $h + 20, $h + 20, $hGlow)
	_GDIPlus_BrushDispose($hGlow)
	Local $iLogoSize = $h - 12, $iTextX = 16
	If FileExists($sLogoFile) Then
		Local $hImg = _GDIPlus_ImageLoadFromFile($sLogoFile)
		If Not @error And $hImg <> 0 Then
			Local $iW = _GDIPlus_ImageGetWidth($hImg), $iH = _GDIPlus_ImageGetHeight($hImg)
			Local $fScale = $iLogoSize / ($iH > $iW ? $iH : $iW)
			Local $iDw = Int($iW * $fScale), $iDh = Int($iH * $fScale)
			_GDIPlus_GraphicsSetInterpolationMode($hG, 7) ; high quality bicubic
			_GDIPlus_GraphicsDrawImageRect($hG, $hImg, 16 + Int(($iLogoSize - $iDw) / 2), 6 + Int(($iLogoSize - $iDh) / 2), $iDw, $iDh)
			_GDIPlus_ImageDispose($hImg)
			$iTextX = 16 + $iLogoSize + 14
		EndIf
	Else
		; no logo file yet: a round mark with the first letter
		Local $hBrush = _GDIPlus_BrushCreateSolid(__ThemeARGB($g_iThemeAccent))
		_GDIPlus_GraphicsFillEllipse($hG, 16, 6, $iLogoSize, $iLogoSize, $hBrush)
		_GDIPlus_BrushDispose($hBrush)
		__ThemeText($hG, StringLeft($sTitle, 1), 16, 6, $iLogoSize, $iLogoSize, 0xFFFFFF, 22, 1)
		$iTextX = 16 + $iLogoSize + 14
	EndIf
	__ThemeText($hG, $sTitle, $iTextX, Int($h / 2) - 27, $w - $iTextX, 34, $g_iThemeChromeText, 18, 1, True)
	__ThemeText($hG, $sSub, $iTextX + 1, Int($h / 2) + 5, $w - $iTextX, 22, $g_iThemeMuted, 9, 0, True)
	; bottom line
	Local $hPen = _GDIPlus_PenCreate(__ThemeARGB($g_iThemeLine), 1)
	_GDIPlus_GraphicsDrawLine($hG, 0, $h - 1, $w, $h - 1, $hPen)
	_GDIPlus_PenDispose($hPen)
	Return __ThemeToHBitmap($hG, $hBitmap)
EndFunc   ;==>ThemeDrawHeader

; shows an HBITMAP in a Pic control and frees the one it replaces
Func ThemeSetPicBitmap($idPic, $hHBitmap)
	Local $hOld = GUICtrlSendMsg($idPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hHBitmap)
	If $hOld <> 0 And $hOld <> $hHBitmap Then _WinAPI_DeleteObject($hOld)
EndFunc   ;==>ThemeSetPicBitmap

; ---------------------------------------------------------------------------------------------------------------------
; fixes for the native controls that ignore the default colours
; ---------------------------------------------------------------------------------------------------------------------

; Group boxes drawn by the Windows visual style print their caption in black whatever the colours: the style is
; removed from every group box below $hWnd (children included) so the caption follows GUICtrlSetColor.
Func ThemeFixGroups($hWnd)
	Local $aChildren = _WinAPI_EnumChildWindows($hWnd)
	If Not IsArray($aChildren) Then Return 0
	Local $iFixed = 0
	For $i = 1 To $aChildren[0][0]
		If $aChildren[$i][1] <> "Button" Then ContinueLoop
		If BitAND(_WinAPI_GetWindowLong($aChildren[$i][0], $GWL_STYLE), 0xF) <> $BS_GROUPBOX Then ContinueLoop
		_WinAPI_SetWindowTheme($aChildren[$i][0], "", "")
		Local $iId = _WinAPI_GetDlgCtrlID($aChildren[$i][0])
		If $iId > 0 Then GUICtrlSetColor($iId, $g_iThemeMutedDark)
		$iFixed += 1
	Next
	Return $iFixed
EndFunc   ;==>ThemeFixGroups

; a rich edit (the logs) on the content colour; the writers convert their colours to COLORREF themselves
Func ThemeLogControl($hRichEdit)
	If $hRichEdit = 0 Then Return
	_GUICtrlRichEdit_SetBkColor($hRichEdit, __ThemeColorRef($g_iThemeLogBg))
EndFunc   ;==>ThemeLogControl

; ---------------------------------------------------------------------------------------------------------------------
; drawn buttons that replace GUICtrlCreateButton: same control id usage (events, show / hide, enable / disable)
; ---------------------------------------------------------------------------------------------------------------------

Global $g_aThemeButtons[0][6] ; id | text | kind | width | height | outer colour

; $sKind: "primary" (accent), "danger" (red), "default" (light grey)
Func ThemeButtonCreate($sText, $x, $y, $w, $h, $sKind = "default", $iOuter = $g_iThemeBg)
	If $h < 1 Then $h = 25
	Local $id = GUICtrlCreatePic("", $x, $y, $w, $h)
	GUICtrlSetCursor(-1, 0)
	Local $n = UBound($g_aThemeButtons)
	ReDim $g_aThemeButtons[$n + 1][6]
	$g_aThemeButtons[$n][0] = $id
	$g_aThemeButtons[$n][1] = $sText
	$g_aThemeButtons[$n][2] = $sKind
	$g_aThemeButtons[$n][3] = $w
	$g_aThemeButtons[$n][4] = $h
	$g_aThemeButtons[$n][5] = $iOuter
	__ThemeButtonPaint($n, True)
	Return $id
EndFunc   ;==>ThemeButtonCreate

Func __ThemeButtonPaint($n, $bEnabled)
	Local $iBg, $iFg, $bBold = False
	Switch $g_aThemeButtons[$n][2]
		Case "primary"
			$iBg = $bEnabled ? $g_iThemeAccent : 0x93C5FD
			$iFg = 0xFFFFFF
			$bBold = True
		Case "danger"
			$iBg = $bEnabled ? 0xDC2626 : 0xFCA5A5
			$iFg = 0xFFFFFF
			$bBold = True
		Case Else
			$iBg = $bEnabled ? 0xE5E7EB : 0xF3F4F6
			$iFg = $bEnabled ? $g_iThemeText : 0x9CA3AF
	EndSwitch
	ThemeSetPicBitmap($g_aThemeButtons[$n][0], ThemeDrawButton($g_aThemeButtons[$n][1], $g_aThemeButtons[$n][3], $g_aThemeButtons[$n][4], $iBg, $iFg, $bBold, 8, $g_aThemeButtons[$n][5]))
EndFunc   ;==>__ThemeButtonPaint

Func __ThemeButtonIndex($id)
	For $n = 0 To UBound($g_aThemeButtons) - 1
		If $g_aThemeButtons[$n][0] = $id Then Return $n
	Next
	Return -1
EndFunc   ;==>__ThemeButtonIndex

; GUICtrlSetState for a drawn button: applies the state and repaints the enabled / disabled look
Func ThemeButtonState($id, $iState)
	GUICtrlSetState($id, $iState)
	Local $n = __ThemeButtonIndex($id)
	If $n < 0 Then Return
	If BitAND($iState, $GUI_ENABLE) Or BitAND($iState, $GUI_DISABLE) Then __ThemeButtonPaint($n, BitAND(GUICtrlGetState($id), $GUI_DISABLE) = 0)
EndFunc   ;==>ThemeButtonState

; GUICtrlSetData for a drawn button: new caption
Func ThemeButtonSetText($id, $sText)
	Local $n = __ThemeButtonIndex($id)
	If $n < 0 Then
		GUICtrlSetData($id, $sText)
		Return
	EndIf
	$g_aThemeButtons[$n][1] = $sText
	__ThemeButtonPaint($n, BitAND(GUICtrlGetState($id), $GUI_DISABLE) = 0)
EndFunc   ;==>ThemeButtonSetText
