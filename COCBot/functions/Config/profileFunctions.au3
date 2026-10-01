; #FUNCTION# ====================================================================================================================
; Name ..........: profileFunctions.au3
; Description ...: Functions for the new profile system
; Author ........: LunaEclipse(02-2016)
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; ===============================================================================================================================

Func setupProfileComboBox()
	; Array to store Profile names to add to ComboBox
	Local $profileString = ""
	Local $aProfiles = _FileListToArray($g_sProfilePath, "*", $FLTA_FOLDERS)
	Local $aProfileList = ["<No Profiles>"]
	If @error Then
		; No folders for profiles so lets set the combo box to a generic entry
		$profileString = $aProfileList[0]
	Else
		; Lets create a new array without the first entry which is a count for populating the combo box
		Local $a[$aProfiles[0]]
		$aProfileList = $a
		For $i = 1 To $aProfiles[0]
			$aProfileList[$i - 1] = $aProfiles[$i]
		Next

		; Convert the array into a string
		$profileString = _ArrayToString($aProfileList, "|")
	EndIf
	$g_asProfiles = $aProfileList
	SetDebugLog("Profiles found: " & $profileString)
EndFunc   ;==>setupProfileComboBox

Func createProfile($bCreateNew = False)
	FuncEnter(createProfile)
	If $bCreateNew = True Then
		; create new profile (recursive call from setupProfile() and selectProfile() !!!)
		setupProfileComboBox()
		setupProfile()
		saveConfig()
		setupProfileComboBox()
		selectProfile()
		Return FuncReturn()
	EndIf

	; create the profile directory if it doesn't already exist.
	DirCreate($g_sProfilePath & "\" & $g_sProfileCurrentName)
	DirCreate($g_sPrivateProfilePath & "\" & $g_sProfileCurrentName)

	; If the Profiles file does not exist create it.
	If Not FileExists($g_sProfilePath & "\profile.ini") Then
		Local $hFile = FileOpen($g_sProfilePath & "\profile.ini", $FO_APPEND + $FO_CREATEPATH)
		FileWriteLine($hFile, "[general]")
		FileClose($hFile)
	EndIf

	SetupProfileFolder()
	; Create the profiles sub-folders
	DirCreate($g_sProfileLogsPath)
	DirCreate($g_sProfileLootsPath)
	DirCreate($g_sProfileTempPath)
	DirCreate($g_sProfileTempDebugPath)
	DirCreate($g_sProfileDonateCapturePath)
	DirCreate($g_sProfileDonateCaptureWhitelistPath)
	DirCreate($g_sProfileDonateCaptureBlacklistPath)

	If FileExists($g_sProfileConfigPath) = 0 Then SetLog("New Profile '" & $g_sProfileCurrentName & "' created")
	FuncReturn()
EndFunc   ;==>createProfile

Func setupProfile($sProfile = Default)
	FuncEnter(setupProfile)
	If Not IsString($sProfile) Then $sProfile = $g_sProfileCurrentName

	If aquireProfileMutex($sProfile, False, True) = 0 Then
		Return FuncReturn(False)
	EndIf
	If $g_sProfileCurrentName And $g_sProfileCurrentName <> $sProfile Then
		releaseProfileMutex($g_sProfileCurrentName)
		If $g_hLogFile <> 0 Then
			FileClose($g_hLogFile)
			$g_hLogFile = 0
		EndIf

		If $g_hAttackLogFile <> 0 Then
			FileClose($g_hAttackLogFile)
			$g_hAttackLogFile = 0
		EndIf
	EndIf

	$g_sProfileCurrentName = $sProfile

	; Create the profile if needed, this also sets the variables if the profile exists.
	createProfile()

	Return FuncReturn(True)
EndFunc   ;==>setupProfile

; The profile to run ($g_sProfileCurrentName by default, from the command line): its mutex, its folders, its settings.
Func selectProfile($sProfile = Default)
	FuncEnter(selectProfile)
	If Not IsString($sProfile) Then $sProfile = $g_sProfileCurrentName

	If aquireProfileMutex($sProfile, False, True) = 0 Then
		Return FuncReturn(False)
	EndIf
	If $g_sProfileCurrentName <> $sProfile Then
		releaseProfileMutex($g_sProfileCurrentName)
	EndIf
	$g_sProfileCurrentName = $sProfile

	; Create the profile if needed, this also sets the variables if the profile exists.
	createProfile()
	readConfig()
	Return FuncReturn(True)
EndFunc   ;==>selectProfile

Func aquireProfileMutex($sProfile = Default, $bReturnOnlyMutex = Default, $bShowMsgBox = False)
	If $sProfile = Default Then $sProfile = $g_sProfileCurrentName
	If $bReturnOnlyMutex = Default Then $bReturnOnlyMutex = False
	; check if mutex is or can be aquired
	Local $iProfile = _ArraySearch($g_ahMutex_Profile, $sProfile, 0, 0, 0, 0, 1, 0)
	If $iProfile >= 0 Then
		; Mutex already aquired
		If $bReturnOnlyMutex Then
			Return $g_ahMutex_Profile[$iProfile][1]
		EndIf
		Return 2
	EndIf

	; try to aquire mutex, since 7.4.4 beta 3, it's not using full pathname anymore to ensure shared_prefs with same village name is not used by different bot installs
	; Local $hMutex_Profile = CreateMutex(StringReplace($g_sProfilePath & "\" & $sProfile, "\", "-"))
	Local $hMutex_Profile = CreateMutex("MyBot.run-Profile-" & $sProfile)
	If $bReturnOnlyMutex Then
		Return $hMutex_Profile
	EndIf

	Local $sMsg = StringRegExpReplace(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_02", "My Bot with Profile %s is already in use.\r\n\r\n", $sProfile), "[\r\n]", "")

	If $hMutex_Profile = 0 Then
		; mutex already in use
		SetLog($sMsg, $COLOR_ERROR)
		;SetLog($sMsg, "Cannot switch to profile " & $sProfile, $COLOR_ERROR)
		If $bShowMsgBox Then
			MsgBox(BitOR($MB_OK, $MB_ICONINFORMATION, $MB_TOPMOST), $g_sBotTitle, $sMsg)
		EndIf
		Return 0
	EndIf

	; add mutex to array
	SetDebugLog("Aquire Mutex for Profile: " & $sProfile)
	$iProfile = UBound($g_ahMutex_Profile)
	ReDim $g_ahMutex_Profile[$iProfile + 1][2]
	$g_ahMutex_Profile[$iProfile][0] = $sProfile
	$g_ahMutex_Profile[$iProfile][1] = $hMutex_Profile

	Return 1
EndFunc   ;==>aquireProfileMutex

Func releaseProfileMutex($sProfile = Default)
	If $sProfile = Default Then $sProfile = $g_sProfileCurrentName
	Local $iProfile = _ArraySearch($g_ahMutex_Profile, $sProfile, 0, 0, 0, 0, 1, 0)
	If $iProfile >= 0 Then
		SetDebugLog("Release Mutex for Profile: " & $sProfile)
		ReleaseMutex($g_ahMutex_Profile[$iProfile][1])
		_ArrayDelete($g_ahMutex_Profile, $iProfile)
		Return True
	EndIf
	Return False
EndFunc   ;==>releaseProfileMutex

Func releaseProfilesMutex($bCurrentAlso = False)
	If UBound($g_ahMutex_Profile) > 0 Then
		Local $iReleased = 0
		For $i = 0 To UBound($g_ahMutex_Profile) - 1
			If $bCurrentAlso Or $g_sProfileCurrentName <> $g_ahMutex_Profile[$i - $iReleased][0] Then
				If releaseProfileMutex($g_ahMutex_Profile[$i - $iReleased][0]) Then $iReleased += 1
			EndIf
		Next
	EndIf
EndFunc   ;==>releaseProfilesMutex
