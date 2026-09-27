; #FUNCTION# ====================================================================================================================
; Name ..........: ImageSearchCVCompat
; Description ...: Answers the DLL image search calls with the bot's own OpenCV engine when a PNG mirror of the
;                  template exists, so the 400+ call sites keep working unchanged while the templates migrate.
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  DllCallMyBot() hands every call to CVInterceptDllCall() first. Three DLL functions are taken over:
;                    FindTile(hBitmap, tile.xml, area, max)                         -> "N|x,y|x,y" or ""
;                    SearchMultipleTilesBetweenLevels(hBitmap, dir, area, max, redlines, minLevel, maxLevel)
;                                                                                   -> "key|key|..." or ""
;                    GetProperty(key, name)  for the keys created here (they end with "#cv")
;                  The mirror rule: imgxml\<path>\Name_Level_Thr.xml  <->  imgcv\<path>\Name_Level_Thr.png, and a folder
;                  is taken over as soon as imgcv\<path>\ holds at least one PNG (its subfolders included, as the DLL
;                  searches them). Name / Level / Thr come from the file name like the DLL does: object name, level
;                  (a number, letters may follow, e.g. 13A), match threshold in percent. Points returned are the centre
;                  of the template, like the DLL. Keys are "Name_Level_Thr#cv" (unique suffix when needed) so that the
;                  callers that split the key on "_" still read the name and the level.
;                  Areas: "FV" (the whole captured bitmap), "ECD" / "DCD" (the village diamond: whole bitmap too) or a
;                  rectangle "x,y|x,y|x,y|x,y" whose bounding box is searched.
; ===============================================================================================================================
#include-once

Global $g_aCVProps[0][7] ; key | objectname | objectlevel | objectpoints | filename | totalobjects | fillLevel
Global $g_iCVKeySeq = 0

