; #FUNCTION# ====================================================================================================================
; Name ..........: DiscordRichPresence
; Description ...: Shows what the bot is doing on the Discord profile of the user (Rich Presence).
; Syntax ........: DiscordRPCStart() / DiscordRPCTick() / DiscordRPCStop()
; Return values .: -
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  Talks to the Discord desktop application through its local named pipe, \\.\pipe\discord-ipc-0 to -9,
;                  with the IPC protocol of Rich Presence: a frame is an opcode (int32), a length (int32) and a UTF-8
;                  JSON body. Opcodes: 0 HANDSHAKE, 1 FRAME, 2 CLOSE, 3 PING, 4 PONG. The handshake announces the
;                  application id, then every SET_ACTIVITY frame replaces what the profile shows.
;                  Nothing is installed and nothing leaves the machine: the pipe is local, Discord itself publishes
;                  the status. Without the Discord application running, or without an application id, the bot simply
;                  does nothing here.
;                  Discord limits the updates to about 5 per 20 seconds, so a new activity is only sent every 15 s
;                  and only when the text really changed.
;                  Measured on a live machine: the pipe answers a handshake in 300 ms.
; ===============================================================================================================================
#include-once

Global $g_hDiscordRPCPipe = 0 ; 0 = not connected
Global $g_hDiscordRPCTimer = 0 ; last activity sent
Global $g_hDiscordRPCRetry = 0 ; last failed connection
Global $g_sDiscordRPCLast = "" ; last activity sent, to skip identical updates
Global $g_iDiscordRPCStart = 0 ; unix time the run started (pauses left out), for the elapsed counter
Global $g_bDiscordRPCDisplayType = True ; False once Discord refused status_display_type (older Discord client)

Global Const $g_iRPCOpHandshake = 0, $g_iRPCOpFrame = 1, $g_iRPCOpClose = 2

; --------------------------------------------------------------------------------------------------------------------
; pipe
; --------------------------------------------------------------------------------------------------------------------

Func __RPCPipeOpen($sName)
	Local $a = DllCall("kernel32.dll", "handle", "CreateFileW", "wstr", $sName, "dword", 0xC0000000, _
			"dword", 0, "ptr", 0, "dword", 3, "dword", 0, "ptr", 0) ; GENERIC_READ|WRITE, OPEN_EXISTING
	If @error Or Not IsArray($a) Then Return 0
	If $a[0] = -1 Or $a[0] = 0 Then Return 0
	Return $a[0]
EndFunc   ;==>__RPCPipeOpen

Func __RPCWrite($iOpCode, $sJson)
	If $g_hDiscordRPCPipe = 0 Then Return False
	Local $dData = StringToBinary($sJson, 4) ; UTF-8
	Local $iLen = BinaryLen($dData)
	If $iLen < 1 Then Return False
	Local $tFrame = DllStructCreate("int op;int len;byte data[" & $iLen & "]")
	DllStructSetData($tFrame, "op", $iOpCode)
	DllStructSetData($tFrame, "len", $iLen)
	DllStructSetData($tFrame, "data", $dData)
	Local $a = DllCall("kernel32.dll", "bool", "WriteFile", "handle", $g_hDiscordRPCPipe, "struct*", $tFrame, _
			"dword", 8 + $iLen, "dword*", 0, "ptr", 0)
	If @error Or Not IsArray($a) Or Not $a[0] Then Return False
	Return ($a[4] = 8 + $iLen)
EndFunc   ;==>__RPCWrite

; bytes waiting in the pipe, 0 when nothing or on error (never blocks)
Func __RPCPending()
	If $g_hDiscordRPCPipe = 0 Then Return 0
	Local $a = DllCall("kernel32.dll", "bool", "PeekNamedPipe", "handle", $g_hDiscordRPCPipe, "ptr", 0, "dword", 0, _
			"dword*", 0, "dword*", 0, "dword*", 0)
	If @error Or Not IsArray($a) Or Not $a[0] Then Return 0
	Return $a[5]
EndFunc   ;==>__RPCPending

; one answer frame, "" when nothing readable. Only called when __RPCPending() said there is data.
Func __RPCRead(ByRef $iOpCode)
	$iOpCode = -1
	If $g_hDiscordRPCPipe = 0 Then Return ""
	Local $tHdr = DllStructCreate("int op;int len")
	Local $a = DllCall("kernel32.dll", "bool", "ReadFile", "handle", $g_hDiscordRPCPipe, "struct*", $tHdr, _
			"dword", 8, "dword*", 0, "ptr", 0)
	If @error Or Not IsArray($a) Or Not $a[0] Or $a[4] < 8 Then Return ""
	$iOpCode = DllStructGetData($tHdr, "op")
	Local $iLen = DllStructGetData($tHdr, "len")
	If $iLen < 1 Or $iLen > 65536 Then Return ""
	Local $tBody = DllStructCreate("byte data[" & $iLen & "]")
	$a = DllCall("kernel32.dll", "bool", "ReadFile", "handle", $g_hDiscordRPCPipe, "struct*", $tBody, _
			"dword", $iLen, "dword*", 0, "ptr", 0)
	If @error Or Not IsArray($a) Or Not $a[0] Then Return ""
	Return BinaryToString(DllStructGetData($tBody, "data"), 4) ; UTF-8
