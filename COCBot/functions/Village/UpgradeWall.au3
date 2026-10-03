; #FUNCTION# ====================================================================================================================
; Name ..........: UpgradeWall
; Description ...: This file checks if enough resources to upgrade walls, and upgrades them
; Syntax ........: UpgradeWall()
; Parameters ....:
; Return values .: None
; Author ........: ProMac (2015), HungLe (2015)
; Modified ......: Sardo (08-2015), KnowJack (08-2015), MonkeyHunter(06-2016) , trlopes (07-2016)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......: checkwall.au3
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

; True when the builder menu was read to the end of its list without a Wall line: no wall can be upgraded at any
; level, so moving on to the next level would only search for nothing (SwitchToNextWallLevel)
Global $g_bWallMenuNoWall = False

Func UpgradeWall()

	Local $iWallCost = Int($g_iWallCost - ($g_iWallCost * Number($g_iBuilderBoostDiscount) / 100))

	If Not $g_bRunState Then Return
	$g_bWallMenuNoWall = False

	If $g_bAutoUpgradeWallsEnable = True Then
		VillageReport(True, True)
		SetLog("Checking Upgrade Walls", $COLOR_INFO)
		SetDebugLog("$iWallCost:" & $iWallCost)
		If SkipWallUpgrade($iWallCost) Then Return
		SetDebugLog("$g_iFreeBuilderCount:" & $g_iFreeBuilderCount)
		If $g_iFreeBuilderCount > 0 Then
			ZoomOut()
			Local $MinWallGold = Number($g_aiCurrentLoot[$eLootGold] - $iWallCost) >= Number($g_iUpgradeWallMinGold) ; Check if enough Gold
			Local $MinWallElixir = Number($g_aiCurrentLoot[$eLootElixir] - $iWallCost) >= Number($g_iUpgradeWallMinElixir) ; Check if enough Elixir

			SetDebugLog("$g_iUpgradeWallLootType" & $g_iUpgradeWallLootType)
			SetDebugLog("$MinWallGold" & $MinWallGold)
			SetDebugLog("$MinWallElixir" & $MinWallElixir)

			While ($g_iUpgradeWallLootType = 0 And $MinWallGold) Or ($g_iUpgradeWallLootType = 1 And $MinWallElixir) Or ($g_iUpgradeWallLootType = 2 And ($MinWallGold Or $MinWallElixir))

				Switch $g_iUpgradeWallLootType
					Case 0
						If $MinWallGold Then
							SetLog("Upgrading Wall using Gold", $COLOR_SUCCESS)
							If imglocCheckWall() Then
								$iWallCost = WallCostNow() ; the selected wall can be of another level than the combo
								If Not __UpgradeWallStep(True, $iWallCost) Then
									SetLog("Upgrade with Gold failed, skipping...", $COLOR_ERROR)
									Return
								EndIf
							ElseIf SwitchToNextWallLevel() Then
								SetLog("No more walls of current level, switching to next", $COLOR_ACTION)
							Else
								Return
							EndIf
						Else
							SetLog("Gold is below minimum, Skipping Upgrade", $COLOR_ERROR)
						EndIf
					Case 1
						If $MinWallElixir Then
							SetLog("Upgrading Wall using Elixir", $COLOR_SUCCESS)
							If imglocCheckWall() Then
								$iWallCost = WallCostNow() ; the selected wall can be of another level than the combo
								If Not __UpgradeWallStep(False, $iWallCost) Then
									SetLog("Upgrade with Elixier failed, skipping...", $COLOR_ERROR)
									Return
								EndIf
							ElseIf SwitchToNextWallLevel() Then
								SetLog("No more walls of current level, switching to next", $COLOR_ACTION)
							Else
								Return
							EndIf
						Else
							SetLog("Elixir is below minimum, Skipping Upgrade", $COLOR_ERROR)
						EndIf
					Case 2
						If $MinWallElixir Then
							SetLog("Upgrading Wall using Elixir", $COLOR_SUCCESS)
							If imglocCheckWall() Then
								$iWallCost = WallCostNow() ; the selected wall can be of another level than the combo
								If Not __UpgradeWallStep(False, $iWallCost) Then
									SetLog("Upgrade with Elixir failed, attempt to upgrade using Gold", $COLOR_ERROR)
									If Not __UpgradeWallStep(True, $iWallCost) Then
										SetLog("Upgrade with Gold failed, skipping...", $COLOR_ERROR)
										Return
									EndIf
								EndIf
							ElseIf SwitchToNextWallLevel() Then
								SetLog("No more walls of current level, switching to next", $COLOR_ACTION)
							Else
								Return
							EndIf
						Else
							SetLog("Elixir is below minimum, attempt to upgrade using Gold", $COLOR_ERROR)
							If $MinWallGold Then
								If imglocCheckWall() Then
									$iWallCost = WallCostNow() ; the selected wall can be of another level than the combo
									If Not __UpgradeWallStep(True, $iWallCost) Then
										SetLog("Upgrade with Gold failed, skipping...", $COLOR_ERROR)
										Return
									EndIf
								ElseIf SwitchToNextWallLevel() Then
									SetLog("No more walls of current level, switching to next", $COLOR_ACTION)
								Else
									Return
								EndIf
							Else
								SetLog("Gold is below minimum, Skipping Upgrade", $COLOR_ERROR)
							EndIf
						EndIf
				EndSwitch

				; Check Builder/Shop if open by accident
				If _CheckPixel($g_aShopWindowOpen, $g_bCapturePixel, Default, "ChkShopOpen", $COLOR_DEBUG) = True Then
					Click(820, 40, 1, 100, "#0315") ; Close it
				EndIf

				ClearScreen()
				VillageReport(True, True)
				If SkipWallUpgrade($iWallCost) Then Return
				$MinWallGold = Number($g_aiCurrentLoot[$eLootGold] - $iWallCost) > Number($g_iUpgradeWallMinGold) ; Check if enough Gold
				$MinWallElixir = Number($g_aiCurrentLoot[$eLootElixir] - $iWallCost) > Number($g_iUpgradeWallMinElixir) ; Check if enough Elixir

			WEnd
		Else
			SetLog("No free builder, Upgrade Walls skipped..", $COLOR_ERROR)
		EndIf
	EndIf
	If _Sleep($DELAYUPGRADEWALL1) Then Return
	VillageReport(True, True)
	UpdateStats()
	checkMainScreen(False) ; Check for errors during function

