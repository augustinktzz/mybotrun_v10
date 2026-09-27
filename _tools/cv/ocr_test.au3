; Harness for the glyph OCR: strips cut from captures, glyphs in imgcv\OCR\<font>\ next to this script.
#include <GDIPlus.au3>
#include <File.au3>
#include <Array.au3>
#include <Math.au3>
#include <StringConstants.au3>
#include <FileConstants.au3>

Global Const $g_sLibPath = @ScriptDir & "\..\..\lib"
Global Const $g_iGAME_WIDTH = 860, $g_iGAME_HEIGHT = 732
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
#include "..\..\COCBot\functions\Image Search\ImageSearchCVCompat.au3"
#include "..\..\COCBot\functions\Image Search\ImageSearchCVOcr.au3"

_GDIPlus_Startup()
Local $iFail = 0
Func Check($sWhat, $bOk)
	ConsoleWrite(($bOk ? "PASS  " : "FAIL  ") & $sWhat & @CRLF)
	If Not $bOk Then $iFail += 1
EndFunc

; HBITMAP of a region of a PNG, like _CaptureRegion2(x, y, x + w, y + h) gives the bot
Func StripFromPng($sFile, $x, $y, $w, $h)
	Local $hImg = _GDIPlus_ImageLoadFromFile($sFile)
	Local $hClone = _GDIPlus_BitmapCloneArea($hImg, $x, $y, $w, $h, $GDIP_PXF32ARGB)
	Local $hBmp = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hClone)
	_GDIPlus_BitmapDispose($hClone)
	_GDIPlus_ImageDispose($hImg)
	Return $hBmp
EndFunc

Func OcrCheck($sFile, $x, $y, $w, $h, $sFont, $sExpect)
	Local $hBmp = StripFromPng($sFile, $x, $y, $w, $h)
	Local $hTimer = TimerInit()
	Local $sGot = CVOcr($hBmp, $sFont)
	Local $iMs = Round(TimerDiff($hTimer))
	_WinAPI_DeleteObject($hBmp)
	Check($sFont & " " & StringRegExpReplace($sFile, ".*\\", "") & " @" & $x & "," & $y & " -> '" & $sGot & "' expected '" & $sExpect & "' (" & $iMs & " ms)", $sGot = $sExpect)
EndFunc

Check("unknown font gives no glyphs", Not CVOcrFontExists("nope"))
Check("coc-ms font loads", CVOcrFontExists("coc-ms"))

; the strips the glyphs were cut from
OcrCheck(@ScriptDir & "\captures\now.png", 705, 23, 110, 16, "coc-ms", "7 028 173")
OcrCheck(@ScriptDir & "\captures\now.png", 705, 72, 110, 16, "coc-ms", "9 571 221")
OcrCheck(@ScriptDir & "\captures\now.png", 705, 121, 110, 16, "coc-ms", "154 442")
OcrCheck(@ScriptDir & "\captures\village_home.png", 705, 72, 110, 16, "coc-ms", "5 703 063")
; other captures, never seen by the glyph cutter
OcrCheck(@ScriptDir & "\captures\village_home.png", 705, 23, 110, 16, "coc-ms", "4 595 121")
OcrCheck(@ScriptDir & "\captures\village_home.png", 705, 121, 110, 16, "coc-ms", "233 100")
OcrCheck(@ScriptDir & "\captures\test_menu_before.png", 705, 23, 110, 16, "coc-ms", "4 595 121")
OcrCheck(@ScriptDir & "\captures\test_menu_before.png", 705, 121, 110, 16, "coc-ms", "233 100")
OcrCheck(@ScriptDir & "\captures\builder_menu_1.png", 705, 72, 110, 16, "coc-ms", "5 703 063")
; gems (same font, shorter strip)
OcrCheck(@ScriptDir & "\captures\now.png", 705, 170, 110, 16, "coc-ms", "544")
OcrCheck(@ScriptDir & "\captures\village_home.png", 705, 170, 110, 16, "coc-ms", "449")
; a strip with no text at all
OcrCheck(@ScriptDir & "\captures\now.png", 300, 600, 110, 16, "coc-ms", "")

; through the DLL call interception
Local $hBmp = StripFromPng(@ScriptDir & "\captures\now.png", 705, 23, 110, 16)
Local $aRes = CVInterceptDllCall("ocr", $hBmp, "coc-ms", 0, 0)
Check("interception ocr coc-ms -> " & (IsArray($aRes) ? "'" & $aRes[0] & "'" : "not handled"), IsArray($aRes) And $aRes[0] = "7 028 173")
Check("interception leaves unknown fonts to the DLL", CVInterceptDllCall("ocr", $hBmp, "coc-nope", 0, 0) = False)
_WinAPI_DeleteObject($hBmp)

_GDIPlus_Shutdown()
ConsoleWrite(($iFail = 0 ? "ALL PASSED" : $iFail & " FAILED") & @CRLF)
Exit $iFail

