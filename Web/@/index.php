<?php

//tracking
$Processed = -microtime(true);
$queries = 0;
$cacheleft = 0;

require_once __DIR__ . '/inc/configs.inc.php';
require_once __DIR__ . '/inc/utils.inc.php';

// cache
$redis = new Redis();
$cache = false;

// mysql
$row = array();
$res = null;

//data
$global = array();
$server = array();
$srcdsi = array();

ini_set('max_execution_time', 60);
$lockfile = __DIR__ . '/inc/query.lock';
while(file_exists($lockfile))
{
    usleep(1000000);
}

if($redis->connect($_config['redis']['host'], $_config['redis']['port'], 1, NULL, 200)) {

    $redis->auth($_config['redis']['pswd']);
    $redis->select(1);
    $redis->setOption(Redis::OPT_SERIALIZER, Redis::SERIALIZER_PHP);
    $redis->setOption(Redis::OPT_PREFIX, 'dashboard_cache_');
    $cache = true;
    
    //$redis->flushDB();

    // load cache
    $global = json_decode($redis->get('dashboard_global'), true);
    $server = json_decode($redis->get('dashboard_server'), true);
}

// rebuild cache
if(count($global) < 1 || count($server) < 1) {

    $rds = new mysqli($_config['mysql']['host'], $_config['mysql']['user'], $_config['mysql']['pswd'], $_config['mysql']['name'], $_config['mysql']['port']);

    if(!$rds->connect_errno){

        //get active connect time
        $res = $rds->query("SELECT COUNT(uid) AS active FROM `dxg_users` WHERE lastseen > UNIX_TIMESTAMP()-7776000");
        $queries++;
        $row = $res->fetch_array();
        $global['active'] = $row['active'];

        //get times connected
        $res = $rds->query("SELECT COUNT(id) AS connects FROM `dxg_analytics` WHERE connect_time > UNIX_TIMESTAMP()-7776000");
        $queries++;
        $row = $res->fetch_array();
        $global['connect'] = $row['connects'];
        
        //get total time
        $res = $rds->query("SELECT SUM(onlineTotal) AS time FROM `dxg_stats`");
        $queries++;
        $row = $res->fetch_array();
        $global['time'] = $row['time'];
        
        //get new players
        $thismonth = strtotime(date("Y-m"));
        $res = $rds->query("SELECT Count(uid) as newbee FROM `dxg_users` WHERE firstjoin >= $thismonth");
        $queries++;
        $row = $res->fetch_array();
        $global['newbee'] = $row['newbee'];

        //get total players
        $res = $rds->query("SELECT Count(uid) as players FROM `dxg_users`");
        $queries++;
        $row = $res->fetch_array();
        $global['players'] = $row['players'];

        //get server
        $res = $rds->query("SELECT * FROM `dxg_servers` WHERE ip not like '127.0.0.1' ORDER BY sid");
        $queries++;
        while($row = $res->fetch_array())
        {
            $dat = array();
            $dat['id'] = $row['sid'];
            $dat['ip'] = $row['ip'];
            $dat['pt'] = $row['port'];
            $dat['ne'] = $row['name'];
            $server[] = $dat;
        }

        if($cache){

            $redis->set('dashboard_global', json_encode($global), array('nx', 'ex'=>3600));
            $redis->set('dashboard_server', json_encode($server), array('nx', 'ex'=>3600));
        }
    }
}

$total = 0;
$query = array();
$global['current'] = 0;
$srcds = 0;

foreach($server as $srv)
{
    $addr = $srv['ip'] . ":" . $srv['pt'];
    $load = true;
    
    if($cache){
        $serverInfo = json_decode($redis->get($addr), true);
        $cacheleft = $redis->ttl($addr);
    }

    if(count($serverInfo) < 1){

        $load = false;
        $retry = 0;
        $serverInfo = null;

        if(!file_exists($lockfile))
            file_put_contents($lockfile, "Source Engine Query");

        do
        {
            $serverInfo = QuerySRCDSInfo($addr);
            $srcds++;
            $retry++;
            
            if($retry > 3)
                break;

        } while($serverInfo === null);

        if($serverInfo === null){
            $serverInfo['Error'] = true;
            $serverInfo['HostName'] = $srv['ne']."(" . $addr . ")查询失败...";
        }
    }

    $serverInfo['ip'] = $addr;
    $serverInfo['id'] = $srv['id'];

    $query[] = $serverInfo;

    if(!isset($serverInfo['Error']))
    {
        $total++;
        $global['current'] += $serverInfo['Players'];
    }

    if(!$load && $cache){
        $redis->set($addr, json_encode($serverInfo), array('nx', 'ex'=>180));
    }
}

