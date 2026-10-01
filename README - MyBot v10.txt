MyBot v12.0.0 BETA - Clash of Clans bot (based on MyBot.run 8.2, updated for CoC 18.600 and BlueStacks 5)
========================================================================================================

Support: Telegram @augustinktzz

REQUIREMENTS
------------
- Windows 10 or 11, 64 bit.
- BlueStacks 5 (tested with 5.22). In the Multi-instance Manager, an Android 9 "Pie 64 bit"
  instance named  Pie64  (the default name of the first Pie 64 instance).
- Clash of Clans installed and logged in on that instance, with the village loaded at least once.
- Node.js 20 or later (https://nodejs.org), once: the bot's interface (GUI-Electron) runs on it.
  Nothing else to install: no AutoIt, no Python. The bot sets the instance resolution itself
  (860 x 732) on the first start; if it asks to restart BlueStacks, accept.

INSTALL
-------
1. Unzip the folder wherever you like (Documents, Desktop...). Not inside "Program Files".
2. Add the folder to your antivirus exclusions: the bot reads the screen and clicks for you, which
   some antivirus products block.
3. Start BlueStacks with CoC open on your village.
4. Double-click  "Lancer MyBot GUI.bat"  (the first time it installs Electron, about a minute).
   The bot has no window of its own any more: this interface launches it and drives it.
   Profiles page: profile (default "MyVillage", created on the first start), emulator, instance.
5. Village page: tick what the bot should handle (collecting, treasury, donations...).
   Army and Attack pages: choose your army and your search strategy. Save (Ctrl+S).
   Dashboard: "Open the bot", then  Start . The Log page shows what the bot does.

UPDATING
--------
Your settings live in  Profiles\<profile name>\  and the zip only ships an empty Profiles folder:
- unzip the new version OVER the old folder (accept replacing the files);
- or unzip elsewhere and copy your old  Profiles\  folder into it.
Nothing to set up again: new options take their default value, everything else is kept.

SEVERAL VILLAGES AT ONCE (MultiBot)
-----------------------------------
MultiBot.exe, next to the bot, runs one bot per village: each bot has its own profile and its own
BlueStacks instance (Multi-instance Manager > New instance, Android 9 Pie 64 bit, one instance per
village, each with CoC logged into its village).
- New setup: a profile name (created on the first start), the instance (the list comes from BlueStacks),
  and the launch options: hide the emulator, no Watchdog, start the run at once ("Mini GUI" no longer
  does anything: the bot has no window).
  The lower groups are settings of that bot's profile: window arrangement and offsets to place the
  setups side by side, screen capture mode, dedicated ADB port (tick it with several instances),
  processor cores and threads, and the Halt attack condition of the Bot page.
- Start all bots / Close all bots, or per setup with the right click: start, close, restart, but
  also start the run, stop it, pause and resume without closing the bot, plus the instance itself.
- The State column follows each bot (Off, Starting, Idle, Running, Paused).
- "Start with Windows" puts a shortcut of that setup in the Startup folder; "Desktop shortcut" makes
  one on the Desktop.
Close comes from the bot itself (as its Exit button): the settings are saved and the Watchdog ends
with it. A bot killed from the task manager is relaunched by its Watchdog: use MultiBot instead.
"Bots active at once" (Bot page) tells how many bots may search and attack at the same time;
the others wait their turn. Half of the processor cores is a good value.

NOTIFICATIONS (Notifications page)
----------------------------------
Telegram: create a bot with @BotFather, paste its token, tick "Enable Telegram", open your bot in
          Telegram and send it /start, then save (Ctrl+S).
Discord:  tick "Enable Discord", paste the webhook URL (Channel > Edit Channel > Integrations >
          Webhooks > Copy Webhook URL), then save (Ctrl+S).
The first message comes when the bot starts.
Both channels get the same messages: attack reports, stats and alerts. The last raid is posted to
Discord as a card with loot, stars, destruction and league, and the raid screenshot attached.

DISCORD STATUS ON YOUR PROFILE (Rich Presence)
----------------------------------------------
Notifications page > "Discord status" shows on your own Discord profile what the bot is doing: your Town
Hall level and profile name, the gold / elixir / dark elixir you have, and how long the bot has been
running. Off by default. It needs the Discord application running on the same PC (nothing leaves your
machine: the bot talks to Discord through a local pipe, Discord publishes the status).

Setup, once:
1. Go to discord.com/developers/applications and press "New Application". Name it as you like, that
   name is what Discord shows above the status.
2. Copy the "Application ID" and paste it in the box next to the option.
3. Optional, for the pictures: in that application, Rich Presence > Art Assets, add a large image named
   village and two small ones named running and paused.
4. The "Link" box adds a "Join the server" button under your status; the field next to it holds the
   invite it opens (right click on your server in Discord > Invite People > Copy). Empty = no button.
The status follows what you type as soon as you leave the box, bot running or not: no restart needed.
If the option is on and your profile shows nothing, the log says why (no ID, ID refused, Discord not
running).

WARNING: this status is public. Anyone who can see your Discord profile sees that the bot is running,
and your resources. Leave the option off if you do not want that.

LEAGUE
------
Since CoC 18.600 there are no trophies any more: the league is a tier from 1 (Skeleton 1) to 36
(Legend I), read on the badge of the main screen. The search filters and the "Max.League" stop
conditions use that number.

SIEGE MACHINES AND SPELLS
-------------------------
Attack page > Dead Base (and Active Base) > Attack:
- "Use siege machine" deploys the machine loaded in your Clan Castle, whichever one it is. Untick it
  to keep the machine for a war; the castle troops are still dropped by the "Clan Castle" option next
  to it. Leave the list beside them on "Default" unless you really want to force one machine.
- The spell boxes on the rows below are now used by the Standard and SmartFarm attacks: the spells
  you tick are dropped on the push, right after the heroes. Nothing is dropped if you tick nothing,
  and Lightning and Earthquake stay reserved when Smart Zap is on.

SEASON PASS
-----------
Village page > Misc > "Collect Challenge Rewards": every few hours the bot opens the season pass, claims
the rewards you have reached (the green cards), scrolls the track back to catch the ones behind,
and closes it. When a reward offers two options, the "Pass choice" list beside it decides: the
resource (gold, elixir, dark elixir), the magic item, or always the left one.

BUILDER BASE
------------
The Notifications page has a "Builder Base raid" option: at the end of each builder base attack cycle the
bot posts the number of attacks, the gold, elixir and trophies the cycle brought in, and a screenshot
of the base. It is a Discord card when a webhook is set, a plain message on Telegram.

WALLS
-----
The bot uses the game's Upgrade More button: every wall of the searched level that your gold or
elixir can pay, once the Min. Gold / Min. Elixir to save is kept, is upgraded in a single batch. There
is nothing to set. The batch shrinks by itself when the walls left at that level do not allow it, and
gold and elixir are never mixed in one batch. The builder base does the same with its wall suggestions.

OWN IMAGE TEMPLATES (imgcv)
---------------------------
The bot has a second image search engine of its own, built on the OpenCV libraries shipped in lib\: it
searches plain PNG templates stored in imgcv\. Cut them from a screenshot at the bot's resolution
(860 x 732, the screenshots in Profiles\<profile>\Temp\Debug are the right size) and drop them in the
right folder, no tool needed:
- imgcv\own\Walls\<level>\ holds the pieces of wall (corners, junctions...) the encrypted templates
  cannot see; each hit is still verified by reading the wall's info bar. One folder per level, and all
  of them optional: with no folder at all the bot still upgrades walls of any level through the
  builder menu;
- imgcv\<same path as imgxml>\ mirrors a DLL template folder: once it holds PNG files, that folder is
  searched by the OpenCV engine instead of the DLL (the 400 image searches of the bot need no change);
- imgcv\OCR\<font>\ holds the glyphs of a font: the text is then read by the bot itself.
A shadow.txt file in a folder makes the bot run both engines and only log the OpenCV result, which is
how a migrated folder is validated before the switch. The folders shipped with shadow.txt are being
validated: nothing changes for you, the log just shows "CV ..." lines. See imgcv\README.txt.

THE INTERFACE (GUI-Electron, Windows and Linux)
-----------------------------------------------
GUI-Electron\ is the bot's interface: dashboard, live log, attack log, every setting of the profile,
strategies and profiles. The former AutoIt window of the bot is gone: the bot runs without a window,
the interface launches it, sends it Start / Pause / Stop / Close and edits the profile files.
- Needs Node.js 20 or later (https://nodejs.org), once. The first start installs Electron.
- Windows: double-click  "Lancer MyBot GUI.bat"  (it restarts as administrator, like the bot).
- Linux: ./"Lancer MyBot GUI.sh"  with the bot in Wine (AutoIt + .NET 4.8 in the prefix) and the
  Generic emulator. Details in GUI-Electron\README.md.
- Settings are saved only while the bot of that profile is closed (the bot rewrites them on exit).

IF SOMETHING GOES WRONG
-----------------------
- The full log is in  Profiles\<profile>\Logs\ .
- Whenever the bot does not recognise a screen (button not found...), it keeps a screenshot in
  Profiles\<profile>\Temp\Debug\ . Send the log and that screenshot to support.
- The bot cannot find the village at start: check that CoC is on the village (not on a popup),
  that the instance is named Pie64, and that BlueStacks accepted the 860 x 732 resolution.
- Do not modify anything in  imgxml\  or  MyBot.run.dll : the bot would refuse to start.

The bot is licensed under GPL v3 (see License.txt). The sources are in the COCBot folder.
