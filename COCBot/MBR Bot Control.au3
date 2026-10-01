; #FUNCTION# ====================================================================================================================
; Name ..........: MBR Bot Control
; Description ...: The bot without a window: its hidden host window, start, stop, search mode, pause and close.
;                  The interface is GUI-Electron (GUI-Electron\): it edits the profile files and drives the bot through
;                  its window API (COCBot\functions\Other\ApiClient.au3), as MultiBot does.
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........: GkevinOD (2014)
; Modified ......: Hervidero (2015), kaganus (08-2015), CodeSlinger69 (01-2017), headless rewrite (2026)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  Taken from the former MBR GUI Design, MBR GUI Control, MBR GUI Action and splash screen files.
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once

Global $g_hLaunchMutex = 0 ; held while this bot launches: one bot launches at a time, it uses a lot of CPU
Global $g_bBotCanStart = False ; the prerequisites (MyBot.run.dll, .NET, files...) were found at launch, see CanBotStart()

#Region Host window
; The bot keeps one window, never shown: it carries the bot title that the interface, MultiBot, the Watchdog and the
; other bots look for, and it receives the API messages ("MyBot.run/API/1.1").
Func CreateBotWindow()
	$g_hFrmBot = GUICreate($g_sBotTitle, 32, 32, -1, -1, $WS_POPUP)
	UpdateBotTitle()
	; WM_CLOSE (CloseRunningBot of a restarting bot, Task Manager) asks the bot to close, as its API does
	GUISetOnEvent($GUI_EVENT_CLOSE, "BotCloseRequest", $g_hFrmBot)
EndFunc   ;==>CreateBotWindow

; Launch only one bot at a time: launching consumes too much CPU (was done by the splash screen).
Func LaunchLock()
	$g_hLaunchMutex = AcquireMutexTicket("Launching", 1, Default, False)
EndFunc   ;==>LaunchLock

Func LaunchUnlock()
	If $g_hLaunchMutex = 0 Then Return
	ReleaseMutex($g_hLaunchMutex)
	$g_hLaunchMutex = 0
EndFunc   ;==>LaunchUnlock

; A launch step, in the debug log (was the splash screen progress).
Func LaunchStep($sStatus)
	SetDebugLog("Launch: " & $sStatus & " (" & Round(__TimerDiff($g_hBotLaunchTime) / 1000, 2) & " sec)")
EndFunc   ;==>LaunchStep

; The profile to run: created when the command line names a new one, then read.
Func InitializeBotProfile()
	; Initialize attack log
	AtkLogHead()

	If FileExists($g_sProfileConfigPath) = 0 And $g_asCmdLine[0] > 0 Then
		; create new profile when doesn't exist but specified via command line
		createProfile()
		saveConfig()
	EndIf
	setupProfileComboBox() ; the list of profiles, used by the account switch
	selectProfile() ; also reads the settings of the profile
EndFunc   ;==>InitializeBotProfile

Func CheckDpiAwareness($bCheckOnlyIfAlreadyAware = False, $bForceDpiAware = False, $bForceDpiAware2 = False)

	Static $sbDpiAware = False

	If $bCheckOnlyIfAlreadyAware = True Then Return $sbDpiAware

	Local $bDpiAware = False
	Local $bChanged = False

	If Not IsBotLaunched() And $bForceDpiAware2 = False Then Return $bChanged

	If $g_iDpiAwarenessMode <> 0 And RegRead("HKCU\Control Panel\Desktop\WindowMetrics", "AppliedDPI") <> 96 Then
		; DPI is different, check if awareness needs to be set
		$bDpiAware = $bForceDpiAware = True _ ; override to set DPI Awareness regardless of current state
				Or $g_bChkBackgroundMode = False _ ; in non background mode Desktop screen capture is totally wrong due to the scaling
				Or GetProcessDpiAwareness(GetAndroidPid()) ; in normal background mode using WinAPI and Android is DPI Aware, bot must be too or window will be scaled and blury
		$bChanged = $bDpiAware And Not $sbDpiAware
		If $bChanged Then
			$sbDpiAware = True ; do it only once, assume bot will become DPI aware
			; Make this process DPI aware, so it doesn't scale (for now only way to get bot working right)
			Local $aResult = DllCall("user32.dll", "boolean", "SetProcessDPIAware")
			SetDebugLog("SetProcessDPIAware called: " & @error & ((UBound($aResult) = 0) ? ("") : (", " & $aResult[0])))
		EndIf
	EndIf

	Return $bChanged
