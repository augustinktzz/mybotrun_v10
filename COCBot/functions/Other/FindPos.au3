; #FUNCTION# ====================================================================================================================
; Name ..........: FindPos
; Description ...:
; Syntax ........: FindPos()
; Parameters ....:
; Return values .: None
; Author ........: Your Name
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func FindPos()
	; A "Generic" Android has no Windows window to click on: see FindPosOnCapture()
	If $g_sAndroidEmulator = "Generic" Then Return FindPosOnCapture()
	getBSPos()
	AndroidToFront(Default, "FindPos") ; Activate Android Window
	While 1
		If _IsPressed("01") Or _IsPressed("02") Then
			Local $Pos = MouseGetPos()
			; adjust Android Control Position
			$Pos[0] -= $g_aiBSpos[0]
			$Pos[1] -= $g_aiBSpos[1]
			; adjust village offset
			ConvertFromVillagePos($Pos[0], $Pos[1])
			; wait till released
			While _IsPressed("01") Or _IsPressed("02")
				Sleep(10)
			WEnd
			Return $Pos
		EndIf
		Sleep(10)
	WEnd
EndFunc   ;==>FindPos

; FindPos() for a "Generic" Android: Waydroid is a Linux window that Wine cannot see, and a phone has no
; window at all, so a click on it never reaches the bot. Shows the current Android screen in a window of
; the bot's own and takes the click there instead. The picture is the screen at 1:1, so the click is
; in Android coordinates once the banner above it is taken off. Closing the window or stopping the bot
; returns (-1, -1), which every Locate* caller rejects as "not valid" before offering Cancel.
Func FindPosOnCapture()
	Local $aPos[2] = [-1, -1]
	Local $hHBitmap = 0
	_CaptureGameScreen($hHBitmap)
	If $hHBitmap = 0 Then Return $aPos

	; a banner above the picture, so that the window is not taken for a second emulator
	Local Const $iBanner = 30
	Local $iOrgMode = Opt("GUIOnEventMode", 0)
	Local $hGui = GUICreate("MyBot - " & GetTranslatedFileIni("MBR Popups", "Locate_building_05", "Click on the building"), $g_iGAME_WIDTH, $iBanner + $g_iGAME_HEIGHT, -1, -1, -1, $WS_EX_TOPMOST)
	GUICtrlCreateLabel(GetTranslatedFileIni("MBR Popups", "Locate_building_06", "Picture of the game taken by MyBot: click on the building in this picture"), 0, 0, $g_iGAME_WIDTH, $iBanner, BitOR($SS_CENTER, $SS_CENTERIMAGE))
	GUICtrlSetFont(-1, 11, 700)
	GUICtrlSetColor(-1, 0xFFFF00) ; the colours of the Locate prompts (_ExtMsgBoxSet)
	GUICtrlSetBkColor(-1, 0x004080)
	Local $idPic = GUICtrlCreatePic("", 0, $iBanner, $g_iGAME_WIDTH, $g_iGAME_HEIGHT)
	; the control shows the capture without going through a file (0 = IMAGE_BITMAP)
	GUICtrlSendMsg($idPic, $STM_SETIMAGE, 0, $hHBitmap)
	GUISetState(@SW_SHOW, $hGui)
	WinActivate($hGui)

	Local $aMsg, $aInfo
	While $g_bRunState
		$aMsg = GUIGetMsg(1)
		If $aMsg[1] = $hGui And $aMsg[0] = $GUI_EVENT_CLOSE Then ExitLoop
		$aInfo = GUIGetCursorInfo($hGui)
		If IsArray($aInfo) And ($aInfo[2] Or $aInfo[3]) And WinActive($hGui) _
				And $aInfo[0] >= 0 And $aInfo[1] >= $iBanner And $aInfo[0] < $g_iGAME_WIDTH And $aInfo[1] < $iBanner + $g_iGAME_HEIGHT Then
			$aPos[0] = $aInfo[0]
			$aPos[1] = $aInfo[1] - $iBanner
			; wait till released
			Do
				Sleep(10)
				$aInfo = GUIGetCursorInfo($hGui)
			Until Not IsArray($aInfo) Or Not ($aInfo[2] Or $aInfo[3])
			ExitLoop
		EndIf
		Sleep(10)
	WEnd

	; a 32 bpp bitmap is copied by the control: delete that copy as well as ours
	Local $hShown = GUICtrlSendMsg($idPic, $STM_GETIMAGE, 0, 0)
	GUIDelete($hGui)
	Opt("GUIOnEventMode", $iOrgMode)
	If $hShown And $hShown <> $hHBitmap Then _WinAPI_DeleteObject($hShown)
	GdiDeleteHBitmap($hHBitmap)

	; adjust village offset, as FindPos() does
	If $aPos[0] >= 0 Then ConvertFromVillagePos($aPos[0], $aPos[1])
	Return $aPos
EndFunc   ;==>FindPosOnCapture
