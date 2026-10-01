#!/bin/bash
# Builds lib/adb.scripts/mybot-touch.dex from MyBotTouch.java. Needs a Java 11+ with the jdk.compiler module and
# Google's D8 (r8.jar, https://dl.google.com/android/maven2/com/android/tools/r8/), path in $R8_JAR.
set -e
here=$(cd "$(dirname "$0")" && pwd)
r8=${R8_JAR:-$HOME/.local/share/r8/r8.jar}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
java -m jdk.compiler/com.sun.tools.javac.Main -source 11 -target 11 -nowarn -Xlint:-options -d "$tmp/classes" "$here/MyBotTouch.java"
java -cp "$r8" com.android.tools.r8.D8 --release --min-api 21 --output "$tmp" "$tmp"/classes/*.class
cp "$tmp/classes.dex" "$here/../../lib/adb.scripts/mybot-touch.dex"
echo "built lib/adb.scripts/mybot-touch.dex"
