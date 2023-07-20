<?php

########################################################################
# Extension Manager/Repository config file for ext: "realurl"
#
# Auto generated 26-08-2008 14:40
#
# Manual updates:
# Only the data in the array - anything else is removed by next write.
# "version" and "dependencies" must not be touched!
########################################################################

$EM_CONF[$_EXTKEY] = array(
	'title' => 'RealURL: URLs like normal websites',
	'description' => 'Creates nice looking URLs for TYPO3 pages. Converts http://example.com/index.phpid=12345&L=2 to http://example.com/path/to/your/page/.',
	'category' => 'fe',
	'shy' => 0,
	'version' => '1.5.1',
	'dependencies' => '',
	'conflicts' => '',
	'priority' => '',
	'loadOrder' => '',
	'module' => 'testmod',
	'state' => 'stable',
	'uploadfolder' => 0,
	'createDirs' => '',
	'modify_tables' => 'pages,sys_domain',
	'clearcacheonload' => 1,
	'lockType' => '',
	'author' => 'Dmitry Dulepov',
	'author_email' => 'dmitry@typo3.org',
	'author_company' => '',
	'CGLcompliance' => '',
	'CGLcompliance_note' => '',
	'constraints' => array(
		'depends' => array(
			'php' => '4.0.0-0.0.0',
			'typo3' => '4.0.0-0.0.0',
		),
		'conflicts' => array(
			'cooluri' => '',
		),
		'suggests' => array(
		),
	),
	'_md5_values_when_last_written' => 'a:25:{s:9:"ChangeLog";s:4:"6451";s:10:"_.htaccess";s:4:"a6b1";s:20:"class.tx_realurl.php";s:4:"6977";s:29:"class.tx_realurl_advanced.php";s:4:"564d";s:32:"class.tx_realurl_autoconfgen.php";s:4:"8dfb";s:26:"class.tx_realurl_dummy.php";s:4:"6e1b";s:28:"class.tx_realurl_tcemain.php";s:4:"630b";s:33:"class.tx_realurl_userfunctest.php";s:4:"750e";s:21:"ext_conf_template.txt";s:4:"5b1a";s:12:"ext_icon.gif";s:4:"ea80";s:17:"ext_localconf.php";s:4:"b820";s:14:"ext_tables.php";s:4:"4e14";s:14:"ext_tables.sql";s:4:"772c";s:16:"locallang_db.xml";s:4:"fe70";s:12:"doc/TODO.txt";s:4:"b8cb";s:14:"doc/manual.sxw";s:4:"ea07";s:13:"mod1/conf.php";s:4:"f960";s:14:"mod1/index.php";s:4:"c2b6";s:18:"mod1/locallang.xml";s:4:"23df";s:22:"mod1/locallang_mod.xml";s:4:"9fd8";s:19:"mod1/moduleicon.png";s:4:"6b5a";s:38:"modfunc1/class.tx_realurl_modfunc1.php";s:4:"8fe8";s:22:"modfunc1/locallang.xml";s:4:"0593";s:16:"testmod/conf.php";s:4:"309a";s:17:"testmod/index.php";s:4:"d33b";}',
);

?>