EndFunc   ;==>CheckDpiAwareness

Func GetProcessDpiAwareness($iPid)
	$iPid = ProcessExists($iPid)
	If $iPid = 0 Then
		Return SetError(1, 0, 0)
	EndIf
	Local $hProcess
	If _WinAPI_GetVersion() >= 6.0 Then
		$hProcess = _WinAPI_OpenProcess($PROCESS_QUERY_LIMITED_INFORMATION, 0, $iPid)
	Else
		$hProcess = _WinAPI_OpenProcess($PROCESS_QUERY_INFORMATION, 0, $iPid)
	EndIf
	If @error Then
		Return SetError(2, 0, 0)
	EndIf
	Local $aResult = DllCall("user32.dll", "boolean", "GetProcessDpiAwarenessInternal", "handle", $hProcess, "ulong*", 0)
	_WinAPI_CloseHandle($hProcess)
	If @error Or UBound($aResult) < 3 Then Return SetError(3, 0, 0)
	Local $iDpiAwareness = $aResult[2]
	Return $iDpiAwareness
EndFunc   ;==>GetProcessDpiAwareness

Func DisableProcessWindowsGhosting()
	DllCall($g_hLibUser32DLL, "none", "DisableProcessWindowsGhosting")
EndFunc   ;==>DisableProcessWindowsGhosting

Func ConsoleWindow($bShow = Default)
	Static $bConsoleAllocated = False
	If $bShow = Default Then $bShow = Not $bConsoleAllocated
	If $bShow Then
		_WinAPI_AllocConsole()
		_WinAPI_SetConsoleIcon($g_sLibIconPath, $eIcnGUI)
		$bConsoleAllocated = True
		SetDebugLog("Allocate Console Window")
	Else
		SetDebugLog("Free Console Window")
		_WinAPI_FreeConsole()
		$bConsoleAllocated = False
	EndIf
EndFunc   ;==>ConsoleWindow

; /? : the command line help, on the console (the bot has no window to show it in).
Func ShowCommandLineHelp()
	ConsoleWindow(True)
	ConsoleWrite($g_sBotTitle & @CRLF & @CRLF & _
			"MyBot.run.exe [profile] [emulator] [instance] [options]" & @CRLF & _
			"   (from the sources: AutoIt3.exe MyBot.run.au3 [profile] [emulator] [instance] [options])" & @CRLF & @CRLF & _
			"  /autostart, /a       start the run once the bot is up" & @CRLF & _
			"  /hideandroid, /ha    hide the emulator window" & @CRLF & _
			"  /nowatchdog, /nwd    no Watchdog (a crashed bot is not relaunched)" & @CRLF & _
			"  /restart, /r         close the bot already running for this profile first" & @CRLF & _
			"  /dpiaware, /da       for a Windows zoom above 100 %" & @CRLF & _
			"  /debug, /dev         developer mode, detailed log" & @CRLF & _
			"  /console, /c         open a console window" & @CRLF & _
			"  /profiles=<folder>   another Profiles folder" & @CRLF & @CRLF & _
			"The interface is GUI-Electron: ""Lancer MyBot GUI.bat"" (Windows) or ""Lancer MyBot GUI.sh"" (Linux)." & @CRLF)
	Sleep(10000) ; time to read it before the console closes
EndFunc   ;==>ShowCommandLineHelp
#EndRegion Host window

#Region Requests
Func SetCriticalMessageProcessing($bEnterCritical = Default)
	If $bEnterCritical = Default Then Return $g_bCriticalMessageProcessing
	Local $wasCritical = $g_bCriticalMessageProcessing
	$g_bCriticalMessageProcessing = $bEnterCritical
	Return $wasCritical
EndFunc   ;==>SetCriticalMessageProcessing

Func IsConfigActive()
	Return $g_bReadConfigIsActive Or $g_bSaveConfigIsActive
EndFunc   ;==>IsConfigActive

Func IsBotLaunched()
	Return $g_iBotLaunchTime > 0
EndFunc   ;==>IsBotLaunched

; The lab and pet house upgrades end on their own: forget an upgrade time once it has passed.
Func SetTime()
	If _DateIsValid($g_sLabUpgradeTime) And _DateDiff("s", _NowCalc(), $g_sLabUpgradeTime) <= 0 Then $g_sLabUpgradeTime = ""
	If _DateIsValid($g_sPetUpgradeTime) And _DateDiff("s", _NowCalc(), $g_sPetUpgradeTime) <= 0 Then $g_sPetUpgradeTime = ""
