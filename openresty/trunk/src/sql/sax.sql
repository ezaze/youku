-- MySQL dump 10.11
--
-- Host: m3746i.mars.grid.sina.com.cn    Database: sax
-- ------------------------------------------------------
-- Server version	5.5.12-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `adunit`
--

DROP TABLE IF EXISTS `adunit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `adunit` (
  `id` varchar(64) NOT NULL DEFAULT '',
  `wdht` varchar(20) NOT NULL,
  `location` varchar(20) DEFAULT NULL,
  `adnum` int(11) NOT NULL DEFAULT '1',
  `publisher` int(10) NOT NULL,
  `adtype` text,
  `displaytype` text,
  `rotatenum` int(11) NOT NULL DEFAULT '1',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `gina` varchar(5000) DEFAULT '',
  `nad` text,
  `networkinfo` varchar(5000) DEFAULT '',
  `channel` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `adunit_bak`
--

DROP TABLE IF EXISTS `adunit_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `adunit_bak` (
  `id` varchar(64) NOT NULL DEFAULT '',
  `wdht` varchar(20) NOT NULL,
  `location` varchar(20) NOT NULL DEFAULT '',
  `adnum` int(11) NOT NULL DEFAULT '1',
  `publisher` int(10) NOT NULL,
  `adtype` text NOT NULL,
  `displaytype` text NOT NULL,
  `rotatenum` int(11) NOT NULL DEFAULT '1',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `advertiser`
--

DROP TABLE IF EXISTS `advertiser`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `advertiser` (
  `id` int(10) NOT NULL DEFAULT '0',
  `dspid` int(10) NOT NULL,
  `advertiserid` varchar(256) NOT NULL,
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `type` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `advertiser_bak`
--

DROP TABLE IF EXISTS `advertiser_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `advertiser_bak` (
  `id` int(10) NOT NULL DEFAULT '0',
  `dspid` int(10) NOT NULL,
  `advertiserid` int(10) NOT NULL,
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `creative`
--

DROP TABLE IF EXISTS `creative`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `creative` (
  `id` int(10) NOT NULL DEFAULT '0',
  `dspid` int(10) NOT NULL,
  `dspideaid` varchar(256) NOT NULL,
  `advertiserid` varchar(256) NOT NULL,
  `ideatype` tinyint(2) NOT NULL DEFAULT '0',
  `wdht` varchar(128) DEFAULT NULL,
  `onlineurl` varchar(1024) DEFAULT NULL,
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `creative_bak`
--

DROP TABLE IF EXISTS `creative_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `creative_bak` (
  `id` int(10) NOT NULL DEFAULT '0',
  `dspid` int(10) NOT NULL,
  `dspideaid` int(10) NOT NULL,
  `advertiserid` int(10) NOT NULL,
  `ideatype` tinyint(2) NOT NULL DEFAULT '0',
  `wdht` varchar(128) NOT NULL DEFAULT '',
  `onlineurl` varchar(1024) NOT NULL DEFAULT '',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dsp`
--

DROP TABLE IF EXISTS `dsp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dsp` (
  `id` int(10) NOT NULL,
  `dspname` varchar(64) DEFAULT NULL,
  `bidurl` text NOT NULL,
  `notifyurl` text NOT NULL,
  `redirecturl` text NOT NULL,
  `priority` int(11) NOT NULL DEFAULT '0',
  `qps` int(10) NOT NULL DEFAULT '0',
  `encryptionkey` varchar(64) DEFAULT NULL,
  `integritykey` varchar(64) DEFAULT NULL,
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dsp_bak`
--

DROP TABLE IF EXISTS `dsp_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dsp_bak` (
  `id` int(10) NOT NULL DEFAULT '0',
  `dspname` varchar(64) DEFAULT NULL,
  `bidurl` text NOT NULL,
  `notifyurl` text NOT NULL,
  `redirecturl` text NOT NULL,
  `priority` int(11) NOT NULL DEFAULT '0',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `network`
--

DROP TABLE IF EXISTS `network`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `network` (
  `id` int(11) NOT NULL,
  `name` varchar(64) NOT NULL,
  `url` text,
  `status` tinyint(4) DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `resource`
--

DROP TABLE IF EXISTS `resource`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resource` (
  `id` int(10) NOT NULL DEFAULT '0',
  `levelname` varchar(64) DEFAULT NULL,
  `dspprice` decimal(10,2) NOT NULL,
  `dspwhitelist` text,
  `blackadtype` text,
  `blackterm` text,
  `blackclickurl` text,
  `flag` tinyint(2) NOT NULL DEFAULT '1',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `pdwhitelist` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `resource_bak`
--

DROP TABLE IF EXISTS `resource_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resource_bak` (
  `id` int(10) NOT NULL DEFAULT '0',
  `levelname` varchar(64) DEFAULT NULL,
  `dspprice` decimal(10,2) NOT NULL,
  `dspwhitelist` text NOT NULL,
  `blackadtype` text NOT NULL,
  `blackterm` text NOT NULL,
  `blackclickurl` text NOT NULL,
  `flag` tinyint(2) NOT NULL DEFAULT '1',
  `status` tinyint(2) NOT NULL DEFAULT '1',
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `server`
--

DROP TABLE IF EXISTS `server`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `server` (
  `ip` varchar(20) NOT NULL,
  `port` int(11) NOT NULL DEFAULT '80',
  `type` char(1) NOT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ip`,`port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `server_bak`
--

DROP TABLE IF EXISTS `server_bak`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `server_bak` (
  `ip` varchar(20) NOT NULL,
  `port` int(11) NOT NULL DEFAULT '80',
  `type` char(1) NOT NULL,
  `createtime` datetime DEFAULT NULL,
  `modifytime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ip`,`port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-06-09 10:47:58
