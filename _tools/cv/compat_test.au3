; Harness: runs the bot's ImageSearchCV + ImageSearchCVCompat files outside the bot, on PNG captures.
#include <GDIPlus.au3>
#include <File.au3>
#include <Array.au3>
#include <Math.au3>
#include <StringConstants.au3>
#include <FileConstants.au3>

; stubs and globals the two files expect from the bot
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

Func HBitmapFromPng($sFile)
	Local $hImg = _GDIPlus_ImageLoadFromFile($sFile)
	Local $h = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hImg)
	_GDIPlus_ImageDispose($hImg)
	Return $h
EndFunc

; --- name parsing
Local $sName, $iLevel, $sLevel, $fThr, $sExtra
__CVTemplateNameParts("C:\x\Wall_13A_92.png", $sName, $iLevel, $sLevel, $fThr, $sExtra)
Check("name parts Wall_13A_92 -> " & $sName & "/" & $iLevel & "/" & $sLevel & "/" & $fThr, $sName = "Wall" And $iLevel = 13 And $sLevel = "13A" And $fThr = 0.92)
__CVTemplateNameParts("stoneDS-99-487-69,879896966152_0_92.png", $sName, $iLevel, $sLevel, $fThr, $sExtra)
Check("name parts stone -> " & $sName & "/" & $iLevel & "/" & $fThr, $sName = "stoneDS-99-487-69,879896966152" And $iLevel = 0 And $fThr = 0.92)
__CVTemplateNameParts("Collector_12_89_50.png", $sName, $iLevel, $sLevel, $fThr, $sExtra)
Check("name parts extra -> " & $sExtra, $sExtra = "50")

; --- area box
Local $aBox = __CVAreaBox("FV", 860, 732)
Check("area FV", $aBox[0] = 0 And $aBox[1] = 0 And $aBox[2] = 860 And $aBox[3] = 732)
$aBox = __CVAreaBox("300,200|400,200|400,300|300,300", 860, 732)
Check("area rect -> " & $aBox[0] & "," & $aBox[1] & " " & $aBox[2] & "x" & $aBox[3], $aBox[0] = 300 And $aBox[1] = 200 And $aBox[2] = 100 And $aBox[3] = 100)
$aBox = __CVAreaBox("-20,700|900,700|900,800|-20,800", 860, 732)
Check("area clipped -> " & $aBox[0] & "," & $aBox[1] & " " & $aBox[2] & "x" & $aBox[3], $aBox[0] = 0 And $aBox[1] = 700 And $aBox[2] = 860 And $aBox[3] = 32)