EndFunc   ;==>SetTime

; Start and search mode are refused while a prerequisite is missing: the former window disabled its Start button.
Func CanBotStart()
	If $g_bBotCanStart Then Return True
	SetLog("Start refused: a file or a prerequisite of the bot is missing, see the messages above", $COLOR_ERROR)
	Return False
EndFunc   ;==>CanBotStart

Func btnStart()
	If Not CanBotStart() Then Return
	; decide when to run
	Local $bRunNow = $g_iBotAction <> $eBotNoAction
	If $bRunNow Then
		BotStart()
	Else
		$g_iBotAction = $eBotStart
	EndIf
	$g_iActualTrainSkip = 0
EndFunc   ;==>btnStart

Func btnStop()
	If $g_bRunState Then
		; always invoked in MyBot.run.au3!
		$g_bRunState = False ; Exit BotStart()
	EndIf
	$g_iBotAction = $eBotStop
EndFunc   ;==>btnStop

Func btnSearchMode()
	If Not CanBotStart() Then Return
	; decide when to run
	Local $bRunNow = $g_iBotAction <> $eBotNoAction
	If $bRunNow Then
		BotSearchMode()
	Else
		$g_iBotAction = $eBotSearchMode
	EndIf
EndFunc   ;==>btnSearchMode

Func btnPause($bRunNow = True)
	TogglePause()
EndFunc   ;==>btnPause

Func btnResume()
	TogglePause()
EndFunc   ;==>btnResume

Func btnMakeScreenshot()
	If $g_bRunState Then
		; call with flag when bot is running to execute on _sleep() idle
		$g_bMakeScreenshotNow = True
	Else
		; call directly when bot is stopped
		If $g_bScreenshotPNGFormat = False Then
			MakeScreenshot($g_sProfileTempPath, "jpg")
		Else
			MakeScreenshot($g_sProfileTempPath, "png")
		EndIf
	EndIf
EndFunc   ;==>btnMakeScreenshot

Func BotCloseRequest()
	If $g_iBotAction = $eBotClose Then
		; already requested to close, but user is impatient, so close now
		BotClose()
	Else
		SetLog("Closing " & $g_sBotTitle & ", please wait ...")
	EndIf
	$g_bRunState = False
	$g_bBotPaused = False
	$g_iBotAction = $eBotClose
EndFunc   ;==>BotCloseRequest

Func BotClose($SaveConfig = Default, $bExit = True)
	If $SaveConfig = Default Then $SaveConfig = IsBotLaunched()
	$g_bRunState = False
	$g_bBotPaused = False
	ResumeAndroid()
	SetLog("Closing " & $g_sBotTitle & " now ...")
	LockBotSlot(False)

	If $SaveConfig = True Then
		setupProfile()
		SaveConfig()
	EndIf

	; ensure windows are not top anymore
	$g_bChkBackgroundMode = True

	If $g_bAndroidCloseWithBot And $g_hAndroidWindow Then
		$g_bRunState = True
		CloseAndroid("BotClose")
		$g_bRunState = False
	Else
		AndroidBotStopEvent() ; signal android that bot is now stoppting
		AndroidToFront(Default, "BotClose")
		AndroidAdbTerminateShellInstance()
	EndIf

	; Close Mutexes
	If $g_hMutex_BotTitle <> 0 Then ReleaseMutex($g_hMutex_BotTitle)
	ReleaseProfilesMutex(True)
	If $g_hMutex_MyBot <> 0 Then ReleaseMutex($g_hMutex_MyBot)
	; Clean up resources
	__GDIPlus_Shutdown()
	_Crypt_Shutdown()
	TCPShutdown() ; Close the TCP service.

	If $g_hAndroidWindow <> 0 Then ControlFocus($g_hAndroidWindow, "", $g_hAndroidWindow) ; show Android in taskbar again
	GUIDelete($g_hFrmBot)

	; Global DllStuctCreate
	$g_aiAndroidAdbScreencapBuffer = 0 ; Allocated in MBR Global Variables.au3
	$g_hStruct_SleepMicro = 0 ; Allocated in MBR Global Variables.au3, used in _Sleep.au3

	; Unregister managing hosts
	UnregisterManagedMyBotHost()

	If $bExit = True Then Exit