EndFunc   ;==>__RPCRead

; reads and drops whatever Discord sent back, so the pipe never fills up
Func __RPCDrain()
	Local $iOp, $iGuard = 0
	While __RPCPending() >= 8 And $iGuard < 8
		Local $sAnswer = __RPCRead($iOp)
		$iGuard += 1
		If $iOp = $g_iRPCOpClose Then
			SetDebugLog("Discord presence: closed by Discord " & $sAnswer, $COLOR_DEBUG)
			DiscordRPCStop(False)
			Return False
		EndIf
		; an activity Discord refused: a client that does not know status_display_type refuses the whole
		; activity, so it is sent again without it
		If StringInStr($sAnswer, '"evt":"ERROR"') Then
			SetDebugLog("Discord presence: activity refused " & $sAnswer, $COLOR_DEBUG)
			If $g_bDiscordRPCDisplayType Then
				$g_bDiscordRPCDisplayType = False
				DiscordRPCRefresh()
			EndIf
		EndIf
	WEnd
	Return True
EndFunc   ;==>__RPCDrain

; --------------------------------------------------------------------------------------------------------------------
; JSON
; --------------------------------------------------------------------------------------------------------------------

Func __RPCJson($sText)
	Local $s = StringReplace($sText, "\", "\\")
	$s = StringReplace($s, '"', '\"')
	$s = StringReplace($s, @CRLF, " ")
	$s = StringReplace($s, @CR, " ")
	$s = StringReplace($s, @LF, " ")
	$s = StringReplace($s, @TAB, " ")
	Return $s
EndFunc   ;==>__RPCJson

; Discord refuses details / state shorter than 2 or longer than 128 characters
Func __RPCField($sText)
	$sText = StringStripWS($sText, $STR_STRIPLEADING + $STR_STRIPTRAILING)
	If StringLen($sText) > 128 Then $sText = StringLeft($sText, 125) & "..."
	Return $sText
EndFunc   ;==>__RPCField

; --------------------------------------------------------------------------------------------------------------------
; public
; --------------------------------------------------------------------------------------------------------------------

Func DiscordRPCAvailable()
	Return ($g_bDiscordRPCEnable And StringRegExp(StringStripWS($g_sDiscordRPCClientId, 8), "^\d{17,20}$"))
EndFunc   ;==>DiscordRPCAvailable

; opens the pipe and announces the application id. False when Discord is not there: it is retried later, never blocks.
Func DiscordRPCStart()
	If Not $g_bDiscordRPCEnable Then Return False
	If Not DiscordRPCAvailable() Then
		; the application id is built into the bot: only a broken build gets here, say it once
		If Not $g_bDiscordRPCIdWarned Then
			$g_bDiscordRPCIdWarned = True
			SetLog("Discord status: the application ID of this build is not valid, nothing is shown", $COLOR_ERROR)
		EndIf
		Return False
	EndIf
	$g_bDiscordRPCIdWarned = False
	If $g_hDiscordRPCPipe <> 0 Then Return True
	If $g_hDiscordRPCRetry <> 0 And __TimerDiff($g_hDiscordRPCRetry) < 60000 Then Return False ; one try per minute

	For $i = 0 To 9
		$g_hDiscordRPCPipe = __RPCPipeOpen("\\.\pipe\discord-ipc-" & $i)
		If $g_hDiscordRPCPipe <> 0 Then ExitLoop
	Next
	If $g_hDiscordRPCPipe = 0 Then
		$g_hDiscordRPCRetry = __TimerInit()
		SetDebugLog("Discord presence: no Discord application running", $COLOR_DEBUG)
		Return False
	EndIf

	If Not __RPCWrite($g_iRPCOpHandshake, '{"v":1,"client_id":"' & StringStripWS($g_sDiscordRPCClientId, 8) & '"}') Then
		DiscordRPCStop(False)
		$g_hDiscordRPCRetry = __TimerInit()
		Return False
	EndIf

	; Discord answers READY, or CLOSE with the reason when the application id is wrong
	Local $iWait = 0
	While __RPCPending() < 8 And $iWait < 20
		If _Sleep(50) Then Return False
		$iWait += 1
	WEnd
	Local $iOp
	Local $sAnswer = __RPCRead($iOp)
	If $iOp = $g_iRPCOpClose Or $sAnswer = "" Then
		SetLog("Discord presence refused: " & ($sAnswer <> "" ? $sAnswer : "no answer") & " - check the Application ID", $COLOR_ERROR)
		DiscordRPCStop(False)
		$g_hDiscordRPCRetry = __TimerInit()
		Return False
	EndIf

	$g_iDiscordRPCStart = __RPCRunStart()
	$g_sDiscordRPCLast = ""
	$g_hDiscordRPCRetry = 0
	SetLog("Discord presence connected", $COLOR_SUCCESS)
	Return True
EndFunc   ;==>DiscordRPCStart

; UTC seconds since 1970, the unit Discord expects. Taken from the system clock in UTC (a local time would
; shift the elapsed counter shown on the profile by the time zone).
Func __RPCUnixNow()
	Local $tFT = DllStructCreate("uint64 ft")
	DllCall("kernel32.dll", "none", "GetSystemTimeAsFileTime", "struct*", $tFT)
	If @error Then Return 0
	; FILETIME counts 100 ns ticks since 1601, 11644473600 seconds before 1970
	Return Int(DllStructGetData($tFT, "ft") / 10000000) - 11644473600
EndFunc   ;==>__RPCUnixNow

; Unix time the run started, from the bot's own run time (pauses left out): the counter on the profile no longer
; starts again from zero when the pipe reconnects.
Func __RPCRunStart()
	Local $iRun = $g_iTimePassed
	If $g_bRunState And Not $g_bBotPaused And $g_hTimerSinceStarted <> 0 Then $iRun += Int(__TimerDiff($g_hTimerSinceStarted))
	Return __RPCUnixNow() - Int($iRun / 1000)
EndFunc   ;==>__RPCRunStart

; clears the status and closes the pipe. $bClear = False when Discord already hung up.
Func DiscordRPCStop($bClear = True)
	If $g_hDiscordRPCPipe = 0 Then Return
	If $bClear Then
		; an activity without content removes the status from the profile
		__RPCWrite($g_iRPCOpFrame, '{"cmd":"SET_ACTIVITY","nonce":"' & __RPCUnixNow() & '-off","args":{"pid":' & @AutoItPID & '}}')
		Sleep(100) ; plain Sleep: BotStop() must not be interrupted by the bot state here
	EndIf
	DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $g_hDiscordRPCPipe)
	$g_hDiscordRPCPipe = 0
	$g_sDiscordRPCLast = ""
