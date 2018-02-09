#!/bin/bash

FTP_HOST=$2
FTP_USER=$3
FTP_PSWD=$4

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
FILE=$COUNT-$5.7z

echo " "
echo "*** Trigger build ***"
echo " "
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

chmod +x addons/sourcemod/scripting/spcomp

for file in Game/include/MagicGirl.NET.inc
do
  sed -i "s%<commit-count>%$COUNT%g" $file > output.txt
  rm output.txt
done

mkdir build
mkdir build/Game
mkdir build/Game/scripts
mkdir build/Game/plugins
mkdir build/Website

cp -rf Game/* addons/sourcemod/scripting

addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/MagicGirl.sp -o"build/Game/plugins/MagicGirl.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-stats.sp -o"build/Game/plugins/mg-stats.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-user.sp -o"build/Game/plugins/mg-user.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-motd.sp -o"build/Game/plugins/mg-motd.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-vars.sp -o"build/Game/plugins/mg-vars.smx"

mv Web/* build/Website
mv Game/* build/Game/scripts
mv LICENSE build

cd build
7z a $FILE -t7z -mx9 LICENSE Game Website >nul

echo -e "Upload file ..."
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Core/ $FILE"

echo "Upload RAW..."
cd Game/plugins
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ MagicGirl.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ mg-stats.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ mg-user.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ mg-motd.smx"
lftp -c "open -u $FTP_USER,$FTP_PSWD $FTP_HOST; put -O /PuellaMagi/Raw/ mg-vars.smx"