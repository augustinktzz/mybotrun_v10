; #FUNCTION# ====================================================================================================================
; Name ..........: SuggestedUpgrades()
; Description ...: Goes to Builders Base and Upgrades buildings with 'suggested upgrades window'.
; Syntax ........: SuggestedUpgrades()
; Parameters ....:
; Return values .: None
; Author ........: ProMac (05-2017)
; Modified ......: Moebius14 (12-2023)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func chkActivateBBSuggestedUpgrades()
	; CheckBox Enable Suggested Upgrades [Update values][Update GUI State]
	If GUICtrlRead($g_hChkBBSuggestedUpgrades) = $GUI_CHECKED Then
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreGold, $GUI_ENABLE)
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreElixir, $GUI_ENABLE)
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreHall, $GUI_ENABLE)
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreWall, $GUI_ENABLE)
		GUICtrlSetState($g_hChkPlacingNewBuildings, $GUI_ENABLE)
		GUICtrlSetState($g_hChkBBSaveWallBuilder, $GUI_ENABLE)
		chkActivateBBSuggestedUpgradesGold()
		chkActivateBBSuggestedUpgradesElixir()
	Else
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreGold, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreElixir, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreHall, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreWall, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkPlacingNewBuildings, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkBBSaveWallBuilder, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
	EndIf
EndFunc   ;==>chkActivateBBSuggestedUpgrades

Func chkActivateBBSuggestedUpgradesGold()
	If GUICtrlRead($g_hChkBBSuggestedUpgradesIgnoreGold) = $GUI_CHECKED Then
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreElixir, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreHall, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
	Else
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreElixir, $GUI_ENABLE)
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreHall, $GUI_ENABLE)
	EndIf
EndFunc   ;==>chkActivateBBSuggestedUpgradesGold

Func chkActivateBBSuggestedUpgradesElixir()
	If GUICtrlRead($g_hChkBBSuggestedUpgradesIgnoreElixir) = $GUI_CHECKED Then
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreGold, BitOR($GUI_UNCHECKED, $GUI_DISABLE))
	Else
		GUICtrlSetState($g_hChkBBSuggestedUpgradesIgnoreGold, $GUI_ENABLE)
	EndIf
EndFunc   ;==>chkActivateBBSuggestedUpgradesElixir

Func chkPlacingNewBuildings()
	$g_iChkPlacingNewBuildings = (GUICtrlRead($g_hChkPlacingNewBuildings) = $GUI_CHECKED) ? 1 : 0
EndFunc   ;==>chkPlacingNewBuildings

; MAIN CODE
; --------------------------------------------------------------------------------------------------------------------
; Reading the suggestion lines of the builder base
; The window lists the suggested upgrades, one row each: the name on the left, the price with its resource icon on the
; right. Only the first rows are visible and the wall rows come last, so with the last builder kept for walls the bot
; used to open every building of the first rows, find no wall, and wait for the next cycle - 167 times in a day,
; without a single wall upgraded. The name is now read before anything is clicked, and the list is scrolled.
; The name is read with the font of the builder menu (lib\listSymbols_coc-buildermenu-name.xml). When nothing can be
; read the bot falls back to what it did before, opening the row to see what it is.
; --------------------------------------------------------------------------------------------------------------------
; Measured on a live 860 x 732 builder base: the rows are 28.6 px apart, the name starts at x 381 and never runs
; past x 492, the price and its resource icon sit at x 535-630 on the very same line as the name.
Global Const $g_iBBSuggestTop = 102, $g_iBBSuggestBottom = 405 ; the band the resource icons are searched in
Global Const $g_iBBSuggestNameX = 376, $g_iBBSuggestNameW = 150 ; the name, level with its icon
Global Const $g_iBBSuggestMaxScroll = 3
Global $g_sBBSuggestLastName = ""

; 1 = that row is a wall, 0 = it is not, -1 = the name could not be read
Func __BBSuggestLineIsWall($iIconY)
	Local $iY = $iIconY - 10
	If $iY < $g_iBBSuggestTop Then $iY = $g_iBBSuggestTop
	Local $sName = StringStripWS(getOcrAndCapture("coc-buildermenu-name", $g_iBBSuggestNameX, $iY, $g_iBBSuggestNameW, 20, False), 3)
	$g_sBBSuggestLastName = $sName
	If StringLen($sName) < 3 Then Return -1
	If StringInStr($sName, "Suggest") Or StringInStr($sName, "upgrade") Then Return -1 ; the header, not a row
	Return (StringInStr($sName, "Wall") > 0) ? 1 : 0
EndFunc   ;==>__BBSuggestLineIsWall

