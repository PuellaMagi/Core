<?php

require_once __DIR__ . '/../inc/configs.inc.php';
require_once __DIR__ . '/../inc/utils.inc.php';

$redis = new Redis();
$cache = false;

if($redis->connect($_config['redis']['host'], $_config['redis']['port'], 1, NULL, 200)) {

    $redis->auth($_config['redis']['pswd']);
    $redis->select(2);
    $redis->setOption(Redis::OPT_SERIALIZER, Redis::SERIALIZER_PHP);
    $redis->setOption(Redis::OPT_PREFIX, 'api_cache_');
    $cache = true;
    
    //$redis->flushDB();

    // load cache
    $res = json_decode($redis->get('res_list'), true);
    $map = json_decode($redis->get('map_list'), true);
}

if(count($res) < 1 && count($map) < 1) {
    
    $rds = new mysqli($_config['mysql']['host'], $_config['mysql']['user'], $_config['mysql']['pswd'], $_config['mysql']['name'], $_config['mysql']['port']);

    if(!$rds->connect_errno){

        $res = $rds->query("SELECT * FROM dxg_mapdb ORDER by `mod`, `map` ASC");
        while($row = $res->fetch_array())
        {
            $info = array();
            $info['mod'] = $row['mod'];
            $info['map'] = $row['map'];
            $info['crc'] = $row['crc32'];
            $map[] = $info;
            unset($info);
        }
        
        if($cache){
            $redis->set('map_list', json_encode($map), array('nx', 'ex'=>36000));
        }
    }
}

$output = "";

if(isset($_GET['maplist'])){
    foreach($map as $k => $v)
    {
        $output .= ($v['mod'].";".$v['map'].";".$v['crc'].PHP_EOL);
    }
}elseif(isset($_GET['reslist'])){
    foreach($res as $k => $v)
    {
        $output .= ($v['path'].";".$v['crc'].PHP_EOL);
    }
}

header("Content-Type: application/octet-stream");
Header("Accept-Ranges: bytes"); 
header("Content-length: " . strlen($output));
Header("Content-Disposition: attachment; filename=maplist.txt"); 

echo $output;
?>