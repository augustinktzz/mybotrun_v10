; #FUNCTION# ====================================================================================================================
; Name ..........: MultiBot
; Description ...: Launches and manages several bots at once: one MyBot.run.exe per profile, each on its own emulator instance.
; Author ........: MyBot.run team, rewritten for MyBot v10 (2026)
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  Every setup is a section of Profiles\MultiBot-Profiles.ini (Profile, Emulator, Instance, Parameters), the
;                  same file the original MultiBot used. A setup is started like the .bat does it:
;                      MyBot.run.exe <profile> <emulator> <instance> [/hideandroid /minigui /nowatchdog /debug /dpiaware /autostart]
;                  The bots are then driven through their own API, the window message "MyBot.run/API/1.1": start and stop
;                  the run, pause, resume and close. Closing that way lets the bot save its settings and end its Watchdog,
;                  which would otherwise relaunch a bot that was simply killed. The same message answers a state query,
;                  shown in the State column and refreshed every few seconds.
;                  Nothing here reads the game: MultiBot only talks to the bot windows and to the emulator.
; ===============================================================================================================================
#pragma compile(Icon, "Images\MyBot.ico")
#pragma compile(FileDescription, MultiBot - starts and manages several MyBot instances)
#pragma compile(ProductName, MultiBot)
; the bots run elevated (#RequireAdmin in MyBot.run.au3): from a lower level their command lines are unreadable and
; Windows drops the messages sent to their windows, so MultiBot has to run at the same level
#RequireAdmin

#include <Array.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiListView.au3>
#include <GuiMenu.au3>
#include <ListViewConstants.au3>
#include <Misc.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3>
#include <WinAPIProc.au3>
#include <WinAPISys.au3>
#include <WinAPISysWin.au3>
#include <WindowsConstants.au3>

If _Singleton("MyBot.run/MultiBot", 1) = 0 Then
	Local $hOther = WinGetHandle("[TITLE:MultiBot; CLASS:AutoIt v3 GUI]")
	If Not @error Then
		WinSetState($hOther, "", @SW_SHOW)
		WinSetState($hOther, "", @SW_RESTORE)
		WinActivate($hOther)
	EndIf
	Exit
EndIf

; --------------------------------------------------------------------------------------------------------------------
; settings
; --------------------------------------------------------------------------------------------------------------------
Global Const $g_sBotExe = "MyBot.run.exe", $g_sBotAu3 = "MyBot.run.au3"
Global Const $g_sIni = @ScriptDir & "\Profiles\MultiBot-Profiles.ini"
Global Const $g_sGlobalIni = @ScriptDir & "\Profiles\profile.ini"
Global Const $g_iParameters = 6 ; Parameters = string of 0/1: debug, dpiaware, hideandroid, minigui, nowatchdog, autostart
Global Const $g_asParamSwitch[$g_iParameters] = ["/debug", "/dpiaware", "/hideandroid", "/minigui", "/nowatchdog", "/autostart"]

; the bot API (COCBot\functions\Other\Api.au3 and ApiClient.au3): wParam low word = command, high word = state bits,
; lParam = window of the sender, which receives the answer with the same message
Global Const $WM_MYBOTRUN_API = _WinAPI_RegisterWindowMessage("MyBot.run/API/1.1")
Global Const $API_QUERY = 0x00FF ; state query that does not register the sender as a bot host
Global Const $API_START = 0x1000, $API_STOP = 0x1010, $API_RESUME = 0x1020, $API_PAUSE = 0x1030, $API_CLOSE = 0x1040
Global Const $API_RUNNING = 1, $API_PAUSED = 2, $API_LAUNCHED = 4

Global Enum $eColProfile = 0, $eColInstance, $eColState
Global Enum $eMenuStartBot = 1000, $eMenuCloseBot, $eMenuRestartBot, $eMenuStartRun, $eMenuStopRun, $eMenuPause, $eMenuResume, _
		$eMenuStartVM, $eMenuStopVM, $eMenuEdit, $eMenuDelete, $eMenuShortcut, $eMenuAutostart

Global $g_hGui = 0, $g_hList = 0, $g_hMenuContext = 0, $g_bHidden = False
Global $g_hBtnNew, $g_hBtnStartAll, $g_hBtnCloseAll, $g_hBtnStartVMs, $g_hBtnStopVMs, $g_hMenuBotDir, $g_hMenuProfileDir, $g_hMenuAdbReset
Global $g_hTrayShow, $g_hTrayStartAll, $g_hTrayCloseAll, $g_hTrayExit

; running bots: profile | pid | hwnd | state text | last answer (TimerInit) | command line
Global $g_aBots[0][6]
Global $g_hPollTimer = 0

Main()

; --------------------------------------------------------------------------------------------------------------------
; main window
; --------------------------------------------------------------------------------------------------------------------
Func Main()
	Opt("TrayMenuMode", 3)
	Opt("TrayOnEventMode", 0)
	Opt("GUIOnEventMode", 0)

	$g_hGui = GUICreate("MultiBot", 420, 400, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX), $WS_EX_ACCEPTFILES)
	GUISetIcon(@ScriptDir & "\Images\MyBot.ico", -1, $g_hGui)
	Local $hMenu = GUICtrlCreateMenu("Menu")
	$g_hMenuBotDir = GUICtrlCreateMenuItem("Open the bot folder", $hMenu)
	$g_hMenuProfileDir = GUICtrlCreateMenuItem("Open the Profiles folder", $hMenu)
	GUICtrlCreateMenuItem("", $hMenu)
	$g_hMenuAdbReset = GUICtrlCreateMenuItem("ADB reset (kills adb.exe and HD-Adb.exe)", $hMenu)

	$g_hList = GUICtrlCreateListView("", 8, 8, 404, 270, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_SINGLESEL))
	_GUICtrlListView_SetExtendedListViewStyle($g_hList, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
	_GUICtrlListView_InsertColumn($g_hList, $eColProfile, "Profile", 180)
	_GUICtrlListView_InsertColumn($g_hList, $eColInstance, "Instance", 110)
	_GUICtrlListView_InsertColumn($g_hList, $eColState, "State", 90)
	GUICtrlSetTip($g_hList, "Double click: start the bot of that setup. Right click: everything else.")

	$g_hBtnNew = GUICtrlCreateButton("New setup", 8, 286, 404, 26)
	GUICtrlSetTip(-1, "A setup is a profile of the bot on one emulator instance")
	$g_hBtnStartAll = GUICtrlCreateButton("Start all bots", 8, 318, 198, 26)
	GUICtrlSetTip(-1, "Launches one bot per setup, a second apart")
	$g_hBtnCloseAll = GUICtrlCreateButton("Close all bots", 214, 318, 198, 26)
	GUICtrlSetTip(-1, "Asks every bot to close itself, the way its own Exit does")
	$g_hBtnStartVMs = GUICtrlCreateButton("Start all instances", 8, 350, 198, 26)
	GUICtrlSetTip(-1, "Starts the emulator instance of every setup")
	$g_hBtnStopVMs = GUICtrlCreateButton("Stop all instances", 214, 350, 198, 26)
	GUICtrlSetTip(-1, "Ends the emulator instance of every setup (close the bots first)")

	$g_hMenuContext = _GUICtrlMenu_CreatePopup()
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Start bot", $eMenuStartBot)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Close bot", $eMenuCloseBot)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Restart bot", $eMenuRestartBot)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "")
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Start the run", $eMenuStartRun)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Stop the run", $eMenuStopRun)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Pause", $eMenuPause)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Resume", $eMenuResume)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "")
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Start the instance", $eMenuStartVM)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Stop the instance", $eMenuStopVM)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "")
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Desktop shortcut", $eMenuShortcut)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Start with Windows", $eMenuAutostart)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "")
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Edit", $eMenuEdit)
	_GUICtrlMenu_AddMenuItem($g_hMenuContext, "Delete", $eMenuDelete)

	$g_hTrayShow = TrayCreateItem("Show MultiBot")
	TrayCreateItem("")
	$g_hTrayStartAll = TrayCreateItem("Start all bots")
	$g_hTrayCloseAll = TrayCreateItem("Close all bots")
	TrayCreateItem("")
	$g_hTrayExit = TrayCreateItem("Exit")
	TraySetIcon(@ScriptDir & "\Images\MyBot.ico")
	TraySetToolTip("MultiBot")
	TraySetState($TRAY_ICONSTATE_SHOW)

	GUIRegisterMsg($WM_MYBOTRUN_API, "OnBotAnswer")
	GUIRegisterMsg($WM_NOTIFY, "OnListNotify")
	GUISetState(@SW_SHOW, $g_hGui)

	DirCreate(@ScriptDir & "\Profiles")
	RefreshList()
	$g_hPollTimer = TimerInit()
	PollBots(True)

	While True
		Local $aMsg = GUIGetMsg(1)
		If $aMsg[1] = $g_hGui Then
			Switch $aMsg[0]
				Case $GUI_EVENT_CLOSE
					HideToTray()
				Case $g_hBtnNew
					If EditSetup("") Then RefreshList()
				Case $g_hBtnStartAll
					ForEachSetup("StartBot", 1000)
				Case $g_hBtnCloseAll
					ForEachSetup("CloseBot", 0)
				Case $g_hBtnStartVMs
					ForEachSetup("StartInstance", 1000)
				Case $g_hBtnStopVMs
					ForEachSetup("StopInstance", 0)
				Case $g_hMenuBotDir
					ShellExecute(@ScriptDir)
				Case $g_hMenuProfileDir
					ShellExecute(@ScriptDir & "\Profiles")
				Case $g_hMenuAdbReset
					AdbReset()
			EndSwitch
		EndIf
		Switch TrayGetMsg()
			Case $g_hTrayShow, $TRAY_EVENT_PRIMARYDOUBLE
				ShowFromTray()
			Case $g_hTrayStartAll
				ForEachSetup("StartBot", 1000)
			Case $g_hTrayCloseAll
				ForEachSetup("CloseBot", 0)
			Case $g_hTrayExit
				Exit
		EndSwitch
		If TimerDiff($g_hPollTimer) > 3000 Then
			$g_hPollTimer = TimerInit()
			PollBots()
		EndIf
		Sleep(10)
	WEnd
