; MyBotBridge.au3 - pont entre l'interface Electron et les fenetres du bot, sous Linux.
;
; Sous Linux le bot tourne dans Wine : un programme Linux ne peut pas envoyer de message a ses fenetres. Ce pont tourne
; donc lui aussi dans Wine (wine AutoIt3.exe MyBotBridge.au3, lance par lib/bot.js) et parle exactement comme
; MyBotBridge.ps1, le pont de Windows : une commande JSON par ligne sur l'entree standard, une reponse JSON
; { id, ok, result | error } par ligne sur la sortie standard. Il se ferme quand l'interface ferme son entree.
;
; Il parle au bot comme MultiBot : par le message fenetre "MyBot.run/API/1.1" (COCBot\functions\Other\ApiClient.au3).
;   wParam (mot bas) = commande : 0x00FF etat, 0x1000 demarrer, 0x1010 arreter, 0x1020 reprendre, 0x1030 pause, 0x1040 fermer
;   lParam           = notre fenetre, a laquelle le bot repond avec le meme message :
;                      mot bas de wParam = 1 pour l'etat, commande + 1 sinon ; mot haut = 1 run en cours, 2 en pause,
;                      4 bot lance ; lParam = la fenetre du bot.
; Une reponse n'est acceptee que si son mot bas correspond a la commande envoyee : une reponse arrivee trop tard pour
; une commande precedente n'est pas prise pour celle de la suivante.
;
; Commandes :
;   { id, cmd: "list" }                                    -> fenetres "My Bot ..." : hwnd, pid, title, commandLine
;   { id, cmd: "ask", hwnd, code, timeout }                -> { bits } ; -1 = pas de reponse, -2 = message refuse
;   { id, cmd: "launch", file, args, cwd }                 -> { pid }  (ShellExecute, comme Start-Process)
;
; Les chaines echangees sont en ASCII : l'interface echappe tout autre caractere en \uXXXX, et ce pont fait de meme.

#NoTrayIcon
#include <WinAPISysWin.au3>
#include <WinAPIProc.au3>
#include <StringConstants.au3>

Opt("MustDeclareVars", 1)

Global Const $g_iApiMessage = _WinAPI_RegisterWindowMessage("MyBot.run/API/1.1")
Global $g_hBridge = GUICreate("MyBotBridge") ; fenetre cachee qui recoit les reponses
Global $g_iAnswerFrom = 0, $g_iAnswerWParam = 0, $g_bAnswered = False
GUIRegisterMsg($g_iApiMessage, "OnBotAnswer")

Main()

Func Main()
	Reply(0, True, '{"ready":true,"pid":' & @AutoItPID & '}')
	Local $sBuffer = ""
	While 1
		Local $sChunk = ConsoleRead()
		If @error Then ExitLoop ; entree fermee : l'interface est partie
		If $sChunk = "" Then
			Sleep(10)
			ContinueLoop
		EndIf
		$sBuffer &= $sChunk
		Local $iLf = StringInStr($sBuffer, @LF)
		While $iLf > 0
			Local $sLine = StringStripWS(StringLeft($sBuffer, $iLf - 1), $STR_STRIPLEADING + $STR_STRIPTRAILING)
			$sBuffer = StringMid($sBuffer, $iLf + 1)
			If $sLine <> "" Then Handle($sLine)
			$iLf = StringInStr($sBuffer, @LF)
		WEnd
	WEnd
	GUIDelete($g_hBridge)
EndFunc   ;==>Main

Func Handle($sLine)
	Local $iId = Number(JsonGet($sLine, "id"))
	Local $sCmd = JsonGet($sLine, "cmd")
	Switch $sCmd
		Case "list"
			Reply($iId, True, ListBots())
		Case "ask"
			Local $iBits = Ask(Number(JsonGet($sLine, "hwnd")), Number(JsonGet($sLine, "code")), Number(JsonGet($sLine, "timeout")))
			Reply($iId, True, '{"bits":' & $iBits & '}')
		Case "launch"
			Local $iPid = Launch(JsonGet($sLine, "file"), JsonGet($sLine, "args"), JsonGet($sLine, "cwd"))
			If $iPid > 0 Then
				Reply($iId, True, '{"pid":' & $iPid & '}')
			Else
				Reply($iId, False, JsonString("impossible de lancer " & JsonGet($sLine, "file")))
			EndIf
		Case Else
			Reply($iId, False, JsonString("commande inconnue : " & $sCmd))
	EndSwitch
EndFunc   ;==>Handle