; True when one of the rows on screen is a wall. False only when the names could be read and none of them is one,
; so a font or a coordinate that does not work never makes the bot scroll past what it is looking for.
Func __BBSuggestHasWall(ByRef $aLine)
	If Not IsArray($aLine) Or UBound($aLine) = 0 Then Return False
	Local $bReadSomething = False
	For $i = 0 To UBound($aLine) - 1
		Local $iIsWall = __BBSuggestLineIsWall($aLine[$i][2])
		If $iIsWall = 1 Then Return True
		If $iIsWall = 0 Then $bReadSomething = True
	Next
	Return Not $bReadSomething ; nothing readable: behave as if a wall could be there
EndFunc   ;==>__BBSuggestHasWall

; Drags the list up by about one screen. True when it really moved, which is told by the name of the first row.
Func __BBSuggestScroll()
	Local $sBefore = $g_sBBSuggestLastName
	Local $aFirst = QuickMIS("CNX", $g_sImgAutoUpgradeBB, 490, $g_iBBSuggestTop, 630, $g_iBBSuggestTop + 60)
	If IsArray($aFirst) And UBound($aFirst) > 0 Then
		__BBSuggestLineIsWall($aFirst[0][2])
		$sBefore = $g_sBBSuggestLastName
	EndIf
	ClickDrag(560, $g_iBBSuggestBottom - 40, 560, $g_iBBSuggestTop + 40)
	If _Sleep(1200) Then Return False
	$aFirst = QuickMIS("CNX", $g_sImgAutoUpgradeBB, 490, $g_iBBSuggestTop, 630, $g_iBBSuggestTop + 60)
	If Not IsArray($aFirst) Or UBound($aFirst) = 0 Then Return False
	__BBSuggestLineIsWall($aFirst[0][2])
	Return ($g_sBBSuggestLastName <> $sBefore)
EndFunc   ;==>__BBSuggestScroll