EndFunc   ;==>Main

Func HideToTray()
	$g_bHidden = True
	GUISetState(@SW_HIDE, $g_hGui)
	TrayTip("MultiBot", "Still running here. Double click to open it, Exit to end it.", 3)
EndFunc   ;==>HideToTray

Func ShowFromTray()
	$g_bHidden = False
	GUISetState(@SW_SHOW, $g_hGui)
	GUISetState(@SW_RESTORE, $g_hGui)
	WinActivate($g_hGui)
EndFunc   ;==>ShowFromTray

; double click starts the bot, right click opens the menu
Func OnListNotify($hWnd, $iMsg, $wParam, $lParam)
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	If HWnd(DllStructGetData($tNMHDR, "hWndFrom")) <> GUICtrlGetHandle($g_hList) Then Return $GUI_RUNDEFMSG
	Local $iCode = DllStructGetData($tNMHDR, "Code")
	Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $lParam)
	Local $iIndex = DllStructGetData($tInfo, "Index")
	Switch $iCode
		Case $NM_DBLCLK
			If $iIndex >= 0 Then StartBot(_GUICtrlListView_GetItemText($g_hList, $iIndex, $eColProfile))
		Case $NM_RCLICK
			If $iIndex >= 0 Then
				_GUICtrlListView_SetItemSelected($g_hList, $iIndex, True, True)
				ContextMenu(_GUICtrlListView_GetItemText($g_hList, $iIndex, $eColProfile))
			EndIf
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>OnListNotify