EndFunc   ;==>UpgradeWall

Func UpgradeWallGold($iWallCost = $g_iWallCost)

	If _Sleep($DELAYRESPOND) Then Return

	Local $aUpgradeButton = findButton("Upgrade", Default, 2, True)
	If IsArray($aUpgradeButton) And UBound($aUpgradeButton) > 0 Then
		For $i = 0 To UBound($aUpgradeButton) - 1
			If QuickMIS("BC1", $g_sImgWallResource, $aUpgradeButton[$i][0] + 32, $aUpgradeButton[$i][1] - 30, $aUpgradeButton[$i][0] + 47, $aUpgradeButton[$i][1] - 14) Then
				If $g_iQuickMISName = "WallGold" Then
					Click($aUpgradeButton[$i][0], $aUpgradeButton[$i][1])
					ExitLoop
				EndIf
			EndIf
		Next
	EndIf

	If _Sleep($DELAYUPGRADEWALLGOLD2) Then Return

	If _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8E, 6), 20) Then ; wall upgrade window red x
		If isNoUpgradeLoot(False) = True Then
			SetLog("Upgrade stopped due no loot", $COLOR_ERROR)
			Return False
		EndIf
		Click(620, 540 + $g_iMidOffsetY, 1, 120, "#0317")
		If _Sleep(1000) Then Return
		If isGemOpen(True) Then
			SetLog("Upgrade stopped due no loot", $COLOR_ERROR)
			Return False
		ElseIf _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8E, 6), 20) Then ; wall upgrade window red x, didnt closed on upgradeclick, so not able to upgrade
			CloseWindow()
			SetLog("unable to upgrade", $COLOR_ERROR)
			Return False
		Else
			If _Sleep($DELAYUPGRADEWALLGOLD3) Then Return
			ClearScreen()
			SetLog("Upgrade complete", $COLOR_SUCCESS)
			PushMsg("UpgradeWithGold")
			$g_iNbrOfWallsUppedGold += 1
			$g_iNbrOfWallsUpped += 1
			$g_iCostGoldWall += $iWallCost
			UpdateStats()
			Return True
		EndIf
	EndIf

	ClearScreen()
	SetLog("No Upgrade Gold Button", $COLOR_ERROR)
	Pushmsg("NoUpgradeGoldButton")
	Return False

EndFunc   ;==>UpgradeWallGold

Func UpgradeWallElixir($iWallCost)

	If _Sleep($DELAYRESPOND) Then Return

	Local $aUpgradeButton = findButton("Upgrade", Default, 2, True)
	If IsArray($aUpgradeButton) And UBound($aUpgradeButton) > 0 Then
		For $i = 0 To UBound($aUpgradeButton) - 1
			If QuickMIS("BC1", $g_sImgWallResource, $aUpgradeButton[$i][0] + 32, $aUpgradeButton[$i][1] - 30, $aUpgradeButton[$i][0] + 47, $aUpgradeButton[$i][1] - 14) Then
				If $g_iQuickMISName = "WallElix" Then
					Click($aUpgradeButton[$i][0], $aUpgradeButton[$i][1])
					ExitLoop
				EndIf
			EndIf
		Next
	EndIf

	If _Sleep($DELAYUPGRADEWALLELIXIR2) Then Return

	If _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8E, 6), 20) Then ; wall upgrade window red x
		If isNoUpgradeLoot(False) = True Then
			SetLog("Upgrade stopped due to insufficient loot", $COLOR_ERROR)
			Return False
		EndIf
		Click(620, 540 + $g_iMidOffsetY, 1, 120, "#0317")
		If _Sleep(1000) Then Return
		If isGemOpen(True) Then
			SetLog("Upgrade stopped due to insufficient loot", $COLOR_ERROR)
			Return False
		ElseIf _ColorCheck(_GetPixelColor(800, 88 + $g_iMidOffsetY, True), Hex(0xF38E8E, 6), 20) Then ; wall upgrade window red x, didnt closed on upgradeclick, so not able to upgrade
			CloseWindow()
			SetLog("unable to upgrade", $COLOR_ERROR)
			Return False
		Else
			If _Sleep($DELAYUPGRADEWALLELIXIR3) Then Return
			ClearScreen()
			SetLog("Upgrade complete", $COLOR_SUCCESS)
			PushMsg("UpgradeWithElixir")
			$g_iNbrOfWallsUppedElixir += 1
			$g_iNbrOfWallsUpped += 1
			$g_iCostElixirWall += $iWallCost
			UpdateStats()
			Return True
		EndIf
	EndIf

	ClearScreen()
	SetLog("No Upgrade Elixir Button", $COLOR_ERROR)
	Pushmsg("NoUpgradeElixirButton")
	Return False

EndFunc   ;==>UpgradeWallElixir