Func MainSuggestedUpgradeCode($bDebugImage = $g_bDebugImageSave)

	; If is not selected return
	If Not $g_iChkBBSuggestedUpgrades Then Return
	Local $bDebug = $g_bDebugSetLog
	Local $bScreencap = True
	Local $y = $g_iBBSuggestTop, $x = 490, $x1 = 630
	Local $iScrolls = 0

	BuilderBaseReport(True, True)

	; Master Builder is not available return
	If $g_iFreeBuilderCountBB = 0 Then
		SetLog("No Master Builder available for suggested upgrades !", $COLOR_INFO)
		Return
	EndIf

	; with the last builder kept for walls only the wall suggestions can be taken: said once when it
	; happens, the lines are then tried quietly (a suggestion has to be opened to know whether it is a wall)
	Local $bWallsOnly = False

	; Check if you are on Builder Base
	If isOnBuilderBase(True) Then

		SetLog("Starting Auto Upgrades", $COLOR_INFO)

		While 1

			If Not $bWallsOnly And Not BBBuilderFreeForBuilding(True) Then
				$bWallsOnly = True
				SetLog("Only wall suggestions will be taken", $COLOR_INFO)
			EndIf

			; Will Open the Suggested Window and check if is OK
			If ClickOnBuilder() Then
				SetDebugLog("Upgrade Window Opened successfully", $COLOR_INFO)
				; Proceeds with icon detection
				Local $aLine = QuickMIS("CNX", $g_sImgAutoUpgradeBB, $x, $y, $x1, $g_iBBSuggestBottom + $g_iMidOffsetY)
				; walls sit at the end of the list: scroll down before giving up, so the builder kept for them
				; is actually used instead of waiting for a wall to show up in the first rows
				If $bWallsOnly And Not __BBSuggestHasWall($aLine) And $iScrolls < $g_iBBSuggestMaxScroll Then
					$iScrolls += 1
					If __BBSuggestScroll() Then
						SetDebugLog("No wall in sight, scrolled the suggestions (" & $iScrolls & "/" & $g_iBBSuggestMaxScroll & ")", $COLOR_DEBUG)
						$y = $g_iBBSuggestTop
						ContinueLoop
					EndIf
					$iScrolls = $g_iBBSuggestMaxScroll ; the list does not move any more, it is all there
				EndIf
				; Proceeds with icon detection
				If IsArray($aLine) And UBound($aLine) > 0 Then
					_ArraySort($aLine, 0, 0, 0, 2) ;sort by Y coord
					For $i = 0 To UBound($aLine) - 1
						Local $g_WallDetected = False
						Local $aResult = GetIconPosition($x, $aLine[$i][2] - 10, $x1, $aLine[$i][2] + 10, $g_sImgAutoUpgradeBB, $bScreencap, $bDebug, $bDebugImage)
						If IsArray($aResult) And UBound($aResult) > 0 Then
							; with the builder kept for walls, the name of the row decides: opening a building only to
							; close it again cost a click and a reopened menu for every suggestion of every cycle
							If $bWallsOnly And ($aResult[2] = "Gold" Or $aResult[2] = "Elixir") And __BBSuggestLineIsWall($aLine[$i][2]) = 0 Then
								SetDebugLog("[" & $i + 1 & "] " & $g_sBBSuggestLastName & ": not a wall, not opened", $COLOR_DEBUG)
								If $i = UBound($aLine) - 1 Then ExitLoop 2
								ContinueLoop
							EndIf
							Switch $aResult[2]
								Case "Gold"
									Click($aResult[0], $aResult[1], 1)
									If _Sleep(2000) Then Return
									If IsWallDetected() Then $g_WallDetected = True
									If Not $g_WallDetected And $bWallsOnly Then ; not a wall, the builder stays for walls, next suggestion
										SetDebugLog("[" & $i + 1 & "] " & "not a wall, skipped", $COLOR_DEBUG)
										If $i = UBound($aLine) - 1 Then ExitLoop 2
										$y = $aLine[$i][2] + 15
										ExitLoop
									EndIf
									If GetUpgradeButton($aResult[2], $bDebug, $bDebugImage, $g_WallDetected) Then
										If $g_WallDetected Then
											ExitLoop
										Else
											$g_iFreeBuilderCountBB -= 1
											If $g_iFreeBuilderCountBB = 0 Then
												ExitLoop 2
											Else
												ExitLoop
											EndIf
										EndIf
									Else
										If $i = UBound($aLine) - 1 Then ExitLoop 2
										$y = $aLine[$i][2] + 15
										ExitLoop
									EndIf
								Case "Elixir"
									Click($aResult[0], $aResult[1], 1)
									If _Sleep(2000) Then Return
									If IsWallDetected() Then $g_WallDetected = True
									If Not $g_WallDetected And $bWallsOnly Then ; not a wall, the builder stays for walls, next suggestion
										SetDebugLog("[" & $i + 1 & "] " & "not a wall, skipped", $COLOR_DEBUG)
										If $i = UBound($aLine) - 1 Then ExitLoop 2
										$y = $aLine[$i][2] + 15
										ExitLoop
									EndIf
									If GetUpgradeButton($aResult[2], $bDebug, $bDebugImage, $g_WallDetected) Then
										If $g_WallDetected Then
											ExitLoop
										Else
											$g_iFreeBuilderCountBB -= 1
											If $g_iFreeBuilderCountBB = 0 Then
												ExitLoop 2
											Else
												ExitLoop
											EndIf
										EndIf
									Else
										If $i = UBound($aLine) - 1 Then ExitLoop 2
										$y = $aLine[$i][2] + 15
										ExitLoop
									EndIf
								Case "New"
									If $g_iChkPlacingNewBuildings = 1 Then
										If $bWallsOnly Then ; the builder stays for walls, next suggestion
											If $i = UBound($aLine) - 1 Then ExitLoop 2
											$y = $aLine[$i][2] + 15
											ExitLoop
										EndIf
										SetLog("[" & $i + 1 & "]" & " New Building detected, Placing it...", $COLOR_INFO)
										If NewBuildings($aResult, $bDebugImage) Then
											$g_iFreeBuilderCountBB -= 1
											If $g_iFreeBuilderCountBB = 0 Then
												ExitLoop 2
											Else
												ExitLoop
											EndIf
										Else
											If $i = UBound($aLine) - 1 Then ExitLoop 2
											$y = $aLine[$i][2] + 15
											ExitLoop
										EndIf
									Else
										SetLog("[" & $i + 1 & "]" & " New Building detected, but not enabled...", $COLOR_INFO)
									EndIf
								Case "NoResources"
									SetLog("[" & $i + 1 & "]" & " Not enough Resource, continuing...", $COLOR_INFO)
								Case Else
									SetLog("[" & $i + 1 & "]" & " Unsupported icon, continuing...", $COLOR_INFO)
							EndSwitch
						EndIf
						If $i = UBound($aLine) - 1 Then ExitLoop 2
					Next
				Else
					ExitLoop
				EndIf
			Else
				ExitLoop
			EndIf

			If _Sleep(1000) Then Return
			If Not $g_bRunState Then Return

		WEnd

		SetLog("Exiting Auto Upgrade...", $COLOR_INFO)

		If _Sleep(250) Then Return
		Local $asSearchResult = decodeSingleCoord(FindImageInPlace2("MasterBuilderHead", $g_sImgMasterBuilderHead, 445, 0, 500, 54, True))
		If IsArray($asSearchResult) And UBound($asSearchResult) = 2 Then
			If IsArray(_PixelSearch($asSearchResult[0] - 1, $asSearchResult[1] + 53, $asSearchResult[0] + 1, $asSearchResult[1] + 55, Hex(0xFFFFFF, 6), 15, True)) Then ClickP($asSearchResult)
		EndIf
		If _Sleep(1000) Then Return
		ClearScreen("Right", False)
		If _Sleep(500) Then Return
		If Not $g_bRunState Then Return
	EndIf

	If QuickMIS("BC1", $sImgTunnel, 0, 190 + $g_iMidOffsetY, $g_iGAME_WIDTH, $g_iGAME_HEIGHT) Then
		SetLog("Back To Main Builder Base", $COLOR_INFO)
		If $g_iQuickMISName = "TunnelOO" Then
			Click($g_iQuickMISX - Random(25, 70, 1), $g_iQuickMISY + Random(0, 30, 1))
		Else
			Click($g_iQuickMISX - Random(30, 50, 1), $g_iQuickMISY + Random(10, 40, 1))
		EndIf
	EndIf

	If _Sleep(2000) Then Return

	ZoomOut()