Func ContextMenu($sProfile)
	Local $bOn = (BotWindow($sProfile) <> 0)
	_GUICtrlMenu_SetItemEnabled($g_hMenuContext, $eMenuStartBot, Not $bOn, False)
	Local $aiOnlyOpen[6] = [$eMenuCloseBot, $eMenuRestartBot, $eMenuStartRun, $eMenuStopRun, $eMenuPause, $eMenuResume]
	For $iItem In $aiOnlyOpen
		_GUICtrlMenu_SetItemEnabled($g_hMenuContext, $iItem, $bOn, False)
	Next
	_GUICtrlMenu_SetItemChecked($g_hMenuContext, $eMenuAutostart, FileExists(StartupLink($sProfile)), False)
	Switch _GUICtrlMenu_TrackPopupMenu($g_hMenuContext, $g_hGui, -1, -1, 1, 1, 2)
		Case $eMenuStartBot
			StartBot($sProfile)
		Case $eMenuCloseBot
			CloseBot($sProfile)
		Case $eMenuRestartBot
			If CloseBot($sProfile, True) Then StartBot($sProfile)
		Case $eMenuStartRun
			SendBot($sProfile, $API_START)
		Case $eMenuStopRun
			SendBot($sProfile, $API_STOP)
		Case $eMenuPause
			SendBot($sProfile, $API_PAUSE)
		Case $eMenuResume
			SendBot($sProfile, $API_RESUME)
		Case $eMenuStartVM
			StartInstance($sProfile)
		Case $eMenuStopVM
			StopInstance($sProfile)
		Case $eMenuShortcut
			MakeShortcut($sProfile, @DesktopDir & "\MyBot - " & $sProfile & ".lnk")
			TrayTip("MultiBot", "Shortcut created on the Desktop for " & $sProfile, 3)
		Case $eMenuAutostart
			If FileExists(StartupLink($sProfile)) Then
				FileDelete(StartupLink($sProfile))
			Else
				MakeShortcut($sProfile, StartupLink($sProfile))
			EndIf
		Case $eMenuEdit
			If EditSetup($sProfile) Then RefreshList()
		Case $eMenuDelete
			If MsgBox(BitOR($MB_YESNO, $MB_ICONQUESTION), "MultiBot", "Remove the setup " & $sProfile & " from MultiBot?" & @CRLF & "(the profile folder and its settings are kept)", 0, $g_hGui) = $IDYES Then
				IniDelete($g_sIni, $sProfile)
				FileDelete(StartupLink($sProfile))
				RefreshList()
			EndIf
	EndSwitch
EndFunc   ;==>ContextMenu

; --------------------------------------------------------------------------------------------------------------------
; setups (Profiles\MultiBot-Profiles.ini)
; --------------------------------------------------------------------------------------------------------------------
Func Setups()
	Local $aNone[0]
	Local $aSections = IniReadSectionNames($g_sIni)
	If @error Then Return $aNone
	Local $aList[0]
	For $i = 1 To $aSections[0]
		If $aSections[$i] = "Options" Then ContinueLoop
		ReDim $aList[UBound($aList) + 1]
		$aList[UBound($aList) - 1] = $aSections[$i]
	Next
	If UBound($aList) > 1 Then _ArraySort($aList)
	Return $aList
EndFunc   ;==>Setups

Func SetupEmulator($sProfile)
	Return IniRead($g_sIni, $sProfile, "Emulator", "BlueStacks5")
EndFunc   ;==>SetupEmulator

Func SetupInstance($sProfile)
	Return IniRead($g_sIni, $sProfile, "Instance", "Pie64")
EndFunc   ;==>SetupInstance

; the setup, other than $sExcept, that already uses this emulator instance; "" when it is free
Func SetupOnInstance($sEmulator, $sInstance, $sExcept = "")
	Local $aSetups = Setups()
	For $i = 0 To UBound($aSetups) - 1
		If $aSetups[$i] = $sExcept Then ContinueLoop
		If SetupEmulator($aSetups[$i]) = $sEmulator And SetupInstance($aSetups[$i]) = $sInstance Then Return $aSetups[$i]
	Next
	Return ""
EndFunc   ;==>SetupOnInstance

; the launch switches of a setup, from its 0/1 string
Func SetupSwitches($sProfile)
	Local $sBits = IniRead($g_sIni, $sProfile, "Parameters", "")
	Local $s = ""
	For $i = 0 To $g_iParameters - 1
		If StringMid($sBits, $i + 1, 1) = "1" Then $s &= " " & $g_asParamSwitch[$i]
	Next
	Return $s
EndFunc   ;==>SetupSwitches

; the command line of a setup, as the .bat writes it
Func SetupArguments($sProfile)
	Local $sName = $sProfile
	If StringInStr($sName, " ") Then $sName = '"' & $sName & '"'
	Return $sName & " " & SetupEmulator($sProfile) & " " & SetupInstance($sProfile) & SetupSwitches($sProfile)
EndFunc   ;==>SetupArguments

Func RefreshList()
	Local $iSelected = _GUICtrlListView_GetSelectedIndices($g_hList)
	_GUICtrlListView_BeginUpdate($g_hList)
	_GUICtrlListView_DeleteAllItems($g_hList)
	Local $aSetups = Setups()
	For $i = 0 To UBound($aSetups) - 1
		_GUICtrlListView_AddItem($g_hList, $aSetups[$i])
		_GUICtrlListView_AddSubItem($g_hList, $i, SetupInstance($aSetups[$i]), $eColInstance)
		_GUICtrlListView_AddSubItem($g_hList, $i, BotState($aSetups[$i]), $eColState)
	Next
	_GUICtrlListView_EndUpdate($g_hList)
	If $iSelected <> "" And Int($iSelected) < UBound($aSetups) Then _GUICtrlListView_SetItemSelected($g_hList, Int($iSelected))
	; setups written by an older MultiBot may share an instance: say it, the dialog refuses it from now on
	Static $bWarned = False
	If Not $bWarned Then
		$bWarned = True
		For $i = 0 To UBound($aSetups) - 1
			Local $sOther = SetupOnInstance(SetupEmulator($aSetups[$i]), SetupInstance($aSetups[$i]), $aSetups[$i])
			If $sOther <> "" Then
				MsgBox($MB_ICONWARNING, "MultiBot", $aSetups[$i] & " and " & $sOther & " use the same instance (" & SetupInstance($aSetups[$i]) & ")." & @CRLF & _
						"Only one of them can run: give each village its own instance (right click > Edit).", 0, $g_hGui)
				ExitLoop
			EndIf
		Next
	EndIf
EndFunc   ;==>RefreshList

Func ForEachSetup($sFunc, $iDelay)
	Local $aSetups = Setups()
	For $i = 0 To UBound($aSetups) - 1
		Call($sFunc, $aSetups[$i])
		If $iDelay > 0 And $i < UBound($aSetups) - 1 Then Sleep($iDelay)
	Next
EndFunc   ;==>ForEachSetup