; les fenetres principales des bots : GUI AutoIt dont le titre commence par "My Bot" (UpdateBotTitle)
Func ListBots()
	Local $aWins = WinList("[REGEXPTITLE:^My Bot]")
	Local $sOut = "", $i
	For $i = 1 To $aWins[0][0]
		Local $hWnd = $aWins[$i][1]
		If _WinAPI_GetClassName($hWnd) <> "AutoIt v3 GUI" Then ContinueLoop
		Local $iPid = WinGetProcess($hWnd)
		; comme la CommandLine de WMI : l'executable entre guillemets, puis ses arguments
		Local $sPath = _WinAPI_GetProcessFileName($iPid)
		Local $sArgs = _WinAPI_GetProcessCommandLine($iPid)
		Local $sCmdLine = ($sPath = "" ? "" : '"' & $sPath & '"' & ($sArgs = "" ? "" : " " & $sArgs))
		If $sOut <> "" Then $sOut &= ","
		$sOut &= '{"hwnd":' & Int($hWnd) & ',"pid":' & $iPid & ',"title":' & JsonString($aWins[$i][0]) & ',"commandLine":' & JsonString($sCmdLine) & '}'
	Next
	Return "[" & $sOut & "]"
EndFunc   ;==>ListBots

; envoie une commande et attend la reponse du bot (bits d'etat) ; -1 sans reponse, -2 si le message est refuse
Func Ask($iHwnd, $iCode, $iTimeout)
	If $iTimeout <= 0 Then $iTimeout = 1500
	Local $iExpected = ($iCode <= 0xFF ? 1 : $iCode + 1)
	$g_bAnswered = False
	If Not _WinAPI_PostMessage(HWnd($iHwnd), $g_iApiMessage, $iCode, $g_hBridge) Then Return -2
	Local $hTimer = TimerInit()
	While TimerDiff($hTimer) < $iTimeout
		Sleep(10) ; AutoIt traite les messages pendant Sleep : la reponse arrive dans OnBotAnswer
		If $g_bAnswered Then
			$g_bAnswered = False
			If $g_iAnswerFrom = $iHwnd And BitAND($g_iAnswerWParam, 0xFFFF) = $iExpected Then Return BitAND(BitShift($g_iAnswerWParam, 16), 0xFFFF)
		EndIf
	WEnd
	Return -1
EndFunc   ;==>Ask

Func OnBotAnswer($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg
	$g_iAnswerFrom = Int($lParam)
	$g_iAnswerWParam = Int($wParam)
	$g_bAnswered = True
	Return 0
EndFunc   ;==>OnBotAnswer

; comme Start-Process : sans lien avec les entrees / sorties du pont. Un .au3 est lance par cet AutoIt3.exe.
Func Launch($sFile, $sArgs, $sCwd)
	Local $iPid
	If StringRight($sFile, 4) = ".au3" Then
		$iPid = ShellExecute(@AutoItExe, '"' & $sFile & '" ' & $sArgs, $sCwd)
	Else
		$iPid = ShellExecute($sFile, $sArgs, $sCwd)
	EndIf
	If @error Then Return 0
	Return $iPid
EndFunc   ;==>Launch

Func Reply($iId, $bOk, $sPayloadJson)
	ConsoleWrite('{"id":' & $iId & ',"ok":' & ($bOk ? 'true,"result":' : 'false,"error":') & $sPayloadJson & '}' & @LF)
EndFunc   ;==>Reply

; ------------------------------------------------------------------ JSON (juste ce que ce protocole utilise)

; chaine JSON en ASCII pur : tout caractere hors ASCII imprimable est echappe en \uXXXX
Func JsonString($s)
	Local $sOut = '"', $i, $c, $n
	For $i = 1 To StringLen($s)
		$c = StringMid($s, $i, 1)
		$n = AscW($c)
		If $c = '"' Then
			$sOut &= '\"'
		ElseIf $c = '\' Then
			$sOut &= '\\'
		ElseIf $n < 32 Or $n > 126 Then
			$sOut &= '\u' & StringLower(Hex($n, 4))
		Else
			$sOut &= $c
		EndIf
	Next
	Return $sOut & '"'
EndFunc   ;==>JsonString

; valeur d'une cle de premier niveau d'un objet JSON plat : chaine decodee, ou texte du nombre ; "" si absente
Func JsonGet($sJson, $sKey)
	Local $a = StringRegExp($sJson, '"' & $sKey & '"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|true|false|null)', $STR_REGEXPARRAYMATCH)
	If @error Then Return ""
	Local $v = $a[0]
	If StringLeft($v, 1) <> '"' Then Return ($v = "null" ? "" : $v)
	Return JsonUnescape(StringMid($v, 2, StringLen($v) - 2))
EndFunc   ;==>JsonGet

Func JsonUnescape($s)
	Local $sOut = "", $i = 1, $c
	While $i <= StringLen($s)
		$c = StringMid($s, $i, 1)
		If $c <> '\' Then
			$sOut &= $c
			$i += 1
			ContinueLoop
		EndIf
		$c = StringMid($s, $i + 1, 1)
		Switch $c
			Case "n"
				$sOut &= @LF
			Case "r"
				$sOut &= @CR
			Case "t"
				$sOut &= @TAB
			Case "b"
				$sOut &= Chr(8)
			Case "f"
				$sOut &= Chr(12)
			Case "u"
				$sOut &= ChrW(Dec(StringMid($s, $i + 2, 4)))
				$i += 4
			Case Else ; \" \\ \/
				$sOut &= $c
		EndSwitch
		$i += 2
	WEnd
	Return $sOut
EndFunc   ;==>JsonUnescape
