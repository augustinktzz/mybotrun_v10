; #FUNCTION# ====================================================================================================================
; Name ..........: ImageSearchCVOcr
; Description ...: OCR of the game texts with glyph templates, on the bot's own OpenCV engine
; Syntax ........: CVOcr($hHBitmap, $sFont)
; Parameters ....: $hHBitmap - the captured strip (a GDI HBITMAP, what getOcr() receives)
;                  $sFont    - the font name the bot uses ("coc-ms", "coc-loot"...): folder imgcv\OCR\<font>\
; Return values .: the text read, "" when nothing was recognised or the font has no glyph folder
; Remarks .......: This file is part of MyBot Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
;                  A font is a folder of PNG glyphs cut from a real capture, one file per character:
;                    0_88.png ... 9_88.png, colon_88.png (:), slash (/), comma (,), dot (.), percent (%), minus (-),
;                    plus (+), space is never a file, letters as a_88.png (a) or up_L_88.png (L).
;                  The number after the underscore is the match threshold in percent (88 when absent).
;                  Every glyph is matched over the whole strip, the candidates of all glyphs are sorted by score and
;                  kept greedily when they do not overlap an already kept one by more than half a glyph width, then
;                  read left to right. A gap wider than a third of the mean glyph width between two glyphs becomes a
;                  space, as the DLL did (its callers strip or collapse the spaces).
;                  DllCallMyBot("ocr", hBitmap, font) is answered here when imgcv\OCR\<font>\ exists, see
;                  ImageSearchCVCompat.au3; a shadow.txt file in the folder logs the result and leaves the DLL in charge.
; ===============================================================================================================================
#include-once

Global $g_aCVFonts[0][2] ; font name | glyph array

; the glyph set of a font: [n][5] of character, IplImage*, width, height, threshold. 0 rows when the font is unknown.
Func __CVFont($sFont)
	For $i = 0 To UBound($g_aCVFonts) - 1
		If $g_aCVFonts[$i][0] = $sFont Then Return $g_aCVFonts[$i][1]
	Next
	Local $aGlyphs[0][5]
	Local $sDir = $g_sImgCVDir & "OCR\" & $sFont
	If Not FileExists($sDir) Then Return $aGlyphs
	Local $aList = _FileListToArray($sDir, "*.png", $FLTA_FILES, True)
	If @error Or $aList[0] = 0 Then Return $aGlyphs
	If Not CVInit() Then Return $aGlyphs ; the glyphs are OpenCV images
	For $f = 1 To $aList[0]
		Local $sBase = StringRegExpReplace(StringRegExpReplace($aList[$f], ".*\\", ""), "\.[Pp][Nn][Gg]$", "")
		Local $aParts = StringSplit($sBase, "_", $STR_NOCOUNT)
		Local $fThr = 0.88, $sChar = $aParts[0]
		If UBound($aParts) > 1 And StringRegExp($aParts[UBound($aParts) - 1], "^\d+$") Then $fThr = Number($aParts[UBound($aParts) - 1]) / 100
		If $sChar = "up" And UBound($aParts) > 2 Then $sChar = StringUpper($aParts[1])
		Switch $sChar
			Case "colon"
				$sChar = ":"
			Case "slash"
				$sChar = "/"
			Case "comma"
				$sChar = ","
			Case "dot"
				$sChar = "."
			Case "percent"
				$sChar = "%"
			Case "minus"
				$sChar = "-"
			Case "plus"
				$sChar = "+"
		EndSwitch
		Local $aTpl = __CVTemplate($aList[$f])
		If $aTpl[0] = 0 Then ContinueLoop
		Local $n = UBound($aGlyphs)
		ReDim $aGlyphs[$n + 1][5]
		$aGlyphs[$n][0] = $sChar
		$aGlyphs[$n][1] = $aTpl[0]
		$aGlyphs[$n][2] = $aTpl[1]
		$aGlyphs[$n][3] = $aTpl[2]
		$aGlyphs[$n][4] = $fThr
	Next
	If UBound($aGlyphs) = 0 Then Return $aGlyphs ; nothing usable, not cached so a later call can retry
	Local $m = UBound($g_aCVFonts)
	ReDim $g_aCVFonts[$m + 1][2]
	$g_aCVFonts[$m][0] = $sFont
	$g_aCVFonts[$m][1] = $aGlyphs
	Return $aGlyphs
