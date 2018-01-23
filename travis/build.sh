#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)

#INFO
echo "*** Trigger build ***"


#下载SM
echo "Download sourcemod ..."
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz


#设置文件为可执行
echo -e "Set compiler env ..."
chmod +x addons/sourcemod/scripting/spcomp


#更改版本信息
echo -e "Prepare compile ..."
for file in store.sp
do
  sed -i "s%<commit-count>%$COUNT%g" $file > output.txt
  rm output.txt
done


#拷贝文件到编译器文件夹
echo -e "Copy scripts to compiler folder ..."
cp -rf Game/* addons/sourcemod/scripting


#编译...
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/MagicGirl.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-stats.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-user.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/mg-motd.sp