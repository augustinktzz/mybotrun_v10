; #FUNCTION# ====================================================================================================================
; Name ..........: SetLog
; Description ...:
; Syntax ........: SetLog($String[, $Color = $COLOR_BLACK[, $Font = "Verdana"[, $FontSize = 7.5[, $statusbar = 1[, $time = Time([,
;                  $bConsoleWrite = True]]]]]])
; Parameters ....: $sLogMessage         - The message which gets shown in Bot log
;                  $iColor               - [optional] an unknown value. Default is $COLOR_BLACK.
;                  $sFont                - [optional] an unknown value. Default is "Verdana".
;                  $iFontSize            - [optional] an unknown value. Default is 7.5.
;                  $statusbar           - [optional] a string value. Default is 1.
;                  $time                - [optional] a dll struct value. Default is Time(.
;                  $bConsoleWrite       - [optional] a boolean value. Default is True.
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (01-2017), MikeD (04-2021)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once

Global $g_oTxtLogInitText = ObjCreate("Scripting.Dictionary") ; lines logged before the log file exists, see FlushPendingLog()
Global $g_bSilentSetDebugLog = False

Func SetLog($sLogMessage, $iColor = Default, $sFont = Default, $iFontSize = Default, $iStatusbar = Default, $bConsoleWrite = Default, $time = Default, $bEndLine = Default) ;Sets the text for the log
	If $sLogMessage <> "" Then Return _SetLog($sLogMessage, $iColor, $sFont, $iFontSize, $iStatusbar, $time, $bConsoleWrite, $bEndLine)
EndFunc   ;==>SetLog

; internal _SetLog(), don't use outside this file
Func _SetLog($sLogMessage, $Color = Default, $Font = Default, $FontSize = Default, $statusbar = Default, $time = Default, $bConsoleWrite = Default, $bEndLine = Default, _
		$LogPrefix = Default, $bPostponed = Default, $bSilentSetLog = Default, $bWriteToLogFile = Default)

	Local Static $bActive = False
	Local Static $hLogCheckFreeSpaceTimer = 0

	If $Color = Default Then $Color = $COLOR_BLACK
	If $Font = Default Then $Font = "Verdana"
	If $FontSize = Default Then $FontSize = 7.5
	If $statusbar = Default Then $statusbar = 1
	If $time = Default Then $time = Time()
	Local $debugTime = TimeDebug()
	If $bConsoleWrite = Default Then $bConsoleWrite = True
	If $bEndLine = Default Then $bEndLine = True
	If $LogPrefix = Default Then $LogPrefix = "L "
	If $bPostponed = Default Then $bPostponed = $g_bCriticalMessageProcessing
	If $bSilentSetLog = Default Then $bSilentSetLog = $g_bSilentSetLog
	If $bWriteToLogFile = Default Then $bWriteToLogFile = True

	Local $log = $LogPrefix & $debugTime & $sLogMessage
	If $bConsoleWrite = True And $sLogMessage <> "" Then
		Local $sLevel = GetLogLevel($Color)
		_ConsoleWrite($sLevel & $log) ; Always write any log to console
	EndIf
	If $g_hLogFile = 0 And $g_sProfileLogsPath Then
		CreateLogFile()
	EndIf

	; write to log file
	If $bWriteToLogFile Then __FileWriteLog($g_hLogFile, $log)
	If $LogPrefix = "L " And $g_bNotifyDiscordFullLog Then NotifyDiscordLogAdd($time, $sLogMessage) ; full log to Discord option, batched
	If $g_hLogFile = 0 And $bWriteToLogFile Then
		; no log file yet (the profile is not known yet): the line is written as soon as the file exists
		$g_oTxtLogInitText($g_oTxtLogInitText.Count + 1) = $log
	EndIf

	; recursion handling
	If $bActive Then Return
	$bActive = True

	If $g_iLogCheckFreeSpaceMB And $g_bRunState Then
		If $hLogCheckFreeSpaceTimer = 0 Or __TimerDiff($hLogCheckFreeSpaceTimer) > 600000 Then
			; check free space of profile folder
			Local $fFree = DriveSpaceFree($g_sProfilePath & "\" & $g_sProfileCurrentName)
			If $hLogCheckFreeSpaceTimer = 0 Then SetDebugLog("Free disk space is " & $fFree & " MB")
			$hLogCheckFreeSpaceTimer = __TimerInit()
			If @error = 0 And $fFree < $g_iLogCheckFreeSpaceMB Then
				$hLogCheckFreeSpaceTimer = 0 ; force check on next start
				SetLog("Less than " & $g_iLogCheckFreeSpaceMB & " MB free disk space, bot is stopping!", $COLOR_ERROR)
				If $g_bRunState Then btnStop()
			EndIf
		EndIf
	EndIf
	$bActive = False
EndFunc   ;==>_SetLog

Func GetLogLevel($Color)
	; translate log level
	Local $sLevel = ""
	Switch $Color
		Case $COLOR_ERROR
			$sLevel = "ERROR    "
		Case $COLOR_WARNING
			$sLevel = "WARN     "
		Case $COLOR_SUCCESS
			$sLevel = "SUCCESS  "
		Case $COLOR_SUCCESS1
			$sLevel = "SUCCESS1 "
		Case $COLOR_INFO
			$sLevel = "INFO     "
		Case $COLOR_DEBUG
			$sLevel = "DEBUG    "
		Case $COLOR_DEBUG1
			$sLevel = "DEBUG1   "
		Case $COLOR_DEBUG2
			$sLevel = "DEBUG2   "
		Case $COLOR_DEBUGS
			$sLevel = "DEBUGS   "
		Case $COLOR_ACTION
			$sLevel = "ACTION   "
		Case $COLOR_ACTION1
			$sLevel = "ACTION1  "
		Case $COLOR_OLIVE
			$sLevel = "OLIVE   "
		Case $COLOR_BLACK
			$sLevel = "NORMAL   "
		Case Else
			$sLevel = Hex($Color, 6) & "   "
	EndSwitch
	Return $sLevel
EndFunc   ;==>GetLogLevel

Func SetDebugLog($sLogMessage, $sColor = $COLOR_DEBUG, $bSilentSetLog = Default, $Font = Default, $FontSize = Default, $statusbar = 0)
	Local $sLogPrefix = "D "
	Local $sLog = $sLogPrefix & TimeDebug() & $sLogMessage
	If $bSilentSetLog = Default Then $bSilentSetLog = $g_bSilentSetDebugLog

	If $g_bDebugSetLog And Not $bSilentSetLog Then
		_SetLog($sLogMessage, $sColor, $Font, $FontSize, $statusbar, Default, Default, Default, $sLogPrefix)
	Else
		If $sLogMessage <> "" Then _ConsoleWrite(GetLogLevel($sColor) & $sLog) ; Always write any log to console
		If $g_hLogFile = 0 And $g_sProfileLogsPath Then CreateLogFile()
		If $g_hLogFile Then
			__FileWriteLog($g_hLogFile, $sLog)
		Else
			_SetLog($sLogMessage, $sColor, $Font, $FontSize, $statusbar, Default, False, Default, $sLogPrefix, Default, True) ; $bConsoleWrite = False
		EndIf
	EndIf
EndFunc   ;==>SetDebugLog

Func SetGuiLog($sLogMessage, $Color = Default, $bGuiLog = Default)
	If $bGuiLog = Default Then $bGuiLog = True
	If $bGuiLog = True Then
		Return _SetLog($sLogMessage, $Color)
	EndIf
	Return SetDebugLog($sLogMessage, $Color)
EndFunc   ;==>SetGuiLog

; Lines logged before the log file existed, written to it now.
Func FlushPendingLog()
	If $g_hLogFile = 0 Or $g_oTxtLogInitText.Count = 0 Then Return 0
	Local $iLogs = $g_oTxtLogInitText.Count
	For $i = 1 To $iLogs
		__FileWriteLog($g_hLogFile, $g_oTxtLogInitText($i))
	Next
	$g_oTxtLogInitText.RemoveAll
	Return $iLogs
EndFunc   ;==>FlushPendingLog

Func CheckPostponedLog()
	$g_hTxtLogTimer = __TimerInit()
	Return FlushPendingLog()
EndFunc   ;==>CheckPostponedLog

Func SetAtkLog($String1, $String2 = "", $Color = $COLOR_BLACK, $Font = "Lucida Console", $FontSize = 7.5) ;Sets the text for the log
	If $g_hAttackLogFile = 0 Then CreateAttackLogFile()
	;string1 see in video, string1&string2 put in file
	_FileWriteLog($g_hAttackLogFile, $String1 & $String2)
EndFunc   ;==>SetAtkLog

Func SetSwitchAccLog($String, $Color = $COLOR_BLACK, $Font = "Verdana", $FontSize = 7.5, $time = True)
	If $time = True Then
		$time = Time()
	Else
		$time = 0
	EndIf

	If $g_hSwitchLogFile = 0 Then CreateSwitchLogFile()
	_FileWriteLog($g_hSwitchLogFile, $String)
EndFunc   ;==>SetSwitchAccLog

Func AtkLogHead()
	SetAtkLog(_PadStringCenter(" " & GetTranslatedFileIni("MBR Func_AtkLogHead", "AtkLogHead_Text_01", "ATTACK LOG") & " ", 71, "="), "", $COLOR_BLACK, "MS Shell Dlg", 8.5)
	SetAtkLog(GetTranslatedFileIni("MBR Func_AtkLogHead", "AtkLogHead_Text_02", '|                       ------- LOOT --------            -- BONUS --   |'), "")
	SetAtkLog(GetTranslatedFileIni("MBR Func_AtkLogHead", "AtkLogHead_Text_03", '|AC| TIME|  TIER|SRC|DS|   GOLD| ELIXIR|   DE| TR| *|  %| G & E|  DE|L.|'), "")
EndFunc   ;==>AtkLogHead

Func __FileWriteLog($handle, $text)
	Return FileWriteLine($handle, BitAND(WinGetState($g_hFrmBot), 2) & ": " & $text)
EndFunc   ;==>__FileWriteLog

Func SetLogCentered($String, $sPad = Default, $Color = Default, $bClearLog = False) ; $bClearLog: cleared the former log window
	If $sPad = Default Then $sPad = "="
	_SetLog(_PadStringCenter($String, 53, $sPad), $Color, "Lucida Console", 8)
EndFunc   ;==>SetLogCentered

Func SetDebugLogSilent($bSilent = Default)
	If $bSilent = Default Then $bSilent = True
	Local $bWasSilent = $g_bSilentSetDebugLog
	$g_bSilentSetDebugLog = $bSilent
	Return $bWasSilent
EndFunc   ;==>SetDebugLogSilent