?>
<html data-ng-app="app">
    <head>
        <title>MagicGirl.Net - Homepage</title>
        <meta name="author" content="Kyle and JH10001" />
        <meta name="copyright" content="2018 Kyle and JH10001" />
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="icon" href="image/icon.ico" type="image/x-icon" />
		<link rel="shortcut icon" href="image/icon.ico" type="image/x-icon" />
		<link rel="apple-touch-icon-precomposed" href="image/logo.png" />
        <link href="css/bootsteam.min.css" rel="stylesheet" />
        <link href="css/sb-admin-2.min.css" rel="stylesheet" />
        <link href="css/font-awesome.min.css" rel="stylesheet" />
        <!--<script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.5.6/angular.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.4.0/angular-animate.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/angular-ui-bootstrap/1.3.3/ui-bootstrap-tpls.min.js"></script>
        <script src="js/main.js"></script>-->
        <style>main{margin-top:30px;}</style>
    </head>
    <body data-ng-controller="demoController as vm" style="background: url('image/background.png'); background-repeat: repeat-xy; background-attachment: fixed; width:100%; height:100%;">

        <!-- NAV bar -->
        <nav class="navbar navbar-default navbar-fixed-top" data-spy="affix" data-offset-top="485">
            <div class="container">
                <div class="navbar-header">
                    <button type="button" class="navbar-toggle collapsed" data-ng-click="isCollapsed1 = !isCollapsed1" data-ng-class="{'navbar-open': isCollapsed1}">
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </button>
                    <a class="navbar-brand" href="/">
                        <span><img src="image/logo.png" width="32" height="32"> PuellaMagi </span>
                    </a>
                </div>
                <div class="collapse navbar-collapse" data-uib-collapse="!isCollapsed1">
                    <ul class="nav navbar-nav navbar-left">
                        <li><a href="#"><font size="3">首页</a></font></li>
                    </ul>
                </div>
            </div>
        </nav>

        <main class="container">
            <data-uib-accordion data-close-others="true" class="bootstrap-css">
                
                <div class="content">
                    <div class="page-header"></div>
                    <div class="panel panel-info">
                        <div class="panel-heading">
                            <h3 class="panel-title">公告板</h3>
                        </div>
                        <div class="panel-body">
                            <br/>
                            <p> 如果你想申请开一个属于你自己的CSGO/INS社区服务器. </p>
                            <p> 编辑你的想法发送到邮箱  30486416[AT]qq[DOT]com .</p>
                            <br/>
                        </div>
                    </div>

                    <div class="page-header"></div>
                    <div class="row">
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-green">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3 fa fa-user fa-5x" aria-hidden="true"></div>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $global['current']; ?></div>
                                            当前在线人数(人)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-primary">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-user-plus fa-5x" aria-hidden="true"></i>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $global['newbee']; ?></div>
                                            本月新增玩家(人)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-yellow">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-gamepad fa-5x" aria-hidden="true"></i>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $global['active']; ?></div>
                                            本月活跃玩家(人)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-red">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-users fa-5x" aria-hidden="true"></i>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $global['players']; ?></div>
                                            玩家总数(人)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-yellow">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-server fa-5x" aria-hidden="true"></i>
                                        <!--<i class="fa fa-globe" aria-hidden="true"></i>-->
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $total; ?></div>
                                            服务器在线(组)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-red">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-tasks fa-5x" aria-hidden="true"></i>
                                        <!--<i class="fa fa-globe" aria-hidden="true"></i>-->
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo (ceil((time()-1516536000)/3600)); ?></div>
                                            服务器已运行(小时)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-primary">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-tachometer  fa-5x" aria-hidden="true"></i>
                                        <!--<i class="fa fa-globe" aria-hidden="true"></i>-->
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo $global['connect']; ?></div>
                                            累计连线次数(次)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-md-6">
                            <div class="panel panel-green">
                                <div class="panel-heading">
                                    <div class="row">
                                        <i class="col-xs-3 fa fa-clock-o fa-5x" aria-hidden="true"></i>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge"><?php echo (ceil($global['time']/3600)); ?></div>
                                            累计游戏时间(小时)
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="page-header"></div>
                    <div class="panel panel-default">
                        <div class="panel-heading"></div>
                        <div class="panel-body">
                            <div class="table-responsive">
                                <table class="table table-striped table-hover table-outside-bordered" data-link="row">
                                    <thead>
                                        <th style="width:  3%; padding-left:  5px; "> </th>
                                        <th style="width:  5%; padding-left:  3px; "> Mod </th>
                                        <th style="width:  5%; padding-left:  3px; "> OS </th>
                                        <th style="width:  5%; padding-left:  3px; "> VAC </th>
                                        <th style="width: 40%; padding-left: 10px; "> Server </th>
                                        <th style="width:  5%; padding-left:  5px; "> Player </th>
                                        <th style="width: 25%; padding-left: 10px; "> Map </th>
                                        <th style="width: 10%; "></th>
                                    </thead>
                                    <?php

                                        foreach($query as $server)
                                        {
                                            if(isset($server['Error'])){
                                                echo '<tr class="danger">';
                                                echo '<td> </td>';
                                                echo '<td> ERR </td>';
                                                echo '<td> ERR </td>';
                                                echo '<td> ERR </td>';
                                                echo '<td>' . $server['HostName'] . '</td>';
                                                echo '<td> ERR </td>';
                                                echo '<td> ERR </td>';
                                                echo '<td><a href="steam://connect/' . $server['ip'] . '" class="btn btn-danger btn-sm"><i class="fa fa-steam fa-1g" aria-hidden="true"></i> Connect</a></td>';
                                            }else{
                                                echo '<tr class="active">';
                                                echo '<td> </td>';
                                                echo '<td><img src="image/'. $server['ModDir'] .'.png" width="24" height="24" title="' . $server['ModDesc'] . '" /></td>';
                                                echo '<td><img src="image/'. $server['Os'] .'.png" width="24" height="24" title="' . ($server['Os'] == "w" ? "Windows Server 2016" : "Debian 9.3") . '" /></td>';
                                                echo '<td>' . ($server['Secure'] == 1 ? '<img src="image/vac.png" width="24" height="24" title="Valve Anti-Cheat" />' : '') . '</td>';
                                                echo '<td>' . $server['HostName'] . '</td>';
                                                echo '<td>' . $server['Players'] . '/' . $server['MaxPlayers'] . '</td>';
                                                echo '<td>' . $server['Map'] . '</td>';
                                                echo '<td><a href="steam://connect/' . $server['ip'] . '" class="btn btn-success btn-sm"><i class="fa fa-steam fa-1g" aria-hidden="true"></i> Connect</a></td>';
                                            }
                                            echo '</tr>';
                                        }
                                    ?>
                                </table>
                            </div>
                        </div>
                    </div>
                    <div class="well" style="text-align: center">
                        <p>Made by <a href="https://github.com/PuellaMagi">PuellaMagi</a>.</p>
                        <?php 
                            if($cacheleft <= 0){
                                echo '<p>This page updated on <span class="text-primary"> a few seconds ago</span>.</p>';
                            }else{
                                $cacheleft = time() - (180 - $cacheleft);
                                echo '<p>This page cached on <span class="text-primary">' . date("Y.m.d H:i:s", $cacheleft) . '</span>.</p>';
                            }
                        ?>
                        <p><span id="debuginfo">Processed in <?php $Processed += microtime(true); echo (Round($Processed, 6)); ?> s, <?php echo $queries; ?> DBQ(s), <?php echo $srcds; ?> SEQ(s), Gzip On, Redis <?php echo ($cache ? "On" : "Off"); ?>.</span></p>
                    </div>
                </div>
            </data-uib-accordion>
        </main>
    </body>
</html>
<?php 
unlink($lockfile);
?>