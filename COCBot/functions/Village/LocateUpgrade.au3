; #FUNCTION# ====================================================================================================================
; Name ..........: LocateUpgrade.au3
; Description ...: Finds and determines cost of upgrades
; Syntax ........: LocateOneUpgrade($inum) = $inum is building array index [0-3]
; Parameters ....:
; Return values .:
; Author ........: KnowJack (April-2015)
; Modified ......: KnowJack (Jun/Aug-2015),Sardo 2015-08,Monkeyhunter(2106-2)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

; Reads the cost, type, name, level and time of a located upgrade. With no window any more the bot cannot ask
; for a value it fails to read: the upgrade is then skipped, and retried later when it repeats.
Func UpgradeValue($inum, $bRepeat = False) ;function to find the value and type of the upgrade.
	Local $aString, $aResult, $ButtonPixel
	Local $bOopsFlag = False

	If $bRepeat Or $g_abUpgradeRepeatEnable[$inum] Then ; check for upgrade in process when continiously upgrading
		ClearScreen()
		If _Sleep($DELAYUPGRADEVALUE1) Then Return
		BuildingClick($g_avBuildingUpgrades[$inum][0], $g_avBuildingUpgrades[$inum][1]) ;Select upgrade trained
		If _Sleep($DELAYUPGRADEVALUE4) Then Return
		If $bOopsFlag = True Then SaveDebugImage("ButtonView")
		; check if upgrading collector type building, and reselect in case previous click only collect resource
		If StringInStr($g_avBuildingUpgrades[$inum][4], "collect", $STR_NOCASESENSEBASIC) Or _
				StringInStr($g_avBuildingUpgrades[$inum][4], "mine", $STR_NOCASESENSEBASIC) Or _
				StringInStr($g_avBuildingUpgrades[$inum][4], "drill", $STR_NOCASESENSEBASIC) Then
			ClearScreen()
			If _Sleep($DELAYUPGRADEVALUE1) Then Return
			BuildingClick($g_avBuildingUpgrades[$inum][0], $g_avBuildingUpgrades[$inum][1]) ;Select collector upgrade trained
			If _Sleep($DELAYUPGRADEVALUE4) Then Return
		EndIf
		; check for upgrade in process
		If QuickMIS("BC1", $g_sImgCancelButton, 130, 500 + $g_iBottomOffsetY, 740, 590 + $g_iBottomOffsetY) Then
			SetLog("Selection #" & $inum + 1 & " Upgrade in process - Skipped!", $COLOR_WARNING)
			ClearScreen()
			Return False
		EndIf
	Else ; If upgrade not in process
		If $g_avBuildingUpgrades[$inum][0] <= 0 Or $g_avBuildingUpgrades[$inum][1] <= 0 Then Return False
		$g_avBuildingUpgrades[$inum][2] = 0 ; Clear previous upgrade value if run before
		$g_avBuildingUpgrades[$inum][3] = "" ; Clear previous loot type if run before
		$g_avBuildingUpgrades[$inum][4] = "" ; Clear upgrade name if run before
		$g_avBuildingUpgrades[$inum][5] = "" ; Clear upgrade level if run before
		$g_avBuildingUpgrades[$inum][6] = "" ; Clear upgrade time if run before
		$g_avBuildingUpgrades[$inum][7] = "" ; Clear upgrade end date/time if run before
		ClearScreen()
		SetLog("-$Upgrade #" & $inum + 1 & " Location =  " & "(" & $g_avBuildingUpgrades[$inum][0] & "," & $g_avBuildingUpgrades[$inum][1] & ")", $COLOR_DEBUG1) ;Debug
		If _Sleep($DELAYUPGRADEVALUE1) Then Return
		BuildingClick($g_avBuildingUpgrades[$inum][0], $g_avBuildingUpgrades[$inum][1], "#0212") ;Select upgrade trained
		If _Sleep($DELAYUPGRADEVALUE2) Then Return
		If $bOopsFlag = True Then SaveDebugImage("ButtonView")
	EndIf

	If $bOopsFlag And $g_bDebugImageSave Then SaveDebugImage("ButtonView")

	$aResult = BuildingInfo(242, 475 + $g_iBottomOffsetY)
	If $aResult[0] > 0 Then
		$g_avBuildingUpgrades[$inum][4] = $aResult[1] ; Store bldg name
		If $aResult[0] > 1 Then
			$g_avBuildingUpgrades[$inum][5] = $aResult[2] ; Store bdlg level
		Else
			SetLog("Error: Level for Upgrade not found?", $COLOR_ERROR)
		EndIf
	Else
		SetLog("Error: Name & Level for Upgrade not found?", $COLOR_ERROR)
	EndIf
	SetLog("Upgrade Name = " & $g_avBuildingUpgrades[$inum][4] & ", Level = " & $g_avBuildingUpgrades[$inum][5], $COLOR_INFO) ;Debug

	Local $aUpgradeButton, $aTmpUpgradeButton
	Local $IsTHWeapon = False
	$aUpgradeButton = findButton("Upgrade", Default, 1, True)

	If $aResult[1] = "Town Hall" And $aResult[2] > 11 Then ;Upgrade THWeapon
		$aTmpUpgradeButton = findButton("THWeapon") ;try to find UpgradeTHWeapon button (swords)
		If IsArray($aTmpUpgradeButton) And UBound($aTmpUpgradeButton) = 2 Then
			$IsTHWeapon = True
			Switch $aResult[2]
				Case 12
					$g_avBuildingUpgrades[$inum][4] = "Giga Tesla"
				Case 13
					$g_avBuildingUpgrades[$inum][4] = "Giga Inferno"
				Case 14
					$g_avBuildingUpgrades[$inum][4] = "Giga Inferno"
				Case 15
					$g_avBuildingUpgrades[$inum][4] = "Giga Inferno"
				Case 16
					$g_avBuildingUpgrades[$inum][4] = "Giga Inferno"
				Case 17
					$g_avBuildingUpgrades[$inum][4] = "Inferno Artillery"
			EndSwitch
			$aUpgradeButton = $aTmpUpgradeButton
		EndIf
	EndIf

	If IsArray($aUpgradeButton) And UBound($aUpgradeButton, 1) = 2 Then
		ClickP($aUpgradeButton, 1, 120, "#0213") ; Click Upgrade Button
		If _Sleep($DELAYUPGRADEVALUE5) Then Return
		If $bOopsFlag And $g_bDebugImageSave Then SaveDebugImage("UpgradeView")

		CloseSuperchargeWindow()

		If $IsTHWeapon Then
			Local $THWLevelUp = getOcrAndCapture("coc-YellowLevel", 503, 116, 190, 20)
			$THWLevelUp = StringReplace($THWLevelUp, "1", "")
			If $THWLevelUp > 1 And $THWLevelUp <= 5 Then $g_avBuildingUpgrades[$inum][5] = Number($THWLevelUp - 1)
		EndIf

		_CaptureRegion()
		Select ;Ensure the right upgrade window is open!
			Case _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8D, 6), 20) ; Check if the building Upgrade window is open red bottom of white X to close
				If _ColorCheck(_GetPixelColor(500, 455 + $g_iMidOffsetY, True), Hex(0xD62F47, 6), 20) Then ; Check if upgrade requires upgrade to TH and can not be completed
					If $g_abUpgradeRepeatEnable[$inum] = True Then
						SetLog("Selection #" & $inum + 1 & " can not repeat upgrade, need TH upgrade - Skipped!", $COLOR_ERROR)
						$g_abUpgradeRepeatEnable[$inum] = False
					Else
						SetLog("Selection #" & $inum + 1 & " upgrade not available, need TH upgrade - Skipped!", $COLOR_ERROR)
					EndIf
					ClearUpgradeInfo($inum) ; clear upgrade information
					$g_abBuildingUpgradeEnable[$inum] = False
					$g_avBuildingUpgrades[$inum][7] = "" ; Clear upgrade end date/time if run before
					CloseWindow()
					Return False
				EndIf

				Local $aiSupercharge = _PixelSearch(540, 90 + $g_iMidOffsetY, 700, 100 + $g_iMidOffsetY, Hex(0x00FFFF, 6), 20)
				If IsArray($aiSupercharge) Then
					$g_avBuildingUpgrades[$inum][5] = $g_avBuildingUpgrades[$inum][5] & "+"
				EndIf

				If _ColorCheck(_GetPixelColor(682, 545 + $g_iMidOffsetY, True), Hex(0xFFF957, 6), 20) Then $g_avBuildingUpgrades[$inum][3] = "Gold" ;Check if Gold required and update type
				If _ColorCheck(_GetPixelColor(682, 545 + $g_iMidOffsetY, True), Hex(0xFF5AFF, 6), 20) Then $g_avBuildingUpgrades[$inum][3] = "Elixir" ;Check if Elixir required and update type
				If _ColorCheck(_GetPixelColor(682, 545 + $g_iMidOffsetY, True), Hex(0x4B3950, 6), 20) Then $g_avBuildingUpgrades[$inum][3] = "Dark" ;Check if Dark Elixir required and update type

				$g_avBuildingUpgrades[$inum][2] = Number(getCostsUpgrade(552, 541 + $g_iMidOffsetY)) ; Try to read white text.
				If $g_avBuildingUpgrades[$inum][2] = "" Then $g_avBuildingUpgrades[$inum][2] = Number(getCostsUpgrade(552, 532 + $g_iMidOffsetY)) ; Try to read yellow text (Discount).
				If $g_avBuildingUpgrades[$inum][2] = "" Then $g_avBuildingUpgrades[$inum][2] = Number(getCostsUpgradeRed(552, 541 + $g_iMidOffsetY)) ;read Red upgrade text
				If $g_avBuildingUpgrades[$inum][2] = "" Then $g_avBuildingUpgrades[$inum][2] = Number(getCostsUpgradeRed(552, 532 + $g_iMidOffsetY)) ;read Orange upgrade text (Discount).
				If $g_avBuildingUpgrades[$inum][2] = "" And $g_abUpgradeRepeatEnable[$inum] = False Then $bOopsFlag = True ; set error flag for user to set value if not repeat upgrade

				$g_avBuildingUpgrades[$inum][6] = getBldgUpgradeTime(717, 544 + $g_iMidOffsetY) ; Try to read white text showing time for upgrade
				If $g_avBuildingUpgrades[$inum][6] = "" Then $g_avBuildingUpgrades[$inum][6] = getBldgUpgradeTime(717, 532 + $g_iMidOffsetY) ; Try to read yellow text (Discount).
				SetLog("Upgrade #" & $inum + 1 & " Time = " & $g_avBuildingUpgrades[$inum][6], $COLOR_INFO)
				If $g_avBuildingUpgrades[$inum][6] <> "" Then $g_avBuildingUpgrades[$inum][7] = "" ; Clear old upgrade end time

			Case Else
				isGemOpen(True)
				SetLog("Selected Upgrade Window Opening Error, try again", $COLOR_ERROR)
				ClearUpgradeInfo($inum) ; clear upgrade information
				CloseWindow()
				Return False

		EndSelect

		If $g_avBuildingUpgrades[$inum][2] = "" Or $g_avBuildingUpgrades[$inum][3] = "" And Not $g_abUpgradeRepeatEnable[$inum] Then ;report loot error if exists
			SetLog("Error finding loot info " & $inum & ", Loot = " & $g_avBuildingUpgrades[$inum][2] & ", Type= " & $g_avBuildingUpgrades[$inum][3], $COLOR_ERROR)
			$g_avBuildingUpgrades[$inum][0] = -1 ; Clear upgrade location value as it is invalid
			$g_avBuildingUpgrades[$inum][1] = -1 ; Clear upgrade location value as it  is invalid
			CloseWindow()
			Return False
		EndIf
		SetLog("Upgrade #" & $inum + 1 & " Value = " & _NumberFormat($g_avBuildingUpgrades[$inum][2]) & " " & $g_avBuildingUpgrades[$inum][3], $COLOR_INFO) ; debug & document cost of upgrade
	Else
		If $g_abUpgradeRepeatEnable[$inum] = False Then
			SetLog("Upgrade selection problem - data cleared, please try again", $COLOR_ERROR)
			ClearUpgradeInfo($inum)
		ElseIf $g_abUpgradeRepeatEnable[$inum] = True Then
			SetLog("Repeat upgrade problem - will retry value update later", $COLOR_ERROR)
		EndIf
		CloseWindow()
		Return False
	EndIf

	CloseWindow()

	If _Sleep(1000) Then Return
	Return True

