_tools\cv - work files of the bot's own OpenCV engine (not shipped in the zip)
============================================================================

compat_test.au3     checks ImageSearchCVCompat (the DLL call interception) on saved captures. Run it with
                    AutoIt3.exe (32 bit), it must print "ALL PASSED". imgxml\Test\ holds dummy .xml names,
                    imgcv\Test\ the PNG mirrors, captures\ the screens.
ocr_test.au3        checks the glyph OCR (ImageSearchCVOcr) on the main screen counters of the captures.
cvtest.au3          raw OpenCV check: AutoIt3.exe cvtest.au3 <screen.png> <template.png> [threshold] prints
                    the best matches with their score - the tool to pick the threshold of a new template.
Extract-Glyphs.ps1  cuts the glyphs of a known text out of a capture strip:
                    . .\Extract-Glyphs.ps1
                    Extract-Glyphs -Image captures\now.png -X 705 -Y 23 -W 110 -H 16 -Text "7028173" -OutDir ..\..\imgcv\OCR\coc-ms

Migrating a template folder from the DLL to the OpenCV engine
-------------------------------------------------------------
1. Cut PNG templates from 860x732 captures, name them like the DLL files (Name_Level_Threshold.png) and
   put them in imgcv\<same path as under imgxml>\. Thresholds: 80 for UI icons and buttons (the menu
   lists stop between two pixels and blur the art), 75 for village objects; check the negatives with
   cvtest.au3 (the best wrong match must stay well under the threshold).
2. Put a shadow.txt file in the folder: the bot then searches with both engines, writes "CV Search ..."
   and "CV shadow ..." lines in the debug log and keeps the DLL answer.
3. Compare the logs; when the OpenCV result is right, delete shadow.txt: the folder is now served by the
   OpenCV engine and the DLL is not called for it any more.
Fonts follow the same steps under imgcv\OCR\<font>\ (glyph PNGs, see ImageSearchCVOcr.au3): the bot logs
"CV ocr <font>: '...'" next to the value the DLL read.
