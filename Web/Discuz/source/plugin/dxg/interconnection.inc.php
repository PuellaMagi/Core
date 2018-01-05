<?php

if(!defined('IN_DISCUZ')){
	exit('Access Denied');
}

if(!$_G['uid']){

    showmessage('to_login', null, array(), array('showmsg' => true, 'login' => 1));

}

require_once __DIR__ . '/configs.php';
require_once __DIR__ . '/function.php';

$steam64 = -1;
$steam32 = -1;
$steamid = -1;

$module = $_GET['mod'] ? $_GET['mod'] : 'main';

$dzusers = DB::fetch_first("SELECT * FROM dxg_users WHERE uid = $_G[uid]");

$database = mysqli_connect($db_host, $db_user, $db_pswd, $db_name);

if($dzusers['steamID64']){

    $dzusers['name'] = htmlspecialchars(xss_clean($dzusers['steamNickname']));
    $dzusers['avatar_full'] = str_replace(".jpg", "_full.jpg", $dzusers['avatar']);
	$steam64 = $dzusers['steamID64'];
    $steam32 = SteamID64ToSteamID32($steam64, true);
    $steamid = SteamID64ToSteamID32($steam64, false);

    if(($dzusers['lastupdate'] < time()-1800) && UpdateSteamProfiles($database, $api_key, $steam64, $_G['uid'])){

        showmessage('已更新您的Steam账户数据', 'plugin.php?id=dxg');
        die();

    }

}else{

    require_once 'openid.inc.php';
    $openid = new LightOpenID($_SERVER['HTTP_HOST']);

    if(!$openid->mode){

        $openid->identity = 'http://steamcommunity.com/openid';
        header('Location: ' . $openid->authUrl());

    } else{

        if ($openid->validate()){
            
            $steam64 = basename($openid->identity);
            
            if($users = DB::fetch_first("SELECT * FROM dxg_users WHERE steamid = '$steam64'")){
                
                showmessage('此SteamID已关联其他论坛账户', 'forum.php');
                die();
            
            }

            if(!InsertNewUsers($_G['uid'], $steam64, $database)){

                showmessage('同步Steam数据到论坛账户失败', 'forum.php');
                die();

            }

            if(UpdateSteamProfiles($database, $api_key, $steam64, $_G['uid'])){

                showmessage('已更新您的Steam账户数据', 'plugin.php?id=dxg');
                die();

            }

            showmessage('发生异常错误,请重试!', 'plugin.php?id=dxg');

        }else{
            header('Location: $_SERVER[HTTP_HOST]');
        }
    }
}

$file = __DIR__ . '/module/'.$module.'.inc.php';

if(!file_exists($file)){

    showmessage('系统正在建设... 离完善还有一段时日...');

}

$coinnum = C::t('common_member_count')->fetch($_G['uid'])['extcredits1'];

require_once $file;
require_once template('interconnection:template');

mysqli_close($database);

?>