EndFunc   ;==>BotClose
#EndRegion Requests

#Region Start and stop
Func BotStart($bAutostartDelay = 0)
	FuncEnter(BotStart)

	If Not $g_bSearchMode Then
		If $g_hLogFile = 0 Then CreateLogFile() ; only create new log file when doesn't exist yet
		CreateAttackLogFile()
		If $g_iFirstRun = -1 Then $g_iFirstRun = 1
	EndIf
	SetLogCentered(" BOT LOG ", Default, Default, True)

	ResumeAndroid()
	CleanSecureFiles()
	; click delays of the profile
	Opt("MouseClickDelay", GetClickUpDelay())
	Opt("MouseClickDownDelay", GetClickDownDelay())

	$g_bRunState = True
	$g_bTogglePauseAllowed = True
	$g_bSkipFirstZoomout = False
	$g_bIsSearchLimit = False
	$g_bIsClientSyncError = False
	$g_bZoomoutFailureNotRestartingAnything = False
	$g_bRestart = False
	$g_bStayOnBuilderBase = False

	$g_bTrainEnabled = True
	$g_bDonationEnabled = True
	$g_bMeetCondStop = False
	$g_bIsClientSyncError = False
	$g_bFirstStart = True

	; the settings may have been edited (GUI-Electron) while the bot was stopped: what the bot learnt is saved first
	SaveConfig()
	readConfig()
	CreaTableDB()

	DiscordRPCStart() ; Discord profile status, does nothing when the option is off

	; Initial ObjEvents for the Autoit objects errors
	__ObjEventIni()

	If BitAND($g_iAndroidSupportFeature, 1 + 2) = 0 And $g_bChkBackgroundMode = True Then
		$g_bChkBackgroundMode = False
		CheckDpiAwareness()
		SetLog("Background Mode not supported for " & $g_sAndroidEmulator & " and has been disabled", $COLOR_ERROR)
	EndIf

	If $bAutostartDelay Then
		SetLog("Bot Auto Starting in " & Round($bAutostartDelay / 1000, 0) & " seconds", $COLOR_ERROR)
		_SleepStatus($bAutostartDelay)
	EndIf

	$g_sClanGamesScore = "N/A"
	$g_sClanGamesTimeRemaining = "N/A"
	$YourAccScore[0] = -1
	$YourAccScore[1] = True
	$IsCGEventRunning = 0
	$g_bIsBBevent = 0
	$g_bClanGamesCompleted = 0
	$g_bFirstStartBarrel = 1
	$g_sAvailableAppBuilder = 0
	$g_sAvailableLabAssistant = 0
	$g_iBuilderBoostDiscount = 0
	$g_bFirstStartForHiddenHero = 1
	$g_iHeroAvailable = $eHeroNone
	For $i = 0 To 4
		$g_aiHeroUpgradeFinishDate[$i] = 0
	Next
	For $i = 0 To 4
		$g_aiHeroNeededResource[$i] = 0
	Next
	For $i = 0 To 7
		$bCheckHeroOrder[$i] = False
	Next
	$g_aiAttackedCountPause = 0
	$g_aiAttackedCount = 0
	For $i = 0 To $g_iModeCount - 1
		$g_aiAttackedVillageCount[$i] = 0
	Next

	CleanSuperchargeTemplates()

	; wait for slot
	LockBotSlot(True)
	If $g_bRunState = False Then Return FuncReturn()

	Local $Result = False
	If WinGetAndroidHandle() = 0 Then
		$Result = OpenAndroid(False)
	EndIf
	SetDebugLog("Android Window Handle: " & WinGetAndroidHandle())
	If $g_hAndroidWindow <> 0 Then ;Is Android open?
		If Not $g_bRunState Then Return FuncReturn()
		If $g_bAndroidBackgroundLaunched = True Or AndroidControlAvailable() Then ; Really?
			If Not $Result Then
				$Result = InitiateLayout()
			EndIf
		Else
			; Not really
			SetLog("Current " & $g_sAndroidEmulator & " Window not supported by MyBot", $COLOR_ERROR)
			$Result = RebootAndroid(False)
		EndIf
		If Not $g_bRunState Then Return FuncReturn()
		Local $hWndActive = $g_hAndroidWindow
		; check if window can be activated
		If $g_bNoFocusTampering = False And $g_bAndroidBackgroundLaunched = False Then
			Local $hTimer = __TimerInit()
			$hWndActive = -1
			Local $activeHWnD = WinGetHandle("")
			While __TimerDiff($hTimer) < 1000 And $hWndActive <> $g_hAndroidWindow And Not _Sleep(100)
				$hWndActive = WinActivate($g_hAndroidWindow) ; ensure bot has window focus
			WEnd
			WinActivate($activeHWnD) ; restore current active window
		EndIf
		If Not $g_bRunState Then Return FuncReturn()
		If $hWndActive = $g_hAndroidWindow And ($g_bAndroidBackgroundLaunched = True Or AndroidControlAvailable()) Then  ; Really?
			Initiate() ; Initiate and run bot
		Else
			SetLog("Cannot use " & $g_sAndroidEmulator & ", please check log", $COLOR_ERROR)
			btnStop()
		EndIf
	Else
		SetLog("Cannot start " & $g_sAndroidEmulator & ", please check log", $COLOR_ERROR)
		btnStop()
	EndIf
	FuncReturn()