; imgcv counterpart of an imgxml file or folder, "" when there is none (or when it holds no PNG)
Func __CVMirrorPath($sImgxml)
	Local $sRoot = @ScriptDir & "\imgxml\"
	Local $sPath = $sImgxml
	If StringLeft($sPath, StringLen($sRoot)) <> $sRoot Then
		; some callers build the path from a relative "imgxml\..." piece
		Local $iPos = StringInStr($sPath, "\imgxml\")
		If $iPos = 0 Then Return ""
		$sPath = @ScriptDir & StringMid($sPath, $iPos)
		If StringLeft($sPath, StringLen($sRoot)) <> $sRoot Then Return ""
	EndIf
	Local $sMirror = $g_sImgCVDir & StringMid($sPath, StringLen($sRoot) + 1)
	If StringRight($sMirror, 4) = ".xml" Then
		$sMirror = StringTrimRight($sMirror, 4) & ".png"
		Return FileExists($sMirror) ? $sMirror : ""
	EndIf
	If StringRight($sMirror, 1) = "\" Then $sMirror = StringTrimRight($sMirror, 1)
	If Not FileExists($sMirror) Or Not StringInStr(FileGetAttrib($sMirror), "D") Then Return ""
	Local $aList = _FileListToArrayRec($sMirror, "*.png", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
	If @error Or $aList[0] = 0 Then Return ""
	Return $sMirror
EndFunc   ;==>__CVMirrorPath

; Name, level (numeric part and full text), threshold (0..1) and 4th part of a template file name
Func __CVTemplateNameParts($sFile, ByRef $sName, ByRef $iLevel, ByRef $sLevel, ByRef $fThr, ByRef $sExtra)
	Local $sBase = StringRegExpReplace($sFile, ".*\\", "")
	$sBase = StringRegExpReplace($sBase, "\.[Pp][Nn][Gg]$", "")
	Local $aParts = StringSplit($sBase, "_", $STR_NOCOUNT)
	$sName = $aParts[0]
	$sLevel = (UBound($aParts) > 1) ? $aParts[1] : "0"
	Local $aNum = StringRegExp($sLevel, "^(\d+)", $STR_REGEXPARRAYMATCH)
	$iLevel = IsArray($aNum) ? Number($aNum[0]) : 0
	$fThr = 0.9
	If UBound($aParts) > 2 And StringRegExp($aParts[2], "^\d+$") Then $fThr = Number($aParts[2]) / 100
	$sExtra = (UBound($aParts) > 3) ? $aParts[3] : ""
EndFunc   ;==>__CVTemplateNameParts

; Bounding box of an area string inside a $iW x $iH bitmap: [x, y, w, h]
Func __CVAreaBox($sArea, $iW, $iH)
	Local $aBox[4] = [0, 0, $iW, $iH]
	If StringInStr($sArea, ",") = 0 Then Return $aBox ; FV, ECD, DCD, ""
	Local $iMinX = 999999, $iMinY = 999999, $iMaxX = -1, $iMaxY = -1
	Local $aPts = StringSplit($sArea, "|", $STR_NOCOUNT)
	For $i = 0 To UBound($aPts) - 1
		Local $aXY = StringSplit($aPts[$i], ",", $STR_NOCOUNT)
		If UBound($aXY) < 2 Then ContinueLoop
		Local $x = Number($aXY[0]), $y = Number($aXY[1])
		If $x < $iMinX Then $iMinX = $x
		If $y < $iMinY Then $iMinY = $y
		If $x > $iMaxX Then $iMaxX = $x
		If $y > $iMaxY Then $iMaxY = $y
	Next
	If $iMaxX < 0 Then Return $aBox
	If $iMinX < 0 Then $iMinX = 0
	If $iMinY < 0 Then $iMinY = 0
	If $iMaxX > $iW Then $iMaxX = $iW
	If $iMaxY > $iH Then $iMaxY = $iH
	If $iMaxX - $iMinX < 1 Or $iMaxY - $iMinY < 1 Then Return $aBox
	$aBox[0] = Int($iMinX)
	$aBox[1] = Int($iMinY)
	$aBox[2] = Int($iMaxX - $iMinX)
	$aBox[3] = Int($iMaxY - $iMinY)
	Return $aBox
EndFunc   ;==>__CVAreaBox

; Matches of one PNG template inside the box of an image: [n][3] of centre x, centre y (image coordinates), score
Func __CVMatchInBox($pImg, $iImgW, $iImgH, $sPng, $aBox, $fThr, $iMax)
	Local $aNone[0][3]
	Local $aTpl = __CVTemplate($sPng)
	If $aTpl[0] = 0 Then Return $aNone
	Local $pSrc = $pImg, $iW = $iImgW, $iH = $iImgH, $tSub = 0
	If $aBox[0] > 0 Or $aBox[1] > 0 Or $aBox[2] < $iImgW Or $aBox[3] < $iImgH Then
		; a CvMat header on the sub-rectangle, no pixel copy
		$tSub = DllStructCreate("byte[64]")
		Local $a = DllCall($g_hCVCore, "ptr:cdecl", "cvGetSubRect", "ptr", $pImg, "ptr", DllStructGetPtr($tSub), "int", $aBox[0], "int", $aBox[1], "int", $aBox[2], "int", $aBox[3])
		If @error Or $a[0] = 0 Then Return $aNone
		$pSrc = $a[0]
		$iW = $aBox[2]
		$iH = $aBox[3]
	EndIf
	Local $aHits = __CVMatch($pSrc, $iW, $iH, $aTpl[0], $aTpl[1], $aTpl[2], $fThr, $iMax)
	For $i = 0 To UBound($aHits) - 1
		$aHits[$i][0] = $aBox[0] + $aHits[$i][0] + Int($aTpl[1] / 2)
		$aHits[$i][1] = $aBox[1] + $aHits[$i][1] + Int($aTpl[2] / 2)
	Next
	Return $aHits
EndFunc   ;==>__CVMatchInBox

; A folder holding a file named shadow.txt is searched by both engines: our result goes to the debug log and the DLL still
; answers the call. The way to validate a migrated folder in the running bot before switching it for good.
Func __CVIsShadow($sMirror)
	Local $sDir = StringInStr(FileGetAttrib($sMirror), "D") ? $sMirror : StringRegExpReplace($sMirror, "\\[^\\]*$", "")
	Return FileExists($sDir & "\shadow.txt")
EndFunc   ;==>__CVIsShadow

Func __CVStoreProps($sName, $sLevel, $sPoints, $sFile, $iTotal, $sExtra)
	Local $n = UBound($g_aCVProps)
	; the file name without extension is already Name_Level_Thr[_extra]
	Local $sKey = StringRegExpReplace(StringRegExpReplace($sFile, ".*\\", ""), "\.[Pp][Nn][Gg]$", "")
	$g_iCVKeySeq += 1
	$sKey &= "#cv" & $g_iCVKeySeq
	ReDim $g_aCVProps[$n + 1][7]
	$g_aCVProps[$n][0] = $sKey
	$g_aCVProps[$n][1] = $sName
	$g_aCVProps[$n][2] = $sLevel
	$g_aCVProps[$n][3] = $sPoints
	$g_aCVProps[$n][4] = $sFile
	$g_aCVProps[$n][5] = $iTotal
	$g_aCVProps[$n][6] = $sExtra
	Return $sKey
EndFunc   ;==>__CVStoreProps

; Takes a DLL call over when the templates have a PNG mirror. Returns an array shaped like DllCall's
; ([0] = the string the DLL would return) or False when the DLL must handle the call.
Func CVInterceptDllCall($sFunc, $vParam1, $vParam2, $vParam3, $vParam4, $vParam5 = "", $vParam6 = 0, $vParam7 = 1000)
	; DllCallMyBot passes the Default keyword for the parameters a call did not use
	If IsKeyword($vParam4) Then $vParam4 = 0
	If IsKeyword($vParam5) Then $vParam5 = ""
	If IsKeyword($vParam6) Then $vParam6 = 0
	If IsKeyword($vParam7) Then $vParam7 = 1000
	Switch $sFunc
		Case "ocr" ; (hBitmap, font name, debug flag): the glyph OCR when imgcv\OCR\<font>\ exists
			If Not CVOcrFontExists($vParam2) Then Return False
			Local $aRet[4] = ["", $vParam1, $vParam2, $vParam3]
			Local $hTimer = __TimerInit()
			$aRet[0] = CVOcr($vParam1, $vParam2)
			SetDebugLog("CV ocr " & $vParam2 & ": '" & $aRet[0] & "' (" & Round(__TimerDiff($hTimer)) & " ms)", $COLOR_DEBUG)
			If __CVIsShadow($g_sImgCVDir & "OCR\" & $vParam2) Then Return False ; validation only, the DLL answers
			Return $aRet

		Case "GetProperty"
			If StringInStr($vParam1, "#cv") = 0 Then Return False
			Local $aRet[3] = ["", $vParam1, $vParam2]
			For $i = 0 To UBound($g_aCVProps) - 1
				If $g_aCVProps[$i][0] = $vParam1 Then
					Switch $vParam2
						Case "objectname"
							$aRet[0] = $g_aCVProps[$i][1]
						Case "objectlevel"
							$aRet[0] = $g_aCVProps[$i][2]
						Case "objectpoints"
							$aRet[0] = $g_aCVProps[$i][3]
						Case "filename"
							$aRet[0] = $g_aCVProps[$i][4]
						Case "totalobjects"
							$aRet[0] = String($g_aCVProps[$i][5])
						Case "fillLevel"
							$aRet[0] = $g_aCVProps[$i][6]
						Case Else
							$aRet[0] = ""
					EndSwitch
					ExitLoop
				EndIf
			Next
			Return $aRet

		Case "FindTile"
			Local $sPng = __CVMirrorPath($vParam2)
			If $sPng = "" Then Return False
			Local $aRet[5] = ["", $vParam1, $vParam2, $vParam3, $vParam4]
			If Not CVInit() Then Return $aRet
			Local $iW, $iH
			Local $pImg = __CVImageFromHBitmap($vParam1, $iW, $iH)
			If $pImg = 0 Then Return $aRet
			Local $sName, $iLevel, $sLevel, $fThr, $sExtra
			__CVTemplateNameParts($sPng, $sName, $iLevel, $sLevel, $fThr, $sExtra)
			Local $iMax = Number($vParam4)
			If $iMax < 1 Then $iMax = 20
			Local $hTimer = __TimerInit()
			Local $aHits = __CVMatchInBox($pImg, $iW, $iH, $sPng, __CVAreaBox($vParam3, $iW, $iH), $fThr, $iMax)
			__CVReleaseImage($pImg)
			If UBound($aHits) > 0 Then
				$aRet[0] = UBound($aHits)
				For $i = 0 To UBound($aHits) - 1
					$aRet[0] &= "|" & $aHits[$i][0] & "," & $aHits[$i][1]
				Next
			EndIf
			SetDebugLog("CV FindTile " & $sName & "_" & $sLevel & ": " & ($aRet[0] = "" ? "nothing" : $aRet[0]) & " (" & Round(__TimerDiff($hTimer)) & " ms)", $COLOR_DEBUG)
			If __CVIsShadow($sPng) Then Return False ; validation only, the DLL answers
			Return $aRet

		Case "SearchMultipleTilesBetweenLevels"
			Local $sDir = __CVMirrorPath($vParam2)
			If $sDir = "" Then Return False
			Local $aRet[8] = ["", $vParam1, $vParam2, $vParam3, $vParam4, $vParam5, $vParam6, $vParam7]
			If Not CVInit() Then Return $aRet
			Local $aList = _FileListToArrayRec($sDir, "*.png", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_SORT, $FLTAR_FULLPATH)
			If @error Or $aList[0] = 0 Then Return $aRet
			Local $iW, $iH
			Local $pImg = __CVImageFromHBitmap($vParam1, $iW, $iH)
			If $pImg = 0 Then Return $aRet
			Local $aBox = __CVAreaBox($vParam3, $iW, $iH)
			Local $iMax = Number($vParam4)
			If $iMax < 1 Then $iMax = 20
			Local $iMin = Number($vParam6), $iMaxLevel = Number($vParam7)
			ReDim $g_aCVProps[0][7]
			Local $hTimer = __TimerInit(), $iFiles = 0
			For $f = 1 To $aList[0]
				Local $sName, $iLevel, $sLevel, $fThr, $sExtra
				__CVTemplateNameParts($aList[$f], $sName, $iLevel, $sLevel, $fThr, $sExtra)
				If $iLevel < $iMin Or $iLevel > $iMaxLevel Then ContinueLoop
				$iFiles += 1
				Local $aHits = __CVMatchInBox($pImg, $iW, $iH, $aList[$f], $aBox, $fThr, $iMax)
				If UBound($aHits) = 0 Then ContinueLoop
				Local $sPoints = ""
				For $i = 0 To UBound($aHits) - 1
					$sPoints &= ($i > 0 ? "|" : "") & $aHits[$i][0] & "," & $aHits[$i][1]
				Next
				Local $sKey = __CVStoreProps($sName, $sLevel, $sPoints, $aList[$f], UBound($aHits), $sExtra)
				$aRet[0] &= ($aRet[0] <> "" ? "|" : "") & $sKey
			Next
			__CVReleaseImage($pImg)
			SetDebugLog("CV Search " & StringRegExpReplace($vParam2, ".*\\imgxml\\", "") & ": " & $iFiles & " template(s), " & UBound($g_aCVProps) & " found (" & Round(__TimerDiff($hTimer)) & " ms)" & ($aRet[0] <> "" ? " " & $aRet[0] : ""), $COLOR_DEBUG)
			If __CVIsShadow($sDir) Then
				For $i = 0 To UBound($g_aCVProps) - 1
					SetDebugLog("CV shadow " & $g_aCVProps[$i][0] & " -> " & $g_aCVProps[$i][3], $COLOR_DEBUG)
				Next
				ReDim $g_aCVProps[0][7]
				Return False ; validation only, the DLL answers
			EndIf
			Return $aRet
	EndSwitch
	Return False
EndFunc   ;==>CVInterceptDllCall

; 3-channel IplImage* from a GDI HBITMAP (the bot's $g_hHBitmap2), 0 on failure
Func __CVImageFromHBitmap($hHBitmap, ByRef $iW, ByRef $iH)
	If $hHBitmap = 0 Then Return 0
	Local $hBitmap = _GDIPlus_BitmapCreateFromHBITMAP($hHBitmap)
	If @error Or $hBitmap = 0 Then Return 0
	Local $pImg = __CVImageFromBitmap($hBitmap, $iW, $iH)
	_GDIPlus_BitmapDispose($hBitmap)
	Return $pImg
EndFunc   ;==>__CVImageFromHBitmap
