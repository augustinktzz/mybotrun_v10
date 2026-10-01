; #FUNCTION# ====================================================================================================================
; Name ..........: AndroidGeneric
; Description ...: Android emulator distributor for any Android already reachable over ADB.
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........:
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;
;                  Unlike BlueStacks5/MEmu/Nox, the "Generic" emulator is not installed, launched,
;                  configured or owned by the bot, and it has no Windows window:
;                    - an Android Studio AVD or Waydroid on Linux, with the bot under Wine
;                    - a physical device or any other emulator already listening on ADB
;                  Everything therefore goes through ADB, which the bot already supports:
;                    - capture   : ADB screencap ("background mode 2"), feature bit 2
;                    - input     : ADB click / minitouch, feature bits 4+8+32
;                    - liveness  : the headless path in WinGetAndroidHandle(), where
;                                  $g_hAndroidWindow holds a PID instead of a window handle
;                  The one thing ADB alone cannot provide is the host<->Android shared folder the
;                  screencap relies on, so InitGeneric() sets $g_bAndroidAdbNoSharedFolder and the
;                  few places that need the file on the other side use "adb pull"/"adb push". No
;                  other emulator sets that flag, so no Windows code path changes.
;
;                  The bot never starts or stops this Android: start it yourself, then start the bot.
; Related .......: Android.au3, $g_avAndroidAppConfig in MBR Global Variables.au3
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once

; Path to the ADB executable used for a Generic device: the one shipped with the bot, so its
; version is known and it is the same binary on Windows and under Wine.
Func GetGenericAdbPath()
	Local $sAdbPath = $g_sLibPath & "\adb\adb.exe"
	If FileExists($sAdbPath) Then Return $sAdbPath
	Return ""
EndFunc   ;==>GetGenericAdbPath

; Folder holding the ADB executable. Used like GetMEmuPath()/GetNoxPath() to answer "is it installed".
Func GetGenericPath()
	Local $sAdbPath = GetGenericAdbPath()
	If $sAdbPath = "" Then Return ""
	Return StringLeft($sAdbPath, StringInStr($sAdbPath, "\", 0, -1))
EndFunc   ;==>GetGenericPath

; The bot never launches this Android, so there is no command line to match or reproduce.
Func GetGenericProgramParameter($bAlternative = False)
	If $bAlternative Then Return ""
	Return ""
EndFunc   ;==>GetGenericProgramParameter

; Called by WinGetAndroidHandle() to decide whether a process it found is "our" Android. The
; process we report is the ADB server, and any ADB server serves this device, so accept it.
Func IsGenericCommandLine($CommandLine)
	Return True
EndFunc   ;==>IsGenericCommandLine

; No DirectX window exists, so only ADB screencap can work.
Func GetGenericBackgroundMode()
	Return $g_iAndroidBackgroundModeOpenGL
EndFunc   ;==>GetGenericBackgroundMode

; There is no backend service the bot may kill: the Android is owned by the user.
Func GetGenericSvcPid()
	Return 0
EndFunc   ;==>GetGenericSvcPid

; The ADB device this Generic Android is reached at. $g_sAndroidAdbGenericDevice overrides the
; default from $g_avAndroidAppConfig, so a different port or an AVD name can be used.
Func GetGenericAdbDevice()
	If $g_sAndroidAdbGenericDevice <> "" Then Return $g_sAndroidAdbGenericDevice
	If $g_sAndroidAdbDevice <> "" Then Return $g_sAndroidAdbDevice
	Return $g_avAndroidAppConfig[$g_iAndroidConfig][10]
EndFunc   ;==>GetGenericAdbDevice

; Returns the serials "adb devices" currently reports in state "device", as an array. Serials in
; any other state ("offline", "unauthorized", "no permissions", ...) are not usable and are left out.
Func GenericAdbReadyDevices($sAdbPath)
	Local $process_killed
	Local $aReady[0]
	Local $sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "devices", $process_killed, 10000, False, True)
	Local $aLines = StringSplit(StringStripCR($sOutput), @LF, $STR_NOCOUNT)
	Local $i
	For $i = 0 To UBound($aLines) - 1
		Local $sLine = StringStripWS($aLines[$i], 3)
		; "<serial>\t<state>"; the header line has no tab and no state, so it drops out here.
		Local $iTab = StringInStr($sLine, @TAB)
		If $iTab < 2 Then ContinueLoop
		If StringStripWS(StringMid($sLine, $iTab + 1), 3) <> "device" Then ContinueLoop
		ReDim $aReady[UBound($aReady) + 1]
		$aReady[UBound($aReady) - 1] = StringStripWS(StringLeft($sLine, $iTab - 1), 3)
	Next
	Return $aReady
EndFunc   ;==>GenericAdbReadyDevices

; True when an Android is reachable over ADB, and sets $g_sAndroidAdbGenericDevice to the serial
; that answered. This is the whole liveness test for a Generic Android.
;
; The configured serial wins. If it is not there but exactly one other device is, that one is
; adopted: an Android Studio AVD shows up as "emulator-5554" rather than the "127.0.0.1:5555"
; default, and a phone shows up under its own serial, so requiring the user to configure it first
; would make the common case fail for no reason. With several devices attached the choice is
; ambiguous, so nothing is adopted and the user is told to name one.
Func GenericAdbDeviceReady($bConnectFirst = True, $bSetLog = False)
	Local $process_killed, $i
	Local $sAdbPath = GetGenericAdbPath()
	If $sAdbPath = "" Then Return False
	Local $sDevice = GetGenericAdbDevice()

	; A host:port device has to be connected to before it is listed; an "emulator-NNNN" or a
	; physical serial is discovered by the ADB server on its own.
	If $bConnectFirst And StringInStr($sDevice, ":") > 0 Then
		LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "connect " & $sDevice, $process_killed, 10000, False, True)
	EndIf

	Local $aReady = GenericAdbReadyDevices($sAdbPath)
	For $i = 0 To UBound($aReady) - 1
		If $aReady[$i] = $sDevice Then Return True
	Next

	; Nothing attached yet: on Linux, Waydroid is a known place to look. It listens for ADB on its
	; container's address, which is not 127.0.0.1 and is never connected to by itself.
	If UBound($aReady) = 0 And $bConnectFirst Then
		Local $sWaydroid = GenericWaydroidAdbDevice()
		If $sWaydroid <> "" Then
			SetDebugLog($g_sAndroidEmulator & " trying Waydroid at " & $sWaydroid)
			LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "connect " & $sWaydroid, $process_killed, 10000, False, True)
			$aReady = GenericAdbReadyDevices($sAdbPath)
		EndIf
	EndIf

	If UBound($aReady) = 1 Then
		$g_sAndroidAdbGenericDevice = $aReady[0]
		SetDebugLog($g_sAndroidEmulator & " using the only attached ADB device: " & $aReady[0])
		Return True
	EndIf

	If UBound($aReady) > 1 Then
		If $bSetLog Then
			SetLog($g_sAndroidEmulator & ": " & UBound($aReady) & " ADB devices attached, none of them " & $sDevice, $COLOR_ERROR)
			SetLog("Set $g_sAndroidAdbGenericDevice to the one to use, e.g. " & $aReady[0], $COLOR_INFO)
		EndIf
		Return False
	EndIf

	If $bSetLog Then
		SetLog("ADB device " & $sDevice & " is not available", $COLOR_ERROR)
		SetLog("Start your Android first, then check: adb devices", $COLOR_INFO)
	Else
		SetDebugLog("ADB device " & $sDevice & " is not available")
	EndIf
	Return False