EndFunc   ;==>MainSuggestedUpgradeCode

; This function will Open the Suggested Window and check if is OK
Func ClickOnBuilder()

	If _Sleep(250) Then Return
	Local $asSearchResult = decodeSingleCoord(FindImageInPlace2("MasterBuilderHead", $g_sImgMasterBuilderHead, 445, 0, 500, 54, True))
	; Debug Stuff
	Local $sDebugText = ""

	If IsArray($asSearchResult) And UBound($asSearchResult) = 2 Then

		If IsArray(_PixelSearch($asSearchResult[0] - 1, $asSearchResult[1] + 53, $asSearchResult[0] + 1, $asSearchResult[1] + 55, Hex(0xFFFFFF, 6), 30, True)) Then Return True

		; Master Builder Check pixel [i] icon
		Local Const $aMasterBuilder[4] = [$asSearchResult[0] - 15, $asSearchResult[1] - 9, 0x7ABDE3, 10]

		; Master Builder is not available return
		If $g_iFreeBuilderCountBB = 0 Then SetLog("No Master Builder available! [" & $g_iFreeBuilderCountBB & "/" & $g_iTotalBuilderCountBB & "]", $COLOR_INFO)

		; Master Builder available
		If $g_iFreeBuilderCountBB > 0 Then
			; Check the Color and click
			If _CheckPixel($aMasterBuilder, True) Then
				; Click on Builder
				Click($aMasterBuilder[0], $aMasterBuilder[1], 1)
				If _Sleep(2000) Then Return
				; Let's verify if the Suggested Window open
				If IsArray(_PixelSearch($asSearchResult[0] - 1, $asSearchResult[1] + 53, $asSearchResult[0] + 1, $asSearchResult[1] + 55, Hex(0xFFFFFF, 6), 30, True)) Then
					Return True
				Else
					$sDebugText = "Window didn't opened"
				EndIf
			Else
				$sDebugText = "BB Pixel problem"
			EndIf
		EndIf
	Else
		$sDebugText = "Cannot find Master Builder Head"
		If $g_bDebugImageSave Then SaveDebugImage("MasterBuilderHead")
	EndIf

	If $sDebugText <> "" Then SetLog("Problem on Suggested Upg Window: [" & $sDebugText & "]", $COLOR_ERROR)
	Return False
EndFunc   ;==>ClickOnBuilder

Func GetIconPosition($x, $y, $x1, $y1, $directory, $Screencap = True, $Debug = False, $bDebugImage = $g_bDebugImageSave)
	; [0] = x position , [1] y postion , [2] Gold, Elixir or New
	Local $aResult[3] = [-1, -1, ""]

	If QuickMIS("BC1", $directory, $x, $y, $x1, $y1, $Screencap, $Debug) Then
		If $bDebugImage Then SaveDebugRectImage("GetIconPosition", $x & "," & $y & "," & $x1 & "," & $y1)
		; Correct positions to Check Green 'New' Building word
		Local $asSearchResult = decodeSingleCoord(FindImageInPlace2("MasterBuilderHead", $g_sImgMasterBuilderHead, 445, 0, 500, 54, True))
		If IsArray($asSearchResult) And UBound($asSearchResult) = 2 Then
			Local $iYoffset = $g_iQuickMISY - 15, $iY1offset = $g_iQuickMISY + 7
			Local $iX = $asSearchResult[0] - 193, $iX1 = $g_iQuickMISX
			; Store the values
			$aResult[0] = $g_iQuickMISX
			$aResult[1] = $g_iQuickMISY
			$aResult[2] = $g_iQuickMISName
			; The pink/salmon color on zeros
			If QuickMIS("BC1", $g_sImgAutoUpgradeNoRes, $aResult[0], $iYoffset, $aResult[0] + 100, $iY1offset, True, $Debug) Then
				; Store new values
				$aResult[2] = "NoResources"
				Return $aResult
			EndIf
			; Proceeds with 'New' detection
			If QuickMIS("BC1", $g_sImgAutoUpgradeNew, $iX, $iYoffset, $iX1, $iY1offset, True, $Debug) Then
				; Store new values
				$aResult[0] = $g_iQuickMISX + 35
				$aResult[1] = $g_iQuickMISY
				$aResult[2] = "New"
			EndIf
		Else
			SetLog("Cannot find Master Builder Head", $COLOR_ERROR)
			If $g_bDebugImageSave Then SaveDebugImage("MasterBuilderHead")
			Return 0
		EndIf
	EndIf

	Return $aResult
