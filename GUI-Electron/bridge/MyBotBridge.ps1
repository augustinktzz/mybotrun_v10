# MyBotBridge.ps1 - pont entre l'interface Electron et les fenetres du bot.
#
# Lance une fois par l'interface (powershell -File), il reste ouvert et lit une commande JSON par ligne sur l'entree
# standard ; il repond une ligne JSON { id, ok, result | error } sur la sortie standard. Il se ferme avec l'interface.
#
# Il parle au bot comme MultiBot : par le message fenetre "MyBot.run/API/1.1" (COCBot\functions\Other\ApiClient.au3).
#   wParam (mot bas) = commande : 0x00FF etat, 0x1000 demarrer, 0x1010 arreter, 0x1020 reprendre, 0x1030 pause, 0x1040 fermer
#   lParam           = notre fenetre, a laquelle le bot repond avec le meme message :
#                      mot haut de wParam = 1 run en cours, 2 en pause, 4 bot lance ; lParam = la fenetre du bot.
# Le bot tourne en administrateur (#RequireAdmin) et Windows jette les messages d'un processus de niveau inferieur :
# l'interface doit donc elle aussi etre lancee en administrateur.
#
# Commandes :
#   { id, cmd: "list" }                                    -> fenetres "My Bot ..." : hwnd, pid, title, commandLine
#   { id, cmd: "ask", hwnd, code, timeout }                -> { bits } ; -1 = pas de reponse, -2 = message refuse
#   { id, cmd: "launch", file, args, cwd }                 -> { pid }  (Start-Process, comme ShellExecute)
#                                                          un .au3 (bot lance depuis ses sources) passe par AutoIt3.exe

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

public class MyBotApi : NativeWindow
{
    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterWindowMessage(string name);
    [DllImport("user32.dll", SetLastError = true)] static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder text, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    public class BotWindow
    {
        public long Hwnd;
        public int Pid;
        public string Title;
    }

    public readonly uint ApiMessage;
    readonly Dictionary<long, int> answers = new Dictionary<long, int>();

    public MyBotApi()
    {
        ApiMessage = RegisterWindowMessage("MyBot.run/API/1.1");
        CreateHandle(new CreateParams()); // fenetre cachee qui recoit les reponses
    }

    protected override void WndProc(ref Message m)
    {
        if ((uint)m.Msg == ApiMessage)
        {
            lock (answers) answers[m.LParam.ToInt64()] = (int)((m.WParam.ToInt64() >> 16) & 0xFFFF);
            return;
        }
        base.WndProc(ref m);
    }

    // les fenetres principales des bots : GUI AutoIt dont le titre commence par "My Bot" (UpdateBotTitle)
    public static List<BotWindow> FindBots()
    {
        var list = new List<BotWindow>();
        EnumWindows(delegate (IntPtr h, IntPtr p)
        {
            var cls = new StringBuilder(64);
            GetClassName(h, cls, cls.Capacity);
            if (cls.ToString() != "AutoIt v3 GUI") return true;
            var title = new StringBuilder(256);
            GetWindowText(h, title, title.Capacity);
            if (!title.ToString().StartsWith("My Bot")) return true;
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            list.Add(new BotWindow { Hwnd = h.ToInt64(), Pid = (int)pid, Title = title.ToString() });
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // envoie une commande et attend la reponse du bot (bits d'etat) ; -1 sans reponse, -2 si Windows refuse le message
    public int Ask(long hwnd, int command, int timeoutMs)
    {
        lock (answers) answers.Remove(hwnd);
        if (!PostMessage(new IntPtr(hwnd), ApiMessage, new IntPtr(command), Handle)) return -2;
        var watch = Stopwatch.StartNew();
        while (watch.ElapsedMilliseconds < timeoutMs)
        {
            Application.DoEvents();
            lock (answers)
            {
                int bits;
                if (answers.TryGetValue(hwnd, out bits)) return bits;
            }
            System.Threading.Thread.Sleep(15);
        }
        return -1;
    }
}
'@

$api = New-Object MyBotApi

function Send-Reply($id, [bool]$ok, $payload) {
    $out = [ordered]@{ id = $id; ok = $ok }
    if ($ok) { $out.result = $payload } else { $out.error = [string]$payload }
    [Console]::Out.WriteLine((ConvertTo-Json -InputObject $out -Compress -Depth 5))
    [Console]::Out.Flush()
}

function Get-BotWindows {
    $bots = @()
    foreach ($w in [MyBotApi]::FindBots()) {
        $cmdLine = ''
        try { $cmdLine = [string](Get-CimInstance Win32_Process -Filter "ProcessId = $($w.Pid)").CommandLine } catch { }
        $bots += [ordered]@{ hwnd = $w.Hwnd; pid = $w.Pid; title = $w.Title; commandLine = $cmdLine }
    }
    return , $bots
}

# AutoIt3.exe 32 bits (le bot refuse de tourner en 64 bits) : celui de l'installation d'AutoIt, pour lancer un .au3
# sans dependre de l'action associee aux .au3 (souvent "Modifier" dans SciTE)
function Find-AutoIt {
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\AutoIt v3\AutoIt', 'HKLM:\SOFTWARE\AutoIt v3\AutoIt') {
        try {
            $dir = (Get-ItemProperty -Path $key -Name InstallDir -ErrorAction Stop).InstallDir
            if ($dir -and (Test-Path (Join-Path $dir 'AutoIt3.exe'))) { return (Join-Path $dir 'AutoIt3.exe') }
        } catch { }
    }
    foreach ($dir in ${env:ProgramFiles(x86)}, $env:ProgramFiles) {
        if ($dir -and (Test-Path (Join-Path $dir 'AutoIt3\AutoIt3.exe'))) { return (Join-Path $dir 'AutoIt3\AutoIt3.exe') }
    }
    throw "AutoIt3.exe introuvable : installez AutoIt (https://www.autoitscript.com) ou utilisez MyBot.run.exe"
}

Send-Reply 0 $true @{ ready = $true; pid = $PID }

while ($true) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) { break } # entree fermee : l'interface est partie
    if ($line.Trim() -eq '') { continue }
    $req = $null
    try {
        $req = ConvertFrom-Json $line
        switch ($req.cmd) {
            'list' { Send-Reply $req.id $true (Get-BotWindows) }
            'ask' { Send-Reply $req.id $true @{ bits = $api.Ask([long]$req.hwnd, [int]$req.code, [int]$req.timeout) } }
            'launch' {
                $file = $req.file
                $argList = $req.args
                if ($file -like '*.au3') {
                    $argList = "`"$file`" $argList"
                    $file = Find-AutoIt
                }
                $proc = Start-Process -FilePath $file -ArgumentList $argList -WorkingDirectory $req.cwd -PassThru
                Send-Reply $req.id $true @{ pid = $proc.Id }
            }
            default { Send-Reply $req.id $false "commande inconnue : $($req.cmd)" }
        }
    }
    catch {
        $id = if ($req) { $req.id } else { -1 }
        Send-Reply $id $false $_.Exception.Message
    }
}
