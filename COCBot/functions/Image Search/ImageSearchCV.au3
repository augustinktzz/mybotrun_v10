; #FUNCTION# ====================================================================================================================
; Name ..........: ImageSearchCV
; Description ...: Template matching with plain PNG templates, on the OpenCV already shipped in lib\
; Syntax ........: FindImageCV($sTemplate[, $iLeft[, $iTop[, $iRight[, $iBottom[, $fThreshold[, $iMax]]]]]])
; Parameters ....: $sTemplate  - a PNG file, or a folder whose PNG files are all searched (relative to imgcv\ or absolute)
;                  $iLeft ...  - the region of the game screen to search (860 x 732 coordinates)
;                  $fThreshold - 0..1, normalised correlation coefficient (0.90 is a strict match, 0.75 a loose one)
;                  $iMax       - how many matches to return per template
; Return values .: 2D array [n][4]: centre x, centre y (game screen coordinates), score, template file name. n = 0 when nothing
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  The bot's own image search engine, next to the one of the DLL: templates are ordinary PNG files cut
;                  from an 860 x 732 capture (imgcv\<group>\<name>.png), so any new game object can be made detectable
;                  by anyone with a screenshot. Uses the C API of opencv_core220 / opencv_imgproc220 through DllCall:
;                  the capture (32 bit ARGB from GDI+) is wrapped in an IplImage header, converted to 3-channel BGR,
;                  matched with cvMatchTemplate (CV_TM_CCOEFF_NORMED) and read back with cvMinMaxLoc; a template-sized
;                  box is cleared around each match to find the next one. Templates are converted once and cached.
;                  Measured: a full screen against a 28 x 22 template in ~115 ms, the same object cut in one capture
;                  scores 0.998 in another one taken minutes later.
; ===============================================================================================================================
#include-once

Global Const $g_sImgCVDir = @ScriptDir & "\imgcv\"
Global $g_hCVCore = -1, $g_hCVProc = -1
Global $g_asCVTemplateCache[0][4] ; path | IplImage* | width | height

Global Const $CV_IPL_DEPTH_8U = 8, $CV_IPL_DEPTH_32F = 32, $CV_BGRA2BGR = 1, $CV_TM_CCOEFF_NORMED = 5

Func CVInit()
	If $g_hCVCore <> -1 And $g_hCVProc <> -1 Then Return True
	$g_hCVCore = DllOpen($g_sLibPath & "\opencv_core220.dll")
	$g_hCVProc = DllOpen($g_sLibPath & "\opencv_imgproc220.dll")
	If $g_hCVCore = -1 Or $g_hCVProc = -1 Then
		SetLog("ImageSearchCV: cannot load the OpenCV libraries from " & $g_sLibPath, $COLOR_ERROR)
		Return False
	EndIf
	Return True
EndFunc   ;==>CVInit

; 3-channel BGR IplImage* from a GDI+ bitmap (a copy, the bitmap can go afterwards). 0 on failure.
Func __CVImageFromBitmap($hBitmap, ByRef $iW, ByRef $iH)
	$iW = _GDIPlus_ImageGetWidth($hBitmap)
	$iH = _GDIPlus_ImageGetHeight($hBitmap)
	If $iW < 1 Or $iH < 1 Then Return 0
	Local $tData = _GDIPlus_BitmapLockBits($hBitmap, 0, 0, $iW, $iH, $GDIP_ILMREAD, $GDIP_PXF32ARGB)
	If @error Then Return 0
	Local $pScan0 = DllStructGetData($tData, "Scan0"), $iStride = DllStructGetData($tData, "Stride")
	Local $a4 = DllCall($g_hCVCore, "ptr:cdecl", "cvCreateImageHeader", "int", $iW, "int", $iH, "int", $CV_IPL_DEPTH_8U, "int", 4)
	If @error Or $a4[0] = 0 Then
		_GDIPlus_BitmapUnlockBits($hBitmap, $tData)
		Return 0
	EndIf
	DllCall($g_hCVCore, "none:cdecl", "cvSetData", "ptr", $a4[0], "ptr", $pScan0, "int", $iStride)
	Local $a3 = DllCall($g_hCVCore, "ptr:cdecl", "cvCreateImage", "int", $iW, "int", $iH, "int", $CV_IPL_DEPTH_8U, "int", 3)
	DllCall($g_hCVProc, "none:cdecl", "cvCvtColor", "ptr", $a4[0], "ptr", $a3[0], "int", $CV_BGRA2BGR)
	DllCall($g_hCVCore, "none:cdecl", "cvReleaseImageHeader", "ptr*", $a4[0])
	_GDIPlus_BitmapUnlockBits($hBitmap, $tData)
	Return $a3[0]
EndFunc   ;==>__CVImageFromBitmap