EndFunc   ;==>DiscordRPCStop

; Forgets the last activity sent, so the next check sends it again even if the two lines did not change:
; for the button and its link, which are not part of those lines.
Func DiscordRPCRefresh()
	$g_sDiscordRPCLast = ""
	$g_hDiscordRPCTimer = 0
EndFunc   ;==>DiscordRPCRefresh

; Sends the activity. $sDetails is the first line, $sState the second one, $sLargeText the tooltip of the picture.
; The application name on the profile is the one of the Discord application; status_display_type 2 makes the member
; list show the first line instead, the bot version ("Playing MyBotRun_v12.0.2"), which follows every update.
Func DiscordRPCSet($sDetails, $sState, $bForce = False, $sLargeText = "")
	If Not DiscordRPCAvailable() Then Return False
	If $g_hDiscordRPCPipe = 0 Then
		If Not DiscordRPCStart() Then Return False
	EndIf
	If Not __RPCDrain() Then Return False

	$sDetails = __RPCField($sDetails)
	$sState = __RPCField($sState)
	If $sLargeText = "" Then $sLargeText = $g_sBotTitle
	$sLargeText = __RPCField($sLargeText)
	Local $bRunning = $g_bRunState And Not $g_bBotPaused
	Local $sSignature = $sDetails & "|" & $sState & "|" & $sLargeText & "|" & $bRunning & "|" & $g_bDiscordRPCDisplayType
	If Not $bForce Then
		If $sSignature = $g_sDiscordRPCLast Then Return True ; nothing changed
		If $g_hDiscordRPCTimer <> 0 And __TimerDiff($g_hDiscordRPCTimer) < 15000 Then Return True ; Discord rate limit
	EndIf

	; the elapsed counter follows the bot's run time; a few seconds of drift are left alone, or the counter would
	; jitter at every update
	If $bRunning Then
		Local $iStart = __RPCRunStart()
		If Abs($iStart - $g_iDiscordRPCStart) > 5 Then $g_iDiscordRPCStart = $iStart
	EndIf

	Local $sSmall = $g_bRunState ? ($g_bBotPaused ? "paused" : "running") : "idle"
	Local $sJson = '{"cmd":"SET_ACTIVITY","nonce":"' & __RPCUnixNow() & "-" & Random(1000, 9999, 1) & '","args":{"pid":' & @AutoItPID & ',"activity":{'
	If $sDetails <> "" Then $sJson &= '"details":"' & __RPCJson($sDetails) & '",'
	If $sState <> "" Then $sJson &= '"state":"' & __RPCJson($sState) & '",'
	If $g_bDiscordRPCDisplayType And $sDetails <> "" Then $sJson &= '"status_display_type":2,'
	If $bRunning Then $sJson &= '"timestamps":{"start":' & $g_iDiscordRPCStart & '},' ; no counter while paused or stopped
	$sJson &= '"assets":{"large_image":"village","large_text":"' & __RPCJson($sLargeText) & '","small_image":"' & $sSmall & '","small_text":"' & $sSmall & '"}'
	Local $sButtonUrl = __RPCButtonUrl()
	If $g_bDiscordRPCButton And $sButtonUrl <> "" Then $sJson &= ',"buttons":[{"label":"Join the server","url":"' & __RPCJson($sButtonUrl) & '"}]'
	$sJson &= '}}}'

	If Not __RPCWrite($g_iRPCOpFrame, $sJson) Then
		SetDebugLog("Discord presence: write failed, reconnecting later", $COLOR_DEBUG)
		DiscordRPCStop(False)
		$g_hDiscordRPCRetry = __TimerInit()
		Return False
	EndIf
	$g_hDiscordRPCTimer = __TimerInit()
	$g_sDiscordRPCLast = $sSignature
	Return True
