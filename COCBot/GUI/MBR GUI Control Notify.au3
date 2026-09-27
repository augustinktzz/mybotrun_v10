;#FUNCTION# ====================================================================================================================
; Name ..........: MBR GUI Control Notify
; Description ...: This file Includes all functions to current GUI
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........: MyBot.run team
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once

Func chkPBTGenabled()

	If GUICtrlRead($g_hChkNotifyTGEnable) = $GUI_CHECKED Then
		$g_bNotifyTGEnable = True
		GUICtrlSetState($g_hTxtNotifyTGToken, $GUI_ENABLE)
		GUICtrlSetState($g_hBtnNotifyTestTG, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyRemote, $GUI_ENABLE) ; remote control reads commands, only Telegram can do that
	Else
		$g_bNotifyTGEnable = False
		GUICtrlSetState($g_hTxtNotifyTGToken, $GUI_DISABLE)
		GUICtrlSetState($g_hBtnNotifyTestTG, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyRemote, $GUI_DISABLE)
	EndIf

	; the alert options serve both channels, Discord alone is enough to keep them available
	If $g_bNotifyTGEnable = True Or GUICtrlRead($g_hChkNotifyDiscordEnable) = $GUI_CHECKED Then
		GUICtrlSetState($g_hTxtNotifyOrigin, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertMatchFound, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastRaidIMG, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertUpgradeWall, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastRaidTXT, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertOutOfSync, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertTakeBreak, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertVillageStats, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastAttack, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertAnotherDevice, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertCampFull, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertBuilderIdle, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertMaintenance, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertBAN, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyBOTUpdate, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertSmartWaitTime, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertLaboratoryIdle, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyAlertBBRaid, $GUI_ENABLE)
	Else
		GUICtrlSetState($g_hTxtNotifyOrigin, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertMatchFound, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastRaidIMG, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertUpgradeWall, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastRaidTXT, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertOutOfSync, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertTakeBreak, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertVillageStats, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertLastAttack, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertAnotherDevice, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertCampFull, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertBuilderIdle, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertMaintenance, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertBAN, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyBOTUpdate, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertSmartWaitTime, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertLaboratoryIdle, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyAlertBBRaid, $GUI_DISABLE)
	EndIf
EndFunc   ;==>chkPBTGenabled

Func chkDiscordEnabled()
	If GUICtrlRead($g_hChkNotifyDiscordEnable) = $GUI_CHECKED Then
		$g_bNotifyDiscordEnable = True
		GUICtrlSetState($g_hTxtNotifyDiscordWebhook, $GUI_ENABLE)
		GUICtrlSetState($g_hBtnNotifyTestDiscord, $GUI_ENABLE)
		GUICtrlSetState($g_hChkNotifyDiscordFullLog, $GUI_ENABLE)
	Else
		$g_bNotifyDiscordEnable = False
		GUICtrlSetState($g_hTxtNotifyDiscordWebhook, $GUI_DISABLE)
		GUICtrlSetState($g_hBtnNotifyTestDiscord, $GUI_DISABLE)
		GUICtrlSetState($g_hChkNotifyDiscordFullLog, $GUI_DISABLE)
	EndIf
	chkPBTGenabled() ; refresh the shared alert options
EndFunc   ;==>chkDiscordEnabled

Func chkNotifyHours()
	Local $b = GUICtrlRead($g_hChkNotifyOnlyHours) = $GUI_CHECKED
	For $i = 0 To 23
		GUICtrlSetState($g_hChkNotifyhours[$i], $b ? $GUI_ENABLE : $GUI_DISABLE)
	Next
	_GUI_Value_STATE($b ? "ENABLE" : "DISABLE", $g_hChkNotifyOnlyWeekDays&"#"&$g_hChkNotifyhoursE1&"#"&$g_hChkNotifyhoursE2)

	If $b = False Then
		GUICtrlSetState($g_hChkNotifyOnlyWeekDays, $GUI_UNCHECKED)
		chkNotifyWeekDays()
	EndIf
EndFunc   ;==>chkNotifyHours

Func chkNotifyhoursE1()
    Local $b = GUICtrlRead($g_hChkNotifyhoursE1) = $GUI_CHECKED And GUICtrlRead($g_hChkNotifyhours[0]) = $GUI_CHECKED
    For $i = 0 To 11
	   GUICtrlSetState($g_hChkNotifyhours[$i], $b ? $GUI_UNCHECKED : $GUI_CHECKED)
    Next
	Sleep(300)
	GUICtrlSetState($g_hChkNotifyhoursE1, $GUI_UNCHECKED)
EndFunc   ;==>chkNotifyhoursE1

Func chkNotifyhoursE2()
    Local $b = GUICtrlRead($g_hChkNotifyhoursE2) = $GUI_CHECKED And GUICtrlRead($g_hChkNotifyhours[12]) = $GUI_CHECKED
	For $i = 12 To 23
	   GUICtrlSetState($g_hChkNotifyhours[$i], $b ? $GUI_UNCHECKED : $GUI_CHECKED)
    Next
	Sleep(300)
	GUICtrlSetState($g_hChkNotifyhoursE2, $GUI_UNCHECKED)
EndFunc		;==>chkNotifyhoursE2

