; #FUNCTION# ====================================================================================================================
; Name ..........: Wine
; Description ...: Detects whether the bot runs under Wine (on Linux) rather than on Windows.
; Syntax ........: IsRunningUnderWine()
; Parameters ....: None
; Return values .: True under Wine, False on Windows
; Author ........:
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;
;                  Every Linux-specific workaround in the bot is guarded by this function. Wine's ntdll
;                  exports wine_get_version and Windows' ntdll does not, so on Windows the DllCall fails
;                  and this returns False: all those workarounds are inert there and the Windows code
;                  paths run exactly as they always did.
;
;                  Kept in its own file because several separately compiled programs need it
;                  (MyBot.run, Watchdog, Wmi) and they do not all include the same files.
; Related .......: Multilanguage.au3, WmiAPI.au3
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once
#include <WinAPISysWin.au3>
#include <WindowsConstants.au3>

Func IsRunningUnderWine()
	Static $iWine = -1 ; the answer cannot change while the bot runs, so compute it once
	If $iWine = -1 Then
		DllCall("ntdll.dll", "str:cdecl", "wine_get_version")
		$iWine = (@error = 0 ? 1 : 0)
	EndIf
	Return $iWine = 1
EndFunc   ;==>IsRunningUnderWine

; Places every tab control under hWnd at the bottom of the z-order of its siblings. The bot builds
; each tab page as a separate child window laid over its tab control. Under Wine the tab control is
; painted over those pages, so every tab page stays blank - the log, the Village/Attack/Bot tabs and
; all their sub-tabs - while their controls exist and hold their data. Moving the tab control below
; its pages makes them show; it keeps working when the user switches tabs. Returns how many moved.
Func WineSendTabControlsToBottom($hWnd)
	Local $aChildren = _WinAPI_EnumChildWindows($hWnd, False)
	If Not IsArray($aChildren) Then Return 0
	Local $i, $iMoved = 0
	For $i = 1 To $aChildren[0][0]
		If $aChildren[$i][1] <> "SysTabControl32" Then ContinueLoop
		_WinAPI_SetWindowPos($aChildren[$i][0], $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOACTIVATE))
		$iMoved += 1
	Next
	Return $iMoved
EndFunc   ;==>WineSendTabControlsToBottom