; --- mirror
Check("mirror of missing folder is empty", __CVMirrorPath(@ScriptDir & "\imgxml\Nope\") = "")
Check("mirror of Test\Icons found", __CVMirrorPath(@ScriptDir & "\imgxml\Test\Icons\") <> "")
Check("mirror of Wall xml -> png", StringRight(__CVMirrorPath(@ScriptDir & "\imgxml\Test\Walls\Wall_13A_92.xml"), 15) = "Wall_13A_92.png")
Check("mirror of missing xml is empty", __CVMirrorPath(@ScriptDir & "\imgxml\Test\Walls\Wall_14A_92.xml") = "")

; --- SearchMultipleTilesBetweenLevels on the scrolled builder menu (9 elixir rows, 3 DE rows, no gold)
Local $hBmp = HBitmapFromPng(@ScriptDir & "\captures\builder_menu_2.png")
Local $aRes = CVInterceptDllCall("SearchMultipleTilesBetweenLevels", $hBmp, @ScriptDir & "\imgxml\Test\Icons\", "FV", 0, "FV", 0, 1000)
Check("search returns an array", IsArray($aRes))
ConsoleWrite("keys: " & $aRes[0] & @CRLF)
Local $aKeys = StringSplit($aRes[0], "|", $STR_NOCOUNT)
Local $iElix = 0, $iGold = 0
For $i = 0 To UBound($aKeys) - 1
	Local $aName = CVInterceptDllCall("GetProperty", $aKeys[$i], "objectname", 0, 0)
	Local $aPts = CVInterceptDllCall("GetProperty", $aKeys[$i], "objectpoints", 0, 0)
	Local $aTot = CVInterceptDllCall("GetProperty", $aKeys[$i], "totalobjects", 0, 0)
	ConsoleWrite("  " & $aKeys[$i] & " -> " & $aName[0] & " x" & $aTot[0] & " : " & $aPts[0] & @CRLF)
	If $aName[0] = "Elix" Then $iElix = Number($aTot[0])
	If $aName[0] = "Gold" Then $iGold = Number($aTot[0])
	Local $aSplit = StringSplit($aKeys[$i], "_", $STR_NOCOUNT)
	Check("key " & $aKeys[$i] & " splits to name/level " & $aSplit[0] & "/" & $aSplit[1], $aSplit[0] = $aName[0] And $aSplit[1] = "0")
Next
Check("elixir icons found: " & $iElix & " (expect 8, the 9th row is cut by the panel edge)", $iElix = 8)
Check("no gold icon on this page: " & $iGold, $iGold = 0)
Check("unknown key is left to the DLL", CVInterceptDllCall("GetProperty", "Elix_0_92", "objectname", 0, 0) = False)
Check("unmirrored folder is left to the DLL", CVInterceptDllCall("SearchMultipleTilesBetweenLevels", $hBmp, @ScriptDir & "\imgxml\Other\", "FV", 0, "FV", 0, 1000) = False)
; level filter: minLevel 1 excludes the level-0 icons
$aRes = CVInterceptDllCall("SearchMultipleTilesBetweenLevels", $hBmp, @ScriptDir & "\imgxml\Test\Icons\", "FV", 0, "FV", 1, 1000)
Check("level filter excludes level 0 -> '" & $aRes[0] & "'", $aRes[0] = "")
; area limited to the top 3 rows: no elixir there
$aRes = CVInterceptDllCall("SearchMultipleTilesBetweenLevels", $hBmp, @ScriptDir & "\imgxml\Test\Icons\", "410,75|565,75|565,160|410,160", 0, "FV", 0, 1000)
Check("area limited to the DE rows -> '" & $aRes[0] & "'", $aRes[0] = "")
_WinAPI_DeleteObject($hBmp)

; --- the first page: 1 gold, 1 elixir, 1 DE in the suggested rows
$hBmp = HBitmapFromPng(@ScriptDir & "\captures\builder_menu_1.png")
$aRes = CVInterceptDllCall("SearchMultipleTilesBetweenLevels", $hBmp, @ScriptDir & "\imgxml\Test\Icons\", "FV", 0, "FV", 0, 1000)
ConsoleWrite("page 1 keys: " & $aRes[0] & @CRLF)
$aKeys = StringSplit($aRes[0], "|", $STR_NOCOUNT)
For $i = 0 To UBound($aKeys) - 1
	Local $aName = CVInterceptDllCall("GetProperty", $aKeys[$i], "objectname", 0, 0)
	Local $aPts = CVInterceptDllCall("GetProperty", $aKeys[$i], "objectpoints", 0, 0)
	ConsoleWrite("  " & $aName[0] & " : " & $aPts[0] & @CRLF)
	If $aName[0] = "Gold" Then Check("gold icon on the Hidden Tesla row (y~292): " & $aPts[0], StringRegExp($aPts[0], "^4\d\d,29[0-4]$"))
	If $aName[0] = "Elix" Then Check("elixir icon on the DE Drill row (y~321): " & $aPts[0], StringRegExp($aPts[0], "^4\d\d,3(19|2[0-3])$"))
Next
_WinAPI_DeleteObject($hBmp)

; --- FindTile with an area, on the village
$hBmp = HBitmapFromPng(@ScriptDir & "\captures\test_menu_before.png")
$aRes = CVInterceptDllCall("FindTile", $hBmp, @ScriptDir & "\imgxml\Test\Walls\Wall_13A_92.xml", "300,200|400,200|400,300|300,300", 1)
Check("FindTile in area -> '" & $aRes[0] & "'", $aRes[0] = "1|340,243")
$aRes = CVInterceptDllCall("FindTile", $hBmp, @ScriptDir & "\imgxml\Test\Walls\Wall_13A_92.xml", "500,400|600,400|600,500|500,500", 1)
Check("FindTile outside the area -> '" & $aRes[0] & "'", $aRes[0] = "")
$aRes = CVInterceptDllCall("FindTile", $hBmp, @ScriptDir & "\imgxml\Test\Walls\Wall_13A_92.xml", "FV", 3)
Check("FindTile full view, max 3 -> '" & $aRes[0] & "'", StringLeft($aRes[0], 10) = "1|340,243")
_WinAPI_DeleteObject($hBmp)

_GDIPlus_Shutdown()
ConsoleWrite(($iFail = 0 ? "ALL PASSED" : $iFail & " FAILED") & @CRLF)
Exit $iFail


