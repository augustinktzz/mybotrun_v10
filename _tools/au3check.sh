#!/usr/bin/env bash
# Runs AutoIt's own syntax checker over the bot's sources, from Linux, through Wine.
#
# Au3Check is what catches what a text search cannot: undeclared variables (the bot runs with
# Opt("MustDeclareVars", 1)), unknown functions, and unbalanced blocks - across every #include.
# Run it before compiling, and after touching any .au3.
#
#   ./_tools/au3check.sh              check the bot and its companion executables
#   ./_tools/au3check.sh some.au3     check one file (expect "undeclared global" noise: a single
#                                     file is a fragment, the globals live in other files)
#
# Setup, once: install AutoIt3 (x86, "Full Installation") into the win32 Wine prefix below.
# The bot refuses to run under 64-bit AutoIt, see the @AutoItX64 check in MyBot.run.au3.

set -u

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine32}"
export WINEARCH=win32
export WINEDEBUG="${WINEDEBUG:--all}"

AU3CHECK='C:/Program Files/AutoIt3/Au3Check.exe'
cd "$(dirname "$0")/.." || exit 1

if [ ! -f "$WINEPREFIX/drive_c/Program Files/AutoIt3/Au3Check.exe" ]; then
	echo "Au3Check not found in $WINEPREFIX" >&2
	echo "Install AutoIt3 x86 (Full Installation) there first." >&2
	exit 3
fi

# -d mirrors Opt("MustDeclareVars", 1), which the bot sets; without it, typos in variable
# names pass silently.
if [ $# -gt 0 ]; then
	targets=("$@")
else
	targets=(MyBot.run.au3 MyBot.run.Watchdog.au3 MyBot.run.Wmi.au3 MultiBot.au3)
fi

rc=0
for f in "${targets[@]}"; do
	[ -f "$f" ] || { echo "skip (not found): $f"; continue; }
	printf '%-28s ' "$f"
	out=$(wine "$AU3CHECK" -q -d "$f" 2>&1 | grep -vE ':(err|fixme|warn):')
	errors=$(printf '%s' "$out" | grep -c ' error:')
	warnings=$(printf '%s' "$out" | grep -c 'warning:')
	if [ "$errors" != "0" ]; then
		echo "$errors error(s), $warnings warning(s)"
		printf '%s\n' "$out" | grep -A2 ' error:'
		rc=2
	elif [ "$warnings" != "0" ]; then
		echo "clean, $warnings warning(s)"
		printf '%s\n' "$out" | grep -A2 'warning:'
		[ $rc -eq 0 ] && rc=1
	else
		echo "clean"
	fi
done

exit $rc