EndFunc   ;==>DiscordRPCSet

; Called from the main loop: builds the two lines from what the bot knows and sends them.
Func DiscordRPCTick()
	If Not $g_bDiscordRPCEnable Then Return
	If Not DiscordRPCAvailable() Then
		DiscordRPCStart() ; the option was ticked without an id: it says so once and returns
		Return
	EndIf
	; cheap guard so the main loop never pays for the rate limited calls
	If $g_hDiscordRPCTimer <> 0 And __TimerDiff($g_hDiscordRPCTimer) < 15000 Then Return

	; first line: the bot and its version, MyBotRun_v12.0.2 (shown in the member list, see DiscordRPCSet)
	Local $sDetails = "MyBotRun_" & $g_sBotVersion

	Local $sVillage = ""
	If $g_iTownHallLevel > 0 Then $sVillage = "Town Hall " & $g_iTownHallLevel
	If $g_sProfileCurrentName <> "" Then $sVillage &= ($sVillage <> "" ? " - " : "") & $g_sProfileCurrentName
	If $sVillage = "" Then $sVillage = "Clash of Clans"

	Local $sState = ""
	If Not $g_bRunState Then
		$sState = "Bot stopped"
	ElseIf $g_bBotPaused Then
		$sState = "Paused"
	Else
		$sState = ($g_iTownHallLevel > 0 ? "TH" & $g_iTownHallLevel & "  " : "") & "Gold " & __RPCShort($g_aiCurrentLoot[$eLootGold]) & "  Elixir " & __RPCShort($g_aiCurrentLoot[$eLootElixir])
		If $g_aiCurrentLoot[$eLootDarkElixir] > 0 Then $sState &= "  DE " & __RPCShort($g_aiCurrentLoot[$eLootDarkElixir])
	EndIf

	DiscordRPCSet($sDetails, $sState, False, $sVillage)
EndFunc   ;==>DiscordRPCTick

; 7028173 -> 7.0M, 154442 -> 154K
Func __RPCShort($iValue)
	$iValue = Number($iValue)
	If $iValue >= 1000000 Then Return StringFormat("%.1fM", $iValue / 1000000)
	If $iValue >= 1000 Then Return StringFormat("%dK", Int($iValue / 1000))
	Return String(Int($iValue))
EndFunc   ;==>__RPCShort

; The invite the button leads to. Discord refuses an activity whose button URL is not a valid http(s)
; address, so an invite pasted without its scheme (discord.gg/abcd) gets one, and anything else is dropped:
; the status is then published without the button instead of being refused as a whole.
Func __RPCButtonUrl()
	Local $sUrl = StringStripWS($g_sDiscordRPCButtonUrl, 3)
	If $sUrl = "" Then Return ""
	If StringRegExp($sUrl, "^(?i)https?://") = 0 Then $sUrl = "https://" & $sUrl
	If StringRegExp($sUrl, "^(?i)https?://[\w.-]+\.[a-z]{2,}(/\S*)?$") = 0 Then
		SetDebugLog("Discord presence: invite '" & $sUrl & "' is not a valid link, button hidden", $COLOR_DEBUG)
		Return ""
	EndIf
	If StringLen($sUrl) > 512 Then Return ""
	Return $sUrl
EndFunc   ;==>__RPCButtonUrl