EndFunc   ;==>__CVFont

Func CVOcrFontExists($sFont)
	Return UBound(__CVFont($sFont)) > 0
EndFunc   ;==>CVOcrFontExists

Func CVOcr($hHBitmap, $sFont)
	Local $aGlyphs = __CVFont($sFont)
	If UBound($aGlyphs) = 0 Then Return ""
	If Not CVInit() Then Return ""
	Local $iW, $iH
	Local $pImg = __CVImageFromHBitmap($hHBitmap, $iW, $iH)
	If $pImg = 0 Then Return ""
	Return CVOcrImage($pImg, $iW, $iH, $aGlyphs, True)
EndFunc   ;==>CVOcr

; The recognition itself on an IplImage* (released when $bRelease). Candidates: [x left, x right, score, char].
Func CVOcrImage($pImg, $iW, $iH, $aGlyphs, $bRelease = False)
	Local $aCand[0][4]
	Local $fWidthSum = 0, $iWidthCount = 0
	For $g = 0 To UBound($aGlyphs) - 1
		Local $aHits = __CVMatch($pImg, $iW, $iH, $aGlyphs[$g][1], $aGlyphs[$g][2], $aGlyphs[$g][3], $aGlyphs[$g][4], 40)
		For $i = 0 To UBound($aHits) - 1
			Local $n = UBound($aCand)
			ReDim $aCand[$n + 1][4]
			$aCand[$n][0] = $aHits[$i][0]
			$aCand[$n][1] = $aHits[$i][0] + $aGlyphs[$g][2] - 1
			$aCand[$n][2] = $aHits[$i][2]
			$aCand[$n][3] = $aGlyphs[$g][0]
		Next
	Next
	If $bRelease Then __CVReleaseImage($pImg)
	If UBound($aCand) = 0 Then Return ""

	; best first, then keep what does not sit on an already kept glyph
	_ArraySort($aCand, 1, 0, 0, 2)
	Local $aKept[0][4]
	For $i = 0 To UBound($aCand) - 1
		Local $bFree = True
		For $k = 0 To UBound($aKept) - 1
			Local $iOverlap = _Min($aCand[$i][1], $aKept[$k][1]) - _Max($aCand[$i][0], $aKept[$k][0]) + 1
			Local $iNarrow = _Min($aCand[$i][1] - $aCand[$i][0], $aKept[$k][1] - $aKept[$k][0]) + 1
			If $iOverlap > $iNarrow / 2 Then
				$bFree = False
				ExitLoop
			EndIf
		Next
		If Not $bFree Then ContinueLoop
		Local $n = UBound($aKept)
		ReDim $aKept[$n + 1][4]
		$aKept[$n][0] = $aCand[$i][0]
		$aKept[$n][1] = $aCand[$i][1]
		$aKept[$n][2] = $aCand[$i][2]
		$aKept[$n][3] = $aCand[$i][3]
		$fWidthSum += $aCand[$i][1] - $aCand[$i][0] + 1
		$iWidthCount += 1
	Next
	_ArraySort($aKept, 0, 0, 0, 0) ; left to right
	Local $fMeanWidth = $fWidthSum / $iWidthCount
	Local $sText = ""
	For $i = 0 To UBound($aKept) - 1
		If $i > 0 And $aKept[$i][0] - $aKept[$i - 1][1] - 1 > $fMeanWidth / 3 Then $sText &= " "
		$sText &= $aKept[$i][3]
	Next
	Return $sText
EndFunc   ;==>CVOcrImage