EndFunc   ;==>GenericAdbDeviceReady

; Waydroid's ADB address on this Linux host, or "" (always "" on Windows). Waydroid's own DHCP server
; gives its container an address it records in a lease file anyone may read; Wine shows the Linux
; root as drive Z:. Reading it there follows the address if Waydroid ever hands out another one.
Func GenericWaydroidAdbDevice()
	If Not IsRunningUnderWine() Then Return ""
	Local $sLeases = FileRead("Z:\var\lib\misc\dnsmasq.waydroid0.leases")
	If @error Or $sLeases = "" Then Return ""
	; one lease per line: <expiry> <mac> <ip> <hostname> <client id>; the most recent comes last
	Local $aIp = StringRegExp($sLeases, "(?im)^\d+\s+\S+\s+(\d+\.\d+\.\d+\.\d+)\s+waydroid", $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then Return ""
	Return $aIp[UBound($aIp) - 1] & ":5555"
EndFunc   ;==>GenericWaydroidAdbDevice

; Reports the running Android as [PID, instance]. The PID is the ADB server's: for a Generic
; Android that process is what the bot can observe and restart, and the device being listed is
; what tells us Android is really there. Returns [0, ""] when the device is not reachable, so
; the bot's existing "Android is gone" recovery applies unchanged.
Func GetGenericRunningInstance($bStrictCheck = True)
	Local $a[2] = [0, ""]
	If Not GenericAdbDeviceReady(True, False) Then Return $a

	Local $sAdbPath = GetGenericAdbPath()
	Local $aPids = ProcessesExist($sAdbPath, "", 1)
	If UBound($aPids) > 0 Then
		$a[0] = $aPids[0]
	Else
		; Device answered, so an ADB server exists but not as a process we can see (a daemon
		; started outside this session, which is normal under Wine). Report the bot itself so
		; the liveness check stays true while the device answers.
		$a[0] = @AutoItPID
	EndIf
	$a[1] = $g_avAndroidAppConfig[$g_iAndroidConfig][1]
	Return $a
EndFunc   ;==>GetGenericRunningInstance

; Sets up every global for a Generic Android. Returns False when no ADB device is reachable,
; which is also what makes DetectInstalledAndroid() skip "Generic" on a normal Windows machine.
Func InitGeneric($bCheckOnly = False)
	Local $sAdbPath = GetGenericAdbPath()
	If $sAdbPath = "" Then
		If Not $bCheckOnly Then
			SetLog("Cannot find ADB for " & $g_sAndroidEmulator & ":", $COLOR_ERROR)
			SetLog($g_sLibPath & "\adb\adb.exe", $COLOR_ERROR)
			SetError(1, @extended, False)
		EndIf
		Return False
	EndIf

	; "Installed" for a Generic Android means "a device is answering right now".
	If Not GenericAdbDeviceReady(True, Not $bCheckOnly) Then
		If Not $bCheckOnly Then SetError(1, @extended, False)
		Return False
	EndIf

	If $bCheckOnly Then Return True

	InitAndroidConfig(True) ; Restore default config

	Local $process_killed, $sOutput

	$g_sAndroidAdbPath = $sAdbPath
	$g_sAndroidPath = GetGenericPath()
	; The bot has no emulator executable to launch here. It points at ADB so that the process
	; lookups in WinGetAndroidHandle() resolve, and so FileExists() checks pass.
	$g_sAndroidProgramPath = $sAdbPath
	$g_sAndroidAdbDevice = GetGenericAdbDevice()
	$__VBoxManage_Path = "" ; no VirtualBox involved

	; This Android has no window: force the headless/ADB-only path.
	$g_bAndroidBackgroundLaunch = True
	$g_bAndroidAdbScreencap = True
	$g_bAndroidAdbClick = True
	$g_iAndroidBackgroundModeDefault = $g_iAndroidBackgroundModeOpenGL

	; Host and Android do not share a filesystem: move files with adb pull/push instead.
	$g_bAndroidAdbNoSharedFolder = True
	$g_bAndroidAdbGenericTouchDexPushed = False ; pushed on first use, see GenericPinchZoomOut()

	; Android version, for the log and for $g_iAndroidVersionAPI based decisions.
	$sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell getprop ro.build.version.release", $process_killed, 10000, False, True)
	$g_sAndroidVersion = StringStripWS($sOutput, 3)
	If $g_sAndroidVersion = "" Then $g_sAndroidVersion = "unknown"

	$sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell getprop ro.build.version.sdk", $process_killed, 10000, False, True)
	Local $iApi = Int(StringStripWS($sOutput, 3))
	If $iApi > 0 Then $g_iAndroidVersionAPI = $iApi

	; Root lets minitouch write to the touch device directly. Ask for it when we don't already have it: a
	; userdebug Android Studio image grants it; Waydroid and production builds refuse it. Without root,
	; clicks still work through Android's "input" command (GenericDetectTouchDevice decides).
	; Waydroid never grants it, and asking makes its adbd restart: the device then reads "unauthorized" for a
	; moment and the bot's next commands fail. Don't ask there.
	$sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell getprop ro.product.device", $process_killed, 10000, False, True)
	Local $bWaydroid = StringInStr($sOutput, "waydroid") > 0
	$sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell id -u", $process_killed, 10000, False, True)
	If StringStripWS($sOutput, 3) <> "0" And $bWaydroid Then
		SetDebugLog($g_sAndroidEmulator & " ADB shell is not root, Waydroid does not grant it")
	ElseIf StringStripWS($sOutput, 3) <> "0" Then
		SetDebugLog($g_sAndroidEmulator & " ADB shell is not root, requesting root")
		Local $sRoot = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " root", $process_killed, 20000, False, True)
		SetDebugLog($g_sAndroidEmulator & " adb root: " & StringStripWS($sRoot, 3))
		; adbd restarts only when root was granted ("restarting adbd as root"): only then wait for it.
		; A plain Sleep: _Sleep() reports "stop" whenever the bot is not running, as during start-up.
		If StringInStr($sRoot, "restarting") Then
			Sleep(3000)
			LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " wait-for-device", $process_killed, 30000, False, True)
			$sOutput = LaunchConsole($sAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell id -u", $process_killed, 10000, False, True)
		EndIf
	EndIf
	If StringStripWS($sOutput, 3) = "0" Then
		$g_sAndroidShellPrompt = '# '
		SetDebugLog($g_sAndroidEmulator & " ADB shell is root")
	Else
		$g_sAndroidShellPrompt = '$ '
		SetDebugLog($g_sAndroidEmulator & " ADB shell is not root")
	EndIf

	; Which /dev/input/eventN to send touches to, and the range its coordinates use.
	GenericDetectTouchDevice()

	; Stand-in for the shared folder, see ConfigureSharedFolderGeneric().
	$g_sAndroidPicturesPath = $g_sAndroidAdbGenericTmpPath
	$g_sAndroidSharedFolderName = ""
	ConfigureSharedFolder(0)

	SetLog($g_sAndroidEmulator & " ADB device " & $g_sAndroidAdbDevice & ", Android " & $g_sAndroidVersion & " (API " & $g_iAndroidVersionAPI & ")", $COLOR_SUCCESS)

	Return SetError(0, 0, True)
EndFunc   ;==>InitGeneric

; Host side is a folder in the bot's profile; Android side is a scratch folder under
; /data/local/tmp. They are not the same folder - $g_bAndroidAdbNoSharedFolder makes the callers
; bridge them with adb pull/push.
;   $iMode 0 = configure, 1 = verify (True means something had to be fixed), 2 = create
Func ConfigureSharedFolderGeneric($iMode = 0, $bSetLog = Default)
	If $bSetLog = Default Then $bSetLog = True
	Local $bResult = False
	Local $process_killed

	If $g_sAndroidPicturesHostPath = "" Then $g_sAndroidPicturesHostPath = $g_sProfileTempPath
	Local $sHostPath = $g_sAndroidPicturesHostPath & $g_sAndroidPicturesHostFolder
	Local $sAndroidPath = $g_sAndroidPicturesPath & StringReplace($g_sAndroidPicturesHostFolder, "\", "/")

	Switch $iMode
		Case 0, 2
			If FileExists($sHostPath) = 0 Then
				If DirCreate($sHostPath) = 1 Then
					SetGuiLog("Capture folder created: " & $sHostPath, $COLOR_SUCCESS, $bSetLog)
					$bResult = True
				Else
					SetGuiLog("Cannot create capture folder: " & $sHostPath, $COLOR_ERROR, $bSetLog)
					$g_bAndroidSharedFolderAvailable = False
					$g_bAndroidAdbScreencap = False
					Return False
				EndIf
			EndIf
			LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell mkdir -p """ & $sAndroidPath & """", $process_killed, 10000, False, True)
			$g_bAndroidSharedFolderAvailable = True
			If $iMode = 0 Then Return True
			Return $bResult
		Case 1
			If FileExists($sHostPath) = 0 Then
				If DirCreate($sHostPath) = 1 Then
					SetGuiLog("Capture folder created: " & $sHostPath, $COLOR_SUCCESS, $bSetLog)
				Else
					SetGuiLog("Cannot create capture folder: " & $sHostPath, $COLOR_ERROR, $bSetLog)
				EndIf
				$bResult = True
			EndIf
			Return $bResult
	EndSwitch

	Return $bResult
EndFunc   ;==>ConfigureSharedFolderGeneric

; The bot does not launch this Android; it waits for the device the user started.
Func OpenGeneric($bRestart = False)
	Local $hTimer = __TimerInit()

	SetLog("Using " & $g_sAndroidEmulator & " Android on ADB device " & GetGenericAdbDevice(), $COLOR_SUCCESS)

	If Not GenericAdbDeviceReady(True, True) Then
		SetLog($g_sAndroidEmulator & " Android is not running, the bot does not start it", $COLOR_ERROR)
		SetError(1, 1, -1)
		Return False
	EndIf

	; Ensure ADB is connected the way the rest of the bot expects.
	ConnectAndroidAdb(False, False, 60 * 1000)
	If Not $g_bRunState Then Return False

	If WaitForAndroidBootCompleted($g_iAndroidLaunchWaitSec - __TimerDiff($hTimer) / 1000, $hTimer) Then Return False
	If Not $g_bRunState Then Return False

	SetLog($g_sAndroidEmulator & " ready, took " & Round(__TimerDiff($hTimer) / 1000, 2) & " seconds.", $COLOR_SUCCESS)
	Return True
EndFunc   ;==>OpenGeneric

; The Android belongs to the user, so it is never closed. Returning True keeps the callers
; (recovery, reboot, profile switch) on their normal path.
Func CloseGeneric()
	SetDebugLog($g_sAndroidEmulator & " is externally managed, not closing Android")
	AndroidAdbTerminateShellInstance()
	Return True
EndFunc   ;==>CloseGeneric

; Nothing to close: there is no unsupported launch variant of a plain ADB device.
Func CloseUnsupportedGeneric()
	Return False
EndFunc   ;==>CloseUnsupportedGeneric

; Resolution and density are set over ADB. "wm size"/"wm density" is the one emulator-independent
; way to do this, and it is what makes an AVD or Waydroid match the screen the bot expects.
Func SetScreenGeneric()
	If Not InitAndroid() Then Return False

	Local $process_killed
	SetLog("Setting " & $g_sAndroidEmulator & " screen to " & $g_iAndroidClientWidth & "x" & $g_iAndroidClientHeight & " at 160 dpi", $COLOR_ACTION)
	LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell wm size " & $g_iAndroidClientWidth & "x" & $g_iAndroidClientHeight, $process_killed)
	LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell wm density 160", $process_killed)

	ConfigureSharedFolder(2, True)
	Return True
EndFunc   ;==>SetScreenGeneric

; Verifies the device really reports the resolution and density the bot's coordinates assume.
Func CheckScreenGeneric($bSetLog = True)
	If Not InitAndroid() Then Return False

	Local $process_killed, $sOutput, $iErrCnt = 0, $aRegExResult

	; "wm size" prints "Physical size: WxH" and, when overridden, "Override size: WxH".
	$sOutput = LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell wm size", $process_killed, 10000, False, True)
	Local $iWidth = 0, $iHeight = 0
	$aRegExResult = StringRegExp($sOutput, "Override size:\s*(\d+)x(\d+)", $STR_REGEXPARRAYMATCH)
	If @error Then $aRegExResult = StringRegExp($sOutput, "Physical size:\s*(\d+)x(\d+)", $STR_REGEXPARRAYMATCH)
	If Not @error Then
		$iWidth = Int($aRegExResult[0])
		$iHeight = Int($aRegExResult[1])
	EndIf

	If $iWidth <> $g_iAndroidClientWidth Or $iHeight <> $g_iAndroidClientHeight Then
		SetGuiLog("MyBot doesn't work with " & $g_sAndroidEmulator & " screen configuration!", $COLOR_ERROR, $bSetLog)
		SetGuiLog("Screen is " & $iWidth & "x" & $iHeight & " and will be changed to " & $g_iAndroidClientWidth & "x" & $g_iAndroidClientHeight, $COLOR_ERROR, $bSetLog)
		$iErrCnt += 1
	EndIf

	; "wm density" prints "Physical density: N" and, when overridden, "Override density: N".
	$sOutput = LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell wm density", $process_killed, 10000, False, True)
	Local $iDensity = 0
	$aRegExResult = StringRegExp($sOutput, "Override density:\s*(\d+)", $STR_REGEXPARRAYMATCH)
	If @error Then $aRegExResult = StringRegExp($sOutput, "Physical density:\s*(\d+)", $STR_REGEXPARRAYMATCH)
	If Not @error Then $iDensity = Int($aRegExResult[0])

	If $iDensity <> 160 Then
		SetGuiLog("Density is " & $iDensity & " and will be changed to 160", $COLOR_ERROR, $bSetLog)
		$iErrCnt += 1
	EndIf

	If ConfigureSharedFolder(1, $bSetLog) Then $iErrCnt += 1

	If $iErrCnt > 0 Then Return False
	Return True
EndFunc   ;==>CheckScreenGeneric

; No emulator to restart: apply the screen settings over ADB and carry on.
Func RebootGenericSetScreen()
	SetScreenGeneric()
	Return True
EndFunc   ;==>RebootGenericSetScreen

; Zoom out cannot use keystrokes without a window, so use the in-game/ADB method only.
Func ZoomOutGeneric()
	Return AndroidOnlyZoomOut()
EndFunc   ;==>ZoomOutGeneric

; ------------------------------------------------------------------------------------------------
; No-window stubs. Each of these is reached through Execute() from Android.au3; implementing them
; keeps the "not implemented" @error path out of the logs and states the intent explicitly.
; ------------------------------------------------------------------------------------------------

Func UpdateGenericWindowState()
	Return False ; no window, nothing ever changes
EndFunc   ;==>UpdateGenericWindowState

Func RedrawGenericWindow()
	Return False ; no window to redraw
EndFunc   ;==>RedrawGenericWindow

Func HideGenericWindow($bHide = True, $hHWndAfter = Default)
	Return False ; no window to hide, the Android is not ours
EndFunc   ;==>HideGenericWindow

Func EmbedGeneric($bEmbed = Default, $hHWndAfter = Default)
	Return False ; docking needs a Windows window, embed mode is -1 for Generic
EndFunc   ;==>EmbedGeneric

; Maps a pixel coordinate into the touch device's own ABS range, exactly as
; BlueStacks5AdjustClickCoordinates() does for its virtual touch device. An Android Studio AVD
; reports max 32767 on both axes for an 860x732 screen, so a click sent in pixels would land at
; about 1/38 of the intended distance from the left edge. The two axes are scaled separately
; because the screen is not square. A device that reports pixel maxima scales by 1, so this
; becomes a no-op there; maxima of 0 (not detected) also leave the coordinates untouched.
Func GenericAdjustClickCoordinates(ByRef $x, ByRef $y)
	If $g_iAndroidAdbGenericTouchMaxX > 0 And $g_iAndroidClientWidth > 0 Then $x = Round($g_iAndroidAdbGenericTouchMaxX / $g_iAndroidClientWidth * $x)
	If $g_iAndroidAdbGenericTouchMaxY > 0 And $g_iAndroidClientHeight > 0 Then $y = Round($g_iAndroidAdbGenericTouchMaxY / $g_iAndroidClientHeight * $y)
EndFunc   ;==>GenericAdjustClickCoordinates

; Finds the touch device to send events to, and its coordinate range, from "getevent -p".
;
; The bot's own detection in _AndroidAdbLaunchShellInstance() matches a device by name and then
; falls back to one whose ABS_MT_POSITION_X/Y maxima equal the expected screen size. Neither works
; on an AVD: it exposes eleven identically named virtio_input_multi_touch_N devices (one per
; possible display), all reporting max 32767 rather than the pixel size. So resolve it here and
; set $g_sAndroidMouseDevice to a concrete path - that also makes the bot skip its own detection,
; which only runs while $g_sAndroidMouseDevice still equals the value from $g_avAndroidAppConfig.
;
; The lowest-numbered matching device is taken: the AVD numbers them by display, so _1 is the
; primary display's touchscreen.
Func GenericDetectTouchDevice()
	Local $process_killed
	Local $sOutput = LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " shell getevent -p", $process_killed, 20000, False, True)

	; Per device: its event path, its name, then the ABS_MT_POSITION_X (0035) and Y (0036) maxima,
	; without ever running past the start of the next device block.
	Local $aMatches = StringRegExp($sOutput, _
			"/dev/input/event(\d+)\s*\n\s*name:\s*""([^""]*)""(?:(?!/dev/input/event)[\s\S])*?0035\s*:[^\n]*max (\d+)(?:(?!/dev/input/event)[\s\S])*?0036\s*:[^\n]*max (\d+)", _
			$STR_REGEXPARRAYGLOBALMATCH)
	; No touch device the shell can read: Waydroid has only its own wl_*_events, refused to the shell user
	If @error Then Return GenericUseInputCommand()

	Local $i, $iBestNum = -1, $sBestName = "", $iBestMaxX = 0, $iBestMaxY = 0
	; $STR_REGEXPARRAYGLOBALMATCH flattens every match's groups, 4 per device here.
	For $i = 0 To UBound($aMatches) - 4 Step 4
		Local $iNum = Int($aMatches[$i])
		If $iBestNum = -1 Or $iNum < $iBestNum Then
			$iBestNum = $iNum
			$sBestName = $aMatches[$i + 1]
			$iBestMaxX = Int($aMatches[$i + 2])
			$iBestMaxY = Int($aMatches[$i + 3])
		EndIf
	Next
	If $iBestNum = -1 Then Return GenericUseInputCommand()

	$g_bAndroidAdbGenericInputTap = False
	$g_sAndroidMouseDevice = "/dev/input/event" & $iBestNum
	$g_iAndroidAdbGenericTouchMaxX = $iBestMaxX
	$g_iAndroidAdbGenericTouchMaxY = $iBestMaxY

	SetLog($g_sAndroidEmulator & " touch device " & $g_sAndroidMouseDevice & " (" & $sBestName & "), range " & $iBestMaxX & "x" & $iBestMaxY, $COLOR_SUCCESS)
	If $iBestMaxX <> $g_iAndroidClientWidth Or $iBestMaxY <> $g_iAndroidClientHeight Then
		SetDebugLog("Click coordinates scaled by " & Round($iBestMaxX / $g_iAndroidClientWidth, 4) & " / " & Round($iBestMaxY / $g_iAndroidClientHeight, 4))
	EndIf
	Return True
EndFunc   ;==>GenericDetectTouchDevice

; Without a touch device the shell can write to, minitouch cannot work. Android's own "input" command
; can: on Android 10+ it is a thin wrapper over the native "cmd input" service, about 20 ms per tap.
Func GenericUseInputCommand()
	$g_bAndroidAdbGenericInputTap = True
	$g_sAndroidMouseDevice = "" ; skips the bot's own touch-device detection in _AndroidAdbLaunchShellInstance()
	$g_iAndroidAdbMinitouchMode = 2 ; neither 0 (socket) nor 1 (stdin): minitouch is not started at all
	$g_iAndroidAdbGenericTouchMaxX = 0 ; "input" works in screen pixels: no coordinate scaling
	$g_iAndroidAdbGenericTouchMaxY = 0
	SetLog($g_sAndroidEmulator & ": no touch device the ADB shell can use, clicks go through Android's input command", $COLOR_INFO)
	Return True
EndFunc   ;==>GenericUseInputCommand

; Clicks through Android's "input" command (see GenericUseInputCommand). Same contract as
; AndroidMinitouchClick(): while KeepClicks() is active the clicks are queued, and
; AndroidClick(Default, Default) - ReleaseClicks() - sends the whole queue. A queued entry is
; [x, y, action]: "down-up" is a tap; "down", "" (a move) and "up" are the points of a drag.
Func GenericInputClick($x, $y, $times = 1, $speed = 150)
	If $times < 1 Then Return
	Local $i
	Local $bRelease = ($x = Default And $y = Default And $g_aiAndroidAdbClicks[0] > 0)
	If Not $bRelease And $g_aiAndroidAdbClicks[0] > -1 Then
		Local $iPos = $g_aiAndroidAdbClicks[0]
		$g_aiAndroidAdbClicks[0] = $iPos + $times
		ReDim $g_aiAndroidAdbClicks[$g_aiAndroidAdbClicks[0] + 1]
		Local $aClick = [$x, $y, "down-up"]
		For $i = 1 To $times
			$g_aiAndroidAdbClicks[$iPos + $i] = $aClick
		Next
		Return
	EndIf

	Local $aCmds[0]
	If $bRelease Then
		For $i = 1 To $g_aiAndroidAdbClicks[0]
			Local $a = $g_aiAndroidAdbClicks[$i]
			If Not IsArray($a) Then ContinueLoop
			Local $sXY = Int($a[0]) & " " & Int($a[1])
			Switch $a[2]
				Case "down-up"
					_ArrayAdd($aCmds, "input tap " & $sXY)
				Case "down"
					_ArrayAdd($aCmds, "input motionevent DOWN " & $sXY)
				Case "up"
					_ArrayAdd($aCmds, "input motionevent UP " & $sXY)
				Case Else
					_ArrayAdd($aCmds, "input motionevent MOVE " & $sXY)
			EndSwitch
		Next
	Else
		Local $hTimer = __TimerInit()
		For $i = 1 To $times
			If $i > 1 And $speed > 0 Then _ArrayAdd($aCmds, "sleep " & StringFormat("%.3f", $speed / 1000))
			_ArrayAdd($aCmds, "input tap " & Int($x) & " " & Int($y))
		Next
		GenericInputSend($aCmds)
		; like AndroidSlowClick(): the click takes at least $speed ms
		Local $iWait = $speed - __TimerDiff($hTimer)
		If $iWait > 0 Then _Sleep($iWait, False)
		Return
	EndIf
	GenericInputSend($aCmds)
EndFunc   ;==>GenericInputClick

; A drag through "input motionevent", timed like AndroidMinitouchClickDrag(): the finger rests 250 ms
; where it lands, moves in steps, then rests 1 s before lifting so lists stop instead of flinging.
Func GenericInputDrag($x1, $y1, $x2, $y2, $wasRunState = Default)
	Local $aCmds = ["input motionevent DOWN " & Int($x1) & " " & Int($y1), "sleep 0.25"]
	Local $i, $iSteps = 10
	For $i = 1 To $iSteps
		_ArrayAdd($aCmds, "input motionevent MOVE " & Int($x1 + ($x2 - $x1) * $i / $iSteps) & " " & Int($y1 + ($y2 - $y1) * $i / $iSteps))
	Next
	_ArrayAdd($aCmds, "sleep 1")
	_ArrayAdd($aCmds, "input motionevent UP " & Int($x2) & " " & Int($y2))
	If Not GenericInputSend($aCmds, $wasRunState) Then Return SetError(1, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>GenericInputDrag

; Sends shell commands through the bot's steady ADB shell, a few dozen per round trip: one line per
; tap would cost an ADB round trip each, one huge line could exceed the shell's line buffer.
Func GenericInputSend(ByRef $aCmds, $wasRunState = Default, $iTimeout = Default)
	If $wasRunState = Default Then $wasRunState = $g_bRunState
	Local $i, $sBatch = "", $iInBatch = 0
	For $i = 0 To UBound($aCmds) - 1
		$sBatch &= ($sBatch = "" ? "" : ";") & $aCmds[$i]
		$iInBatch += 1
		If $iInBatch = 40 Or $i = UBound($aCmds) - 1 Then
			AndroidAdbSendShellCommand($sBatch, $iTimeout, $wasRunState)
			If @error Then
				SetDebugLog($g_sAndroidEmulator & " input command failed, error " & @error, $COLOR_ERROR)
				Return False
			EndIf
			$sBatch = ""
			$iInBatch = 0
		EndIf
	Next
	Return True
EndFunc   ;==>GenericInputSend

; Zoom out with a two-finger pinch. minitouch could pinch but needs a touch device, and "input" moves one
; finger only. mybot-touch.dex (built by _tools/touch/build.sh) injects the gesture as the shell user, the
; same way "input" does, so it needs neither root nor a touch device.
Func GenericPinchZoomOut($wasRunState = Default)
	Local $sDex = $g_sAndroidAdbGenericTmpPath & "mybot-touch.dex"
	If Not $g_bAndroidAdbGenericTouchDexPushed Then
		If Not AndroidAdbPushFile($g_sAdbScriptsPath & "\mybot-touch.dex", $sDex) Then Return SetError(2, 0, 0)
		$g_bAndroidAdbGenericTouchDexPushed = True
	EndIf
	; fingers on the diagonal through the screen centre, from 70% to 15% of the height apart: the
	; buttons along the edges stay untouched
	Local $aCmds = ["CLASSPATH=" & $sDex & " app_process / MyBotTouch pinch " & Int($g_iGAME_WIDTH / 2) & " " & Int($g_iGAME_HEIGHT / 2) & " " & _
			Int($g_iGAME_HEIGHT * 0.7) & " " & Int($g_iGAME_HEIGHT * 0.15) & " 300 2"]
	; app_process takes a second or two to start: well over the shell's default 3 s with both pinches
	If Not GenericInputSend($aCmds, $wasRunState, 15000) Then Return SetError(1, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>GenericPinchZoomOut

; Clash of Clans reports inactivity, a lost connection or another device through Android's own dialog,
; which looks different on every Android version: the bot's templates are for the emulators' Android and
; miss it elsewhere (Waydroid: Android 13). A Generic Android is read instead: a second game window means
; a dialog is up, and uiautomator lists its texts and buttons. Returns True when a button was clicked.
Func GenericSystemDialog()
	Local $sCount = AndroidAdbSendShellCommand("dumpsys window windows | grep -cE 'Window #[0-9]+ Window\{.* " & $g_sAndroidGamePackage & "/'")
	If Int(StringStripWS($sCount, 3)) < 2 Then Return False
	Local $sXml = AndroidAdbSendShellCommand("uiautomator dump " & $g_sAndroidAdbGenericTmpPath & "mybot-ui.xml >/dev/null 2>&1; cat " & $g_sAndroidAdbGenericTmpPath & "mybot-ui.xml", 15000)
	; uiautomator writes the attributes in a fixed order: text, resource-id, class, ..., bounds
	Local $aNodes = StringRegExp($sXml, '<node [^>]*?text="([^"]*)"[^>]*?class="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then Return False
	Local $i, $sTexts = "", $iX = -1, $iY = -1, $sButton = ""
	For $i = 0 To UBound($aNodes) - 6 Step 6
		If $aNodes[$i] = "" Then ContinueLoop
		$sTexts &= ($sTexts = "" ? "" : " | ") & $aNodes[$i]
		If StringInStr($aNodes[$i + 1], "Button") And StringRegExp($aNodes[$i], "(?i)^\s*(reload( game)?|try again|retry)\s*$") Then
			$sButton = $aNodes[$i]
			$iX = Int(($aNodes[$i + 2] + $aNodes[$i + 4]) / 2)
			$iY = Int(($aNodes[$i + 3] + $aNodes[$i + 5]) / 2)
		EndIf
	Next
	If $sTexts = "" Then Return False
	If $sButton = "" Then
		SetDebugLog($g_sAndroidEmulator & " dialog without a known button: " & $sTexts)
		Return False
	EndIf
	SetLog("Detected: " & $sTexts, $COLOR_INFO)
	Local $bAnotherDevice = StringRegExp($sTexts, "(?i)another device")
	If $bAnotherDevice Then
		; same pause as the image based check (CheckAllObstacles) before taking the village back
		SetLog("Another Device has connected, waiting " & $g_iAnotherDeviceWaitTime & " seconds", $COLOR_ERROR)
		PushMsg("AnotherDevice")
		If _SleepStatus($g_iAnotherDeviceWaitTime * 1000) Then Return True
	EndIf
	SetLog("Click '" & $sButton & "'", $COLOR_INFO)
	PureClick($iX, $iY, 1, 120, "#GenericDialog")
	If _Sleep($DELAYCHECKOBSTACLES1) Then Return True
	If $bAnotherDevice Then checkObstacles_ResetSearch()
	Return True
EndFunc   ;==>GenericSystemDialog

Func GenericBotStartEvent()
	Return True
EndFunc   ;==>GenericBotStartEvent

Func GenericBotStopEvent()
	Return True
EndFunc   ;==>GenericBotStopEvent

; ------------------------------------------------------------------------------------------------
; Shared-folder replacement. Android.au3 calls these only when $g_bAndroidAdbNoSharedFolder is set,
; i.e. only for a Generic Android, at the few points where a file has to exist on the other side.
; ------------------------------------------------------------------------------------------------

; Fetches a file from Android to the host. Returns True when the host file exists afterwards.
Func AndroidAdbPullFile($sAndroidFile, $sHostFile)
	If $g_sAndroidAdbPath = "" Then Return False
	Local $process_killed
	FileDelete($sHostFile)
	Local $sOutput = LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " pull """ & $sAndroidFile & """ """ & $sHostFile & """", $process_killed, $g_iAndroidAdbPullPushTimeout, False, True)
	If FileExists($sHostFile) Then Return True
	SetDebugLog("ADB pull failed: " & $sAndroidFile & " -> " & $sHostFile & ": " & StringStripWS($sOutput, 3), $COLOR_ERROR)
	Return False
EndFunc   ;==>AndroidAdbPullFile

; Sends a host file to Android. ADB reports "1 file pushed" on success; a failure is logged but
; not fatal, so the caller behaves as it would with an unreadable shared folder.
Func AndroidAdbPushFile($sHostFile, $sAndroidFile)
	If $g_sAndroidAdbPath = "" Then Return False
	If FileExists($sHostFile) = 0 Then
		SetDebugLog("ADB push skipped, host file missing: " & $sHostFile, $COLOR_ERROR)
		Return False
	EndIf
	Local $process_killed
	Local $sOutput = LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "-s " & $g_sAndroidAdbDevice & " push """ & $sHostFile & """ """ & $sAndroidFile & """", $process_killed, $g_iAndroidAdbPullPushTimeout, False, True)
	If StringInStr($sOutput, "file pushed") > 0 Then Return True
	SetDebugLog("ADB push failed: " & $sHostFile & " -> " & $sAndroidFile & ": " & StringStripWS($sOutput, 3), $COLOR_ERROR)
	Return False
EndFunc   ;==>AndroidAdbPushFile