EndFunc   ;==>UpgradeValue


Func ClearUpgradeInfo($inum)
	; quick function to reset the $g_avBuildingUpgrades array for one upgrade
	$g_aiPicUpgradeStatus[$inum] = $eIcnRedLight
	$g_avBuildingUpgrades[$inum][0] = -1 ; Clear upgrade location value as it is invalid
	$g_avBuildingUpgrades[$inum][1] = -1 ; Clear upgrade location value as it is invalid
	$g_avBuildingUpgrades[$inum][2] = 0 ; Clear upgrade value as it is invalid
	$g_avBuildingUpgrades[$inum][3] = "" ; Clear upgrade type as it is invalid
	$g_avBuildingUpgrades[$inum][4] = "" ; Clear upgrade name as it is invalid
	$g_avBuildingUpgrades[$inum][5] = "" ; Clear upgrade level as it is invalid
	$g_avBuildingUpgrades[$inum][6] = "" ; Clear upgrade time as it is invalid
	$g_avBuildingUpgrades[$inum][7] = "" ; Clear upgrade end date/time as it is invalid
EndFunc   ;==>ClearUpgradeInfo

Func CloseSuperchargeWindow()

	If Not _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8D, 6), 20) Then
		If WaitforPixel(283, 193 + $g_iMidOffsetY, 287, 197 + $g_iMidOffsetY, Hex(0x121A87, 6), 20, 6) Then ; Wait 3 seconds
			Local $hTimer = __TimerInit()
			While 1
				If _Sleep(500) Then Return
				Local $aContinueButton = findButton("Continue", Default, 1, True)
				If IsArray($aContinueButton) And UBound($aContinueButton, 1) = 2 Then
					ClickP($aContinueButton, 1, 120, "#0433")
					If _Sleep(2000) Then Return
					ExitLoop
				EndIf
				Local $fDiff = __TimerDiff($hTimer)
				If $fDiff > 5000 Then ExitLoop
			WEnd
		EndIf
	EndIf

EndFunc   ;==>CloseSuperchargeWindow