Func SkipWallUpgrade($iWallCost = $g_iWallCost) ; Dynamic Upgrades

	IniReadS($g_iUpgradeWallLootType, $g_sProfileConfigPath, "upgrade", "use-storage", "0") ; Reset Variable to User Selection

	Local $iUpgradeAction = 0
	Local $iUpgradesNeedGold = 0
	Local $iUpgradesNeedElixir = 0
	Local $iAvailBuilderCount = 0

	SetDebugLog("In SkipWallUpgrade")
	SetDebugLog("$g_iTownHallLevel = " & $g_iTownHallLevel)

	Switch $g_iTownHallLevel
		Case 5 To 8 ;Start at Townhall 5 because any Wall Level below 4 is not supported anyways
			SetDebugLog("Case 5 to 8")
			If $g_iTownHallLevel < $g_iCmbUpgradeWallsLevel + 4 Then
				SetLog("Skip Wall upgrade -insufficient TH-Level", $COLOR_WARNING)
				Return True
			EndIf
		Case 9 To $g_iMaxTHLevel
			SetDebugLog("Case 9 to Max")
			If $g_iTownHallLevel < $g_iCmbUpgradeWallsLevel + 3 Then
				SetLog("Skip Wall upgrade -insufficient TH-Level", $COLOR_WARNING)
				Return True
			EndIf
		Case Else
			SetDebugLog("Else case returning True")
			Return True
	EndSwitch

	If Not getBuilderCount() Then Return True ; update builder data, return true to skip if problem
	If _Sleep($DELAYRESPOND) Then Return True

	$iAvailBuilderCount = $g_iFreeBuilderCount ; capture local copy of free builders

	;;;;; Check building upgrade resouce needs .vs. available resources for walls
	For $iz = 0 To UBound($g_avBuildingUpgrades, 1) - 1 ; loop through all upgrades to see if any are enabled.
		If $g_abBuildingUpgradeEnable[$iz] = True Then $iUpgradeAction += 1 ; count number enabled
	Next

	If $g_iFreeBuilderCount > ($g_bUpgradeWallSaveBuilder ? 1 : 0) And $iUpgradeAction > 0 Then ; check if builder available for bldg upgrade, and upgrades enabled
		; December 2024 : Add Warden Cost to Needed Elixir
		If ($g_iWardenLevel <> -1) And ($g_iWardenLevel < $g_iMaxWardenLevel) And $g_bUpgradeWardenEnable And BitAND($g_iHeroUpgradingBit, $eHeroWarden) <> $eHeroWarden Then
			Local $g_ExactWardenCost = (__UpgCostAt($g_afWardenUpgCost, $g_iWardenLevel) * 1000000) * (1 - Number($g_iBuilderBoostDiscount) / 100)
			$iUpgradesNeedElixir += Number($g_ExactWardenCost)
			$iAvailBuilderCount -= 1
		EndIf
		For $iz = 0 To UBound($g_avBuildingUpgrades, 1) - 1
			; internal check if builder still available, if loop index upgrade slot is enabled, and if upgrade is not in progress
			If $iAvailBuilderCount > ($g_bUpgradeWallSaveBuilder ? 1 : 0) And $g_abBuildingUpgradeEnable[$iz] = True And $g_avBuildingUpgrades[$iz][7] = "" Then
				Switch $g_avBuildingUpgrades[$iz][3]
					Case "Gold"
						$iUpgradesNeedGold += Number($g_avBuildingUpgrades[$iz][2]) ; sum gold required for enabled upgrade
						$iAvailBuilderCount -= 1 ; subtract builder from free count, as only need to save gold for upgrades where builder is available
					Case "Elixir"
						$iUpgradesNeedElixir += Number($g_avBuildingUpgrades[$iz][2]) ; sum elixir required for enabled upgrade
						$iAvailBuilderCount -= 1 ; subtract builder from free count, as only need to save elixir for upgrades where builder is available
				EndSwitch
			EndIf
		Next
		; December 2024 : Add Lab Cost to Needed Elixir
		If $g_bAutoLabUpgradeEnable And $g_iLaboratoryElixirCost > 0 Then
			$iUpgradesNeedElixir += Number($g_iLaboratoryElixirCost)
		EndIf
		SetDebugLog("SkipWall-Upgrade Summary: G:" & $iUpgradesNeedGold & ", E:" & $iUpgradesNeedElixir & ", Wall: " & $iWallCost & ", MinG: " & $g_iUpgradeWallMinGold & ", MinE: " & $g_iUpgradeWallMinElixir) ; debug
		If $iUpgradesNeedGold > 0 Or $iUpgradesNeedElixir > 0 Then ; if upgrade enabled and building upgrade resource is required, log user messages.
			Switch $g_iUpgradeWallLootType
				Case 0 ; Using gold
					If $g_aiCurrentLoot[$eLootGold] - ($iUpgradesNeedGold + $iWallCost + Number($g_iUpgradeWallMinGold)) < 0 Then
						If $iUpgradesNeedGold > 0 Then SetLog("Skip Wall upgrade - insufficient gold for selected upgrades", $COLOR_WARNING)
						Return True
					EndIf
				Case 1 ; Using elixir
					If $g_aiCurrentLoot[$eLootElixir] - ($iUpgradesNeedElixir + $iWallCost + Number($g_iUpgradeWallMinElixir)) < 0 Then
						If $iUpgradesNeedElixir > 0 Then SetLog("Skip Wall upgrade - insufficient elixir for selected upgrades", $COLOR_WARNING)
						Return True
					EndIf
				Case 2 ; Using gold and elixir
					If $g_aiCurrentLoot[$eLootElixir] - ($iUpgradesNeedElixir + $iWallCost + Number($g_iUpgradeWallMinElixir)) < 0 Then
						If $g_aiCurrentLoot[$eLootGold] - ($iUpgradesNeedGold + $iWallCost + Number($g_iUpgradeWallMinGold)) < 0 Then
							SetLog("Skip Wall upgrade - insufficient gold and elixir for selected upgrades", $COLOR_WARNING)
							Return True
						Else
							If $iUpgradesNeedElixir > 0 Then SetLog("Wall upgrade: insufficient elixir for selected upgrades", $COLOR_WARNING)
							SetLog("Using Gold only for Wall Upgrade", $COLOR_SUCCESS1)
							$g_iUpgradeWallLootType = 0
						EndIf
					Else
						If $g_aiCurrentLoot[$eLootGold] - ($iUpgradesNeedGold + $iWallCost + Number($g_iUpgradeWallMinGold)) < 0 Then
							If $iUpgradesNeedGold > 0 Then SetLog("Wall upgrade: insufficient gold for selected upgrades", $COLOR_WARNING)
							SetLog("Using Elixir only for Wall Upgrade", $COLOR_SUCCESS1)
							$g_iUpgradeWallLootType = 1
						EndIf
					EndIf
			EndSwitch
		EndIf
		If _Sleep($DELAYRESPOND) Then Return True
	EndIf
	;;;;;;;;;;;;;;;;;;;;;;;;;;;End upgrades value checking

	Return False

