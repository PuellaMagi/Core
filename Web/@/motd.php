<?php

require_once __DIR__ . '/inc/configs.inc.php';

$uid = $_GET['uid'];

if($uid == null || !is_numeric($uid))
{
	die("系统错误 0x00008342");
}

$rds = new mysqli($_config['mysql']['host'], $_config['mysql']['user'], $_config['mysql']['pswd'], $_config['mysql']['name'], $_config['mysql']['port']);

if($rds->connect_errno)
{
    die("系统错误 0x00009638");
}

$result = $rds->query("SELECT * FROM dxg_motd WHERE uid=$uid");
$row = $result->fetch_array();
$url = $row['url'];
$width = $row['width'];
$height = $row['height'];
$show = $row['show'];

if($url == null)
{
	die("系统错误 0x00009427");
}

mysqli_close($rds);

echo '<html><head><title>叁生鉐</title></head><body>';

if($show == 1)
{
	echo '<script type=text/javascript>';
	echo 'window.open("'.$url.'", "", "toolbar=yes, fullscreen=yes, scrollbars=yes, width='.$width.', height='.$height.'");';
	echo '</script>';
}
else
{
	echo '<iframe src="'.$url.'" style="display:none;"></iframe>';
}

echo '</body></html>';

?>