EndFunc   ;==>GetIconPosition

Func IsWallDetected()
	Local $aBuildingName = BuildingInfo(242, 475 + $g_iBottomOffsetY)
	If StringInStr($aBuildingName[1], "Wall") And Not $g_iChkBBSuggestedUpgradesIgnoreWall Then Return True
	Return False
EndFunc   ;==>IsWallDetected

Func GetUpgradeButton($sUpgButton = "", $Debug = False, $bDebugImage = $g_bDebugImageSave, $bWallUpgrade = False)
	Local $sIconBarDiamond = GetDiamondFromRect2(140, 500 + $g_iBottomOffsetY, 720, 590 + $g_iBottomOffsetY)
	Local $sUpgradeButtonDiamond = GetDiamondFromRect2(350, 470 + $g_iMidOffsetY, 805, 600 + $g_iMidOffsetY)

	If $sUpgButton = "" Then Return

	If Not $bWallUpgrade Then
		If $sUpgButton = "Gold" Then
			If $g_iChkBBSuggestedUpgradesIgnoreGold Or $g_aiCurrentLootBB[$eLootGoldBB] < 250 Then
				If _Sleep(1000) Then Return
				Return False
			EndIf
		ElseIf $sUpgButton = "Elixir" Then
			If $g_iChkBBSuggestedUpgradesIgnoreElixir Or $g_aiCurrentLootBB[$eLootElixirBB] < 250 Then
				If _Sleep(1000) Then Return
				Return False
			EndIf
		EndIf
	EndIf

	Local $ResType = $sUpgButton
	$sUpgButton = @ScriptDir & "\imgxml\Resources\BuildersBase\AutoUpgrade\ButtonUpg\*"

	If $bDebugImage Then SaveDebugDiamondImage("GetUpgradeButton", $sIconBarDiamond)

	; search icon bar for 'upgrade' icon
	Local $aUpgradeIcon = decodeSingleCoord(findImage("GetUpgradeButon", $g_sImgAutoUpgradeBtnDir & "\*", $sIconBarDiamond, 1, True))
	If IsArray($aUpgradeIcon) And UBound($aUpgradeIcon) = 2 Then
		Local $aBuildingName = BuildingInfo(242, 475 + $g_iBottomOffsetY) ; read building text
		SetDebugLog("BuildingName 0 : " & $aBuildingName[0])
		If $aBuildingName[0] >= 1 Then
			SetLog("Building: " & $aBuildingName[1], $COLOR_INFO)
			; Verify if is Builder Hall and If is to Upgrade
			If StringInStr($aBuildingName[1], "Hall") And $g_iChkBBSuggestedUpgradesIgnoreHall Then
				SetLog("Oops! Builder Hall is not to Upgrade!", $COLOR_ERROR)
				If _Sleep(1000) Then Return
				Return False
			EndIf
			If StringInStr($aBuildingName[1], "Wall") And $g_iChkBBSuggestedUpgradesIgnoreWall Then
				SetLog("Oops! Wall is not to Upgrade!", $COLOR_ERROR)
				If _Sleep(1000) Then Return
				Return False
			EndIf

			;Wall Double Button Case
			Local $bWallUseGold = True ; the elixir button is 94 px to the right of the gold one
			If $bWallUpgrade Then

				Select
					Case $ResType = "Elixir" And $g_iChkBBSuggestedUpgradesIgnoreElixir
						SetLog("Elixir upgrade must be ignored", $COLOR_WARNING)
						If $g_iChkBBSuggestedUpgradesIgnoreGold Then
							SetLog("Gold upgrade must be ignored, looking next...", $COLOR_WARNING)
							If _Sleep(1000) Then Return
							Return False
						Else
							If WaitforPixel($aUpgradeIcon[0], $aUpgradeIcon[1] - 60, $aUpgradeIcon[0] + 30, $aUpgradeIcon[1] - 40, "FF887F", 20, 2) Then
								SetLog("Not enough Gold to upgrade Wall, looking next...", $COLOR_WARNING)
								If _Sleep(1000) Then Return
								Return False
							Else
								If _Sleep($DELAYAUTOUPGRADEBUILDING1) Then Return
							EndIf
						EndIf
					Case $ResType = "Elixir" And Not $g_iChkBBSuggestedUpgradesIgnoreElixir
						If UBound(decodeSingleCoord(FindImageInPlace2("UpgradeButton2", $g_sImgUpgradeBtn2Wall, $aUpgradeIcon[0] + 65, $aUpgradeIcon[1] - 44, _
								$aUpgradeIcon[0] + 140, $aUpgradeIcon[1] - 10, True))) > 1 Then __BBWallUseElixir($aUpgradeIcon, $bWallUseGold)
						SetDebugLog("Resource check passed", $COLOR_DEBUG)
						If _Sleep($DELAYAUTOUPGRADEBUILDING1) Then Return
					Case $ResType = "Gold" And $g_iChkBBSuggestedUpgradesIgnoreGold
						SetLog("Gold upgrade must be ignored", $COLOR_WARNING)
						If $g_iChkBBSuggestedUpgradesIgnoreElixir Then
							SetLog("Elixir upgrade must be ignored, looking next...", $COLOR_WARNING)
							If _Sleep(1000) Then Return
							Return False
						Else
							If UBound(decodeSingleCoord(FindImageInPlace2("UpgradeButton2", $g_sImgUpgradeBtn2Wall, $aUpgradeIcon[0] + 65, $aUpgradeIcon[1] - 44, _
									$aUpgradeIcon[0] + 140, $aUpgradeIcon[1] - 10, True))) > 1 Then
								__BBWallUseElixir($aUpgradeIcon, $bWallUseGold)
								If WaitforPixel($aUpgradeIcon[0], $aUpgradeIcon[1] - 60, $aUpgradeIcon[0] + 30, $aUpgradeIcon[1] - 40, "FF887F", 20, 2) Then
									SetLog("Not enough Elixir to upgrade Wall, looking next...", $COLOR_WARNING)
									If _Sleep(1000) Then Return
									Return False
								Else
									If _Sleep($DELAYAUTOUPGRADEBUILDING1) Then Return
								EndIf
							Else
								SetLog("Elixir button not found, looking next...", $COLOR_WARNING)
								If _Sleep(1000) Then Return
								Return False
							EndIf
						EndIf
					Case $ResType = "Gold" And Not $g_iChkBBSuggestedUpgradesIgnoreGold
						SetDebugLog("Resource check passed", $COLOR_DEBUG)
						If _Sleep($DELAYAUTOUPGRADEBUILDING1) Then Return
					Case Else
						SetDebugLog("Any case above not found ?? Bad programmer !", $COLOR_DEBUG)
				EndSelect

			EndIf

			; walls: as many as the loot allows in one go through the game's "Upgrade More" wizard, when the bar has it
			If $bWallUpgrade Then
				Local $iBatch = UpgradeWallMore($bWallUseGold, 0, True)
				If $iBatch > 0 Then Return True
				If $iBatch < 0 Then Return False ; the wizard was closed again, the wall is no longer selected
			EndIf

			ClickP($aUpgradeIcon)

			; wait for Upgrade Window to open
			If _Sleep(1500) Then Return

			; missing check for Upgrade Window

			If $bDebugImage Then SaveDebugDiamondImage("GetUpgradeButton", $sUpgradeButtonDiamond)

			; search for 'resources' upgrade button
			Local $aUpgradeButton = decodeSingleCoord(findImage("GetUpgradeButon", $sUpgButton, $sUpgradeButtonDiamond, 1, True))
			If IsArray($aUpgradeButton) And UBound($aUpgradeButton) = 2 Then

				ClickP($aUpgradeButton)

				If isGemOpen(True) Then
					SetLog("Upgrade stopped due to insufficient loot", $COLOR_ERROR)
					CloseWindow() ; upgrade Window
					Return False
				Else
					SetLog($aBuildingName[1] & " Upgrading!", $COLOR_INFO)
					Return True
				EndIf
			Else
				CloseWindow()
				SetLog("Not enough Resources to Upgrade " & $aBuildingName[1] & " !", $COLOR_ERROR)
			EndIf

		EndIf
	EndIf

	Return False