EndFunc   ;==>SkipWallUpgrade

; Called when no wall of the working level could be selected, neither by the search nor by the builder menu.
; The counts are kept by the bot (see "Wall counts" below): above 0, walls of that level are known to be left and the
; search only missed them, so the level is kept. 0 means none left or not known yet: the bot moves on, as it always did.
Func SwitchToNextWallLevel() ; switches wall level to upgrade to next level
	Local $bMenuNoWall = $g_bWallMenuNoWall
	$g_bWallMenuNoWall = False
	If $bMenuNoWall Then Return False ; the builder menu lists no wall at all, the next level has none to upgrade either
	If $g_aiWallsCurrentCount[$g_iCmbUpgradeWallsLevel + 4] > 0 Then Return False
	Return __WallNextLevel()
EndFunc   ;==>SwitchToNextWallLevel

; Moves the bot to the level above the one it works on. False at the last level the bot knows, or when the town hall
; does not allow it: the level would be saved and SkipWallUpgrade() would then skip every wall, lower levels included.
Func __WallNextLevel()
	Local $iNext = $g_iCmbUpgradeWallsLevel + 5 ; index + 1, as a level (index + 4)
	If $iNext - 4 > UBound($g_aiWallCost) - 1 Then Return False
	If Not WallLevelAllowedByTH($iNext) Then
		SetDebugLog("Walls: level " & $iNext & " needs a higher town hall, the level is kept", $COLOR_DEBUG)
		Return False
	EndIf
	SetDebugLog("$g_iCmbUpgradeWallsLevel = " & $g_iCmbUpgradeWallsLevel)
	Return WallSetWorkingLevel($iNext)
EndFunc   ;==>__WallNextLevel

; True when the town hall lets the bot work on walls of level $iLevel, the rule of SkipWallUpgrade(). A town hall
; level not read yet blocks nothing, SkipWallUpgrade() stops the walls in that case anyway.
Func WallLevelAllowedByTH($iLevel)
	If $g_iTownHallLevel < 5 Then Return True
	If $g_iTownHallLevel <= 8 Then Return ($g_iTownHallLevel >= $iLevel)
	Return ($g_iTownHallLevel >= $iLevel - 1)
EndFunc   ;==>WallLevelAllowedByTH

; #FUNCTION# ====================================================================================================================
; Name ..........: Wall counts
; Description ...: The number of walls of each level ([Walls] Wall04 .. Wall19 of the profile) is kept by the bot.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  The game never shows how many walls of each level a village has, but it tells enough to keep the
;                  counts right without anything typed in the settings:
;                  - every wall upgraded moves one level up: count[n] - k, count[n + 1] + k (WallCountUpgraded);
;                  - in the Upgrade More wizard, "Add Wall" printed in red means every wall of that level is in the
;                    selection, and the price of the selection then gives their exact number (WallCountSet);
;                  - when the search finds no wall of a level and the builder menu offers a higher one, none is left.
;                  A level the bot has not finished yet can stay at 0 (not known): nothing waits for the counts, they
;                  only keep the bot on a level whose walls are known to be left, and show the progress in the GUI.
;                  The counts are saved with the profile, older versions could leave them below zero.
; ===============================================================================================================================

; $iWalls walls of level $iLevel were upgraded: they leave that level for the next one. A level whose count was not
; known stays at 0 instead of going below zero.
Func WallCountUpgraded($iLevel, $iWalls)
	$iLevel = Int(Number($iLevel))
	$iWalls = Int(Number($iWalls))
	If $iWalls < 1 Or $iLevel < 4 Or $iLevel + 1 > UBound($g_aiWallsCurrentCount) - 1 Then Return False ; a bad OCR level must not crash the bot
	$g_aiWallsCurrentCount[$iLevel] -= $iWalls
	If $g_aiWallsCurrentCount[$iLevel] < 0 Then $g_aiWallsCurrentCount[$iLevel] = 0
	If $g_aiWallsCurrentCount[$iLevel + 1] < 0 Then $g_aiWallsCurrentCount[$iLevel + 1] = 0
	$g_aiWallsCurrentCount[$iLevel + 1] += $iWalls
	SetDebugLog("Wall counts: " & $iWalls & " wall(s) " & $iLevel & " -> " & $iLevel + 1 & ", level " & $iLevel & ": " & _
			$g_aiWallsCurrentCount[$iLevel] & ", level " & $iLevel + 1 & ": " & $g_aiWallsCurrentCount[$iLevel + 1], $COLOR_DEBUG)
	Return True
EndFunc   ;==>WallCountUpgraded

; The game showed that the village has exactly $iWalls walls of level $iLevel.
Func WallCountSet($iLevel, $iWalls)
	$iLevel = Int(Number($iLevel))
	$iWalls = Int(Number($iWalls))
	If $iWalls < 0 Or $iLevel < 4 Or $iLevel > UBound($g_aiWallsCurrentCount) - 1 Then Return False
	If $g_aiWallsCurrentCount[$iLevel] <> $iWalls Then SetLog("Walls: " & $iWalls & " wall(s) of level " & $iLevel & " left according to the game (count was " & $g_aiWallsCurrentCount[$iLevel] & ")", $COLOR_INFO)
	$g_aiWallsCurrentCount[$iLevel] = $iWalls
	Return True
EndFunc   ;==>WallCountSet


; #FUNCTION# ====================================================================================================================
; Name ..........: Wall Wizard ("Upgrade More") support, CoC 18.600
; Description ...: Upgrades several walls of the same level in one go instead of one at a time.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  Selecting a wall you can pay for shows a fifth button on its bar:
;                      Info | Select ROW | Upgrade More | Upgrade (gold) | Upgrade (elixir)
;                  "Upgrade More" opens the wall wizard, titled "Wall (Level n)x 1", whose bar is
;                      Remove Wall -1 | Add Wall +10 | Add Wall +1 | Upgrade (gold) | Upgrade (elixir)
;                  Each "Add Wall" adds one more wall of the same level to the selection and the price becomes the
;                  total. The game prints a label or a price in salmon red when the action is impossible: "Add Wall"
;                  red means no more walls at that level, a red price means that resource cannot pay the selection.
;                  Gold and elixir never add up, one selection is paid entirely with one of them.
;                  Measured on a live 860x732 screen: buttons are 94 px apart on y 604, the price sits on y 566-584
;                  and the button label on y 612-640. The bar is centred, so the buttons move when their number
;                  changes; they are located from the gold coin and the elixir drop of the price lines.
; ===============================================================================================================================

