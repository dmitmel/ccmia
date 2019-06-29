#!/bin/sh
rm -rf reference build
cp -rf "$NGLPKG_SDK/reference" ./
mv reference build
LUA_PATH="$NGLPKG_SDK/?.lua;./?.lua" luajit "$NGLPKG_SDK/bake-app.lua" ng.appsize.bdivide ng.appsize.deflate ccmia.main > build/binary
mv build/PROGRAM build/Installer
chmod +x build/Installer
mv build/PROGRAM.cmd build/Installer.cmd
rm build.zip
cp CCMIA-COPYRIGHT.txt build/
cd build
# NOT RELEVANT HERE, SORRY
rm ZLIB-COPYRIGHT.txt
zip -r ../build.zip .
cd ..