EndFunc   ;==>GetUpgradeButton

Func NewBuildings($aResult, $bDebugImage = $g_bDebugImageSave)

	Local $sImgDir = @ScriptDir & "\imgxml\Resources\BuildersBase\AutoUpgrade\NewBuildings\Buildings\*"

	If UBound($aResult) = 3 And $aResult[2] = "New" Then

		; The $g_iQuickMISX and $g_iQuickMISY haves the coordinates compansation from 'New' | GetIconPosition()
		Click($aResult[0], $aResult[1], 1)
		If _Sleep(3000) Then Return

		; If exist Clocks
		Local $sSearchDiamond = GetDiamondFromRect2(16, 220 + $g_iMidOffsetY, 700, 595 + $g_iMidOffsetY)
		Local $ClocksCoordinates = QuickMIS("CNX", $g_sImgAutoUpgradeClock, 16, 220 + $g_iMidOffsetY, 700, 595 + $g_iMidOffsetY)

		If $bDebugImage Then SaveDebugDiamondImage("AutoUpgradeClock", $sSearchDiamond)

		If IsArray($ClocksCoordinates) And UBound($ClocksCoordinates) > 1 Then
			SetLog("[Clocks]: " & UBound($ClocksCoordinates), $COLOR_DEBUG)
			For $i = 0 To UBound($ClocksCoordinates) - 1
				SetLog("Clock " & $i + 1 & " Found at : " & $ClocksCoordinates[$i][1] & ", " & $ClocksCoordinates[$i][2])

				; Just in Case
				If $ClocksCoordinates[$i][1] = "" Or $ClocksCoordinates[$i][2] = "" Then
					CloseWindow()
					ExitLoop
				EndIf

				; Coordinates for Slot & Tile Zone from Clock position
				Local $aCostArea = $ClocksCoordinates[$i][1] & "," & $ClocksCoordinates[$i][2] + 18 & "," & $ClocksCoordinates[$i][1] + 150 & "," & $ClocksCoordinates[$i][2] + 54
				Local $aTileArea = $ClocksCoordinates[$i][1] + 120 & "," & $ClocksCoordinates[$i][2] - 167 & "," & $ClocksCoordinates[$i][1] + 160 & "," & $ClocksCoordinates[$i][2] - 137

				; Lets see if exist resources
				; look for white zeros
				If QuickMIS("BC1", $g_sImgAutoUpgradeZero, $ClocksCoordinates[$i][1], $ClocksCoordinates[$i][2] + 18, $ClocksCoordinates[$i][1] + 150, $ClocksCoordinates[$i][2] + 54) Then

					; Lets se if exist or NOT the Yellow Arrow, If Doesnt exist the [i] icon than exist the Yellow arrow , DONE
					Local $InfoButton = False
					If QuickMIS("BC1", $g_sImgAutoUpgradeInfo, $ClocksCoordinates[$i][1] + 120, $ClocksCoordinates[$i][2] - 167, $ClocksCoordinates[$i][1] + 160, $ClocksCoordinates[$i][2] - 137) Then $InfoButton = True

					If $InfoButton Then
						SetLog("Failed to locate Arrow, looking next...")
						If $bDebugImage Then SaveDebugRectImage("FoundInfo", $aTileArea)

						If $i = UBound($ClocksCoordinates) - 1 Then
							If $g_bDebugSetLog Then SetDebugLog("Slot without enough resources!", $COLOR_DEBUG)
							CloseWindow()
							ExitLoop
						EndIf

						ContinueLoop
					Else

						; look for wall
						If QuickMIS("BC1", $sImgDir, $ClocksCoordinates[$i][1] + 30, $ClocksCoordinates[$i][2] - 100, $ClocksCoordinates[$i][1] + 110, $ClocksCoordinates[$i][2] - 20) Then
							SetLog("Found Wall in Building Menu Tile")
							If $bDebugImage Then SaveDebugRectImage("AutoUpgradeBBwall", $aTileArea)
							CloseWindow()

							If _Sleep(100) Then Return False

							ClickOnBuilder()

							If _Sleep(1000) Then Return False
							ExitLoop
						EndIf

						Local $aiPoint[2]
						$aiPoint[0] = $ClocksCoordinates[$i][1] + 70
						$aiPoint[1] = $ClocksCoordinates[$i][2] - 77

						If $bDebugImage Then SaveDebugPointImage("Tile", $aiPoint)

						Click($ClocksCoordinates[$i][1] + 70, $ClocksCoordinates[$i][2] - 77, 1)
						If _Sleep(4000) Then Return

						Local $aSearchDiamond = GetDiamondFromRect2(80, 60, 800, 570 + $g_iMidOffsetY)
						If $bDebugImage Then SaveDebugDiamondImage("UpgradeNewBldgYesNo", $aSearchDiamond)

						; Lets search for the Correct Symbol on field
						If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgYes, 80, 60, 800, 570 + $g_iMidOffsetY) Then
							Click($g_iQuickMISX, $g_iQuickMISY)
							SetLog("Placed a new Building on Builder Base!", $COLOR_INFO)

							If _Sleep(1000) Then Return

							; Lets check if exist the [x] , Some Buildings like Traps when you place one will give other to place automatically!
							If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) Then
								SetLog("Found another building!")
								Click($g_iQuickMISX, $g_iQuickMISY)
							EndIf

							Return True
						Else

							If Not QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) And QuickMIS("BC1", $sImgTunnel, 0, 190 + $g_iMidOffsetY, $g_iGAME_WIDTH, $g_iGAME_HEIGHT) Then
								ClickDrag(700, 500 + $g_iMidOffsetY, 170, 80 + $g_iMidOffsetY)
								If _Sleep(Random(1500, 2000, 1)) Then Return
								Zoomout()
								If _Sleep(250) Then Return
								If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgYes, 80, 60, 800, 570 + $g_iMidOffsetY) Then
									Click($g_iQuickMISX, $g_iQuickMISY)
									SetLog("Placed a new Building on Builder Base!", $COLOR_INFO)
									If _Sleep(1000) Then Return
									; Lets check if exist the [x] , Some Buildings like Traps when you place one will give other to place automatically!
									If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) Then
										SetLog("Found another building!")
										Click($g_iQuickMISX, $g_iQuickMISY)
									EndIf
									Return True
								EndIf
							EndIf

							For $j = 0 To 8
								If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) Then
									ClickDrag($g_iQuickMISX + 15, $g_iQuickMISY + 36, $g_iQuickMISX + 15 + 40, $g_iQuickMISY + 36 + 30, 500)
									If _Sleep(Random(1500, 2000, 1)) Then Return
									If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgYes, 80, 60, 800, 570 + $g_iMidOffsetY) Then
										Click($g_iQuickMISX, $g_iQuickMISY)
										SetLog("Placed a new Building on Builder Base!", $COLOR_INFO)
										If _Sleep(1000) Then Return False
										; Lets check if exist the [x] , Some Buildings like Traps when you place one will give other to place automatically!
										If QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) Then
											SetLog("Found another building!")
											Click($g_iQuickMISX, $g_iQuickMISY)
										EndIf
										Return True
									EndIf
									SetLog("Failed to deploy a new building on BB! [" & $g_iQuickMISX & "," & $g_iQuickMISY & "]", $COLOR_ERROR)
									If _Sleep(250) Then Return False
									If $j = 8 And QuickMIS("BC1", $g_sImgAutoUpgradeNewBldgNo, 80, 60, 800, 570 + $g_iMidOffsetY) Then
										Click($g_iQuickMISX, $g_iQuickMISY)
										If _Sleep(1000) Then Return False
									EndIf
								Else
									SetLog("Failed to locate Cancel button [x] : " & $j)
								EndIf
								If _Sleep(250) Then Return
							Next

						EndIf
					EndIf
				Else
					If $bDebugImage Then SaveDebugRectImage("NoWhiteZeros", $aCostArea)
					SetLog("Slot without enough resources!", $COLOR_INFO)
					If $i = UBound($ClocksCoordinates) - 1 Then CloseWindow()
				EndIf
			Next
		Else
			SetLog("No Clock Found!", $COLOR_ERROR)
			CloseWindow()
		EndIf

	EndIf

	SetLog("Failed to place new building")
	If _Sleep(1000) Then Return
	Return False

