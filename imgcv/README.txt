imgcv - the bot's own image templates (OpenCV)
==============================================

Plain PNG files searched by the bot with OpenCV template matching, next to the encrypted templates of
MyBot.run.dll. Anyone can add one: take a screenshot of the game at the bot's resolution (860 x 732, the
screenshots in Profiles\<profile>\Temp\Debug are exactly that), cut the object with any image editor,
save it as PNG in the right folder. Keep the cut tight (only the object, a few pixels of background at
most), never resize it.

Three kinds of folders
----------------------
own\<group>\            templates used by the bot's own code, e.g. own\Walls\<level>\*.png: pieces of wall
                        of that level (corners, junctions, single pieces...) tried when the DLL search finds
                        no straight run any more. A bad template only costs a click, every hit is verified.
                        own\ReturnHome\*.png: the villager's "Return Home" button, bottom left of the Clan
                        Wars page and the other pages the bot has to leave (checkObstacles presses it).

<same path as imgxml>\  a MIRROR of a DLL template folder, e.g. Resources\Auto Upgrade\ResourceIcon\.
                        As soon as such a folder holds a PNG, every search of the matching imgxml folder is
                        answered by the OpenCV engine instead of the DLL. Files are named like the DLL ones:
                        Name_Level_Threshold.png (Elix_0_80.png = object "Elix", level 0, match at 80 %).

OCR\<font>\             the glyphs of a font the bot reads with the DLL ("coc-ms" = the main screen
                        counters...): 0_88.png ... 9_88.png, colon, slash, comma, dot, percent, minus, plus,
                        letters as a_88.png or up_L_88.png. When the folder exists the text is read here.

shadow.txt              put this file in a mirror or a font folder to VALIDATE it: the bot uses both
                        engines, writes the OpenCV result in the debug log ("CV Search ...", "CV shadow ...",
                        "CV ocr ...") and keeps the DLL answer. Delete the file to switch for good.

Thresholds: 80 for interface icons and buttons, 75 for village objects, 88 for glyphs. The tools to
check a template against captures are in _tools\cv (developer folder, not in the zip).