Func __CVReleaseImage($pImage)
	If $pImage <> 0 Then DllCall($g_hCVCore, "none:cdecl", "cvReleaseImage", "ptr*", $pImage)
EndFunc   ;==>__CVReleaseImage

; Template from a PNG file, converted once and kept. Returns [IplImage*, width, height], IplImage* = 0 on failure.
Func __CVTemplate($sFile)
	Local $aRet[3] = [0, 0, 0]
	For $i = 0 To UBound($g_asCVTemplateCache) - 1
		If $g_asCVTemplateCache[$i][0] = $sFile Then
			$aRet[0] = $g_asCVTemplateCache[$i][1]
			$aRet[1] = $g_asCVTemplateCache[$i][2]
			$aRet[2] = $g_asCVTemplateCache[$i][3]
			Return $aRet
		EndIf
	Next
	Local $hImage = _GDIPlus_ImageLoadFromFile($sFile)
	If @error Or $hImage = 0 Then
		SetLog("ImageSearchCV: cannot read template " & $sFile, $COLOR_ERROR)
		Return $aRet
	EndIf
	Local $iW = _GDIPlus_ImageGetWidth($hImage), $iH = _GDIPlus_ImageGetHeight($hImage)
	Local $hBmp = _GDIPlus_BitmapCloneArea($hImage, 0, 0, $iW, $iH, $GDIP_PXF32ARGB)
	_GDIPlus_ImageDispose($hImage)
	Local $pImg = __CVImageFromBitmap($hBmp, $iW, $iH)
	_GDIPlus_BitmapDispose($hBmp)
	If $pImg = 0 Then Return $aRet
	Local $n = UBound($g_asCVTemplateCache)
	ReDim $g_asCVTemplateCache[$n + 1][4]
	$g_asCVTemplateCache[$n][0] = $sFile
	$g_asCVTemplateCache[$n][1] = $pImg
	$g_asCVTemplateCache[$n][2] = $iW
	$g_asCVTemplateCache[$n][3] = $iH
	$aRet[0] = $pImg
	$aRet[1] = $iW
	$aRet[2] = $iH
	Return $aRet
EndFunc   ;==>__CVTemplate

; Matches one template in one image. Returns [n][3] of top-left x, top-left y, score (n = 0 when nothing).
Func __CVMatch($pImg, $iImgW, $iImgH, $pTpl, $iTplW, $iTplH, $fThreshold, $iMax)
	Local $aNone[0][3]
	If $iTplW > $iImgW Or $iTplH > $iImgH Then Return $aNone
	Local $iRW = $iImgW - $iTplW + 1, $iRH = $iImgH - $iTplH + 1
	Local $aRes = DllCall($g_hCVCore, "ptr:cdecl", "cvCreateImage", "int", $iRW, "int", $iRH, "int", $CV_IPL_DEPTH_32F, "int", 1)
	If @error Or $aRes[0] = 0 Then Return $aNone
	Local $pRes = $aRes[0]
	DllCall($g_hCVProc, "none:cdecl", "cvMatchTemplate", "ptr", $pImg, "ptr", $pTpl, "ptr", $pRes, "int", $CV_TM_CCOEFF_NORMED)
	If @error Then
		__CVReleaseImage($pRes)
		Return $aNone
	EndIf
	; the IplImage header: imageData and widthStep are needed to clear a box around each maximum
	Local $tHdr = DllStructCreate("int nSize;int ID;int nChannels;int alphaChannel;int depth;byte colorModel[4];byte channelSeq[4];int dataOrder;int origin;int align;int width;int height;ptr roi;ptr maskROI;ptr imageId;ptr tileInfo;int imageSize;ptr imageData;int widthStep", $pRes)
	Local $pData = DllStructGetData($tHdr, "imageData"), $iStep = DllStructGetData($tHdr, "widthStep")
	Local $tMinLoc = DllStructCreate("int x;int y"), $tMaxLoc = DllStructCreate("int x;int y")
	Local $aFound[$iMax][3], $n = 0
	For $k = 1 To $iMax
		Local $a = DllCall($g_hCVCore, "none:cdecl", "cvMinMaxLoc", "ptr", $pRes, "double*", 0, "double*", 0, "ptr", DllStructGetPtr($tMinLoc), "ptr", DllStructGetPtr($tMaxLoc), "ptr", 0)
		If @error Then ExitLoop
		Local $fMax = $a[3], $iX = DllStructGetData($tMaxLoc, "x"), $iY = DllStructGetData($tMaxLoc, "y")
		If $fMax < $fThreshold Then ExitLoop
		$aFound[$n][0] = $iX
		$aFound[$n][1] = $iY
		$aFound[$n][2] = $fMax
		$n += 1
		If $n = $iMax Then ExitLoop
		; clear a template-sized box around this maximum so the next call finds another object
		Local $x0 = $iX - Int($iTplW / 2), $x1 = $iX + Int($iTplW / 2)
		If $x0 < 0 Then $x0 = 0
		If $x1 > $iRW - 1 Then $x1 = $iRW - 1
		For $y = $iY - Int($iTplH / 2) To $iY + Int($iTplH / 2)
			If $y < 0 Or $y > $iRH - 1 Then ContinueLoop
			Local $tRow = DllStructCreate("float[" & ($x1 - $x0 + 1) & "]", $pData + $y * $iStep + $x0 * 4)
			For $i = 1 To $x1 - $x0 + 1
				DllStructSetData($tRow, 1, -1, $i)
			Next
		Next
	Next
	__CVReleaseImage($pRes)
	ReDim $aFound[$n][3]
	Return $aFound