EndFunc   ;==>NewBuildings

; True when a Master Builder may be spent on something that is not a wall. With "Keep 1 builder for
; walls" on, the last free builder is left to the wall suggestions, which are instant and never keep him.
Func BBBuilderFreeForBuilding($bSetLog = True)
	Local $iKeep = ($g_iChkBBSaveWallBuilder = 1 ? 1 : 0)
	If $g_iFreeBuilderCountBB > $iKeep Then Return True
	If $bSetLog Then
		If $g_iFreeBuilderCountBB = 0 Then
			SetLog("No Master Builder available! [" & $g_iFreeBuilderCountBB & "/" & $g_iTotalBuilderCountBB & "]", $COLOR_INFO)
		Else
			SetLog("The last free Master Builder is kept for walls [" & $g_iFreeBuilderCountBB & "/" & $g_iTotalBuilderCountBB & "]", $COLOR_INFO)
		EndIf
	EndIf
	Return False
EndFunc   ;==>BBBuilderFreeForBuilding

; The wall bar has the gold and the elixir Upgrade buttons side by side: move to the elixir one.
Func __BBWallUseElixir(ByRef $aUpgradeIcon, ByRef $bWallUseGold)
	$aUpgradeIcon[0] += 94
	$bWallUseGold = False
EndFunc   ;==>__BBWallUseElixir
