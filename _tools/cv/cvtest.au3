; Standalone check of the OpenCV C API shipped in lib\ (opencv_core220 / opencv_imgproc220): template matching
; on two PNG files, no MyBot code involved. Usage: AutoIt3.exe cvtest.au3 <screen.png> <template.png> [threshold]
#include <GDIPlus.au3>

Global Const $sLib = "D:\VSCode\MyBot-MBR_v8.2.0\lib\"
Global $hCore = DllOpen($sLib & "opencv_core220.dll")
Global $hProc = DllOpen($sLib & "opencv_imgproc220.dll")
ConsoleWrite("DllOpen core=" & $hCore & " imgproc=" & $hProc & @CRLF)
If $hCore = -1 Or $hProc = -1 Then Exit 1

Global Const $IPL_DEPTH_8U = 8, $IPL_DEPTH_32F = 32, $CV_BGRA2BGR = 1, $CV_TM_CCOEFF_NORMED = 5

_GDIPlus_Startup()
Local $sScreen = ($CmdLine[0] >= 1) ? $CmdLine[1] : ""
Local $sTempl = ($CmdLine[0] >= 2) ? $CmdLine[2] : ""
Local $fThr = ($CmdLine[0] >= 3) ? Number($CmdLine[3]) : 0.9

Local $aImg = CVLoadPng($sScreen)
Local $aTpl = CVLoadPng($sTempl)
ConsoleWrite("screen " & $aImg[1] & "x" & $aImg[2] & " template " & $aTpl[1] & "x" & $aTpl[2] & @CRLF)

Local $hTimer = TimerInit()
Local $iRW = $aImg[1] - $aTpl[1] + 1, $iRH = $aImg[2] - $aTpl[2] + 1
Local $aRes = DllCall($hCore, "ptr:cdecl", "cvCreateImage", "int", $iRW, "int", $iRH, "int", $IPL_DEPTH_32F, "int", 1)
ConsoleWrite("cvCreateImage err=" & @error & " res=" & $aRes[0] & @CRLF)
Local $pRes = $aRes[0]
Local $aRet = DllCall($hProc, "none:cdecl", "cvMatchTemplate", "ptr", $aImg[0], "ptr", $aTpl[0], "ptr", $pRes, "int", $CV_TM_CCOEFF_NORMED)
ConsoleWrite("cvMatchTemplate err=" & @error & " in " & Round(TimerDiff($hTimer), 1) & " ms" & @CRLF)

; best matches with a simple suppression: the result rows are written to zero around each maximum
Local $tMinLoc = DllStructCreate("int x;int y"), $tMaxLoc = DllStructCreate("int x;int y")
Local $tRes = DllStructCreate("ptr nSize;int ID;int nChannels;int alphaChannel;int depth;byte colorModel[4];byte channelSeq[4];int dataOrder;int origin;int align;int width;int height;ptr roi;ptr maskROI;ptr imageId;ptr tileInfo;int imageSize;ptr imageData;int widthStep", $pRes)
Local $pData = DllStructGetData($tRes, "imageData"), $iStep = DllStructGetData($tRes, "widthStep")
ConsoleWrite("result " & DllStructGetData($tRes, "width") & "x" & DllStructGetData($tRes, "height") & " step " & $iStep & @CRLF)
For $k = 1 To 15
	Local $a = DllCall($hCore, "none:cdecl", "cvMinMaxLoc", "ptr", $pRes, "double*", 0, "double*", 0, "ptr", DllStructGetPtr($tMinLoc), "ptr", DllStructGetPtr($tMaxLoc), "ptr", 0)
	Local $fMax = $a[3], $iX = DllStructGetData($tMaxLoc, "x"), $iY = DllStructGetData($tMaxLoc, "y")
	ConsoleWrite("match " & $k & ": score " & Round($fMax, 4) & " at " & $iX & "," & $iY & " (centre " & $iX + Int($aTpl[1] / 2) & "," & $iY + Int($aTpl[2] / 2) & ")" & @CRLF)
	If $fMax < $fThr Then ExitLoop
	; suppress a template-sized box around the maximum
	For $y = $iY - Int($aTpl[2] / 2) To $iY + Int($aTpl[2] / 2)
		If $y < 0 Or $y >= $iRH Then ContinueLoop
		Local $x0 = $iX - Int($aTpl[1] / 2), $x1 = $iX + Int($aTpl[1] / 2)
		If $x0 < 0 Then $x0 = 0
		If $x1 >= $iRW Then $x1 = $iRW - 1
		Local $tRow = DllStructCreate("float[" & ($x1 - $x0 + 1) & "]", $pData + $y * $iStep + $x0 * 4)
		For $i = 1 To $x1 - $x0 + 1
			DllStructSetData($tRow, 1, -1, $i)
		Next
	Next
Next
ConsoleWrite("total " & Round(TimerDiff($hTimer), 1) & " ms" & @CRLF)

DllCall($hCore, "none:cdecl", "cvReleaseImage", "ptr*", $pRes)
CVFree($aImg)
CVFree($aTpl)
_GDIPlus_Shutdown()
DllClose($hProc)
DllClose($hCore)
Exit 0

; Loads a PNG as a 3-channel BGR IplImage. Returns [IplImage*, width, height, hBitmap, tBitmapData(kept locked)]
Func CVLoadPng($sFile)
	Local $hImage = _GDIPlus_ImageLoadFromFile($sFile)
	If @error Or $hImage = 0 Then
		ConsoleWrite("cannot load " & $sFile & @CRLF)
		Exit 2
	EndIf
	Local $iW = _GDIPlus_ImageGetWidth($hImage), $iH = _GDIPlus_ImageGetHeight($hImage)
	Local $hBmp = _GDIPlus_BitmapCloneArea($hImage, 0, 0, $iW, $iH, $GDIP_PXF32ARGB)
	_GDIPlus_ImageDispose($hImage)
	Local $tData = _GDIPlus_BitmapLockBits($hBmp, 0, 0, $iW, $iH, $GDIP_ILMREAD, $GDIP_PXF32ARGB)
	Local $pScan0 = DllStructGetData($tData, "Scan0"), $iStride = DllStructGetData($tData, "Stride")
	Local $a4 = DllCall($hCore, "ptr:cdecl", "cvCreateImageHeader", "int", $iW, "int", $iH, "int", $IPL_DEPTH_8U, "int", 4)
	DllCall($hCore, "none:cdecl", "cvSetData", "ptr", $a4[0], "ptr", $pScan0, "int", $iStride)
	Local $a3 = DllCall($hCore, "ptr:cdecl", "cvCreateImage", "int", $iW, "int", $iH, "int", $IPL_DEPTH_8U, "int", 3)
	DllCall($hProc, "none:cdecl", "cvCvtColor", "ptr", $a4[0], "ptr", $a3[0], "int", $CV_BGRA2BGR)
	ConsoleWrite("cvCvtColor err=" & @error & @CRLF)
	DllCall($hCore, "none:cdecl", "cvReleaseImageHeader", "ptr*", $a4[0])
	_GDIPlus_BitmapUnlockBits($hBmp, $tData)
	_GDIPlus_BitmapDispose($hBmp)
	Local $aRet[3] = [$a3[0], $iW, $iH]
	Return $aRet
EndFunc   ;==>CVLoadPng

Func CVFree(ByRef $aImg)
	DllCall($hCore, "none:cdecl", "cvReleaseImage", "ptr*", $aImg[0])
EndFunc   ;==>CVFree
