; checkObstacles' Return Home detection: FindImageCV("own\ReturnHome") on the bottom-left corner, exactly as
; called by the bot, against real 860x732 captures. Usage: AutoIt3.exe returnhome_test.au3 <warpage.png> <village.png> [more negatives...]
#include <GDIPlus.au3>
#include <File.au3>
#include <Array.au3>
#include <Math.au3>
#include <StringConstants.au3>
#include <FileConstants.au3>

Global Const $g_sLibPath = @ScriptDir & "\..\..\lib"
Global Const $g_iGAME_WIDTH = 860, $g_iGAME_HEIGHT = 732, $g_iBottomOffsetY = 12
Global $g_hBitmap = 0
Global Const $COLOR_ERROR = 0, $COLOR_DEBUG = 0, $COLOR_INFO = 0
Func SetLog($s, $c = 0)
	ConsoleWrite("LOG   " & $s & @CRLF)
EndFunc
Func SetDebugLog($s, $c = 0, $b = False)
	ConsoleWrite("DEBUG " & $s & @CRLF)
EndFunc
Func __TimerInit()
	Return TimerInit()
EndFunc
Func __TimerDiff($h)
	Return TimerDiff($h)
EndFunc
Func _CaptureRegion($l = 0, $t = 0, $r = 0, $b = 0)
EndFunc
#include "..\..\COCBot\functions\Image Search\ImageSearchCV.au3"

; the bot's imgcv folder, not the one next to this script
Global $g_sImgCVDirBot = @ScriptDir & "\..\..\imgcv\"

_GDIPlus_Startup()
Global $iPass = 0, $iFail = 0
; loads a PNG, crops the corner the bot captures, and runs the very call of checkObstacles ($bCapture = False)
Func Corner($sFile)
	Local $hImg = _GDIPlus_ImageLoadFromFile($sFile)
	Local $iL = 0, $iT = 560 + $g_iBottomOffsetY, $iR = 160, $iB = $g_iGAME_HEIGHT
	$g_hBitmap = _GDIPlus_BitmapCloneArea($hImg, $iL, $iT, $iR - $iL, $iB - $iT, $GDIP_PXF32ARGB)
	_GDIPlus_ImageDispose($hImg)
	Local $a = FindImageCV($g_sImgCVDirBot & "own\ReturnHome", $iL, $iT, $iR, $iB, 0.80, 1, False)
	_GDIPlus_BitmapDispose($g_hBitmap)
	Return $a
EndFunc
For $i = 1 To $CmdLine[0]
	Local $a = Corner($CmdLine[$i])
	Local $sName = StringRegExpReplace($CmdLine[$i], ".*\\", "")
	If $i = 1 Then
		If UBound($a) = 1 And Abs($a[0][0] - 62) <= 3 And Abs($a[0][1] - 671) <= 3 Then
			$iPass += 1
			ConsoleWrite("PASS  war page: button at " & $a[0][0] & "," & $a[0][1] & " score " & $a[0][2] & @CRLF)
		Else
			$iFail += 1
			ConsoleWrite("FAIL  war page: " & UBound($a) & " match(es)" & @CRLF)
		EndIf
	Else
		If UBound($a) = 0 Then
			$iPass += 1
			ConsoleWrite("PASS  " & $sName & ": nothing found" & @CRLF)
		Else
			$iFail += 1
			ConsoleWrite("FAIL  " & $sName & ": found " & $a[0][0] & "," & $a[0][1] & " score " & $a[0][2] & @CRLF)
		EndIf
	EndIf
Next
_GDIPlus_Shutdown()
ConsoleWrite(@CRLF & "pass " & $iPass & "  fail " & $iFail & @CRLF)
Exit ($iFail > 0 ? 1 : 0)