Func chkNotifyWeekDays()
	Local $b = GUICtrlRead($g_hChkNotifyOnlyWeekDays) = $GUI_CHECKED
	For $i = 0 To 6
		GUICtrlSetState($g_hChkNotifyWeekdays[$i], $b ? $GUI_ENABLE : $GUI_DISABLE)
	Next
	GUICtrlSetState($g_ahChkNotifyWeekdaysE, $b ? $GUI_ENABLE : $GUI_DISABLE)
EndFunc	;==>chkNotifyWeekDays

Func ChkNotifyWeekdaysE()
	Local $b = BitOR(GUICtrlRead($g_hChkNotifyWeekdays[0]), GUICtrlRead($g_hChkNotifyWeekdays[1]), GUICtrlRead($g_hChkNotifyWeekdays[2]), GUICtrlRead($g_hChkNotifyWeekdays[3]), GUICtrlRead($g_hChkNotifyWeekdays[4]), GUICtrlRead($g_hChkNotifyWeekdays[5]), GUICtrlRead($g_hChkNotifyWeekdays[6])) = $GUI_CHECKED
	For $i = 0 To 6
		GUICtrlSetState($g_hChkNotifyWeekdays[$i], $b ? $GUI_UNCHECKED : $GUI_CHECKED)
	Next
	Sleep(300)
	GUICtrlSetState($g_ahChkNotifyWeekdaysE, $GUI_UNCHECKED)
EndFunc   ;==>ChkNotifyWeekdaysE

; "Test" buttons of the Notify tab: they use what is typed in the fields right now, saved or not,
; so a user can check a token or a webhook before the first attack instead of after it.
Func btnNotifyTestTG()
	Local $sToken = StringStripWS(GUICtrlRead($g_hTxtNotifyTGToken), 3)
	If $sToken = "" Then
		SetLog("Telegram test: enter the bot token first", $COLOR_ERROR)
		Return
	EndIf
	SetLog("Telegram test: sending...", $COLOR_INFO)
	NotifyTestTelegram($sToken)
EndFunc   ;==>btnNotifyTestTG

Func btnNotifyTestDiscord()
	Local $sHook = StringStripWS(GUICtrlRead($g_hTxtNotifyDiscordWebhook), 3)
	If $sHook = "" Then
		SetLog("Discord test: paste the webhook URL first", $COLOR_ERROR)
		Return
	EndIf
	SetLog("Discord test: sending...", $COLOR_INFO)
	NotifyTestDiscord($sHook)
EndFunc   ;==>btnNotifyTestDiscord

Func chkDiscordFullLog()
	$g_bNotifyDiscordFullLog = (GUICtrlRead($g_hChkNotifyDiscordFullLog) = $GUI_CHECKED)
	If $g_bNotifyDiscordFullLog Then
		SetLog("Full log to Discord: on, batches every " & Int($g_iNotifyDiscordLogInterval / 1000) & " s", $COLOR_INFO)
	Else
		NotifyDiscordLogFlush(True) ; send what is queued, then stop
	EndIf
EndFunc   ;==>chkDiscordFullLog

; Discord Rich Presence: the Application ID and the link button only make sense when the status is on.
; Switching it off clears the status immediately, so nothing stays on the profile.
Func chkDiscordRPCEnable()
	$g_bDiscordRPCEnable = (GUICtrlRead($g_hChkDiscordRPCEnable) = $GUI_CHECKED)
	GUICtrlSetState($g_hTxtDiscordRPCClientId, $g_bDiscordRPCEnable ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($g_hChkDiscordRPCButton, $g_bDiscordRPCEnable ? $GUI_ENABLE : $GUI_DISABLE)
	chkDiscordRPCButton()
	; whatever is already in the two boxes counts from now, whichever order the user filled them in
	txtDiscordRPCClientId()
	txtDiscordRPCButtonUrl()
	$g_bDiscordRPCIdWarned = False
	If Not $g_bDiscordRPCEnable Then DiscordRPCStop()
EndFunc   ;==>chkDiscordRPCEnable

; the invite box only matters when both the status and the button are on
Func chkDiscordRPCButton()
	$g_bDiscordRPCButton = (GUICtrlRead($g_hChkDiscordRPCButton) = $GUI_CHECKED)
	GUICtrlSetState($g_hTxtDiscordRPCButtonUrl, ($g_bDiscordRPCEnable And $g_bDiscordRPCButton) ? $GUI_ENABLE : $GUI_DISABLE)
	DiscordRPCRefresh() ; the button is not part of the two lines compared before a send
EndFunc   ;==>chkDiscordRPCButton

; The two boxes are read as they are typed (an input sends its event at every change), so the status follows a
; pasted ID or invite at once: nothing depends on a config save or on the order the boxes are filled in.
Func txtDiscordRPCClientId()
	Local $sId = StringStripWS(GUICtrlRead($g_hTxtDiscordRPCClientId), 8)
	If $sId = $g_sDiscordRPCClientId Then Return
	$g_sDiscordRPCClientId = $sId
	$g_bDiscordRPCIdWarned = False
	DiscordRPCStop() ; the connection is tied to the application id: the next check opens it with the new one
EndFunc   ;==>txtDiscordRPCClientId

Func txtDiscordRPCButtonUrl()
	Local $sUrl = StringStripWS(GUICtrlRead($g_hTxtDiscordRPCButtonUrl), 3)
	If $sUrl = $g_sDiscordRPCButtonUrl Then Return
	$g_sDiscordRPCButtonUrl = $sUrl
	DiscordRPCRefresh()
EndFunc   ;==>txtDiscordRPCButtonUrl