EndFunc   ;==>BotStart

Func BotStop()
	CleanSuperchargeTemplates()
	FuncEnter(BotStop)
	DiscordRPCStop() ; clears the status on the Discord profile
	NotifyDiscordLogFlush(True) ; full log to Discord option: do not keep the last lines waiting
	; release bot slot
	LockBotSlot(False)

	; release other switch accounts
	releaseProfilesMutex()

	ResumeAndroid()

	$g_bRunState = False
	$g_bBotPaused = False
	$g_bTogglePauseAllowed = True
	$g_bRestart = False

	AndroidBotStopEvent() ; signal android that bot is now stopping
	If $g_bTerminateAdbShellOnStop Then
		AndroidAdbTerminateShellInstance() ; terminate shell instance
	EndIf

	$g_bBtnAttackNowPressed = False

	SetLogCentered(" Bot Stop ", Default, $COLOR_ACTION)
	If Not $g_bSearchMode Then
		If Not $g_bBotPaused Then $g_iTimePassed += Int(__TimerDiff($g_hTimerSinceStarted))
		If ProfileSwitchAccountEnabled() And Not $g_bBotPaused Then $g_aiRunTime[$g_iCurAccount] += Int(__TimerDiff($g_ahTimerSinceSwitched[$g_iCurAccount]))

		If $g_hLogFile <> 0 Then
			FileClose($g_hLogFile)
			$g_hLogFile = 0
		EndIf

		If $g_hAttackLogFile <> 0 Then
			FileClose($g_hAttackLogFile)
			$g_hAttackLogFile = 0
		EndIf
	Else
		$g_bSearchMode = False
	EndIf

	; Ends ObjEvents for the Autoit objects errors
	__ObjEventEnds()

	ReduceBotMemory()
	FuncReturn()
EndFunc   ;==>BotStop

Func BotSearchMode()
	FuncEnter(BotSearchMode)
	$g_bSearchMode = True
	$g_bRestart = False
	$g_bIsClientSyncError = False
	If $g_iFirstRun = 1 Then $g_iFirstRun = -1
	btnStart()
	checkMainScreen(False)
	If _Sleep(100) Then Return FuncReturn()
	$g_aiCurrentLoot[$eLootTrophy] = getLeagueTier($aLeagueTierMain) ; league tier since CoC 18.600, trophies are gone ; get OCR to read current Village Trophies
	If _Sleep(100) Then Return FuncReturn()
	CheckIfArmyIsReady()
	ClickAway()
	If _Sleep(100) Then Return FuncReturn()
	If IsSearchModeActive($DB) Or IsSearchModeActive($LB) Then
		If _Sleep(100) Then Return FuncReturn()
		PrepareSearch()
		If $g_bOutOfGold Then Return ; Check flag for enough gold to search
		If $g_bRestart Then
			CleanSuperchargeTemplates()
			Return
		EndIf
		If _Sleep(1000) Then Return FuncReturn()
		VillageSearch()
		If $g_bOutOfGold Then Return ; Check flag for enough gold to search
		If _Sleep(100) Then Return FuncReturn()
		CleanSuperchargeTemplates()
	Else
		SetLog("Your Army is not prepared, check the Attack/train options")
	EndIf
	btnStop()
	FuncReturn()
EndFunc   ;==>BotSearchMode