; --------------------------------------------------------------------------------------------------------------------
; the setup dialog, for a new setup ($sProfile = "") or an existing one. Returns True when saved.
; The lower groups are settings of the bot itself, written into Profiles\<profile>\config.ini with the keys the
; bot reads (readConfig.au3); they apply at the next start of that bot.
; --------------------------------------------------------------------------------------------------------------------
Func EditSetup($sProfile)
	Local $bNew = ($sProfile = "")
	Local $sConfig = ProfileConfig($sProfile)
	Local $sBits = IniRead($g_sIni, $sProfile, "Parameters", "000000")

	Local $hDlg = GUICreate($bNew ? "New setup" : "Setup " & $sProfile, 430, 560, -1, -1, -1, -1, $g_hGui)

	GUICtrlCreateGroup("Bot", 8, 8, 414, 128)
	GUICtrlCreateLabel("Profile:", 20, 32, 60, 17)
	Local $hProfile = GUICtrlCreateInput($sProfile, 84, 29, 318, 21)
	GUICtrlSetTip(-1, "Name of the profile folder in Profiles\. It is created on the first start of that bot.")
	If Not $bNew Then GUICtrlSetState($hProfile, $GUI_DISABLE)
	GUICtrlCreateLabel("Emulator:", 20, 60, 60, 17)
	Local $hEmulator = GUICtrlCreateCombo("", 84, 57, 120, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	GUICtrlSetData($hEmulator, "BlueStacks5|MEmu", SetupEmulator($sProfile))
	GUICtrlCreateLabel("Instance:", 216, 60, 60, 17)
	Local $hInstance = GUICtrlCreateCombo("", 280, 57, 122, 21, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
	GUICtrlSetData($hInstance, BlueStacksInstances(), SetupInstance($sProfile))
	GUICtrlSetTip(-1, "The instance of the Multi-instance Manager (Pie64, Pie64_1...). One instance per bot.")
	Local $ahParam[$g_iParameters]
	Local $asParamLabel[$g_iParameters] = ["Debug log", "DPI aware", "Hide the emulator", "Mini GUI", "No Watchdog", "Start the run at once"]
	Local $asParamTip[$g_iParameters] = ["Writes the detailed debug log", "For screens with a Windows zoom above 100%", "The emulator window is hidden while the bot runs (background mode)", "Small bot window", "No Watchdog: a crashed bot is not relaunched", "The run starts by itself once the bot is up (/autostart)"]
	For $i = 0 To $g_iParameters - 1
		$ahParam[$i] = GUICtrlCreateCheckbox($asParamLabel[$i], 20 + Mod($i, 3) * 130, 86 + Int($i / 3) * 22, 128, 20)
		GUICtrlSetTip(-1, $asParamTip[$i])
		If StringMid($sBits, $i + 1, 1) = "1" Then GUICtrlSetState(-1, $GUI_CHECKED)
	Next
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	GUICtrlCreateGroup("Windows", 8, 142, 414, 100)
	Local $hAlign = GUICtrlCreateCheckbox("Arrange the windows", 20, 164, 140, 20)
	GUICtrlSetTip(-1, "The bot places its window and the emulator's as chosen on the right (Bot > Options)")
	Local $hAlignPos = GUICtrlCreateCombo("", 164, 163, 238, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $sAlignList = "0,0: Emulator - Bot|0,0: Bot - Emulator|SNAP: Bot top right of Emulator|SNAP: Bot top left of Emulator|SNAP: Bot bottom right of Emulator|SNAP: Bot bottom left of Emulator|DOCK: Emulator into Bot|FIXED: Emulator - Bot top right|FIXED: Emulator - Bot top left|FIXED: Emulator - Bot bottom right|FIXED: Emulator - Bot bottom left"
	GUICtrlSetData($hAlignPos, $sAlignList, ListItem($sAlignList, Int(IniRead($sConfig, "general", "DisposeWindowsPos", 6))))
	If IniRead($sConfig, "general", "DisposeWindows", 0) = 1 Then GUICtrlSetState($hAlign, $GUI_CHECKED)
	GUICtrlCreateLabel("Offset X:", 20, 194, 50, 17)
	Local $hOffX = GUICtrlCreateInput(IniRead($sConfig, "other", "WAOffsetX", ""), 72, 190, 50, 21, $ES_CENTER)
	GUICtrlCreateLabel("Y:", 130, 194, 16, 17)
	Local $hOffY = GUICtrlCreateInput(IniRead($sConfig, "other", "WAOffsetY", ""), 148, 190, 50, 21, $ES_CENTER)
	GUICtrlSetTip($hOffX, "Shift of the arranged windows in pixels, to place several setups side by side")
	GUICtrlCreateLabel("Screen capture:", 216, 194, 80, 17)
	Local $hBackground = GUICtrlCreateCombo("", 300, 190, 102, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $sBackgroundList = "Default|WinAPI|Screencap"
	GUICtrlSetData($hBackground, $sBackgroundList, ListItem($sBackgroundList, Int(IniRead($sConfig, "android", "backgroundmode", 0))))
	Local $hCloseAndroid = GUICtrlCreateCheckbox("Close the emulator with the bot", 20, 216, 200, 20)
	If IniRead($sConfig, "android", "close", 0) = 1 Then GUICtrlSetState($hCloseAndroid, $GUI_CHECKED)
	Local $hDedicatedAdb = GUICtrlCreateCheckbox("Dedicated ADB port", 236, 216, 166, 20)
	GUICtrlSetTip(-1, "Recommended with several instances: each bot keeps its own ADB connection")
	If IniRead($sConfig, "android", "adb.dedicated.instance", 0) = 1 Then GUICtrlSetState($hDedicatedAdb, $GUI_CHECKED)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	GUICtrlCreateGroup("Processor", 8, 248, 414, 78)
	GUICtrlCreateLabel("Emulator affinity:", 20, 272, 90, 17)
	Local $hAffinity = GUICtrlCreateInput(Int(IniRead($sConfig, "android", "process.affinity.mask", 0)), 112, 268, 56, 21, BitOR($ES_CENTER, $ES_NUMBER))
	GUICtrlSetTip(-1, "Bit mask of the processor cores the emulator may use, 0 = all (3 = cores 0 and 1, 12 = cores 2 and 3...)")
	GUICtrlCreateLabel("Bot threads:", 236, 272, 70, 17)
	Local $hThreads = GUICtrlCreateInput(Int(IniRead($sConfig, "general", "threads", 0)), 312, 268, 56, 21, BitOR($ES_CENTER, $ES_NUMBER))
	GUICtrlSetTip(-1, "Image search threads of this bot, 0 = automatic")
	GUICtrlCreateLabel("Bots active at once:", 20, 300, 100, 17)
	Local $hActiveBots = GUICtrlCreateInput(Int(IniRead($g_sGlobalIni, "general", "globalactivebotsallowed", 2)), 112, 296, 56, 21, BitOR($ES_CENTER, $ES_NUMBER))
	GUICtrlSetTip(-1, "Shared by all setups: how many bots may search or attack at the same time, the others wait their turn. Half the cores is a good value.")
	GUICtrlCreateLabel("Shared threads:", 236, 300, 76, 17)
	Local $hGlobalThreads = GUICtrlCreateInput(Int(IniRead($g_sGlobalIni, "general", "globalthreads", 0)), 312, 296, 56, 21, BitOR($ES_CENTER, $ES_NUMBER))
	GUICtrlSetTip(-1, "Shared by all setups: image search threads for all bots together, 0 = no limit")
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	GUICtrlCreateGroup("Halt attack (Bot > Options)", 8, 332, 414, 78)
	Local $hHalt = GUICtrlCreateCheckbox("Enabled", 20, 356, 70, 20)
	If IniRead($sConfig, "general", "BotStop", 0) = 1 Then GUICtrlSetState($hHalt, $GUI_CHECKED)
	Local $hHaltCommand = GUICtrlCreateCombo("", 96, 354, 140, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $sCommandList = "Halt Attack|Stop Bot|Close Bot|Close Android+Bot|Shutdown PC|Sleep PC|Reboot PC|Turn Idle"
	GUICtrlSetData($hHaltCommand, $sCommandList, ListItem($sCommandList, Int(IniRead($sConfig, "general", "Command", 0))))
	GUICtrlCreateLabel("when", 244, 358, 32, 17)
	Local $hHaltCond = GUICtrlCreateCombo("", 280, 354, 122, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $sCondList = "All Storages Full|Gold Full|Elixir Full|Dark Full|At Certain Time|Bot Running For|Donate Only|Only Stay Online"
	GUICtrlSetData($hHaltCond, $sCondList, ListItem($sCondList, Int(IniRead($sConfig, "general", "Cond", 0))))
	GUICtrlCreateLabel("Hours:", 96, 386, 40, 17)
	Local $hHaltHour = GUICtrlCreateCombo("", 140, 382, 60, 21, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $sHours = "0"
	For $i = 1 To 24
		$sHours &= "|" & $i
	Next
	GUICtrlSetData($hHaltHour, $sHours, String(Int(IniRead($sConfig, "general", "Hour", 0))))
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	GUICtrlCreateLabel("The bot settings apply at the next start of that bot.", 20, 420, 300, 17)
	Local $hSave = GUICtrlCreateButton("Save", 112, 516, 96, 28)
	Local $hCancel = GUICtrlCreateButton("Cancel", 222, 516, 96, 28)
	GUISetState(@SW_SHOW, $hDlg)
	GUISetState(@SW_DISABLE, $g_hGui)

	Local $bSaved = False
	While True
		Local $aMsg = GUIGetMsg(1)
		If $aMsg[1] <> $hDlg Then
			Sleep(10)
			ContinueLoop
		EndIf
		Switch $aMsg[0]
			Case $GUI_EVENT_CLOSE, $hCancel
				ExitLoop
			Case $hEmulator
				GUICtrlSetData($hInstance, GUICtrlRead($hEmulator) = "MEmu" ? "MEmu" : BlueStacksInstances(), GUICtrlRead($hEmulator) = "MEmu" ? "MEmu" : "Pie64")
			Case $hSave
				Local $sName = StringStripWS(GUICtrlRead($hProfile), 3)
				Local $sInstance = StringStripWS(GUICtrlRead($hInstance), 3)
				If $sName = "" Or $sInstance = "" Then
					MsgBox($MB_ICONWARNING, "MultiBot", "The profile and the instance cannot be empty.", 0, $hDlg)
					ContinueLoop
				EndIf
				If StringRegExp($sName, '[\\/:*?"<>|]') Then
					MsgBox($MB_ICONWARNING, "MultiBot", "The profile is a folder name: no \ / : * ? "" < > |", 0, $hDlg)
					ContinueLoop
				EndIf
				If $bNew And IniRead($g_sIni, $sName, "Profile", "") <> "" Then
					MsgBox($MB_ICONWARNING, "MultiBot", "A setup named " & $sName & " exists already.", 0, $hDlg)
					ContinueLoop
				EndIf
				; one instance runs one game, so one bot: two setups on the same instance would fight for its window
				Local $sTaken = SetupOnInstance(GUICtrlRead($hEmulator), $sInstance, $sName)
				If $sTaken <> "" Then
					MsgBox($MB_ICONWARNING, "MultiBot", "The instance " & $sInstance & " is already used by the setup " & $sTaken & "." & @CRLF & _
							"Each village needs its own instance: create one in the BlueStacks Multi-instance Manager and pick it here.", 0, $hDlg)
					ContinueLoop
				EndIf
				$sBits = ""
				For $i = 0 To $g_iParameters - 1
					$sBits &= (GUICtrlRead($ahParam[$i]) = $GUI_CHECKED ? "1" : "0")
				Next
				IniWrite($g_sIni, $sName, "Profile", $sName)
				IniWrite($g_sIni, $sName, "Emulator", GUICtrlRead($hEmulator))
				IniWrite($g_sIni, $sName, "Instance", $sInstance)
				IniWrite($g_sIni, $sName, "Dir", ".")
				IniWrite($g_sIni, $sName, "Parameters", $sBits)

				$sConfig = ProfileConfig($sName)
				DirCreate(@ScriptDir & "\Profiles\" & $sName)
				IniWrite($sConfig, "general", "DisposeWindows", GUICtrlRead($hAlign) = $GUI_CHECKED ? 1 : 0)
				IniWrite($sConfig, "general", "DisposeWindowsPos", ListIndex($sAlignList, GUICtrlRead($hAlignPos)))
				IniWrite($sConfig, "other", "WAOffsetX", StringRegExp(GUICtrlRead($hOffX), "^-?\d+$") ? Int(GUICtrlRead($hOffX)) : "")
				IniWrite($sConfig, "other", "WAOffsetY", StringRegExp(GUICtrlRead($hOffY), "^-?\d+$") ? Int(GUICtrlRead($hOffY)) : "")
				IniWrite($sConfig, "android", "backgroundmode", ListIndex($sBackgroundList, GUICtrlRead($hBackground)))
				IniWrite($sConfig, "android", "close", GUICtrlRead($hCloseAndroid) = $GUI_CHECKED ? 1 : 0)
				IniWrite($sConfig, "android", "adb.dedicated.instance", GUICtrlRead($hDedicatedAdb) = $GUI_CHECKED ? 1 : 0)
				IniWrite($sConfig, "android", "process.affinity.mask", Int(GUICtrlRead($hAffinity)))
				IniWrite($sConfig, "general", "threads", Int(GUICtrlRead($hThreads)))
				IniWrite($sConfig, "general", "BotStop", GUICtrlRead($hHalt) = $GUI_CHECKED ? 1 : 0)
				IniWrite($sConfig, "general", "Command", ListIndex($sCommandList, GUICtrlRead($hHaltCommand)))
				IniWrite($sConfig, "general", "Cond", ListIndex($sCondList, GUICtrlRead($hHaltCond)))
				IniWrite($sConfig, "general", "Hour", Int(GUICtrlRead($hHaltHour)))
				IniWrite($g_sGlobalIni, "general", "globalactivebotsallowed", _Max(1, Int(GUICtrlRead($hActiveBots))))
				IniWrite($g_sGlobalIni, "general", "globalthreads", _Max(0, Int(GUICtrlRead($hGlobalThreads))))
				$bSaved = True
				ExitLoop
		EndSwitch
	WEnd
	GUISetState(@SW_ENABLE, $g_hGui)
	GUIDelete($hDlg)
	WinActivate($g_hGui)
	Return $bSaved
EndFunc   ;==>EditSetup

Func ProfileConfig($sProfile)
	Return @ScriptDir & "\Profiles\" & $sProfile & "\config.ini"
EndFunc   ;==>ProfileConfig

; item n of a "a|b|c" list, and the index of an item
Func ListItem($sList, $iIndex)
	Local $a = StringSplit($sList, "|", $STR_NOCOUNT)
	If $iIndex < 0 Or $iIndex >= UBound($a) Then $iIndex = 0
	Return $a[$iIndex]
EndFunc   ;==>ListItem

Func ListIndex($sList, $sItem)
	Local $a = StringSplit($sList, "|", $STR_NOCOUNT)
	For $i = 0 To UBound($a) - 1
		If $a[$i] = $sItem Then Return $i
	Next
	Return 0
EndFunc   ;==>ListIndex

Func _Max($a, $b)
	Return $a > $b ? $a : $b
EndFunc   ;==>_Max

; --------------------------------------------------------------------------------------------------------------------
; the bots: launch, find their windows, talk to them
; --------------------------------------------------------------------------------------------------------------------
Func StartBot($sProfile)
	If BotWindow($sProfile) <> 0 Then
		TrayTip("MultiBot", "The bot of " & $sProfile & " is already open", 3)
		Return False
	EndIf
	Local $sBot = @ScriptDir & "\" & $g_sBotExe
	If Not FileExists($sBot) Then $sBot = @ScriptDir & "\" & $g_sBotAu3
	If Not FileExists($sBot) Then
		MsgBox($MB_ICONERROR, "MultiBot", $g_sBotExe & " is not next to MultiBot. Put MultiBot in the folder of the bot.", 0, $g_hGui)
		Return False
	EndIf
	ShellExecute($sBot, SetupArguments($sProfile), @ScriptDir)
	SetState($sProfile, "Starting", 0, 0, "")
	Return True
EndFunc   ;==>StartBot

; asks the bot to close itself; waits for it when $bWait. A bot that ignores two requests is ended by force.
Func CloseBot($sProfile, $bWait = False)
	Local $hWnd = BotWindow($sProfile)
	If $hWnd = 0 Then Return True
	Local $iPid = WinGetProcess($hWnd)
	_WinAPI_PostMessage($hWnd, $WM_MYBOTRUN_API, $API_CLOSE, $g_hGui)
	SetState($sProfile, "Closing", $iPid, $hWnd, "")
	If Not $bWait Then Return True
	Local $hTimer = TimerInit()
	While ProcessExists($iPid)
		If TimerDiff($hTimer) > 20000 Then
			; the second request closes at once (BotCloseRequest), the third way is the hard one
			_WinAPI_PostMessage($hWnd, $WM_MYBOTRUN_API, $API_CLOSE, $g_hGui)
			$hTimer = TimerInit()
			While ProcessExists($iPid) And TimerDiff($hTimer) < 10000
				Sleep(200)
			WEnd
			If ProcessExists($iPid) Then ProcessClose($iPid)
			ExitLoop
		EndIf
		Sleep(200)
	WEnd
	Sleep(1000)
	ForgetBot($sProfile)
	Return True
EndFunc   ;==>CloseBot

Func SendBot($sProfile, $iCommand)
	Local $hWnd = BotWindow($sProfile)
	If $hWnd = 0 Then Return False
	_WinAPI_PostMessage($hWnd, $WM_MYBOTRUN_API, $iCommand, $g_hGui)
	Return True
EndFunc   ;==>SendBot

; the bot answers a query or a command with the same message: low word = command + 1, high word = state bits,
; lParam = its window. The window tells which setup it is.
Func OnBotAnswer($hWnd, $iMsg, $wParam, $lParam)
	Local $hBot = HWnd($lParam)
	Local $iBits = BitShift($wParam, 16)
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][2] = $hBot Then
			Local $sState = "Idle"
			If BitAND($iBits, $API_LAUNCHED) = 0 Then
				$sState = "Starting"
			ElseIf BitAND($iBits, $API_PAUSED) Then
				$sState = "Paused"
			ElseIf BitAND($iBits, $API_RUNNING) Then
				$sState = "Running"
			EndIf
			$g_aBots[$i][3] = $sState
			$g_aBots[$i][4] = TimerInit()
			ShowState($g_aBots[$i][0], $sState)
			ExitLoop
		EndIf
	Next
	Return $GUI_RUNDEFMSG
EndFunc   ;==>OnBotAnswer

; every few seconds: which bot windows exist, which setup each belongs to (its command line), and their state
Func PollBots($bForce = False)
	Static $iScan = 0
	$iScan += 1
	If $bForce Or Mod($iScan, 3) = 1 Then ScanBotWindows()
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][2] <> 0 And WinExists($g_aBots[$i][2]) Then
			_WinAPI_PostMessage($g_aBots[$i][2], $WM_MYBOTRUN_API, $API_QUERY, $g_hGui)
			; no answer for a while: the bot is busy starting, or stuck
			If $g_aBots[$i][4] <> 0 And TimerDiff($g_aBots[$i][4]) > 30000 And $g_aBots[$i][3] <> "Starting" Then ShowState($g_aBots[$i][0], "No answer")
		EndIf
	Next
EndFunc   ;==>PollBots

; the bot windows are AutoIt GUIs titled "My Bot ..."; the profile is the first argument of their command line
Func ScanBotWindows()
	Local $aWins = WinList("[CLASS:AutoIt v3 GUI]")
	Local $aSeen[0]
	For $i = 1 To $aWins[0][0]
		If StringLeft($aWins[$i][0], 6) <> "My Bot" Then ContinueLoop
		Local $hWnd = $aWins[$i][1]
		Local $iPid = WinGetProcess($hWnd)
		If $iPid <= 0 Then ContinueLoop
		Local $iKnown = -1
		For $j = 0 To UBound($g_aBots) - 1
			If $g_aBots[$j][1] = $iPid Then
				$iKnown = $j
				ExitLoop
			EndIf
		Next
		If $iKnown = -1 Then
			Local $sCmd = ProcessCommandLine($iPid)
			Local $sProfile = ProfileOfCommandLine($sCmd)
			If $sProfile = "" Then $sProfile = ProfileOfTitle($aWins[$i][0])
			If $sProfile = "" Then ContinueLoop ; a bot not started by a known setup
			If BotWindow($sProfile) <> 0 Then ContinueLoop ; that setup already has its window
			SetState($sProfile, "Open", $iPid, $hWnd, $sCmd)
		Else
			$g_aBots[$iKnown][2] = $hWnd
		EndIf
		ReDim $aSeen[UBound($aSeen) + 1]
		$aSeen[UBound($aSeen) - 1] = $iPid
	Next
	; bots that are gone
	For $i = UBound($g_aBots) - 1 To 0 Step -1
		If $g_aBots[$i][1] = 0 Then
			; launched by us, window not seen yet: keep it a minute, then give up
			If $g_aBots[$i][4] = 0 Then $g_aBots[$i][4] = TimerInit()
			If TimerDiff($g_aBots[$i][4]) > 60000 Then ForgetBot($g_aBots[$i][0])
			ContinueLoop
		EndIf
		If _ArraySearch($aSeen, $g_aBots[$i][1]) = -1 And Not ProcessExists($g_aBots[$i][1]) Then ForgetBot($g_aBots[$i][0])
	Next
EndFunc   ;==>ScanBotWindows

; which setup a command line belongs to: its first argument is the profile, quoted when it has spaces
Func ProfileOfCommandLine($sCmd)
	Local $aTokens = StringRegExp($sCmd, '"[^"]*"|\S+', $STR_REGEXPARRAYGLOBALMATCH)
	If Not IsArray($aTokens) Then Return ""
	Local $aSetups = Setups()
	; skip the executable, and the script when the bot runs from the source with AutoIt3.exe
	For $i = 1 To UBound($aTokens) - 1
		Local $sToken = $aTokens[$i]
		If StringLeft($sToken, 1) = '"' Then $sToken = StringMid($sToken, 2, StringLen($sToken) - 2)
		If StringRight($sToken, 4) = ".au3" Or StringRight($sToken, 4) = ".exe" Then ContinueLoop
		For $j = 0 To UBound($aSetups) - 1
			If $sToken = $aSetups[$j] Then Return $aSetups[$j]
		Next
		Return "" ; the first real argument is not one of ours
	Next
	Return ""
EndFunc   ;==>ProfileOfCommandLine

; when the command line cannot be read (a bot started by hand from another level): the title ends with the
; instance, "My Bot v10.9.9 (Pie64)", and a setup has one instance of its own
Func ProfileOfTitle($sTitle)
	Local $aInst = StringRegExp($sTitle, "\(([^()]+)\)\s*$", $STR_REGEXPARRAYMATCH)
	If Not IsArray($aInst) Then Return ""
	Local $aSetups = Setups()
	For $i = 0 To UBound($aSetups) - 1
		If SetupInstance($aSetups[$i]) = $aInst[0] Then Return $aSetups[$i]
	Next
	Return ""
EndFunc   ;==>ProfileOfTitle

Func ProcessCommandLine($iPid)
	Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
	If Not IsObj($oWMI) Then Return ""
	Local $oList = $oWMI.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId = " & $iPid)
	For $oProc In $oList
		Return String($oProc.CommandLine)
	Next
	Return ""
EndFunc   ;==>ProcessCommandLine

Func BotWindow($sProfile)
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][0] = $sProfile And $g_aBots[$i][2] <> 0 And WinExists($g_aBots[$i][2]) Then Return $g_aBots[$i][2]
	Next
	Return 0
EndFunc   ;==>BotWindow

Func BotState($sProfile)
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][0] = $sProfile Then Return $g_aBots[$i][3]
	Next
	Return "Off"
EndFunc   ;==>BotState

Func SetState($sProfile, $sState, $iPid, $hWnd, $sCmd)
	Local $iRow = -1
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][0] = $sProfile Then
			$iRow = $i
			ExitLoop
		EndIf
	Next
	If $iRow = -1 Then
		$iRow = UBound($g_aBots)
		ReDim $g_aBots[$iRow + 1][6]
		$g_aBots[$iRow][0] = $sProfile
	EndIf
	$g_aBots[$iRow][1] = $iPid
	$g_aBots[$iRow][2] = $hWnd
	$g_aBots[$iRow][3] = $sState
	$g_aBots[$iRow][4] = ($hWnd <> 0 ? TimerInit() : 0)
	$g_aBots[$iRow][5] = $sCmd
	ShowState($sProfile, $sState)
EndFunc   ;==>SetState

Func ForgetBot($sProfile)
	For $i = 0 To UBound($g_aBots) - 1
		If $g_aBots[$i][0] = $sProfile Then
			_ArrayDelete($g_aBots, $i)
			ExitLoop
		EndIf
	Next
	ShowState($sProfile, "Off")
EndFunc   ;==>ForgetBot

Func ShowState($sProfile, $sState)
	For $i = 0 To _GUICtrlListView_GetItemCount($g_hList) - 1
		If _GUICtrlListView_GetItemText($g_hList, $i, $eColProfile) = $sProfile Then
			If _GUICtrlListView_GetItemText($g_hList, $i, $eColState) <> $sState Then _GUICtrlListView_SetItemText($g_hList, $i, $sState, $eColState)
			ExitLoop
		EndIf
	Next
EndFunc   ;==>ShowState

; --------------------------------------------------------------------------------------------------------------------
; the emulator instances
; --------------------------------------------------------------------------------------------------------------------
Func BlueStacksPath()
	Local $asKeys[2] = ["HKLM64\SOFTWARE\BlueStacks_nxt", "HKLM\SOFTWARE\BlueStacks_nxt"]
	For $sKey In $asKeys
		Local $sPath = RegRead($sKey, "InstallDir")
		If $sPath <> "" And FileExists($sPath & "\HD-Player.exe") Then Return StringRegExpReplace($sPath, "\\$", "")
	Next
	If FileExists("C:\Program Files\BlueStacks_nxt\HD-Player.exe") Then Return "C:\Program Files\BlueStacks_nxt"
	Return ""
EndFunc   ;==>BlueStacksPath

; the instances of the Multi-instance Manager, from bluestacks.conf (bst.instance.<name>.display_name = "...")
Func BlueStacksInstances()
	Local $sConf = ""
	Local $asKeys[2] = ["HKLM64\SOFTWARE\BlueStacks_nxt", "HKLM\SOFTWARE\BlueStacks_nxt"]
	For $sKey In $asKeys
		Local $sData = RegRead($sKey, "UserDefinedDir")
		If $sData <> "" And FileExists($sData & "\bluestacks.conf") Then
			$sConf = $sData & "\bluestacks.conf"
			ExitLoop
		EndIf
	Next
	If $sConf = "" And FileExists(@AppDataCommonDir & "\BlueStacks_nxt\bluestacks.conf") Then $sConf = @AppDataCommonDir & "\BlueStacks_nxt\bluestacks.conf"
	If $sConf = "" Then Return "Pie64"
	Local $aNames = StringRegExp(FileRead($sConf), '(?m)^bst\.instance\.([A-Za-z0-9_]+)\.display_name=', $STR_REGEXPARRAYGLOBALMATCH)
	If Not IsArray($aNames) Then Return "Pie64"
	Local $sList = ""
	For $i = 0 To UBound($aNames) - 1
		$sList &= ($sList <> "" ? "|" : "") & $aNames[$i]
	Next
	Return $sList
EndFunc   ;==>BlueStacksInstances

Func MEmuPath()
	Local $sPath = EnvGet("MEmu_Path")
	If $sPath <> "" And FileExists($sPath & "\MEmu.exe") Then Return $sPath
	If FileExists("C:\Program Files\Microvirt\MEmu\MEmu.exe") Then Return "C:\Program Files\Microvirt\MEmu"
	If FileExists("C:\Program Files (x86)\Microvirt\MEmu\MEmu.exe") Then Return "C:\Program Files (x86)\Microvirt\MEmu"
	Return ""
EndFunc   ;==>MEmuPath

Func StartInstance($sProfile)
	Local $sInstance = SetupInstance($sProfile)
	Switch SetupEmulator($sProfile)
		Case "MEmu"
			Local $sMEmu = MEmuPath()
			If $sMEmu = "" Then Return MsgBox($MB_ICONERROR, "MultiBot", "MEmu was not found", 0, $g_hGui)
			ShellExecute($sMEmu & "\MEmu.exe", $sInstance)
		Case Else
			Local $sBS = BlueStacksPath()
			If $sBS = "" Then Return MsgBox($MB_ICONERROR, "MultiBot", "BlueStacks 5 was not found", 0, $g_hGui)
			ShellExecute($sBS & "\HD-Player.exe", "--instance " & $sInstance)
	EndSwitch
EndFunc   ;==>StartInstance

; ends the emulator process of that instance only (HD-Player.exe --instance <name>)
Func StopInstance($sProfile)
	Local $sInstance = SetupInstance($sProfile)
	Local $sExe = (SetupEmulator($sProfile) = "MEmu") ? "MEmu.exe" : "HD-Player.exe"
	Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
	If Not IsObj($oWMI) Then Return
	Local $oList = $oWMI.ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = '" & $sExe & "'")
	For $oProc In $oList
		Local $sCmd = String($oProc.CommandLine)
		Local $aTokens = StringRegExp($sCmd, '"[^"]*"|\S+', $STR_REGEXPARRAYGLOBALMATCH)
		If Not IsArray($aTokens) Then ContinueLoop
		For $i = 1 To UBound($aTokens) - 1
			Local $sToken = StringReplace($aTokens[$i], '"', "")
			If $sToken = $sInstance And ($sExe = "MEmu.exe" Or StringReplace($aTokens[$i - 1], '"', "") = "--instance") Then
				$oProc.Terminate()
				ExitLoop 2
			EndIf
		Next
	Next
EndFunc   ;==>StopInstance

Func AdbReset()
	RunWait(@ComSpec & " /c taskkill /F /IM adb.exe >nul 2>&1", @ScriptDir, @SW_HIDE)
	RunWait(@ComSpec & " /c taskkill /F /IM HD-Adb.exe >nul 2>&1", @ScriptDir, @SW_HIDE)
	TrayTip("MultiBot", "ADB reset done: the bots reconnect by themselves", 3)
EndFunc   ;==>AdbReset

; --------------------------------------------------------------------------------------------------------------------
; shortcuts
; --------------------------------------------------------------------------------------------------------------------
Func StartupLink($sProfile)
	Return @StartupDir & "\MyBot - " & $sProfile & ".lnk"
EndFunc   ;==>StartupLink

Func MakeShortcut($sProfile, $sLink)
	Local $sBot = @ScriptDir & "\" & $g_sBotExe
	If Not FileExists($sBot) Then $sBot = @ScriptDir & "\" & $g_sBotAu3
	FileCreateShortcut($sBot, $sLink, @ScriptDir, SetupArguments($sProfile), "MyBot - " & $sProfile, @ScriptDir & "\Images\MyBot.ico")
EndFunc   ;==>MakeShortcut
