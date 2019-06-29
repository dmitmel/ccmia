#!/bin/sh
# In case you're wondering how to port this to Windows:
# I've made rcmp use the "7z" command, which there's a Windows version of.
SDK=`readlink -m \`dirname $0\``
rm -rf "$SDK/repo-build"
mkdir "$SDK/repo-build"
export CCMIA_LOCAL="$SDK/repo"
LUA_PATH="$SDK/?.lua" "$NGLPKG_SDK/env" "$NGLPKG_SDK/run-app.lua" ccmia.main-rcmp