Func Initiate()
	WinGetAndroidHandle()
	If $g_hAndroidWindow <> 0 And ($g_bAndroidBackgroundLaunched = True Or AndroidControlAvailable()) Then
		SetLogCentered(" " & $g_sBotTitle & " Powered by MyBot.run ", "~", $COLOR_DEBUG)

		Local $Compiled = @ScriptName & (@Compiled ? " Executable" : " Script")
		SetLog($Compiled & " running on " & @OSVersion & " " & @OSServicePack & " " & @OSArch)

		If _Sleep($DELAYRESPOND) Then Return
		If StringInStr(@OSVersion, "WIN_11", $STR_NOCASESENSEBASIC) Or _
				StringInStr(@OSVersion, "WIN_2019", $STR_NOCASESENSEBASIC) Or _
				StringInStr(@OSVersion, "WIN_2022", $STR_NOCASESENSEBASIC) Then
			SetLog(" Windows 11 detected, emulator detection uses window scan", $COLOR_INFO)
		EndIf

		Local $sGameVersion = GetCoCAppVersion()
		If Not @error Then SetLog(">>  CoC Game App Version = " & $sGameVersion, $COLOR_DEBUG)

		If Not $g_bSearchMode Then
			SetLogCentered(" Bot Start ", Default, $COLOR_SUCCESS)
		Else
			SetLogCentered(" Search Mode Start ", Default, $COLOR_SUCCESS)
		EndIf
		SetLogCentered("  Current Profile: " & $g_sProfileCurrentName & " ", "-", $COLOR_INFO)
		If $g_bDebugSetLog Or $g_bDebugOcr Or $g_bDebugRedArea Or $g_bDevMode Or $g_bDebugImageSave Or $g_bDebugBuildingPos Or $g_bDebugOCRdonate Or $g_bDebugAttackCSV Or $g_bDebugAndroid Then
			SetLogCentered(" Warning Debug Mode Enabled! ", "-", $COLOR_ERROR)
			SetLog("      SetLog : " & $g_bDebugSetLog, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("     Android : " & $g_bDebugAndroid, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("         OCR : " & $g_bDebugOcr, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("     RedArea : " & $g_bDebugRedArea, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("   ImageSave : " & $g_bDebugImageSave, $COLOR_ERROR, "Lucida Console", 8)
			SetLog(" BuildingPos : " & $g_bDebugBuildingPos, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("   OCRDonate : " & $g_bDebugOCRdonate, $COLOR_ERROR, "Lucida Console", 8)
			SetLog("   AttackCSV : " & $g_bDebugAttackCSV, $COLOR_ERROR, "Lucida Console", 8)
			SetLogCentered(" Warning Debug Mode Enabled! ", "-", $COLOR_ERROR)
		EndIf

		$g_bInitiateSwitchAcc = True
		$g_sLabUpgradeTime = ""
		$g_sPetUpgradeTime = ""
		$g_sBSmithUpgradeTime = ""
		For $i = 0 To $eLootCount - 1
			$g_abFullStorage[$i] = False
		Next

		If Not $g_bSearchMode Then
			$g_hTimerSinceStarted = __TimerInit()
		EndIf

		AndroidBotStartEvent() ; signal android that bot is now running
		If Not $g_bRunState Then Return

		If Not $g_bSearchMode Then
			If $g_bRestarted Then
				$g_bRestarted = False
				IniWrite($g_sProfileConfigPath, "general", "Restarted", 0)
				PushMsg("Restarted")
			EndIf
		EndIf
		If Not $g_bRunState Then Return

		checkMainScreen()
		If Not $g_bRunState Then Return

		ZoomOut()
		If Not $g_bRunState Then Return

		If Not $g_bSearchMode Then
			BotDetectFirstTime()
			If Not $g_bRunState Then Return

			If $g_bCheckGameLanguage Then TestLanguage()
			If Not $g_bRunState Then Return

			runBot()
		EndIf
	Else
		SetLog("Not in Game!", $COLOR_ERROR)
		btnStop()
	EndIf
EndFunc   ;==>Initiate

Func InitiateLayout()

	WinGetAndroidHandle()
	Local $BSsize = getAndroidPos()

	If IsArray($BSsize) Then ; Is Android Client Control available?

		Local $BSx = $BSsize[2]
		Local $BSy = $BSsize[3]

		SetDebugLog("InitiateLayout: " & $g_sAndroidTitle & " Android-ClientSize: " & $BSx & " x " & $BSy, $COLOR_INFO)

		If Not CheckScreenAndroid($BSx, $BSy) Then ; Is Client size now correct?
			Return RebootAndroidSetScreen() ; recursive call!
		EndIf

		DisposeWindows()
		Return True

	EndIf

	Return False

EndFunc   ;==>InitiateLayout

;~ Hide Android Window again without overwriting $botPos[0] and [1]
Func reHide()
	WinGetAndroidHandle()
	If $g_bIsHidden And $g_hAndroidWindow <> 0 Then
		SetDebugLog("Hide " & $g_sAndroidEmulator & " Window after restart")
		Return HideAndroidWindow(True, Default, Default, "reHide")
	EndIf
	Return 0
EndFunc   ;==>reHide

Func GetCoCAppVersion()
	Local $sCMD = "dumpsys package " & $g_sAndroidGamePackage & " | grep versionName"  ;Get info from APK and grep version number line from text string
	Local $sReturn = AndroidAdbSendShellCommand($sCMD) ; Grep return string = versionName=15.352.8
	If @error Then
		SetLog("Failed to get CoC vesion, Result= " & $sReturn, $COLOR_ERROR)
		SetError(1)
		Return
	EndIf
	Local $sCleanReturn = StringStripWS($sReturn, $STR_STRIPALL)  ; strip white space
	SetDebugLog("Clash of Clans Game App = " & $sCleanReturn)
	Return StringTrimLeft($sCleanReturn, 12)  ; return version number string
EndFunc   ;==>GetCoCAppVersion
#EndRegion Start and stop

#Region Profiles and emulators
; Account switch: load the profile named in $g_sProfileCurrentName, saving the current one first.
Func LoadProfile($bSaveCurrentProfile = True)
	If $bSaveCurrentProfile Then
		saveConfig()
	EndIf

	If setupProfile() Then
		readConfig()
		saveConfig()
		SetLog("Profile " & $g_sProfileCurrentName & " loaded from " & $g_sProfileConfigPath, $COLOR_SUCCESS)
		Return True
	EndIf
	Return False
EndFunc   ;==>LoadProfile

; The emulators found on this machine, in the log.
Func getAllEmulators()

	Local $sEmulatorString = ""

	$__BlueStacks5_Version = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks_nxt\", "Version")
	If Not @error Then
		If GetVersionNormalized($__BlueStacks5_Version) > GetVersionNormalized("5.0") Then $sEmulatorString &= "BlueStacks5|"
	EndIf

	Local $NoxEmulator = GetNoxPath()
	If FileExists($NoxEmulator) Then $sEmulatorString &= "Nox|"

	Local $MEmuEmulator = GetMEmuPath()
	If FileExists($MEmuEmulator) Then $sEmulatorString &= "MEmu|"

	; Generic : any Android already answering on ADB (an AVD, Waydroid, a device, or an emulator
	; outside Windows while the bot runs under Wine). Listed only when a device really answers, so
	; a machine with no ADB device sees exactly the list it saw before. See AndroidGeneric.au3.
	If GenericAdbDeviceReady(True, False) Then $sEmulatorString &= "Generic|"

	If StringRight($sEmulatorString, 1) == "|" Then $sEmulatorString = StringTrimRight($sEmulatorString, 1)

	Local $aEmulator = StringSplit($sEmulatorString, "|", $STR_NOCOUNT)
	If $sEmulatorString <> "" Then
		SetLog("Emulator" & (UBound($aEmulator) > 1 ? "s" : "") & " Found In Your Machine :")
		For $i = 0 To UBound($aEmulator) - 1
			Local $emuVer = ""
			If StringInStr($aEmulator[$i], "BlueStacks5") Then $emuVer = $__BlueStacks5_Version
			If StringInStr($aEmulator[$i], "Memu") Then $emuVer = $__MEmu_Version
			If StringInStr($aEmulator[$i], "nox") Then $emuVer = $__Nox_Version
			If StringInStr($aEmulator[$i], "Generic") Then $emuVer = "ADB device " & GetGenericAdbDevice()
			SetLog("  - " & $aEmulator[$i] & " version: " & $emuVer, $COLOR_SUCCESS)
		Next
	Else
		SetLog("No Emulator found in your machine")
	EndIf
EndFunc   ;==>getAllEmulators
#EndRegion Profiles and emulators