EndFunc   ;==>__CVMatch

; The public search. $sTemplate: "Walls\13" (folder under imgcv\), "Walls\13\junction.png", or an absolute path.
Func FindImageCV($sTemplate, $iLeft = 0, $iTop = 0, $iRight = $g_iGAME_WIDTH, $iBottom = $g_iGAME_HEIGHT, $fThreshold = 0.9, $iMax = 1, $bCapture = True)
	Local $aNone[0][4]
	If Not CVInit() Then Return $aNone
	Local $sPath = $sTemplate
	If Not FileExists($sPath) Then $sPath = $g_sImgCVDir & $sTemplate
	Local $asFiles[0]
	If StringInStr(FileGetAttrib($sPath), "D") Then
		Local $aList = _FileListToArray($sPath, "*.png", $FLTA_FILES, True)
		If @error Then
			SetDebugLog("ImageSearchCV: no PNG template in " & $sPath, $COLOR_DEBUG)
			Return $aNone
		EndIf
		ReDim $asFiles[$aList[0]]
		For $i = 1 To $aList[0]
			$asFiles[$i - 1] = $aList[$i]
		Next
	ElseIf FileExists($sPath) Then
		ReDim $asFiles[1]
		$asFiles[0] = $sPath
	Else
		; a missing folder is normal: the imgcv templates are an optional layer, level by level
		SetDebugLog("ImageSearchCV: no template for " & $sTemplate, $COLOR_DEBUG)
		Return $aNone
	EndIf

	If $iLeft < 0 Then $iLeft = 0
	If $iTop < 0 Then $iTop = 0
	If $iRight > $g_iGAME_WIDTH Then $iRight = $g_iGAME_WIDTH
	If $iBottom > $g_iGAME_HEIGHT Then $iBottom = $g_iGAME_HEIGHT
	If $bCapture Then _CaptureRegion($iLeft, $iTop, $iRight, $iBottom)
	Local $hTimer = __TimerInit()
	Local $iW, $iH
	Local $pImg = __CVImageFromBitmap($g_hBitmap, $iW, $iH)
	If $pImg = 0 Then
		SetLog("ImageSearchCV: cannot read the capture", $COLOR_ERROR)
		Return $aNone
	EndIf

	Local $aAll[0][4]
	For $f = 0 To UBound($asFiles) - 1
		Local $aTpl = __CVTemplate($asFiles[$f])
		If $aTpl[0] = 0 Then ContinueLoop
		Local $aHits = __CVMatch($pImg, $iW, $iH, $aTpl[0], $aTpl[1], $aTpl[2], $fThreshold, $iMax)
		Local $n = UBound($aAll)
		ReDim $aAll[$n + UBound($aHits)][4]
		For $i = 0 To UBound($aHits) - 1
			$aAll[$n + $i][0] = $iLeft + $aHits[$i][0] + Int($aTpl[1] / 2)
			$aAll[$n + $i][1] = $iTop + $aHits[$i][1] + Int($aTpl[2] / 2)
			$aAll[$n + $i][2] = Round($aHits[$i][2], 4)
			$aAll[$n + $i][3] = StringRegExpReplace($asFiles[$f], ".*\\", "")
		Next
	Next
	__CVReleaseImage($pImg)
	If UBound($aAll) > 1 Then _ArraySort($aAll, 1, 0, 0, 2) ; best score first
	Local $sLog = ""
	For $i = 0 To _Min(UBound($aAll), 5) - 1
		$sLog &= ($i > 0 ? " | " : "") & $aAll[$i][3] & " " & $aAll[$i][2] & " @" & $aAll[$i][0] & "," & $aAll[$i][1]
	Next
	SetDebugLog("ImageSearchCV " & $sTemplate & ": " & UBound($aAll) & " match(es) in " & Round(__TimerDiff($hTimer)) & " ms" & ($sLog <> "" ? " - " & $sLog : ""), $COLOR_DEBUG)
	Return $aAll
EndFunc   ;==>FindImageCV
