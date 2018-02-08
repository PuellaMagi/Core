CREATE TABLE `dxg_analytics` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `sid` smallint(5) unsigned NOT NULL DEFAULT '0',
  `ip` varchar(24) DEFAULT NULL,
  `map` varchar(128) DEFAULT NULL,
  `connect_time` int(11) unsigned NOT NULL DEFAULT '0',
  `connect_day` int(11) unsigned NOT NULL DEFAULT '0',
  `duration` smallint(5) NOT NULL DEFAULT '-1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_bans` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `steamid` varchar(32) NOT NULL DEFAULT '0',
  `ip` varchar(24) DEFAULT NULL,
  `nickname` varchar(64) DEFAULT NULL,
  `bCreated` int(11) unsigned NOT NULL DEFAULT '0',
  `bLength` int(11) unsigned NOT NULL DEFAULT '0',
  `bType` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `bSrv` smallint(3) unsigned NOT NULL DEFAULT '0',
  `bSrvMod` smallint(5) unsigned NOT NULL DEFAULT '0',
  `bAdminId` int(11) unsigned NOT NULL DEFAULT '0',
  `bAdminName` varchar(32) DEFAULT NULL,
  `bReason` varchar(128) DEFAULT NULL,
  `bRemovedBy` int(11) NOT NULL DEFAULT '-1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_blocks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bid` int(11) unsigned NOT NULL DEFAULT '0',
  `ip` varchar(32) DEFAULT NULL,
  `date` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_motd` (
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `show` bit(1) NOT NULL DEFAULT b'1',
  `width` smallint(6) unsigned NOT NULL DEFAULT '0',
  `height` smallint(5) unsigned NOT NULL DEFAULT '0',
  `url` varchar(256) NOT NULL DEFAULT 'https://magicgirl.net',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_servers` (
  `sid` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `mod` int(11) unsigned NOT NULL DEFAULT '0',
  `name` varchar(128) NOT NULL DEFAULT 'MagicGirl.NET - Server',
  `ip` varchar(32) NOT NULL DEFAULT '127.0.0.1',
  `port` smallint(6) unsigned NOT NULL DEFAULT '27015',
  `rcon` varchar(32) NOT NULL DEFAULT 'SanSHENGshi',
  PRIMARY KEY (`sid`),
  UNIQUE KEY `uk` (`ip`,`port`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_stats` (
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `vitality` smallint(4) unsigned NOT NULL DEFAULT '0',
  `connectTimes` int(11) unsigned NOT NULL DEFAULT '0',
  `onlineToday` int(11) unsigned NOT NULL DEFAULT '0',
  `onlineTotal` int(11) unsigned NOT NULL DEFAULT '0',
  `onlineOB` int(11) unsigned NOT NULL DEFAULT '0',
  `onlinePlay` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `dxg_users` (
  `uid` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `steamid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `username` varchar(32) NOT NULL DEFAULT 'unnamed',
  `imm` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'AdminImmunityLevel',
  `spt` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `vip` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `ctb` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `opt` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `adm` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `own` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `money` int(11) unsigned NOT NULL DEFAULT '0',
  `firstjoin` int(11) unsigned NOT NULL DEFAULT '0',
  `lastseen` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`),
  UNIQUE KEY `steam_unique` (`steamid`),
  UNIQUE KEY `bind_unique` (`uid`,`steamid`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;