#!/bin/sh
SDK=`readlink -m \`dirname $0\``
LUA_PATH="$SDK/?.lua" "$NGLPKG_SDK/env" "$NGLPKG_SDK/run-app.lua" ccmia.main $*