Global Const $g_iWallBarY = 604, $g_iWallBarPitch = 94

; Reads the wall button bar. True when a bar with an Upgrade button is on screen, and fills:
;   $iGoldX / $iElixirX : x of the gold / elixir Upgrade button (-1 when absent)
;   $bWizard            : True when the wall wizard is open (no blue Info button any more)
;   $bUpgradeMore       : True when the bar carries the "Upgrade More" button (only when a wall is affordable)
Func __WallBarRead(ByRef $iGoldX, ByRef $iElixirX, ByRef $bWizard, ByRef $bUpgradeMore)
	$iGoldX = -1
	$iElixirX = -1
	$bWizard = False
	$bUpgradeMore = False
	_CaptureRegion(190, 560, 800, 645)
	; rightmost gold blob of the price line: the Remove Wall badge is gold too when it is enabled
	Local $iGoldLast = -1, $iGoldSum = 0, $iGoldCnt = 0, $iGoldPrev = -99
	Local $iElixSum = 0, $iElixCnt = 0
	For $x = 190 To 790
		Local $iColGold = 0, $iColElix = 0
		For $y = 565 To 600
			Local $sCol = _GetPixelColor($x - 190, $y - 560, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 210 And $iG > 170 And $iG < 235 And $iB < 90 Then $iColGold += 1
			If $iR > 150 And $iR < 230 And $iG < 110 And $iB > 150 Then $iColElix += 1
		Next
		If $iColGold > 0 Then
			If $x - $iGoldPrev > 6 Then ; a new blob starts, drop the previous one and keep the rightmost
				$iGoldSum = 0
				$iGoldCnt = 0
			EndIf
			$iGoldSum += $x * $iColGold
			$iGoldCnt += $iColGold
			$iGoldPrev = $x
			If $iGoldCnt >= 15 Then $iGoldLast = Int($iGoldSum / $iGoldCnt)
		EndIf
		If $iColElix > 0 Then
			$iElixSum += $x * $iColElix
			$iElixCnt += $iColElix
		EndIf
	Next
	If $iElixCnt >= 15 Then $iElixirX = Int($iElixSum / $iElixCnt) - 32
	If $iGoldLast > 0 Then $iGoldX = $iGoldLast - 33
	If $iGoldX < 0 And $iElixirX > 0 Then $iGoldX = $iElixirX - $g_iWallBarPitch ; gold button is always left of the elixir one
	If $iGoldX < 0 Then Return False

	Local $iBlue = 0 ; blue "i" of the Info button, gone as soon as the wizard is open
	For $y = 575 To 625 Step 2
		For $x = 190 To 300 Step 2
			Local $sCol = _GetPixelColor($x - 190, $y - 560, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iB > 180 And $iB > $iR + 40 And $iG > 90 And $iG < 210 Then $iBlue += 1
		Next
	Next
	$bWizard = ($iBlue < 50)
	; the bar is centred: one more button pushes the Upgrade buttons 47 px to the right
	If Not $bWizard Then $bUpgradeMore = ($iGoldX > (($iElixirX > 0) ? 500 : 453))
	SetDebugLog("WallBar: gold x " & $iGoldX & ", elixir x " & $iElixirX & ", wizard " & ($bWizard ? "yes" : "no") & ", Upgrade More " & ($bUpgradeMore ? "yes" : "no") & " (blue " & $iBlue & ")", $COLOR_DEBUG)
	Return True
EndFunc   ;==>__WallBarRead

; True when the text of the button at $iBtnX is printed in the salmon red the game uses for an impossible
; action. $bPrice reads the price line above the button, otherwise the label under it.
Func __WallTextIsRed($iBtnX, $bPrice = True)
	Local $iTop = ($bPrice ? 566 : 612), $iBottom = ($bPrice ? 584 : 640)
	_CaptureRegion($iBtnX - 40, $iTop, $iBtnX + 40, $iBottom)
	Local $iRed = 0
	For $y = 0 To $iBottom - $iTop
		For $x = 0 To 80
			Local $sCol = _GetPixelColor($x, $y, False)
			If StringLen($sCol) <> 6 Then ContinueLoop
			Local $iR = Dec(StringMid($sCol, 1, 2)), $iG = Dec(StringMid($sCol, 3, 2)), $iB = Dec(StringMid($sCol, 5, 2))
			If $iR > 190 And $iG > 80 And $iG < 180 And $iB > 80 And $iB < 180 And $iR > $iG + 60 And Abs($iG - $iB) < 30 Then $iRed += 1
		Next
	Next
	Return ($iRed >= 80)
EndFunc   ;==>__WallTextIsRed

; Total price printed above the Upgrade button at $iBtnX, 0 when it cannot be read.
Func __WallWizardTotal($iBtnX)
	Return Number(StringRegExpReplace(getCostsUpgrade($iBtnX - 45, 565), "[^0-9]", ""))
EndFunc   ;==>__WallWizardTotal

; Upgrades as many walls of the level currently selected as the resources allow, through the game's
; "Upgrade More" wizard. $bUseGold picks the resource. In the builder base ($bBuilderBase) the price of
; one wall is read from the bar and the builder base loot is used, there is no reserve to keep.
; Returns the number of walls upgraded, 0 when the wizard was not used and the selection was left
; untouched (the caller carries on with its single wall), -1 when the wizard was opened but nothing was
; upgraded and the selection had to be dropped (the caller must select again).
Func UpgradeWallMore($bUseGold, $iWallCost = $g_iWallCost, $bBuilderBase = False)
	If Not $g_bRunState Then Return 0

	Local $iGoldX, $iElixirX, $bWizard, $bUpgradeMore
	If Not __WallBarRead($iGoldX, $iElixirX, $bWizard, $bUpgradeMore) Then Return 0
	If $bWizard Then Return 0 ; a wizard left open from an earlier step, the caller selects again
	If Not $bUpgradeMore Then
		SetDebugLog("WallMore: no Upgrade More button on this wall", $COLOR_DEBUG)
		Return 0
	EndIf
	Local $iBtnX = ($bUseGold ? $iGoldX : $iElixirX)
	If $iBtnX < 0 Then Return 0

	Local $iHave, $iKeep
	If $bBuilderBase Then
		$iWallCost = __WallWizardTotal($iBtnX) ; the bar of the selected wall shows the price of one
		$iHave = ($bUseGold ? Number($g_aiCurrentLootBB[$eLootGoldBB]) : Number($g_aiCurrentLootBB[$eLootElixirBB]))
		$iKeep = 0
	Else
		$iHave = ($bUseGold ? Number($g_aiCurrentLoot[$eLootGold]) : Number($g_aiCurrentLoot[$eLootElixir]))
		$iKeep = ($bUseGold ? Number($g_iUpgradeWallMinGold) : Number($g_iUpgradeWallMinElixir))
	EndIf
	If $iWallCost < 1 Then Return 0
	Local $iBudget = $iHave - $iKeep
	Local $iWant = Int($iBudget / $iWallCost) ; as many walls as the resources allow once the reserve is kept
	If $iWant < 2 Then Return 0 ; nothing to gain over the one wall at a time path

	Click($iGoldX - $g_iWallBarPitch, $g_iWallBarY, 1, 120, "#0340") ; Upgrade More
	If _Sleep(1200) Then Return 0
	If Not __WallBarRead($iGoldX, $iElixirX, $bWizard, $bUpgradeMore) Then Return -1
	If Not $bWizard Then
		SetDebugLog("WallMore: the wizard did not open", $COLOR_DEBUG)
		ClearScreen()
		Return -1
	EndIf

	; the wizard opens on one wall; "Add Wall +10" while ten more fit in the budget, then "Add Wall +1".
	; The game paints the label red when there is no wall of that level left to add.
	Local $iBtnAddOne = $iGoldX - $g_iWallBarPitch
	Local $iBtnAddTen = $iGoldX - 2 * $g_iWallBarPitch
	Local $iBtnRemove = $iGoldX - 3 * $g_iWallBarPitch
	Local $iLevel = $g_iCmbUpgradeWallsLevel + 4 ; the selected wall was checked to be of the working level
	Local $bAllIn = False ; every wall of the level is in the selection
	Local $iAdded = 1
	While $iAdded + 10 <= $iWant
		If __WallTextIsRed($iBtnAddTen, False) Then ExitLoop
		Click($iBtnAddTen, $g_iWallBarY, 1, 120, "#0345")
		If _Sleep(500) Then Return -1
		$iAdded += 10
	WEnd
	While $iAdded < $iWant
		If __WallTextIsRed($iBtnAddOne, False) Then
			SetDebugLog("WallMore: no more walls of that level to add (" & $iAdded & " selected)", $COLOR_DEBUG)
			$bAllIn = True
			ExitLoop
		EndIf
		Click($iBtnAddOne, $g_iWallBarY, 1, 120, "#0341")
		If _Sleep(500) Then Return -1
		$iAdded += 1
	WEnd

	$iBtnX = ($bUseGold ? $iGoldX : $iElixirX)
	If $iBtnX < 0 Then
		ClearScreen()
		Return -1
	EndIf
	; the game paints the price red when that resource cannot pay the selection: give walls back until it can
	Local $iSafety = 0
	While __WallTextIsRed($iBtnX, True) And $iAdded > 1 And $iSafety < 20
		Click($iBtnRemove, $g_iWallBarY, 1, 120, "#0342")
		If _Sleep(500) Then Return -1
		$iAdded -= 1
		$iSafety += 1
	WEnd
	If __WallTextIsRed($iBtnX, True) Then
		SetLog("Wall upgrade: not enough " & ($bUseGold ? "gold" : "elixir") & " for a batch, one wall at a time", $COLOR_INFO)
		ClearScreen()
		Return -1
	EndIf

	If $iSafety > 0 Then $bAllIn = False ; walls were given back, the selection no longer holds the whole level

	; the total the game prints is the truth on how many walls are selected ("+10" may add fewer when the
	; level runs out); it also has to leave the reserve alone
	Local $iTotal = __WallWizardTotal($iBtnX)
	; with the whole level selected, that total is also the number of walls of the level: the count of the profile is
	; set from it before the upgrade, which then takes its walls out of it (WallsStatsMAJ), whichever path upgrades them
	Local $bCounted = False
	If $bAllIn And Not $bBuilderBase And $iTotal > 0 And Mod($iTotal, $iWallCost) = 0 Then $bCounted = WallCountSet($iLevel, Int($iTotal / $iWallCost))
	$iSafety = 0
	While $iTotal > $iBudget And $iTotal > $iWallCost And $iSafety < 20
		Click($iBtnRemove, $g_iWallBarY, 1, 120, "#0342")
		If _Sleep(500) Then Return -1
		$iSafety += 1
		$iTotal = __WallWizardTotal($iBtnX)
	WEnd
	If $iTotal <= 0 Or Mod($iTotal, $iWallCost) <> 0 Then
		SetLog("Wall upgrade: the batch price (" & $iTotal & ") is not a multiple of " & $iWallCost & ", one wall at a time", $COLOR_INFO)
		ClearScreen()
		Return -1
	EndIf
	$iAdded = Int($iTotal / $iWallCost)
	If $iTotal > $iBudget Or $iAdded < 2 Then ; only one wall left in the selection, the normal path does it just as well
		ClearScreen()
		Return -1
	EndIf

	SetLog("Upgrading " & $iAdded & ($bBuilderBase ? " builder base" : "") & " walls at once for " & _NumberFormat($iTotal) & " " & ($bUseGold ? "gold" : "elixir"), $COLOR_SUCCESS)
	Click($iBtnX, $g_iWallBarY, 1, 120, "#0343")
	If _Sleep($DELAYUPGRADEWALLGOLD2) Then Return -1

	; several walls at once ask for a confirmation ("Upgrade Walls ... Okay")
	Local $aOkay = FindGreenOkayButton(True)
	If IsArray($aOkay) Then
		ClickP($aOkay, 1, 120, "#0344")
		If _Sleep($DELAYUPGRADEWALLGOLD3) Then Return -1
	EndIf
	If isGemOpen(True) Then
		SetLog("Wall upgrade: the game asked for gems, batch cancelled", $COLOR_ERROR)
		ClearScreen()
		Return -1
	EndIf
	ClearScreen()

	If $bBuilderBase Then Return $iAdded

	If $bUseGold Then
		$g_iNbrOfWallsUppedGold += $iAdded
		$g_iCostGoldWall += $iTotal
		PushMsg("UpgradeWithGold")
	Else
		$g_iNbrOfWallsUppedElixir += $iAdded
		$g_iCostElixirWall += $iTotal
		PushMsg("UpgradeWithElixir")
	EndIf
	$g_iNbrOfWallsUpped += $iAdded
	UpdateStats() ; moves the walls to the next level in the counts (WallsStatsMAJ)
	; the game has just shown that this batch was the whole level: the next level is searched straight away, instead
	; of after a search and a builder menu scan that could only come back empty
	If $bCounted And $g_aiWallsCurrentCount[$iLevel] = 0 And $g_iCmbUpgradeWallsLevel + 4 = $iLevel Then
		If __WallNextLevel() Then SetLog("All walls of level " & $iLevel & " are upgraded, moving on to level " & $iLevel + 1, $COLOR_SUCCESS)
	EndIf
	Return $iAdded
EndFunc   ;==>UpgradeWallMore

; One upgrade step: a batch through the wizard when the option allows it, otherwise the single wall that
; is already selected. False only when nothing could be upgraded at all.
Func __UpgradeWallStep($bUseGold, $iWallCost = $g_iWallCost)
	Local $iWalls = UpgradeWallMore($bUseGold, $iWallCost)
	If $iWalls > 0 Then Return True
	If $iWalls < 0 Then ; the wizard was opened and closed again, a wall has to be selected once more
		If _Sleep($DELAYRESPOND) Then Return False
		If Not imglocCheckWall() Then Return False
	EndIf
	Return ($bUseGold ? UpgradeWallGold($iWallCost) : UpgradeWallElixir($iWallCost))
EndFunc   ;==>__UpgradeWallStep

; #FUNCTION# ====================================================================================================================
; Name ..........: BuilderMenuSelectWall
; Description ...: Lets the game select a wall through the builder menu when the image search sees none.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  The wall templates are straight runs; the last pieces of a level are corners, junctions and
;                  bits hidden by buildings, which the search never returns. The builder menu (the builder
;                  counter at the top) lists every upgrade left, walls included, as a "Wall xN" line with the
;                  price of one and the resource icon (white price = affordable, red = not). Tapping the line
;                  makes the game select a wall of that level and open its bar, from where the usual code works.
;                  Measured on a live 860x732 screen: the panel spans x 305-578, y 70-410, one line every
;                  28-29 px, the name starts on x 316 and the resource icon sits around x 487 on the line centre.
; ===============================================================================================================================

; the word "Wall" as the menu prints it: brightness of each of the 30 columns x 314-343, summed over the
; 13 rows around the line centre (lum 100 -> 0, 255 -> 1). Column sums do not move when the list stops at
; a fraction of a pixel and the text is blurred over two rows, a pixel-by-pixel mask did.
Global Const $g_afWallMenuProfile[30] = [0.00, 0.15, 3.42, 5.24, 3.37, 3.18, 3.66, 4.28, 3.53, 3.45, 4.12, 5.39, 1.75, 0.76, 4.01, _
		3.11, 2.46, 3.83, 5.45, 0.16, 0.07, 7.71, 0.25, 0.04, 7.70, 0.32, 0.00, 0.00, 0.00, 0.00]

; Centre y of the "Wall" line on the page of the builder menu on screen, -1 when there is none. The whole
; name column is read once, then every possible line centre is compared to the profile above (the Wall
; line scores about 1, the closest other name about 43, so anything under 15 is it).
Func __BuilderMenuFindWallLine()
	Local $iTop = 80, $iBottom = 400, $iH = $iBottom - $iTop
	_CaptureRegion(314, $iTop, 344, $iBottom)
	Local $afCum[30][$iH + 1] ; cumulative brightness down each column
	For $x = 0 To 29
		$afCum[$x][0] = 0
		For $y = 0 To $iH - 1
			Local $sCol = _GetPixelColor($x, $y, False)
			Local $fB = 0
			If StringLen($sCol) = 6 Then
				$fB = ((Dec(StringMid($sCol, 1, 2)) + Dec(StringMid($sCol, 3, 2)) + Dec(StringMid($sCol, 5, 2))) / 3 - 100) / 155
				If $fB < 0 Then $fB = 0
				If $fB > 1 Then $fB = 1
			EndIf
			$afCum[$x][$y + 1] = $afCum[$x][$y] + $fB
		Next
	Next
	Local $fBest = 999, $iBestY = -1
	For $iYc = $iTop + 6 To $iBottom - 7
		Local $fD = 0
		For $x = 0 To 29
			$fD += Abs(($afCum[$x][$iYc + 6 - $iTop + 1] - $afCum[$x][$iYc - 6 - $iTop]) - $g_afWallMenuProfile[$x])
			If $fD > 15 Then ExitLoop
		Next
		If $fD < $fBest Then
			$fBest = $fD
			$iBestY = $iYc
		EndIf
	Next
	SetDebugLog("Builder menu: best Wall profile match " & Round($fBest, 1) & " at y " & $iBestY, $COLOR_DEBUG)
	If $fBest < 15 Then Return $iBestY
	Return -1
EndFunc   ;==>__BuilderMenuFindWallLine

; True when a wall of level $iLevel is selected on screen with its bar open. Scrolls the menu until its
; Wall line shows up; without one there is no wall left to upgrade at any level.
Func BuilderMenuSelectWall($iLevel)
	$g_bWallMenuNoWall = False
	If Not $g_bRunState Then Return False
	If Not ClickMainBuilder() Then Return False ; opens the menu (toggles it back open when it was already there)
	If _Sleep(500) Then Return False

	Local $sLastPage = "", $bListEnd = False
	For $iPage = 1 To 20
		If Not $g_bRunState Then Return False
		; the resource icons give the lines of the page: their layout tells when the list stops moving
		Local $aRows = QuickMIS("CNX", $g_sImgResourceIcon, 410, 75, 565, 400)
		Local $sPage = ""
		If IsArray($aRows) Then
			_ArraySort($aRows, 0, 0, 0, 2) ; by y
			For $i = 0 To UBound($aRows) - 1
				$sPage &= $aRows[$i][0] & Number($aRows[$i][2]) & ";"
			Next
		EndIf
		Local $iWallY = __BuilderMenuFindWallLine()
		SetDebugLog("Builder menu page " & $iPage & ": " & ($sPage = "" ? "no line" : $sPage) & " wall line y " & $iWallY, $COLOR_DEBUG)

		If $iWallY > 0 Then
			Local $sRes = "", $iRowX = 487
			If IsArray($aRows) Then
				For $i = 0 To UBound($aRows) - 1
					If Abs(Number($aRows[$i][2]) - $iWallY) <= 10 Then
						$sRes = ($aRows[$i][0] = "Elix" ? "elixir" : ($aRows[$i][0] = "Gold" ? "gold" : $aRows[$i][0]))
						$iRowX = Number($aRows[$i][1])
					EndIf
				Next
			EndIf
			Local $bAffordable = QuickMIS("BC1", $g_sImgAUpgradeZero, $iRowX, $iWallY - 8, $iRowX + 100, $iWallY + 7)
			SetLog("Builder menu: Wall line found" & ($sRes <> "" ? " (" & $sRes & ")" : "") & ($bAffordable ? "" : ", price in red") & ", letting the game pick one", $COLOR_INFO)
			Click(400, $iWallY)
			If _Sleep(1500) Then Return False
			Local $aInfo = BuildingInfo(242, 475 + $g_iBottomOffsetY)
			If $aInfo[0] >= 1 And StringInStr($aInfo[1], "Wall") Then
				; the game picks the wall itself, so it can be of any level: the bot follows it instead of
				; insisting on the level of the combo, otherwise walls are never upgraded on other levels
				Local $iFound = Number($aInfo[2])
				If $iFound <> $iLevel Then
					If Not WallSetWorkingLevel($iFound) Then
						SetLog("The builder menu offers level " & $aInfo[2] & " walls, which the bot cannot handle", $COLOR_ERROR)
						ClearScreen()
						Return False
					EndIf
					SetLog("Builder menu: a level " & $iFound & " wall was offered (searching level " & $iLevel & "), switching to level " & $iFound, $COLOR_INFO)
					; a wall costs more at every level and the menu offers the cheapest one: with the search finding none
					; either, no wall of the level searched is left (a count typed long ago is corrected)
					If $iFound > $iLevel Then WallCountSet($iLevel, 0)
				EndIf
				SetLog("Wall level " & $iFound & " selected from the builder menu", $COLOR_SUCCESS)
				; the menu stays open over the village: the builder counter closes it and the wall stays selected (measured live)
				Click(435, 30)
				If _Sleep(800) Then Return False
				If IsBuilderMenuOpen() Then
					Click(435, 30)
					If _Sleep(800) Then Return False
				EndIf
				Return True
			Else
				SetDebugLog("Builder menu: the Wall line did not select a wall (" & $aInfo[1] & ")", $COLOR_DEBUG)
			EndIf
			ClearScreen()
			Return False
		EndIf

		If $sPage <> "" And $sPage = $sLastPage Then ; the list did not move, its end is reached
			$bListEnd = True
			ExitLoop
		EndIf
		$sLastPage = $sPage

		; the Wall line is further down
		ClickDrag(440, 380, 440, 120, 400)
		If _Sleep(1200) Then Return False
		If Not IsBuilderMenuOpen() Then ExitLoop
	Next

	; only a list read to its end proves that no wall is left; a menu that closed or 20 pages without an end prove nothing
	$g_bWallMenuNoWall = $bListEnd
	SetLog("Builder menu: no Wall line" & ($bListEnd ? ", no wall left to upgrade" : " (the list could not be read to its end)"), $COLOR_INFO)
	SaveFailureImage("BuilderMenuNoWall")
	ClearScreen()
	Return False
EndFunc   ;==>BuilderMenuSelectWall

; Moves the wall level the bot works on to $iLevel: the combo of Village > Upgrade, the level used by the
; searches and $g_iWallCost all follow. False when the level is outside the levels the bot knows (4 .. 18).
; Used when the game itself picks a wall (builder menu), which can be of any level.
Func WallSetWorkingLevel($iLevel)
	Local $iIndex = Int($iLevel) - 4
	If $iIndex < 0 Or $iIndex > UBound($g_aiWallCost) - 1 Then Return False
	If $iIndex = $g_iCmbUpgradeWallsLevel Then Return True
	$g_iCmbUpgradeWallsLevel = $iIndex
	$g_iWallCost = $g_aiWallCost[$iIndex]
	SaveConfig()
	Return True
EndFunc   ;==>WallSetWorkingLevel

; The cost of one wall of the level the bot works on, discount included. Read again after every
; imglocCheckWall(), the level can have changed (WallSetWorkingLevel).
Func WallCostNow()
	Return Int($g_iWallCost - ($g_iWallCost * Number($g_iBuilderBoostDiscount) / 100))
EndFunc   ;==>WallCostNow
