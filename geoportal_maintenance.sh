#!/bin/bash
############################################################
# Geoportal-SL install script for debian 9 server environment
# 2020-02-20
# debian netinstall 9
# André Holl
# Armin Retterath
# Michel Peltriaux
# Sven van Crombrugge
############################################################

initializeVariables(){
  local setupVabiablesFile="$(pwd)/setup/setup.conf"
  if [[ -f ${setupVabiablesFile} ]];then
    source ${setupVabiablesFile}
  else
    echo -e "\n ${red} Initializing nessesary parameters failed! ${reset} \n"
    echo 'Error called in function "initializeVariables" '
    exit 11
  fi
  
  #colors for install
  red=`tput setaf 1`
  green=`tput setaf 2`
  reset=`tput sgr0`
}

getOptions_postProcessing(){
  #set hostname to ipaddress if no hostname was given
  if [[ $ipaddress != "127.0.0.1" ]] && [[ $hostname == "127.0.0.1" ]] ;then
    hostname=$ipaddress
  fi

  if [[ "$http_proxy_user" != "" ]] && [[ $mode != "none" ]];then
    echo "Please enter your proxy password"
    read  -sp "Password for $http_proxy_user: " http_proxy_pass
  fi

  # proxy config
  # hexlify credentials for export
  if [[ "$http_proxy_user" != "" ]] && [[ "$http_proxy_pass" != "" ]];then
    http_proxy_user_hex=`echo $http_proxy_user | xxd -ps -c 200 | tr -d '\n' |  fold -w2 | paste -sd'%' -`
    http_proxy_user_hex=%$http_proxy_user_hex
    http_proxy_user_hex=${http_proxy_user_hex::len-3}

    http_proxy_pass_hex=`echo $http_proxy_pass | xxd -ps -c 200 | tr -d '\n' |  fold -w2 | paste -sd'%' -`
    http_proxy_pass_hex=%$http_proxy_pass_hex
    http_proxy_pass_hex=${http_proxy_pass_hex::len-3}
  else
    http_proxy_user_hex=""
    http_proxy_pass_hex=""
  fi

  if [[ $mode != "none" ]];then
    check_mode
  fi
}

check_mode(){
  mkdir -pv "${logFolder}"
  
  if [[ $mode = "install" ]]; then
    installation_log=${logFolder}"geoportal_install_$(date +"%d_%m_%Y").log"
    echo -e "\n Performing complete installation \n" | tee ${installation_log}
    install | tee ${installation_log}
  elif [[ $mode = "update" ]];then
    update_log=${logFolder}"geoportal_update_$(date +"%d_%m_%Y").log"
    echo -e "\n Updating your geoportal solution \n" | tee ${update_log}
    update | tee ${update_log}
  elif [[ $mode = "delete" ]];then
    uninstall_log=${logFolder}"geoportal_uninstall_$(date +"%d_%m_%Y").log"
    echo -e "\n Deleting your geoportal solution \n" | tee ${uninstall_log}
    delete | tee ${uninstall_log}
  elif [[ $mode = "backup" ]];then
    backup_log=${logFolder}"geoportal_backup_$(date +"%d_%m_%Y").log"
    echo -e "\n Backing up your geoportal solution \n" | tee ${backup_log}
    backup | tee ${backup_log}
  fi
}

usage(){
  echo "
  This script is for installing and maintaining your geoportal solution
  You can choose from the following options:

        --help                              | Prints help function
        --mode=what you want to do          | Default \"none\" [install,update,delete,backup]

  "
}

getOptions(){
  while getopts h-: arg; do
    case $arg in
      h )  usage;exit;;
      - )  LONG_OPTARG="${OPTARG#*=}"
          case $OPTARG in
      help				)  usage;;
      mode=?*			)  mode=$LONG_OPTARG;;
            '' 				)  break ;; # "--" terminates argument processing
            * 				)  echo "Illegal option --$OPTARG" >&2; usage; exit 2 ;;
          esac ;;
      \? ) exit 2 ;;  # getopts already reported the illegal option
    esac
  done
  shift $((OPTIND-1))

  getOptions_postProcessing
}

updateI18N(){
  /usr/bin/sh ${installation_folder}mapbender/tools/i18n_update_mo.sh
}

backup(){

  backup_checkForExistingBackup(){
    if [ -d ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y") ]; then
      echo "I have found a Backup for today. You should remove or rename it if you want to use this function."
      echo "Do sth like: mv ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y") ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")_old"
      exit
    fi
  }

  backup_createFolders(){
    echo "Creating backup in ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")"
    mkdir -pv ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/
    mkdir -p ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/conf
    mkdir -p ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/http/extensions/mobilemap2/scripts/
    mkdir -p ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/tools/wms_extent/
    mkdir -p ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/${installation_subfolder_django}Geoportal/
    mkdir -p ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/${installation_subfolder_django}useroperations/
  }

  backup_djangoConfigurations(){
    cp -av ${installation_folder}${installation_subfolder_django}Geoportal/settings.py ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/${installation_subfolder_django}Geoportal/
    cp -av ${installation_folder}${installation_subfolder_django}useroperations/conf.py ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/${installation_subfolder_django}useroperations/conf.py
  }

  backup_mapbenderConfigurations(){
    cp -av ${installation_folder}mapbender/conf/* ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/conf/
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap2/scripts/netgis/config.js ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/http/extensions/mobilemap2/scripts/netgis/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extent_service.conf ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/tools/wms_extent/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extents.map ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/tools/wms_extent/
  }

  backup_mapbenderExtensions(){
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap/* ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/http/extensions/mobilemap/
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap2/* ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/http/extensions/mobilemap2/
  }

  backup_userInput_databaseBackup(){
    while true; do
        read -p "Do you want to dump the databases y/n?" yn
        case $yn in
            [Yy]* )
            su - postgres -c "pg_dump mapbender > /tmp/geoportal_mapbender_backup.psql";
            cp -a /tmp/geoportal_mapbender_backup.psql ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y");
            # TODO use defined Variable
            mysqldump --user=root --password=${mysql_root_pw} Geoportal > ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/geoportal_mariaDB_allDatabases.backup;
            break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
  }

  backup_full(){
    backup_checkForExistingBackup
    backup_createFolders
    backup_djangoConfigurations
    backup_mapbenderConfigurations
    backup_mapbenderExtensions
    backup_userInput_databaseBackup
    echo "Backup Done!"
  }

  backup_full
}

install(){

  install_setWMSRegistrationCommands(){
    ##################### Default GUI
    wms_1_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=1 guiId='$default_gui_name' serviceType='wms' serviceAccessUrl=$wms_1_url"
    wms_2_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=1 guiId='$default_gui_name' serviceType='wms' serviceAccessUrl=$wms_2_url"
    wms_3_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=1 guiId='$default_gui_name' serviceType='wms' serviceAccessUrl=$wms_3_url"
    ##################### Default GUI extended search
    wms_4_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=1 guiId='$extended_search_default_gui_name' serviceType='wms' serviceAccessUrl=$wms_1_url"
    wms_5_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=1 guiId='$extended_search_default_gui_name' serviceType='wms' serviceAccessUrl=$wms_2_url"
    ##################### demo service
    wms_6_register_cmd="/usr/bin/php -f ${installation_folder}mapbender/tools/registerOwsCli.php userId=3 guiId='service_container1_free' serviceType='wms' serviceAccessUrl=$wms_4_url"
  }

  install_prepareInstall(){
    install_setWMSRegistrationCommands
  }

  install_createDirectories(){
    if [ $create_folders = 'true' ]; then
        echo -e "\n Creating directories for Mapbender! \n"
        mkdir -pv $installation_folder
        touch $installation_log
        mkdir -pv ${installation_folder}access/
        echo -e "\n ${green} Successfully created directories! ${reset}\n"
    fi
  }

  install_applyProxyConfiguration(){
    if [ "$http_proxy" != "" ];then
        # special case, if you need seperate for proxies for apt,svn,mapbender
        if [ $http_proxy == "custom" ];then
          echo "You have chosen custom proxy config, please enter your proxies one after another, leave blank for none, syntax ipaddress:port"
          read  -p "APT Proxy: " apt_proxy
          read  -p "SVN Proxy: " svn_proxy
          read  -p "Mapbender Proxy: " mb_proxy
          custom_proxy= true
          if [ "$apt_proxy" != "" ];then
            http_proxy_host=`echo $apt_proxy | cut -d: -f1`
            http_proxy_port=`echo $apt_proxy | cut -d: -f2`
          else
            http_proxy_host=""
            http_proxy_port=""
          fi
        else
          http_proxy_host=`echo $http_proxy | cut -d: -f1`
          http_proxy_port=`echo $http_proxy | cut -d: -f2`
        fi

        if [ "$http_proxy_host" != "" ] && [  "$http_proxy_port" != "" ];then

        # system proxy
          if [ "$http_proxy_user_hex" != "" ] && [ "$http_proxy_pass_hex" != "" ];then
            export http_proxy="http://$http_proxy_user_hex:$http_proxy_pass_hex@$http_proxy_host:$http_proxy_port"
            export https_proxy="http://$http_proxy_user_hex:$http_proxy_pass_hex@$http_proxy_host:$http_proxy_port"
          else
            export http_proxy="http://$http_proxy_host:$http_proxy_port"
            export https_proxy="http://$http_proxy_host:$http_proxy_port"
          fi
          # apt_proxy
          if [ -e "/etc/apt/apt.conf" ]; then
              echo -e "\n Apt Config File exists, Backing it up \n"
              cp /etc/apt/apt.conf /etc/apt/apt.conf_backup_geoportal
              echo "Acquire::http::Proxy \"http://$http_proxy_user_hex:$http_proxy_pass_hex@$http_proxy_host:$http_proxy_port\";" > /etc/apt/apt.conf
          else
              echo -e "\n Apt Conf File does not exist, creating it \n"
              touch /etc/apt/apt.conf
              echo "Acquire::http::Proxy \"http://$http_proxy_user_hex:$http_proxy_pass_hex@$http_proxy_host:$http_proxy_port\";" > /etc/apt/apt.conf
          fi
        fi

        apt-get update
        apt-get install -y subversion

        if [ "$custom_proxy" == true ];then
          if [ "$svn_proxy" != "" ];then
            http_proxy_host=`echo $svn_proxy | cut -d: -f1`
            http_proxy_port=`echo $svn_proxy | cut -d: -f2`
          else
            http_proxy_host=""
            http_proxy_port=""
          fi
        fi

        if [ "$http_proxy_host" != "" ] && [ "$http_proxy_port" != "" ];then
          # svn proxy
          cp /etc/subversion/servers /etc/subversion/servers_backup_geoportal
          sed -i "s/# http-proxy-host = defaultproxy.whatever.com/http-proxy-host = $http_proxy_host/g" /etc/subversion/servers
          sed -i "s/# http-proxy-port = 7000/http-proxy-port = $http_proxy_port/g" /etc/subversion/servers
          if [ "$http_proxy_user" != "" ]  && [  "$http_proxy_pass" != "" ];then
            sed -i "s/# http-proxy-username = defaultusername/http-proxy-username = $http_proxy_user/g" /etc/subversion/servers
            sed -i "s/# http-proxy-password = defaultpassword/http-proxy-password = $http_proxy_pass/g" /etc/subversion/servers
          fi
        fi
    fi
    export no_proxy="localhost,127.0.0.1"
  }

  install_echoInstallationParameters(){
    echo -e "
    Geoportal Installation $(date).\n
    Parameters:\n
    --hostname=$hostname\n
    --ipaddress=$ipaddress\n
    --proxy=$http_proxy\n
    --mapbender_database_name=$mapbender_database_name\n
    --mapbender_database_user=$mapbender_database_user\n
    --mapbender_database_password=$mapbender_database_password\n
    --phppgadmin_user=$phppgadmin_user\n
    --phppgadmin_password=$phppgadmin_password\n"

    if [[ ${installation_folder} =~ ^/.+/$ ]] ; then
      echo -e "\n Installing into '${installation_folder}' ... \n" 
    else
      echo -e "\n Invalid installation folder '${installation_folder}'! \n Please use preceding and trailing slashed! eg: /data/" 
      exit
    fi
  }

  install_installSystemPackages(){
    if [ $install_system_packages = 'true' ]; then
      echo -e "\n Installing needed Debian packages for Mapbender! \n"
      apt-get update
      apt-get install -y git php7.0-mysql libapache2-mod-php7.0 php7.0-pgsql php7.0-gd php7.0-curl php7.0-cli  php-gettext g++ make bison bzip2 unzip zip gdal-bin cgi-mapserver php-imagick mysql-server imagemagick locate postgresql postgis postgresql-9.6-postgis-2.3 mc zip unzip links w3m lynx arj xpdf dbview odt2txt ca-certificates oidentd gettext phppgadmin gkdebconf subversion subversion-tools memcached php-memcached php-memcache php-apcu php-apcu-bc curl libproj-dev libapache2-mod-security2
      echo -e "\n ${green}Successfully installed Debian packages for Mapbender! ${reset} \n"
    fi
  }

  install_configurePHPLogging(){
    cp /etc/php/7.0/cli/php.ini /etc/php/7.0/cli/php.ini_geoportal_backup
    cp /etc/php/7.0/apache2/php.ini /etc/php/7.0/apache2/php.ini_geoportal_backup
    sed -i "s/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ERROR/g" /etc/php/7.0/cli/php.ini
    sed -i "s/;error_log = php_errors.log/error_log = \/tmp\/php7_cli_errors\.log/g" /etc/php/7.0/cli/php.ini
  }

  install_mapbender_filesystem_gitFetch(){
    echo -e "\n Downloading Mapbender Sources from Git! \n"
    cd ${installation_folder}
    git clone --progress --single-branch -b ${git_mapbender_repositoryBranch} ${git_mapbender_repositoryURL} mapbender
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully downloaded Mapbender Source! ${reset}\n" 
    else
      echo -e "\n ${red}Downloading of Mapbender failed! Check internet connection and git proxy settings! ${reset}\n"
      exit 11
    fi
  }

  install_mapbender_filesystem(){
    install_mapbender_filesystem_gitFetch

    if [ $checkout_mapbender_conf = 'true' ]; then
        echo -e "\n Download Mapbender conf from SVN \n" 
        svn co http://www.gdi-rp-dienste.rlp.de/svn/de-rp/data/conf
        if [ $? -eq 0 ];then
          echo -e "\n ${green}Successfully downloaded Mapbender Conf! ${reset} \n" 
        else
          echo -e "\n ${red}Downloading of Mapbender Conf failed! Check internet connection and proxy settings in /etc/subversion/servers! ${reset} \n"
          exit
        fi
    fi

    ############################################################
    # compress and create geoportal default conf from /data/conf
    ############################################################
    if [ $install_mapbender_conf = 'true' ]; then
        echo -e "\n Copying Mapbender Conf to ${installation_folder} \n" 
        cp -a ${installation_folder}svn/conf ${installation_folder}
        svn info http://www.gdi-rp-dienste.rlp.de/svn/de-rp/data/conf | grep Revision | grep -Eo '[0-9]{1,}' > ${installation_folder}conf/lastinstalled
        echo -e "\n ${green}Successfully copied Mapbender Conf to ${installation_folder}! ${reset}\n" 
    fi

    ############################################################
    # configure and install mapbender
    ############################################################
    if [ $create_folders = 'true' ]; then
        mkdir -pv ${installation_folder}mapbender/http/tmp/wmc
    fi
  }

  install_mapbender_database_createDatabase(){
    su - postgres -c "dropdb --if-exists -p $mapbender_database_port $mapbender_database_name"
    su - postgres -c "createdb -p $mapbender_database_port -E UTF8 $mapbender_database_name -T template0"
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "DROP USER IF EXISTS $mapbender_database_user"
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "CREATE USER $mapbender_database_user WITH ENCRYPTED PASSWORD '$mapbender_database_password'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -f /usr/share/postgresql/9.6/contrib/postgis-2.3/postgis.sql"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -f /usr/share/postgresql/9.6/contrib/postgis-2.3/spatial_ref_sys.sql"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -f /usr/share/postgresql/9.6/contrib/postgis-2.3/legacy.sql"
    su - postgres -c "PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f /usr/share/postgresql/9.6/contrib/postgis-2.3/topology.sql"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT ALL PRIVILEGES ON DATABASE $mapbender_database_name TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'ALTER DATABASE $mapbender_database_name OWNER TO $mapbender_database_user'"
  }

  install_mapbender_database_configurePostgreSQL(){
    cp /etc/postgresql/9.6/main/pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf_backup
    cp ${installation_folder}${installation_subfolder_django}setup/default-pg_hba.conf-dist ${installation_folder}${installation_subfolder_django}setup/default-pg_hba.conf
    sed -i "s#%%mapbender_database_name%%#${mapbender_database_name}#g" ${installation_folder}${installation_subfolder_django}setup/default-pg_hba.conf
    if [ $? -ne 0 ];then
      echo "Could not configure PostgreSQL"
      exit 13
    fi
    sed -i "s#%%mapbender_database_user%%#${mapbender_database_user}#g" ${installation_folder}${installation_subfolder_django}setup/default-pg_hba.conf
    if [ $? -ne 0 ];then
      echo "Could not configure PostgreSQL"
      exit 13
    fi
    mv -v ${installation_folder}${installation_subfolder_django}setup/default-pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
    service postgresql restart
  }

  install_mapbender_database_create_adoption1(){
    echo  -e '\n Adopting mapbenders default database to geoportal default options. \n'

    cat << EOF > ${installation_folder}geoportal_database_adoption_1.sql
    --create new database content
    --geoportal specific extensions
    ALTER TABLE mb_user ADD COLUMN mb_user_glossar character varying(5);
    --ALTER TABLE mb_user ADD COLUMN mb_user_glossar character varying(14);
    --ALTER TABLE mb_user ADD COLUMN mb_user_textsize character varying(14);
    ALTER TABLE mb_user ADD COLUMN mb_user_textsize character varying(14);
    ALTER TABLE mb_user ADD COLUMN mb_user_last_login_date date;
    ALTER TABLE mb_user ADD COLUMN mb_user_spatial_suggest character varying(5);

    UPDATE gui_category SET category_name='Anwendung' WHERE category_id=2;
    UPDATE gui_category SET category_description='Anwendungen (Applications)' WHERE category_id=2;

    --add anonymous user
    INSERT INTO mb_user (mb_user_id, mb_user_name, mb_user_password, mb_user_owner, mb_user_description, mb_user_login_count, mb_user_email, mb_user_phone, mb_user_department, mb_user_resolution, mb_user_organisation_name, mb_user_position_name, mb_user_phone1, mb_user_facsimile, mb_user_delivery_point, mb_user_city, mb_user_postal_code, mb_user_country, mb_user_online_resource, mb_user_textsize, mb_user_glossar, mb_user_last_login_date, mb_user_digest, mb_user_realname, mb_user_street, mb_user_housenumber, mb_user_reference, mb_user_for_attention_of, mb_user_valid_from, mb_user_valid_to, mb_user_password_ticket, mb_user_firstname, mb_user_lastname, mb_user_academictitle, timestamp_create, timestamp, mb_user_spatial_suggest, mb_user_newsletter, mb_user_allow_survey, mb_user_aldigest, password, is_active, activation_key, timestamp_delete) VALUES (${mapbender_guest_user_id}, 'guest', '084e0343a0486ff05530df6c705c8bb4', 1, 'test', 0, '${webadmin_email}', NULL, '', 72, '', '', NULL, NULL, NULL, '', NULL, NULL, NULL, 'textsize3', 'ja', '2012-01-26', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2013-07-05 08:09:25.560359', '2015-08-20 10:04:04.952796', 'nein', true, true, NULL, '\$2b\$12\$sT7geeXvBlGZyLcT55VxqeNF2yuU8LKnBpfKFwxkiAh147mNxF5Cq',true,'',NULL);

    INSERT INTO mb_user (mb_user_id, mb_user_name, mb_user_password, mb_user_owner, mb_user_description, mb_user_login_count, mb_user_email, mb_user_phone, mb_user_department, mb_user_resolution, mb_user_organisation_name, mb_user_position_name, mb_user_phone1, mb_user_facsimile, mb_user_delivery_point, mb_user_city, mb_user_postal_code, mb_user_country, mb_user_online_resource, mb_user_textsize, mb_user_glossar, mb_user_last_login_date, mb_user_digest, mb_user_realname, mb_user_street, mb_user_housenumber, mb_user_reference, mb_user_for_attention_of, mb_user_valid_from, mb_user_valid_to, mb_user_password_ticket, mb_user_firstname, mb_user_lastname, mb_user_academictitle, timestamp_create, timestamp, mb_user_spatial_suggest, mb_user_newsletter, mb_user_allow_survey, mb_user_aldigest, password, is_active, activation_key, timestamp_delete) VALUES (${mapbender_subadmin_default_user_id}, 'bereichsadmin1', '3ad58afdc417b975256af7a6d3eda7a5', 1, '', 0, '${webadmin_email}', NULL, NULL, 72, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'nein', '2017-07-28', '3c345c2af80400e1e4c94ed0a967e713', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '', 'bereichsadmin1', 'bereichsadmin1', '', '2013-07-05 08:09:25.560359', '2017-07-28 10:12:13.926954', 'nein', false, false, '2a32c845b23d82bea4653810f146397b', '\$2b\$12\$hkhs1s4LrPTNWeZaTHAS5.G63JZSVCmc7xUpaYrdVTAxgeeFe1YM6',true,'',NULL);

    INSERT INTO mb_group VALUES (${mapbender_subadmin_group_id}, 'Bereichsadmin', 1, 'Diensteadministratoren der Behörden', '', NULL, '', '', '', '', '', '', '', '', '', NULL, NULL, '2013-07-05 08:09:25.732456', '2018-05-25 08:57:07.988259', NULL, NULL, NULL, NULL, NULL, NULL, true);

    INSERT INTO mb_group VALUES (${mapbender_guest_group_id}, 'guest', 1, 'Gastgruppe', '', NULL, '', '', '', '', '', '', '', '', '', NULL, NULL, '2013-07-05 08:09:25.732456', '2018-05-25 08:57:07.988259', NULL, NULL, NULL, NULL, NULL, NULL, true);

    INSERT INTO mb_group VALUES (${mapbender_subadmin_default_group_id}, 'testgruppe1', 1, 'testgruppe1', 'testgruppe1', NULL, 'Musterstraße 11', '11111 Musterstadt', 'Musterstadt', 'DE-RP', 'DE', '1111', '1111', 'mustermail@musterdomain.com', 'http://www.geoportal.rlp.de/metadata/GDI-RP_mit_Markenschutz_RGB_70.png', NULL, NULL, '2013-07-05 08:09:25.732456', '2018-05-25 08:57:07.988259', NULL, NULL, NULL, NULL, NULL, NULL, true);

    --guest user into guest group
    INSERT INTO mb_user_mb_group VALUES (${mapbender_guest_user_id}, ${mapbender_guest_group_id}, 1);

    --bereichsadmin1 into guest group
    INSERT INTO mb_user_mb_group VALUES (${mapbender_subadmin_default_user_id}, ${mapbender_guest_group_id}, 1);

    --bereichsadmin1 into Bereichsadmin group
    INSERT INTO mb_user_mb_group VALUES (${mapbender_subadmin_default_user_id}, ${mapbender_subadmin_group_id}, 1);

    --bereichsadmin1 into testgruppe1 group - role primary
    INSERT INTO mb_user_mb_group VALUES (${mapbender_subadmin_default_user_id}, ${mapbender_subadmin_default_group_id}, 2);

    --bereichsadmin1 into testgruppe1 group - role standard
    INSERT INTO mb_user_mb_group VALUES (${mapbender_subadmin_default_user_id}, ${mapbender_subadmin_default_group_id}, 1);

    --root into guest group
    INSERT INTO mb_user_mb_group VALUES (1, ${mapbender_guest_group_id}, 1);

    INSERT INTO gui (gui_id, gui_name, gui_description, gui_public) VALUES ('service_container1', 'service_container1', 'service_container1', 1);

    INSERT INTO gui (gui_id, gui_name, gui_description, gui_public) VALUES ('service_container1_free', 'service_container1_free', 'service_container1_free', 1);

    DELETE FROM gui WHERE gui_id IN ('${default_gui_name}', 'Owsproxy_csv', 'admin_wms_metadata', 'admin_wfs_metadata', 'admin_wmc_metadata', 'admin_metadata', 'admin_ows_scheduler', 'PortalAdmin_DE', 'Administration_DE', '${extended_search_default_gui_name}');
EOF
  }

  install_mapbender_database_run_adoption1(){
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}geoportal_database_adoption_1.sql
  }

  install_mapbender_database_create_adoption2(){
    cat << EOF > ${installation_folder}geoportal_database_adoption_2.sql
    INSERT INTO gui_gui_category (fkey_gui_id, fkey_gui_category_id) VALUES ('${default_gui_name}', 2);
    INSERT INTO gui_gui_category (fkey_gui_id, fkey_gui_category_id) VALUES ('Administration_DE', 2);
    INSERT INTO gui_gui_category (fkey_gui_id, fkey_gui_category_id) VALUES ('PortalAdmin_DE', 2);


    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('PortalAdmin_DE', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('${default_gui_name}', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('Administration_DE', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('Owsproxy_csv', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('${extended_search_default_gui_name}', 1, 'owner');

    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('admin_wms_metadata', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('admin_wfs_metadata', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('admin_wmc_metadata', 1, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('admin_metadata', 1, 'owner');

    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('admin_ows_scheduler', 1, 'owner');

    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('service_container1', ${mapbender_subadmin_default_user_id}, 'owner');
    INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) VALUES ('service_container1_free', ${mapbender_subadmin_default_user_id}, 'owner');

    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('Administration_DE', ${mapbender_subadmin_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('Owsproxy_csv', ${mapbender_subadmin_group_id});

    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin_wmc_metadata', ${mapbender_subadmin_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin_wms_metadata', ${mapbender_subadmin_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin_wfs_metadata', ${mapbender_subadmin_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin_ows_scheduler', ${mapbender_subadmin_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin_metadata', ${mapbender_subadmin_group_id});
    --INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('admin1', ${mapbender_subadmin_group_id});


    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('${default_gui_name}', ${mapbender_guest_group_id});
    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('${extended_search_default_gui_name}', ${mapbender_guest_group_id});

    INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) VALUES ('service_container1_free', ${mapbender_guest_group_id});
    --alter views to integrate real subadmin and guest user ids
    -- View: groups_for_publishing

    -- DROP VIEW groups_for_publishing;

    CREATE OR REPLACE VIEW groups_for_publishing AS
    SELECT mb_group.mb_group_id AS fkey_mb_group_id,
        mb_group.mb_group_id,
        mb_group.mb_group_name,
        mb_group.mb_group_owner,
        mb_group.mb_group_description,
        mb_group.mb_group_title,
        mb_group.mb_group_ext_id,
        mb_group.mb_group_address,
        mb_group.mb_group_postcode,
        mb_group.mb_group_city,
        mb_group.mb_group_stateorprovince,
        mb_group.mb_group_country,
        mb_group.mb_group_voicetelephone,
        mb_group.mb_group_facsimiletelephone,
        mb_group.mb_group_email,
        mb_group.mb_group_logo_path,
        mb_group.mb_group_homepage,
        mb_group.mb_group_admin_code,
        mb_group.timestamp_create,
        mb_group."timestamp",
        mb_group.mb_group_address_location,
        mb_group.uuid,
        mb_group.mb_group_ckan_uuid,
        mb_group.mb_group_ckan_api_key
      FROM mb_group
      WHERE (mb_group.mb_group_id IN ( SELECT DISTINCT f.fkey_mb_group_id
              FROM mb_user_mb_group f,
                mb_user_mb_group s
              WHERE (f.mb_user_mb_group_type = ANY (ARRAY[2, 3])) AND s.fkey_mb_group_id = ${mapbender_subadmin_group_id} AND f.fkey_mb_user_id = s.fkey_mb_user_id));

    ALTER TABLE groups_for_publishing
      OWNER TO postgres;
    GRANT ALL ON TABLE groups_for_publishing TO postgres;
    GRANT ALL ON TABLE groups_for_publishing TO $mapbender_database_user;

    ALTER TABLE groups_for_publishing
      OWNER TO postgres;
    GRANT ALL ON TABLE groups_for_publishing TO postgres;
    GRANT ALL ON TABLE groups_for_publishing TO $mapbender_database_user;

    -- View: registrating_groups

    -- DROP VIEW registrating_groups;

    CREATE OR REPLACE VIEW registrating_groups AS
    SELECT f.fkey_mb_group_id,
        f.fkey_mb_user_id
      FROM mb_user_mb_group f,
        mb_user_mb_group s
      WHERE f.mb_user_mb_group_type = 2 AND s.fkey_mb_group_id = ${mapbender_subadmin_group_id} AND f.fkey_mb_user_id = s.fkey_mb_user_id
      ORDER BY f.fkey_mb_group_id, f.fkey_mb_user_id;

    ALTER TABLE registrating_groups
      OWNER TO postgres;
    GRANT ALL ON TABLE registrating_groups TO postgres;
    GRANT ALL ON TABLE registrating_groups TO $mapbender_database_user;

    -- View: users_for_publishing

    -- DROP VIEW users_for_publishing;

    CREATE OR REPLACE VIEW users_for_publishing AS
    SELECT DISTINCT f.fkey_mb_user_id,
        f.fkey_mb_group_id AS primary_group_id
      FROM mb_user_mb_group f,
        mb_user_mb_group s
      WHERE f.mb_user_mb_group_type = 2 AND s.fkey_mb_group_id = ${mapbender_subadmin_group_id} AND f.fkey_mb_user_id = s.fkey_mb_user_id
      ORDER BY f.fkey_mb_user_id;

    ALTER TABLE users_for_publishing
      OWNER TO postgres;
    GRANT ALL ON TABLE users_for_publishing TO postgres;
    GRANT ALL ON TABLE users_for_publishing TO $mapbender_database_user;

    --add csw information

    INSERT INTO cat VALUES (1, '2.0.2', 'GeoDatenKatalog.De', 'Bereitstellung des Geodatenkatalog.de der GeoDatenInfrastruktur Deutschland (GDI-DE)', 'http://gdk.gdi-de.org/gdi-de/srv/eng/csw?SERVICE=CSW&VERSION=2.0.2&REQUEST=GetCapabilities', 'none', 'none', NULL, NULL, 'admin admin', 'Administrator', NULL, NULL, '', NULL, NULL, NULL, NULL, NULL, 'iserted via sql - no caps available!', 5299, 1502980960);

    INSERT INTO cat_op_conf VALUES (1, 'get', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'getcapabilities');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'getcapabilities');
    INSERT INTO cat_op_conf VALUES (1, 'post_xml', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'getcapabilities');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'describerecord');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'describerecord');
    INSERT INTO cat_op_conf VALUES (1, 'post_xml', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'describerecord');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'getdomain');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'http://ims.geoportal.de/gdi-de/srv/eng/csw', 'getdomain');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'http://ims.geoportal.de/gdi-de/srv/eng/csw-publication', 'transaction');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'http://ims.geoportal.de/gdi-de/srv/eng/csw-publication', 'transaction');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'http://ims.geoportal.de/gdi-de/srv/eng/csw-publication', 'harvest');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'http://ims.geoportal.de/gdi-de/srv/eng/csw-publication', 'harvest');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecords');
    INSERT INTO cat_op_conf VALUES (1, 'post_xml', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecords');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecordbyid');
    INSERT INTO cat_op_conf VALUES (1, 'post_xml', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecordbyid');
    INSERT INTO cat_op_conf VALUES (1, 'get', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecords');
    INSERT INTO cat_op_conf VALUES (1, 'post', 'https://gdk.gdi-de.org/gdi-de/srv/eng/csw', 'getrecordbyid');


    CREATE TABLE gp_csw (
        csw_id integer,
        csw_name text,
        fkey_cat_id integer,
        csw_p integer,
        csw_h integer,
        hierachylevel character(50)
    );


    ALTER TABLE gp_csw OWNER TO postgres;
    GRANT ALL ON TABLE gp_csw TO $mapbender_database_user;

    INSERT INTO gp_csw VALUES (5, 'GeodatenkatalogDE - Sonstige Informationen', 1, 1, 5, 'nonGeographicDataset');
    INSERT INTO gp_csw VALUES (3, 'GeodatenkatalogDE - Dienste', 1, 1, 5, 'service');
    INSERT INTO gp_csw VALUES (4, 'GeodatenkatalogDE - Anwendungen', 1, 1, 5, 'application');
    INSERT INTO gp_csw VALUES (2, 'GeodatenkatalogDE - Geodaten', 1, 1, 5, 'dataset/series');
EOF
  }

  install_mapbender_database_run_adoption2(){
    sudo -u postgres psql -q -d $mapbender_database_name -f ${installation_folder}geoportal_database_adoption_2.sql
  }

  install_mapbender_database_configurePHPPGAdmin(){
    cp /etc/phppgadmin/config.inc.php /etc/phppgadmin/config.inc.php_geoportal_backup
    sed -i "s/conf\['extra_login_security'\] = true/conf\['extra_login_security'\] = false/g" /etc/phppgadmin/config.inc.php
  }

  install_mapbender_database_updateMapbenderDB(){
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "CREATE SCHEMA django AUTHORIZATION $mapbender_database_user"
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'CREATE SCHEMA mapbender'
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "ALTER DATABASE $mapbender_database_name SET search_path TO mapbender,public,pg_catalog,topology"
    #####################
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/pgsql_schema_2.5.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/pgsql_data_2.5.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/pgsql_serial_set_sequences_2.5.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.5_to_2.5.1rc1_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.5.1rc1_to_2.5.1_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.5.1_to_2.6rc1_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.6rc1_to_2.6_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.6_to_2.6.1_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.6.1_to_2.6.2_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.6.2_to_2.7rc1_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7rc1_to_2.7rc2_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.1_to_2.7.2_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.2_to_2.7.3_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.3_to_2.7.4_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.4_to_2.8_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.8_pgsql_UTF-8.sql
  }

  install_mapbender_database_installGUIs(){
    # recreate the guis via psql
    cp ${installation_folder}mapbender/resources/db/gui_Geoportal-RLP.sql ${installation_folder}gui_${default_gui_name}.sql
    cp ${installation_folder}mapbender/resources/db/gui_Geoportal-RLP_2019.sql ${installation_folder}gui_${default_gui_name}_2019.sql

    # exchange all occurences of old default gui name in sql
    sed -i "s/Geoportal-RLP/${default_gui_name}/g" ${installation_folder}gui_${default_gui_name}.sql
    sed -i "s/Geoportal-RLP_2019/${default_gui_name}_2019/g" ${installation_folder}gui_${default_gui_name}_2019.sql

    # recreate the guis via psql - default gui definition is in installation folder!
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}gui_${default_gui_name}.sql
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}gui_${default_gui_name}_2019.sql

    # do the same for extended search gui
    # alter the name of the default extended search gui in the gui definition
    cp ${installation_folder}mapbender/resources/db/gui_Geoportal-RLP_erwSuche2.sql ${installation_folder}gui_${extended_search_default_gui_name}.sql
    # exchange all occurences of old default gui name in sql
    sed -i "s/Geoportal-RLP_erwSuche2/${extended_search_default_gui_name}/g" ${installation_folder}gui_${extended_search_default_gui_name}.sql
    # recreate the guis via psql - default gui definition is in installation folder!
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}gui_${extended_search_default_gui_name}.sql

    # fix invocation of javascript functions for digitize module
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "UPDATE gui_element SET e_pos = '3' where e_id = 'kml' AND fkey_gui_id = '${default_gui_name}'"
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_Owsproxy_csv.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_admin_wms_metadata.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_admin_wfs_metadata.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_admin_wmc_metadata.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_admin_metadata.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_admin_ows_scheduler.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_PortalAdmin_DE.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/gui_Administration_DE.sql

    # changes for 2019 gui
    sudo -u postgres psql -d mapbender -c "INSERT INTO gui_mb_user (fkey_gui_id, fkey_mb_user_id, mb_user_type) values ('${default_gui_name}_2019',1,'owner')"
    sudo -u postgres psql -d mapbender -c "INSERT INTO gui_mb_group (fkey_gui_id, fkey_mb_group_id) values ('${default_gui_name}_2019',$mapbender_guest_group_id)"
    sudo -u postgres psql -d mapbender -c "INSERT INTO gui_gui_category (fkey_gui_id, fkey_gui_category_id) values ('${default_gui_name}_2019',2);"
  }

  install_mapbender_database_addPrivilegesForDBUser(){
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT USAGE ON SCHEMA mapbender TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT USAGE ON SCHEMA public TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA mapbender TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT ALL PRIVILEGES ON DATABASE $mapbender_database_name TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON DATABASE $mapbender_database_name TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA mapbender TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA mapbender TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT CREATE ON DATABASE $mapbender_database_name TO $mapbender_database_user'"
    su - postgres -c "psql -q -p $mapbender_database_port -d $mapbender_database_name -c 'GRANT CREATE ON SCHEMA mapbender TO $mapbender_database_user'"
  }

  install_mapbender_database_projectionAdoption(){
    wget http://crs.bkg.bund.de/crseu/crs/descrtrans/BeTA/BETA2007.gsb || (echo "Failed to Download BETA2007.gsb";exit;)
    cp BETA2007.gsb /usr/share/proj/
    cp /usr/share/proj/epsg /usr/share/proj/epsg_backup_geoportal
    sed -i "s/<31466> +proj=tmerc +lat_0=0 +lon_0=6 +k=1 +x_0=2500000 +y_0=0 +datum=potsdam +units=m +no_defs  <>/<31466> +proj=tmerc +lat_0=0 +lon_0=6 +k=1 +x_0=2500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs  <>/g" /usr/share/proj/epsg
    sed -i "s/<31467> +proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +datum=potsdam +units=m +no_defs  <>/<31467> +proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs  <>/g" /usr/share/proj/epsg
    sed -i "s/<31468> +proj=tmerc +lat_0=0 +lon_0=12 +k=1 +x_0=4500000 +y_0=0 +datum=potsdam +units=m +no_defs  <>/<31468> +proj=tmerc +lat_0=0 +lon_0=12 +k=1 +x_0=4500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs  <>/g" /usr/share/proj/epsg
    sed -i "s/<31469> +proj=tmerc +lat_0=0 +lon_0=15 +k=1 +x_0=5500000 +y_0=0 +datum=potsdam +units=m +no_defs  <>/<31469> +proj=tmerc +lat_0=0 +lon_0=15 +k=1 +x_0=5500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs  <>/g" /usr/share/proj/epsg
    #####################
    cat << EOF > ${installation_folder}geoportal_database_proj_adaption.sql
    UPDATE spatial_ref_sys SET proj4text='+proj=tmerc +lat_0=0 +lon_0=6 +k=1 +x_0=2500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs' WHERE srid = 31466;
    UPDATE spatial_ref_sys SET proj4text='+proj=tmerc +lat_0=0 +lon_0=9 +k=1 +x_0=3500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs' WHERE srid = 31467;
    UPDATE spatial_ref_sys SET proj4text='+proj=tmerc +lat_0=0 +lon_0=12 +k=1 +x_0=4500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs' WHERE srid = 31468;
    UPDATE spatial_ref_sys SET proj4text='+proj=tmerc +lat_0=0 +lon_0=15 +k=1 +x_0=5500000 +y_0=0 +datum=potsdam +ellps=bessel +nadgrids=@BETA2007.gsb,null +units=m +no_defs' WHERE srid = 31469;
EOF
    sudo -u postgres psql -q -d $mapbender_database_name -f ${installation_folder}geoportal_database_proj_adaption.sql
  }

  install_mapbender_database_setSequences(){
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/pgsql_serial_set_sequences_2.7.sql
  }

  install_mapbender_database_setPermissions(){
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/pgsql_serial_set_sequences_2.7.sql
    sed -i "s/mapbenderdbuser/$mapbender_database_user/g" ${installation_folder}${installation_subfolder_django}setup/change_owner.psql
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}${installation_subfolder_django}scripts/change_owner.psql
  }

  install_mapbender_database(){
    if [ $install_mapbender_database = 'true' ]; then
      echo -e "\n Installing Mapbender database \n"
      install_mapbender_database_createDatabase
      install_mapbender_database_configurePostgreSQL
      install_mapbender_database_create_adoption1
      install_mapbender_database_configurePHPPGAdmin
      install_mapbender_database_updateMapbenderDB
      install_mapbender_database_create_adoption2
      install_mapbender_database_run_adoption1
      install_mapbender_database_installGUIs
      install_mapbender_database_run_adoption2
      install_mapbender_database_addPrivilegesForDBUser
      install_mapbender_database_projectionAdoption
      install_mapbender_database_setSequences
      install_mapbender_database_setPermissions
      echo -e "\n ${green}Successfully installed Mapbender Database! ${reset} \n"
    fi
  }

  install_mapbender_configuration_internationalization(){
    updateI18N
  }

  install_mapbender_configuration_alterFolderPermissions(){
    mkdir -pv ${installation_folder}mapbender/metadata
    echo -e "\n Change owner of ${installation_folder} to www-data... \n"
    chown -R www-data:www-data ${installation_folder}mapbender/http/tmp/
    chown -R www-data:www-data ${installation_folder}mapbender/log/
    chown -R www-data:www-data ${installation_folder}mapbender/http/geoportal/preview/
    chown -R www-data:www-data ${installation_folder}mapbender/http/geoportal/news/
    chown -R www-data:www-data ${installation_folder}mapbender/metadata/
  }

  install_mapbender_configuration_injectToConfigurationFiles(){
    # alter connection type to use curl
    sed -i "s/define(\"CONNECTION\", \"http\");/#define(\"CONNECTION\", \"http\");/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/#define(\"CONNECTION\", \"curl\");/define(\"CONNECTION\", \"curl\");/g" ${installation_folder}conf/mapbender.conf

    #####################
    # define proxy settings
    #####################

    if [ "$custom_proxy" == true ];then
      if [ "$mb_proxy" != "" ];then
        http_proxy_host=`echo $mb_proxy | cut -d: -f1`
        http_proxy_port=`echo $mb_proxy | cut -d: -f2`
      else
        http_proxy_host=""
        http_proxy_port=""
      fi
    fi

    if [ "$http_proxy_host" != "" ]  && [  "$http_proxy_port" != "" ];then
      sed -i "s/define(\"CONNECTION_PROXY\", \"\");/define(\"CONNECTION_PROXY\", \"$http_proxy_host\");/g" ${installation_folder}conf/mapbender.conf
      sed -i "s/define(\"CONNECTION_PORT\", \"\");/define(\"CONNECTION_PORT\", \"$http_proxy_port\");/g" ${installation_folder}conf/mapbender.conf
      sed -i "s/define(\"NOT_PROXY_HOSTS\", \"<ip>,<ip>,<ip>\");/define(\"NOT_PROXY_HOSTS\", \"localhost,127.0.0.1\");/g" ${installation_folder}conf/mapbender.conf

      if [ "$http_proxy_user" != "" ] && [ "$http_proxy_pass" != "" ];then
        sed -i "s/define(\"CONNECTION_USER\", \"\");/ s/define(\"CONNECTION_USER\", \"$http_proxy_user\");/g" ${installation_folder}conf/mapbender.conf
        sed -i "s/define(\"CONNECTION_PASSWORD\", \"\");/ s/define(\"CONNECTION_PASSWORD\", \"$http_proxy_pass\");/g" ${installation_folder}conf/mapbender.conf
      fi
    fi

    if [ "$http_proxy_host" != "" ]  && [  "$http_proxy_port" != "" ];then
        #####################
        # integrated mapserver mapfile for metadata footprints
        #####################
        sed -i "s/#\"wms_proxy_host\" \"%%PROXYHOST%%\"/\"wms_proxy_host\" \"${http_proxy_host}\"/g" ${installation_folder}conf/extents_geoportal_rlp.map
        sed -i "s/#\"wms_proxy_port\" \"%%PROXYPORT%%\"/\"wms_proxy_port\" \"${http_proxy_port}\"/g" ${installation_folder}conf/extents_geoportal_rlp.map

        if [ "$http_proxy_user" != "" ] && [ "$http_proxy_pass" != "" ];then
          sed -i "s/#\"wms_auth_type\" \"%%AUTHTYPE%%\"/\"wms_auth_type\" \"digest\"/g" ${installation_folder}conf/extents_geoportal_rlp.map
          sed -i "s/#\"wms_auth_username\" \"%%USERNAME%%\"/\"wms_auth_username\" \"$http_proxy_user\"/g" ${installation_folder}conf/extents_geoportal_rlp.map
          sed -i "s/#\"wms_auth_password\" \"%%PASSWORD%%\"/\"wms_auth_password\" \"$http_proxy_pass\"/g" ${installation_folder}conf/extents_geoportal_rlp.map
        fi
    fi

    #####################
    # set database connection
    #####################
    sed -i "s/%%DBSERVER%%/localhost/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DBPORT%%/$mapbender_database_port/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DBNAME%%/$mapbender_database_name/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DBOWNER%%/$mapbender_database_user/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DBPASSWORD%%/$mapbender_database_password/g" ${installation_folder}conf/mapbender.conf
    sed -i "s#%%INSTALLATIONFOLDER%%#${installation_folder}#g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DOMAINNAME%%/$hostname,$ipaddress,127.0.0.1/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%WEBADMINMAIL%%/$webadmin_email/g" ${installation_folder}conf/mapbender.conf
    sed -i "s#http://%%DOMAINNAME%%#http://${hostname}#g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%DOMAINNAME%%,vmlxgeoportal1/${hostname},${ipaddress}/g" ${installation_folder}conf/mapbender.conf

    #####################
    # special users & groups
    #####################
    sed -i "s/%%PUBLICUSERID%%/$mapbender_guest_user_id/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%PORTALADMINUSERID%%/1/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%ANONYMOUSUSER%%/$mapbender_guest_user_id/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%ANONYMOUSGROUP%%/$mapbender_guest_group_id/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/%%REGISTRATINGGROUP%%/$mapbender_subadmin_group_id/g" ${installation_folder}conf/mapbender.conf

    #####################
    # enable public user auto session
    #####################
    sed -i "s/#define(\"PUBLIC_USER_AUTO_CREATE_SESSION\", true);/define(\"PUBLIC_USER_AUTO_CREATE_SESSION\", true);/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/#define(\"PUBLIC_USER_DEFAULT_GUI\", \"Geoportal-RLP\");/define(\"PUBLIC_USER_DEFAULT_GUI\", \"${default_gui_name}\");/g" ${installation_folder}conf/mapbender.conf
    sed -i "s/#define(\"PUBLIC_USER_DEFAULT_SRS\", \"EPSG:25832\");/define(\"PUBLIC_USER_DEFAULT_SRS\", \"EPSG:25832\");/g" ${installation_folder}conf/mapbender.conf

    echo -e "\n Copying configurations! \n"
    # copy conf files to right places
    cp -v ${installation_folder}conf/geoportal.conf ${installation_folder}mapbender/conf/
    cp -v ${installation_folder}conf/mapbender.conf ${installation_folder}mapbender/conf/
    # alter other conf files
    sed -i "s#%%INSTALLATIONFOLDER%%#${installation_folder}#g" ${installation_folder}conf/geoportal.conf
    if  ! grep -q "SESSION_NAME"  ${installation_folder}conf/mapbender.conf ;then
      echo 'define("SESSION_NAME", "PHPSESSID");' >> ${installation_folder}conf/mapbender.conf
    fi
    echo -e "\n ${green}Successfully copied configurations! ${reset}\n"

    # mapfile for metadata wms
    sed -i "s#%%INSTALLATIONFOLDER%%#${installation_folder}#g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/dbname=geoportal /dbname=$mapbender_database_name /g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/user=postgres /user=$mapbender_database_user password=$mapbender_database_password /g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/port=5436 /port=$mapbender_database_port /g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/%%BBOXWGS84SPACE%%/$bbox_wgs84/g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/\"wms_proxy_host\" \"%%PROXYHOST%%\"/#\"wms_proxy_host\" \"%%PROXYHOST%%\"/g" ${installation_folder}conf/extents_geoportal_rlp.map
    sed -i "s/\"wms_proxy_port\" \"%%PROXYPORT%%\"/#\"wms_proxy_port\" \"%%PROXYPORT%%\"/g" ${installation_folder}conf/extents_geoportal_rlp.map

    cp ${installation_folder}conf/extents_geoportal_rlp.map ${installation_folder}mapbender/tools/wms_extent/extents.map
    # conf file for invocation of metadata wms
    sed -i "s#%%INSTALLATIONFOLDER%%#${installation_folder}#g" ${installation_folder}conf/extent_service_geoportal_rlp.conf
    sed -i "s/%%BBOXWGS84%%/$bbox_wgs84/g" ${installation_folder}conf/extent_service_geoportal_rlp.conf
    cp ${installation_folder}conf/extent_service_geoportal_rlp.conf ${installation_folder}mapbender/tools/wms_extent/extent_service.conf

    # conf file for atomFeedClient
    sed -i "s#%%center_x_i%%#${center_x_i}#g" ${installation_folder}conf/atomFeedClient.conf
    sed -i "s#%%center_y_i%%#${center_y_i}#g" ${installation_folder}conf/atomFeedClient.conf
    cp ${installation_folder}conf/atomFeedClient.conf ${installation_folder}mapbender/conf/atomFeedClient.conf

    # conf file for mobilemap client
    sed -i "s#%%center_x_i%%#${center_x_i}#g" ${installation_folder}conf/config.js
    sed -i "s#%%center_y_i%%#${center_y_i}#g" ${installation_folder}conf/config.js
    sed -i "s#%%initial_scale_i%%#${initial_scale_i}#g" ${installation_folder}conf/config.js
    sed -i "s#%%map_extent_csv%%#${bbox_current_epsg_csv}#g" ${installation_folder}conf/config.js
    sed -i "s#%%server_url%%#${server_url}#g" ${installation_folder}conf/config.js
    sed -i "s#%%background_hybrid_tms_url%%#${background_hybrid_tms_url}#g" ${installation_folder}conf/config.js
    sed -i "s#%%background_aerial_wms_url%%#${background_aerial_wms_url}#g" ${installation_folder}conf/config.js
    cp ${installation_folder}conf/config.js ${installation_folder}mapbender/http/extensions/mobilemap2/scripts/netgis/config.js

    # conf file for mobilemap.conf
    sed -i "s#%%dhm_wms_url%%#${dhm_wms_url}#g" ${installation_folder}conf/mobilemap.conf
    sed -i "s#%%catalogue_interface%%#${catalogue_interface}#g" ${installation_folder}conf/mobilemap.conf
    sed -i "s#%%background_wms_csv%%#${background_wms_csv}#g" ${installation_folder}conf/mobilemap.conf
    cp ${installation_folder}conf/mobilemap.conf ${installation_folder}mapbender/conf/mobilemap.conf

    # shell script for the monitoring cronjob
    cp -v  ${installation_folder}tools/monitorCapabilities.sh-dist ${installation_folder}tools/monitorCapabilities.sh
    sed -i "s#%%MAPBENDER_ROOT_DIRECTORY%%#${installation_folder}mapbender/#g" ${installation_folder}tools/monitorCapabilities.sh
    sed -i "s#%%ADMINISTRATORS_GROUP_ID%%#${mapbender_subadmin_group_id}#g" ${installation_folder}tools/monitorCapabilities.sh
  }

  install_mapbender_configuration_initialServiceRegistration(){
    cd ${installation_folder}mapbender/tools/
    echo -e '\n Register initial default services. \n'
    ##################### Geoportal-RLP
    eval $wms_1_register_cmd
    echo -e "\n"
    eval $wms_2_register_cmd
    echo -e "\n"
    eval $wms_3_register_cmd
    echo -e "\n"
    ##################### Geoportal-RLP_erwSuche2
    eval $wms_4_register_cmd
    echo -e "\n"
    eval $wms_5_register_cmd
    echo -e "\n"
    ##################### demo service
    eval $wms_6_register_cmd

    if [ $? -eq 0 ];then
  		echo -e "\n ${green}Successfully registered services! ${reset}\n"
	  else
    	echo -e "\n ${red}Registering services failed! ${reset}\n"
    fi
  }

  install_mapbender_configuration_qualifyMainGUI(){
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "UPDATE gui_wms SET gui_wms_epsg = '$epsg' WHERE fkey_gui_id = '${default_gui_name}'"
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "UPDATE layer_epsg SET minx = '$minx', miny = '$miny', maxx = '$maxx', maxy = '$maxy' WHERE fkey_layer_id IN (SELECT layer_id FROM layer WHERE fkey_wms_id IN (SELECT fkey_wms_id FROM gui_wms WHERE fkey_gui_id = '${default_gui_name}' AND gui_wms_position = 0) AND layer_parent='') AND epsg = '$epsg'"
    # set first wms to be seen in the overview mapframe
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "UPDATE gui_element_vars SET var_value = '0' WHERE fkey_gui_id='${default_gui_name}' AND fkey_e_id='overview' AND var_name = 'overview_wms'"
    # set resize option to auto
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "UPDATE gui_element_vars SET var_value = 'auto' WHERE fkey_gui_id='${default_gui_name}' AND fkey_e_id='resizeMapsize' AND var_name = 'resize_option'"
    # set max height and width for resize
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "INSERT INTO gui_element_vars(fkey_gui_id, fkey_e_id, var_name, var_value, context, var_type) VALUES('${default_gui_name}', 'resizeMapsize', 'max_width', '1000', 'define a max mapframe width (units pixel) f.e. 700 or false' ,'var')"
    sudo -u postgres psql -q -p $mapbender_database_port -d $mapbender_database_name -c "INSERT INTO gui_element_vars(fkey_gui_id, fkey_e_id, var_name, var_value, context, var_type) VALUES('${default_gui_name}', 'resizeMapsize', 'max_height', '600', 'define a max mapframe height (units pixel) f.e. 700 or false' ,'var')"
    # run these two update scripts again to fix Administration_GUI, 2.7.4 to 2.8 destroys search_wms_view, change mapbender_subadmin_group_id
    sed -i "s/s.fkey_mb_group_id = 36/s.fkey_mb_group_id = ${mapbender_subadmin_group_id}/g" ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.4_to_2.8_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.4_to_2.8_pgsql_UTF-8.sql
    sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.8_pgsql_UTF-8.sql
  }

  install_mapbender_configuration(){
    if [ $checkout_mapbender_conf = 'true' ]; then
      echo -e "\n Configuring Mapbender. \n"
      install_mapbender_configuration_internationalization
      install_mapbender_configuration_alterFolderPermissions
      install_mapbender_configuration_injectToConfigurationFiles
      install_mapbender_configuration_initialServiceRegistration
      install_mapbender_configuration_qualifyMainGUI
      echo -e "\n ${green}Successfully configured Mapbender! ${reset}\n"
    fi
  }

  install_mapbender_configureApacheHTTPD_create_geoportalSite(){
    cat << EOF > ${installation_folder}geoportal-apache.conf
    <VirtualHost *:80>
            ServerName $hostname
            ServerAdmin $webadmin_email
            ReWriteEngine On
            RewriteRule ^/registry/wfs/([\d]+)\/?$ %{REQUEST_SCHEME}://127.0.0.1/http_auth/http/index.php?wfs_id=\$1 [P,L,QSA,NE]
            RewriteRule ^/layer/(.*) %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/php/mod_showMetadata.php?resource=layer&languageCode=de&id=\$1
            RewriteRule ^/wms/(.*) %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/php/mod_showMetadata.php?resource=wms&languageCode=de&id=\$1
            RewriteRule ^/wmc/(.*) %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/php/mod_showMetadata.php?resource=wmc&languageCode=de&id=\$1
            RewriteRule ^/dataset/(.*) %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/php/mod_dataISOMetadata.php?outputFormat=iso19139&id=\$1

            # for mobilemap2 api
            RewriteCond %{QUERY_STRING} ^(.*)wmcid(.*)$
            RewriteRule /mapbender/extensions/mobilemap/map.php %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/extensions/mobilemap2/index.html?%1wmc_id%2
            RewriteCond %{QUERY_STRING} ^(.*)layerid(.*)$
            RewriteRule /mapbender/extensions/mobilemap/map.php %{REQUEST_SCHEME}://%{SERVER_NAME}/mapbender/extensions/mobilemap2/index.html?%1layerid%2
            # for digitizing module
            RewriteRule ^/icons/maki/([^/]+)/([^/]+)/([^[/]+).png$ %{REQUEST_SCHEME}://127.0.0.1/mapbender/php/mod_getSymbolFromRepository.php?marker-color=\$1&marker-size=\$2&marker-symbol=\$3 [P,L,QSA,NE]

            Alias /static/ ${installation_folder}${installation_subfolder_django}static/

            <Directory ${installation_folder}${installation_subfolder_django}static>
          Options -Indexes -FollowSymlinks
          Require all granted
            </Directory>

            DocumentRoot ${installation_folder}/mapbender/http
            Alias /local ${installation_folder}/mapbender/http/local
          <Directory ${installation_folder}/mapbender/http/local>
            Options -Indexes -FollowSymlinks
            AllowOverride None
          Require ip 127.0.0.1
            </Directory>

            ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
            <Directory "/usr/lib/cgi-bin">
                    AllowOverride None
                    Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
                    #SetEnv http_proxy http://IP:PORT
                    Order allow,deny
                    Allow from all
            </Directory>

            ErrorLog /var/log/apache2/error.log

            # Possible values include: debug, info, notice, warn, error, crit,
            # alert, emerg.
            LogLevel error

            CustomLog /var/log/apache2/access.log combined

            Alias /mapbender ${installation_folder}mapbender/http
            <Directory ${installation_folder}mapbender/http/>
              Options MultiViews
              AllowOverride None
              Order deny,allow
              Allow from all
              #Allow from 127.0.0.0/255.0.0.0 ::1/128
              # Insert filter
              SetOutputFilter DEFLATE
              # Netscape 4.x has some problems...
              BrowserMatch ^Mozilla/4 gzip-only-text/html
              # Netscape 4.06-4.08 have some more problems
              BrowserMatch ^Mozilla/4\.0[678] no-gzip
              # MSIE masquerades as Netscape, but it is fine
              # BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
              # NOTE: Due to a bug in mod_setenvif up to Apache 2.0.48
              # the above regex won't work. You can use the following
              # workaround to get the desired effect:
              BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html
              # Don't compress images
              SetEnvIfNoCase Request_URI \
              \.(?:gif|jpe?g|png)$ no-gzip dont-vary
              # Make sure proxies don't deliver the wrong content
              Header append Vary User-Agent env=!dont-vary
            </Directory>

            <Directory ${installation_folder}mapbender/http/tmp>
              <Files ~ "(.php|.perl|.rb|.py)">
                Order allow,deny
                Deny from all
              </Files>
            </Directory>

            #Part for proxy function
            ProxyPreserveHost On
            #ReWriteEngine On
            SetEnv force-proxy-request-1.0 1
            SetEnv proxy-nokeepalive 1
            ProxyTimeout 50
            #NoProxy localhost
            #ProxyBadHeader Ignore
            ProxyMaxForwards 3
            #RewriteLog "/tmp/rewrite.log"
            #RewriteLogLevel 3

            Alias /owsproxy ${installation_folder}mapbender/owsproxy
            <Directory ${installation_folder}mapbender/owsproxy/>
                    Options +FollowSymLinks
                    ReWriteEngine On
                    RewriteBase /owsproxy
                    RewriteRule  ^([\w\d]+)\/([\w\d]+)\/?$ %{REQUEST_SCHEME}://127.0.0.1/owsproxy/http/index.php?sid=\$1\&wms=\$2\& [P,L,QSA,NE]
                    Options +Indexes
                    Allow from all
            </Directory>

            Alias /tools ${installation_folder}mapbender/tools
            <Directory ${installation_folder}mapbender/tools/>
                    Options +FollowSymLinks
                    AllowOverride None
                    AuthType Digest
                    AuthName "mb_tools"
                    AuthDigestProvider file
                    AuthUserFile ${installation_folder}access/.mb_tools
                    Require valid-user
                    order deny,allow
                    deny from all
                    Options +Indexes
                    Allow from all
            </Directory>

            Alias /http_auth ${installation_folder}mapbender/http_auth
            <Directory ${installation_folder}mapbender/http_auth/>
                    Options +FollowSymLinks +Indexes
                    ReWriteEngine On
                    RewriteBase /http_auth
                    RewriteRule  ^([\w\d]+)\/?$ %{REQUEST_SCHEME}://127.0.0.1/http_auth/http/index.php?layer_id=\$1 [P,L,QSA,NE]
                    Order allow,deny
                    Allow from all
            </Directory>

            #wsgi config
            WSGIDaemonProcess $hostname  python-path=${installation_folder}${installation_subfolder_django} python-home=${installation_folder}env processes=2 threads=15 display-name=%{GROUP}
            WSGIProcessGroup $hostname
            WSGIScriptAlias / ${installation_folder}${installation_subfolder_django}Geoportal/wsgi.py
            <Directory ${installation_folder}${installation_subfolder_django}Geoportal>
            Options +ExecCGI
            Require all granted
            </Directory>

    </VirtualHost>
EOF
  }

  install_mapbender_configureApacheHTTPD_enable_geoportalSite(){
    cp -av ${installation_folder}geoportal-apache.conf /etc/apache2/sites-available/
    echo -e "\n Enabling apache2 modules. \n"
    a2enmod rewrite
    a2enmod cgi
    # a2enmod serv-cgi-bin
    a2enmod proxy_http
    a2enmod headers
    a2enmod auth_digest
    # to be compatible to older apache2.2 directives:
    a2enmod access_compat
  }

  install_mapbender_configureApacheHTTPD_alterApacheConf(){
    cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf_backup_geoportal
    # replace only the first occurence of Require all denied - this is the entry for /
    sed -i "0,/Require all denied/{s/Require all denied/Require all granted/}" /etc/apache2/apache2.conf
    sed -i "s/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_COMPILE_ERROR|E_ERROR|E_CORE_ERROR/g" /etc/php/7.0/apache2/php.ini
    service apache2 restart
    if [ "$?" -ne 0 ];then
      echo -e "\n ${red} Apache HTTPD restart failed! ${reset}\n"
      exit
    fi
  }

  install_mapbender_configureApacheHTTPD_configurePHPPGAdmin(){
    echo -e '\n Adopt phppgadmin default apache24 configuration. \n'
    cp /etc/apache2/conf-available/phppgadmin.conf /etc/apache2/conf-available/phppgadmin.conf_backup_geoportal
    cat << EOF > /etc/apache2/conf-available/phppgadmin.conf
    Alias /phppgadmin /usr/share/phppgadmin

    <Directory /usr/share/phppgadmin>

    DirectoryIndex index.php
    AllowOverride None

    # Only allow connections from localhost:

    AuthType Digest
    AuthName "phppgadmin"
    AuthDigestProvider file
    AuthUserFile ${installation_folder}access/.phppgadmin
    Require valid-user

    <IfModule mod_php.c>
      php_flag magic_quotes_gpc Off
      php_flag track_vars On
      #php_value include_path .
    </IfModule>
    <IfModule !mod_php.c>
      <IfModule mod_actions.c>
        <IfModule mod_cgi.c>
          AddType application/x-httpd-php .php
          Action application/x-httpd-php /cgi-bin/php
        </IfModule>
        <IfModule mod_cgid.c>
          AddType application/x-httpd-php .php
          Action application/x-httpd-php /cgi-bin/php
        </IfModule>
      </IfModule>
    </IfModule>

    </Directory>
EOF
  }

  install_mapbender_configureApacheHTTPD_securitySettings_firewallConf(){
    if [ ! -f "/etc/firewall.conf"  ]; then
        cat << EOF > /etc/firewall.conf
    # Generated by iptables-save v1.6.0 on Wed Apr 10 08:53:32 2019
    *filter
    :INPUT ACCEPT [34:2360]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [18:1640]
    -A INPUT -p tcp -m tcp --dport 80 --tcp-flags FIN,SYN,RST,ACK SYN -m connlimit --connlimit-above 100 --connlimit-mask 32 --connlimit-saddr -j REJECT --reject-with tcp-reset
    COMMIT
    # Completed on Wed Apr 10 08:53:32 2019
EOF
    fi  
  }

  install_mapbender_configureApacheHTTPD_securitySettings_iptablesConf(){
    if [ ! -f "/etc/network/if-up.d/iptables"  ]; then
    cat << EOF > /etc/network/if-up.d/iptables
    #!/bin/sh
    iptables-restore < /etc/firewall.conf
EOF
    fi
  }

  install_mapbender_configureApacheHTTPD_securitySettings_adjustSettings(){
    if  ! grep -q "MaxRequestsPerChild"  /etc/apache2/apache2.conf ;then
      sed -i '/^MaxKeepAliveRequests*/a MaxRequestsPerChild 10000' /etc/apache2/apache2.conf
    fi

    if  ! grep -q "FileETag None"  /etc/apache2/apache2.conf ;then
      sed -i '/^MaxKeepAliveRequests*/a FileETag None' /etc/apache2/apache2.conf
    fi

    if  ! grep -q "Header set X-XSS-Protection \"1; mode=block\""  /etc/apache2/conf-available/security.conf ;then
      echo  "Header set X-XSS-Protection \"1; mode=block\"" >>/etc/apache2/conf-available/security.conf
    fi

    if  ! grep -q "Timeout"  /etc/apache2/conf-available/security.conf ;then
      echo  "Timeout 60" >>/etc/apache2/conf-available/security.conf
    fi

    if  ! grep -q -w "session.cookie_httponly = On"  /etc/php/7.0/apache2/php.ini ;then
      sed -i s/"session.cookie_httponly ="/"session.cookie_httponly = On"/g /etc/php/7.0/apache2/php.ini
    fi

    if  ! grep -q -w "session.cookie_lifetime = 14400"  /etc/php/7.0/apache2/php.ini ;then
      sed -i s/"session.cookie_lifetime = 0"/"session.cookie_lifetime = 14400"/g /etc/php/7.0/apache2/php.ini
    fi

    if  ! grep -q -w "session.hash_function = 0"  /etc/php/7.0/apache2/php.ini ;then
      sed -i s/"session.hash_function = 0"/"session.hash_function = 1"/g /etc/php/7.0/apache2/php.ini
    fi

    if  ! grep -q -w "allow_webdav_methods = Off"  /etc/php/7.0/apache2/php.ini ;then
      sed -i "/^doc_root*/a allow_webdav_methods = Off" /etc/php/7.0/apache2/php.ini
    fi

    if  ! grep -q "\-I"  /etc/memcached.conf ;then
    echo  "-I 10m" >>/etc/memcached.conf
    fi

    sed -i s/"ServerTokens OS"/"ServerTokens Prod"/g /etc/apache2/conf-available/security.conf
    sed -i s/"ServerSignature On"/"ServerSignature Off"/g /etc/apache2/conf-available/security.conf
  }

  install_mapbender_configureApacheHTTPD_securitySettings_modsecurity(){
    cp -av /etc/modsecurity/modsecurity.conf-recommended  /etc/modsecurity/modsecurity.conf
    rm -rf /usr/share/modsecurity-crs

    echo -e "\n Downloading Modsecurity Ruleset! \n"
    git clone --progress https://github.com/SpiderLabs/owasp-modsecurity-crs.git /usr/share/modsecurity-crs

    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully downloaded Modsecurity Ruleset! ${reset}\n"
    else
      echo -e "\n ${red}Downloading Modsecurity Ruleset failed! Check internet connection or proxy! ${reset}\n"
      exit
    fi

    cd /usr/share/modsecurity-crs
    mv crs-setup.conf.example crs-setup.conf

    if [ ! -f "/etc/apache2/mods-available/security2.conf_backup_$(date +"%d_%m_%Y")"  ]; then
      mv /etc/apache2/mods-available/security2.conf /etc/apache2/mods-available/security2.conf_backup_$(date +"%d_%m_%Y")
    fi

    echo "<IfModule security2_module>
    SecDataDir /var/cache/modsecurity
    IncludeOptional /etc/modsecurity/*.conf
    IncludeOptional /usr/share/modsecurity-crs/*.conf
    IncludeOptional /usr/share/modsecurity-crs/rules/*.conf
    SecRequestBodyNoFilesLimit 10485760
    SecRuleRemoveById 920350

    </IfModule>" > /etc/apache2/mods-available/security2.conf

    ############################################################
    # activate apache conf and reload
    ############################################################
    a2enmod security2
    a2ensite geoportal-apache
    a2dissite 000-default
    service apache2 restart
    if [ "$?" -ne 0 ];then
      echo -e "\n ${red} Restarting Apache HTTPD failed! ${reset} \n"
      echo 'Error called in function "install_mapbender_configureApacheHTTPD_securitySettings_modsecurity" '
      exit 12
    fi
  }

  install_mapbender_configureApacheHTTPD_securitySettings(){
    install_mapbende_configureApacheHTTPD_securitySettings_firewallConf
    install_mapbende_configureApacheHTTPD_securitySettings_iptablesConf
    iptables-restore < /etc/firewall.conf
    chmod +x /etc/network/if-up.d/iptables
    install_mapbender_configureApacheHTTPD_securitySettings_adjustSettings
    install_mapbender_configureApacheHTTPD_securitySettings_modsecurity
  }

  install_mapbender_configureApacheHTTPD(){
    if [ $configure_apache = 'true' ]; then
      echo -e  "\n Creating apache configuration. \n"
      install_mapbender_configureApacheHTTPD_create_geoportalSite
      install_mapbender_configureApacheHTTPD_enable_geoportalSite
      install_mapbender_configureApacheHTTPD_alterApacheConf
      install_mapbender_configureApacheHTTPD_configurePHPPGAdmin
      install_mapbender_configureApacheHTTPD_securitySettings
      echo -e  "\n ${green}Successfully configured Apache! ${reset}\n"
    fi
  }

  install_mapbender_cronjobs(){
    echo -e  "\n Configuring Cron!\n"
    ############################################################
    # add privileges on search tables to mapbender database user from installation
    ############################################################
    echo "GRANT ALL ON TABLE wms_search_table TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wms_view.sql
    echo "ALTER TABLE wms_search_table OWNER TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wms_view.sql
    echo "ALTER TABLE wms_list OWNER TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wms_view.sql
    echo "GRANT ALL ON TABLE wfs_search_table TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wfs_view.sql
    echo "ALTER TABLE wfs_search_table OWNER TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wfs_view.sql
    echo "GRANT ALL ON TABLE dataset_search_table TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_dataset_view.sql
    echo "ALTER TABLE dataset_search_table OWNER TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_dataset_view.sql
    echo "GRANT ALL ON TABLE wmc_search_table TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wmc_view.sql
    echo "ALTER TABLE wmc_search_table OWNER TO $mapbender_database_user;" >> ${installation_folder}mapbender/resources/db/materialize_wmc_view.sql
    ############################################################
    if [ $configure_cronjobs = 'true' ]; then
      mkdir -pv ${installation_folder}cronjobs/
      cp -v setup/generateMetadata.sh ${installation_folder}cronjobs/generateMetadata.sh
      chmod u+x ${installation_folder}cronjobs/generateMetadata.sh
      
      ############################################################
      # install cronjobs for root account
      ############################################################

      # 1. delete old monitoring xmls
      croncmd1="find ${installation_folder}mapbender/tools/tmp -type f -print | xargs rm -f"
      cronjob1="25 1,3,5,7,9,11,13,15,17,19,21,23 * * * $croncmd1"

      if [ -f "/var/spool/cron/crontabs/root" ];then
        ( crontab -l | grep -v -F "$croncmd1" ; echo "$cronjob1" ) | crontab -
      else
        echo "$cronjob1" | crontab -
      fi
      
      # 2. delete mapbender tmp files
      croncmd2="find ${installation_folder}mapbender/http/tmp  -name '*.*' -mmin +40 -type f | xargs rm -f"
      cronjob2="55 * * * * $croncmd2"
      ( crontab -l | grep -v -F "$croncmd2" ; echo "$cronjob2" ) | crontab -
      
      # 3. delete mapbender tmp wmc files
      croncmd3="find ${installation_folder}mapbender/http/tmp/wmc  -name '*' -mmin +40 -type f | xargs rm -f"
      cronjob3="55 * * * * $croncmd3"
      ( crontab -l | grep -v -F "$croncmd3" ; echo "$cronjob3" ) | crontab -
      
      # 4. delete mapbender log files
      croncmd4="find ${installation_folder}mapbender/log  -name '*.log' -mmin +40 -type f | xargs rm -f"
      cronjob4="5 * * * * $croncmd4"
      ( crontab -l | grep -v -F "$croncmd4" ; echo "$cronjob4" ) | crontab -
      
      # 5. generate metadata xml files
      croncmd5="sh ${installation_folder}cronjobs/generateMetadata.sh"
      cronjob5="45 23 * * * $croncmd5"
      ( crontab -l | grep -v -F "$croncmd5" ; echo "$cronjob5" ) | crontab -
      
      # 6. run ows scheduler - to update ows capabilities
      croncmd6="/usr/bin/php ${installation_folder}mapbender/tools/mod_runScheduler.php"
      cronjob6="57 23 * * * $croncmd6"
      ( crontab -l | grep -v -F "$croncmd6" ; echo "$cronjob6" ) | crontab -
      
      # 7. materialize application search view
      croncmd7="su - postgres -c \"PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/materialize_application_view.sql\""
      cronjob7="0,30 * * * * $croncmd7"
      ( crontab -l | grep -v -F "$croncmd7" ; echo "$cronjob7" ) | crontab -

      # 8. materialize wms search view
      croncmd8="su - postgres -c \"PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/materialize_wms_view.sql\""
      cronjob8="0,30 * * * * $croncmd8"
      ( crontab -l | grep -v -F "$croncmd8" ; echo "$cronjob8" ) | crontab -
      
      # 9. materialize dataset search view
      croncmd9="su - postgres -c \"PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/materialize_dataset_view.sql\""
      cronjob9="1,31 * * * * $croncmd9"
      ( crontab -l | grep -v -F "$croncmd9" ; echo "$cronjob9" ) | crontab -
      
      # 10. materialize wfs search view
      croncmd10="su - postgres -c \"PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/materialize_wfs_view.sql\""
      cronjob10="2,32 * * * * $croncmd10"
      ( crontab -l | grep -v -F "$croncmd10" ; echo "$cronjob10" ) | crontab -
      
      # 11. monitor capabilities (wms/wfs)
      croncmd11="sh ${installation_folder}mapbender/tools/monitorCapabilities.sh"
      cronjob11="7 2,4,6,8,10,12,14,16,18,20,22 * * * $croncmd11"
      ( crontab -l | grep -v -F "$croncmd11" ; echo "$cronjob11" ) | crontab -
      
      # 12. materialize wmc search view
      croncmd12="su - postgres -c \"PGOPTIONS='--client-min-messages=warning' psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/materialize_wmc_view.sql\""
      cronjob12="3,13,23,33,43,53 * * * * $croncmd12"
      ( crontab -l | grep -v -F "$croncmd12" ; echo "$cronjob12" ) | crontab -
      
      # 13. delete inactive users
      croncmd13="su - postgres -c \"psql -q -p $mapbender_database_port -d $mapbender_database_name -f ${installation_folder}mapbender/resources/db/delete_inactive_users.sql\""
      cronjob13="0 0 * * * $croncmd13"
      ( crontab -l | grep -v -F "$croncmd13" ; echo "$cronjob13" ) | crontab -

      ##TODO: send mails
    fi

    ############################################################
    # initially monitor registrated services and add them to catalogue (materialize search tables)
    ############################################################
    eval $croncmd11
    eval $croncmd7
    eval $croncmd8
    eval $croncmd9
    eval $croncmd10
    eval $croncmd12

    echo -e  "\n ${green}Successfully configured Cron! ${reset}\n"
  }

  install_mapbender(){
    install_mapbender_filesystem
    install_mapbender_database
    install_mapbender_configuration
    install_mapbender_configureApacheHTTPD
    install_mapbender_cronjobs

    chown -R www-data:www-data ${installation_folder}mapbender/log/
    phppgadmin_realm="phppgadmin"
    digest_phppgadmin="$( printf "%s:%s:%s" "$phppgadmin_user" "$phppgadmin_realm" "$phppgadmin_password" | md5sum | awk '{print $1}' )"
    printf "%s:%s:%s\n" "$phppgadmin_user" "$phppgadmin_realm" "$digest_phppgadmin" >> ${installation_folder}"access/.phppgadmin"
  }

  install_django_debian_packages(){
    echo -e "\n Installing needed Debian packages for Django \n"
    apt-get update
    apt-get install -y apache2 apache2-dev python3 python3-dev git python3-pip virtualenv libapache2-mod-wsgi-py3 composer zip mysql-utilities zlib1g-dev libjpeg-dev libfreetype6-dev python-dev
    if [ "$?" -eq 0 ];then
      echo -e "\n ${green}Successfully installed Debian packages for Django! ${reset}\n"
    else
      echo -e "\n ${red}Error! Package installation failed. ${reset}\n"
      echo 'Error called in function "install_debian_packaged" '
      exit
    fi
  }

  install_django_checkoutRepository(){
    if [ -d "${installation_folder}${installation_subfolder_django}" ];then
      echo -e "\n ${red} Folder ${installation_folder}${installation_subfolder_django} found, please remove it! ${reset}\n"
      exit
    fi

    echo -e "\n Downloading Geoportal Source to ${installation_folder}! \n"
    git clone -b ${git_django_repositoryBranch} --progress --single-branch ${git_django_repositoryURL} >> $installation_log 2>&1
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully downloaded Geoportal Source! ${reset}\n"
    else
      echo -e "\n ${red}Downloading Geoportal Source failed! Check internet connection or proxy! ${reset}\n"
      exit
    fi
  }

  install_django_configuration(){
    echo -e "\n Configuring Django. \n"

    # this directory is used to store php helper scripts for the intermediate geoportal solution
    mkdir -pv ${installation_folder}mapbender/http/local

    # copy some mapbender related scripts
    cp -a ${installation_folder}${installation_subfolder_django}scripts/guiapi.php ${installation_folder}mapbender/http/local/guiapi.php
    cp -a ${installation_folder}mapbender/http/geoportal/authentication.php ${installation_folder}mapbender/http/geoportal/authentication.php.backup
    cp -a ${installation_folder}${installation_subfolder_django}scripts/authentication.php ${installation_folder}mapbender/http/geoportal/authentication.php
    cp -a ${installation_folder}${installation_subfolder_django}scripts/delete_inactive_users.sql ${installation_folder}mapbender/resources/db/delete_inactive_users.sql
    cp -a ${installation_folder}mapbender/conf/mapbender.conf /${installation_folder}mapbender/conf/mapbender.conf.backup
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/javascripts/mb_downloadFeedClient.php ${installation_folder}/mapbender/http/javascripts/
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/plugins/mb_downloadFeedClient.php ${installation_folder}/mapbender/http/plugins/
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/style.css ${installation_folder}/mapbender/http/extensions/OpenLayers-2.13.1/theme/default/
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/move.png ${installation_folder}/mapbender/http/extensions/OpenLayers-2.13.1/theme/default/img/
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/select.png ${installation_folder}/mapbender/http/extensions/OpenLayers-2.13.1/theme/default/img/
    cp -a ${installation_folder}${installation_subfolder_django}scripts/mb_downloadFeedClient/OpenLayers.js ${installation_folder}mapbender/http/extensions/OpenLayers-2.13.1/

    # change mapbender login path
    sed -i "s/#define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/mapbender\/frames\/login.php\");/define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/mapbender\/frames\/login.php\");/g" ${installation_folder}mapbender/conf/mapbender.conf
    sed -i "s/define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/portal\/anmelden.html\");/#define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/portal\/anmelden.html\");/g" ${installation_folder}mapbender/conf/mapbender.conf

    # django code
    sed -i s/"HOSTNAME = \"localhost\""/"HOSTNAME = \"$hostname\""/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i "s#PROJECT_DIR = \"/data/\"#PROJECT_DIR = \"${installation_folder}\"#g" ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i s/"        'USER':'mapbenderdbuser',"/"        'USER':'$mapbender_database_user',"/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i s/"        'PASSWORD':'mapbenderdbpassword',"/"        'PASSWORD':'$mapbender_database_password',"/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i s/"        'NAME':'mapbender',"/"        'NAME':'$mapbender_database_name',"/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i s/"EMAIL_HOST = 'server.domain.tld'"/"EMAIL_HOST = \"$email_hosting_server\""/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    sed -i s/"EMAIL_HOST_USER = 'geoportal@server.domain.tld'"/"EMAIL_HOST_USER = \"$webadmin_email\""/g ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
  }

  install_django_evenMorePHPINIAdjustments(){
    # enable php_serialize
    if ! grep -q "php_serialize"  /etc/php/7.0/apache2/php.ini;then
      sed -i s/"session.serialize_handler = php"/"session.serialize_handler = php_serialize"/g /etc/php/7.0/apache2/php.ini
    fi

    # activate memcached
    sed -i s/"session.save_handler = files"/"session.save_handler = memcached"/g /etc/php/7.0/apache2/php.ini
    sed -i s"/;     session.save_path = \"N;\/path\""/"session.save_path = \"127.0.0.1:11211\""/g /etc/php/7.0/apache2/php.ini
  }

  install_django_python_virtualEnv(){
    cd ${installation_folder}${installation_subfolder_django}
    echo -e "\n Creating Virtualenv in ${installation_folder}env. \n"
    # create and activate virtualenv
    virtualenv -ppython3 ${installation_folder}env

    if [ $? -eq 0 ];then
      echo -e "\n ${green} Successfully created virtualenv in ${installation_folder}env! ${reset}\n"
    else
      echo -e "\n ${green} Creation of virtualenv in ${installation_folder}env failed! ${reset}\n"
      exit
    fi
  }

  install_django_python_installDependencies(){
    source ${installation_folder}env/bin/activate
    if [ "$?" -ne 0 ];then
      echo -e "\n ${red}Error! Could not activate virtueal environment. ${reset}\n"
      echo 'Error called in function "install_django_python_installDependencies" '
      exit
    fi

    echo -e "\n Installing needed python libraries. \n"
    pip install -r ${installation_folder}${installation_subfolder_django}setup/requirements.txt
    echo -e "\n ${green} Successfully installed python libraries! ${reset}\n"
  }

  install_django_python_initializeDjango(){
    rm -rv ${installation_folder}${installation_subfolder_django}static
    python manage.py collectstatic
    python manage.py migrate --fake sessions zero
    python manage.py migrate --fake-initial
    python manage.py makemigrations useroperations
    python manage.py migrate useroperations
    python manage.py makemessages
    python manage.py compilemessages
    python manage.py loaddata useroperations/fixtures/navigation.json

    service apache2 restart
    if [ "$?" -eq 0 ];then
      echo -e "\n ${green}Successfully configured Django! ${reset}\n"
    else
      echo -e "\n ${red}Error! Unable to restart apache httpd. ${reset}\n"
      echo 'Error called in function "install_django_python_initializeDjango" '
      exit
    fi
  }

  install_django(){
    install_django_debian_packages
    install_django_checkoutRepository
    install_django_configuration
    install_django_evenMorePHPINIAdjustments
    install_django_python_virtualEnv
    install_django_python_installDependencies
    install_django_python_initializeDjango
  }

  install_mediawiki_packageInstallation(){
    if [ ! -f "/etc/apt/sources.list.d/backports.list"  ]; then
      echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list.d/backports.list
    fi
    echo -e "\n Installing Mediawiki! \n"
    apt-get update
    apt-get install -y -t stretch-backports mediawiki
    if [ "$?" -eq 0 ];then
      echo -e "\n ${green}Successfully installed Mediawiki ${reset}! \n"
    else
      echo -e "\n ${red}Error! Package installation failed. ${reset}\n"
      echo 'Error called in function "install_mediawiki_packageInstallation" '
      exit
    fi
  }

  install_mediawiki_database(){
    echo -e "\n Configuring Mysql! \n"
    mysql -uroot -e "UPDATE mysql.user SET Password=PASSWORD('$mysql_root_pw') WHERE User='root';"
    mysql -uroot -e "update mysql.user set plugin='' where user='root';"
    mysql -uroot -e "flush privileges;"

    mysql -uroot -p$mysql_root_pw -e "DELETE FROM mysql.user WHERE User='';"
    mysql -uroot -p$mysql_root_pw -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -uroot -p$mysql_root_pw -e "DROP DATABASE IF EXISTS test;"
    mysql -uroot -p$mysql_root_pw -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -uroot -p$mysql_root_pw -e "FLUSH PRIVILEGES;"
    mysql -uroot -p$mysql_root_pw -e "create database Geoportal;"
    mysql -uroot -p$mysql_root_pw -e "CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_user_pw';"
    mysql -uroot -p$mysql_root_pw -e "GRANT ALL PRIVILEGES ON Geoportal.* TO '$mysql_user'@'localhost' WITH GRANT OPTION;"
    mysql -uroot -p$mysql_root_pw Geoportal < ${installation_folder}${installation_subfolder_django}scripts/geoportal.sql

    if [ "$?" -eq 0 ];then
      echo -e "\n ${green}Successfully configured Mysql! ${reset}\n"
    else
      echo -e "\n ${red}Error! MySQL Configuration failed. ${reset}\n"
      echo 'Error called in function "install_mediawiki_database" '
      exit
    fi
  }

  install_mediawiki_extensions(){
    echo -e "\n Downloading MediaWikiLanguageExtensionBundle! \n"
    cd /tmp/
    wget https://translatewiki.net/mleb/MediaWikiLanguageExtensionBundle-2019.01.tar.bz2

    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully downloaded MediaWikiLanguageExtensionBundle! ${reset}\n"
    else
      echo -e "\n ${red}Failed to Download MediawikiLanguageExtensionBundle! Check connection or proxy! ${reset}\n"
      echo 'Error called in function "install_mediawiki_extensions" '
      exit
    fi

    tar -kxjf MediaWikiLanguageExtensionBundle-2019.01.tar.bz2
    rm /usr/share/mediawiki/extensions/LocalisationUpdate
    cp -a /tmp/extensions/* /usr/share/mediawiki/extensions
    rm -r /tmp/extensions
    rm /tmp/MediaWikiLanguageExtensionBundle-2019.01.tar.bz2
  }

  install_mediawiki_replaceScriptFiles(){
    cp -av ${installation_folder}${installation_subfolder_django}scripts/LocalSettings.php /etc/mediawiki/LocalSettings.php
    cp -av ${installation_folder}${installation_subfolder_django}scripts/mediawiki_css/* /usr/share/mediawiki/skins/
  }

  install_mediawiki_configureSemanticMediaWiki(){
    echo -e "\n Configuring Composer for SemanticMediaWiki extension! \n"
    cd /usr/share/mediawiki
    useradd composer
    mkdir -p /usr/share/mediawiki/extensions/SemanticMediaWiki/
    touch /usr/share/mediawiki/composer.json
    chown composer /usr/share/mediawiki/extensions/SemanticMediaWiki/
    chown composer /usr/share/mediawiki/composer.json
    chown composer /usr/share/mediawiki/
    chown -R composer /usr/share/mediawiki/vendor/
    su composer -c "composer require mediawiki/semantic-media-wiki "~2.5" --update-no-dev"
    if [ "$?" -eq 0 ];then
      echo -e "\n ${green}Successfully configured composer! ${reset} \n"
    else
      echo -e "\n ${red}Error! Configuring Semantic MediaWiki failed. ${reset}\n"
      echo 'Error called in function "install_mediawiki_configureSemanticMediaWiki" '
      exit
    fi
  }

  install_mediawiki_injectLocalSettings(){
    sed -i s/"\$wgDefaultSkin = \"vector\";/\$wgDefaultSkin = \"timeless\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"\$wgServer = \"http:\/\/192.168.56.222\";"/"\$wgServer = \"http:\/\/${hostname}\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"\$wgEmergencyContact = \"apache@192.168.56.222\";"/"\$wgEmergencyContact = \"apache@${hostname}\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"\$wgPasswordSender = \"apache@192.168.56.222\";"/"\$wgPasswordSender = \"apache@${hostname}\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"\$wgDBuser = \"geowiki\";"/"\$wgDBuser = \"${mysql_user}\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"\$wgDBpassword = \"root\";"/"\$wgDBpassword = \"${mysql_user_pw}\";"/g /etc/mediawiki/LocalSettings.php
    sed -i s/"enableSemantics( '192.168.56.222' );"/"enableSemantics( '${hostname}' );"/g /etc/mediawiki/LocalSettings.php
    if ! grep -q "\$wgRawHtml ="  /etc/mediawiki/LocalSettings.php;then
      echo "\$wgRawHtml = true;" >> /etc/mediawiki/LocalSettings.php
    fi
  }

  install_mediawiki_update(){
    if [[ $(which php &> /dev/null) -eq 0 ]];then
      php /usr/share/mediawiki/maintenance/update.php --quiet --skip-external-dependencies
    else
      exit 10
    fi
  }

  install_mediawiki(){
    install_mediawiki_packageInstallation
    install_mediawiki_database
    install_mediawiki_extensions
    install_mediawiki_replaceScriptFiles
    install_mediawiki_configureSemanticMediaWiki
    install_mediawiki_injectLocalSettings
    install_mediawiki_update
  }

  install_full(){
    install_prepareInstall
    install_createDirectories
    install_applyProxyConfiguration
    install_echoInstallationParameters
    install_installSystemPackages
    install_configurePHPLogging
    install_mapbender
    install_django
    install_mediawiki
    echo -e "\n ${green}Installation Complete! ${reset}\n"
  }
  install_full

  postInstallationChecks_apacheHTTPD(){
    pgrep apache2 > /dev/null
    if [ $? -ne 0 ];then
      echo -e "\n ${red}Apache is not running! Going to check syntax and restart it! ${reset}\n"
      apache2ctl configtest
      service apache2 restart
    else
      echo -e "\n ${green}Apache is up and running! ${reset}\n"
    fi
  }

  postInstallationChecks_curlLandingPage(){
    if [[ $(which curl &> /dev/null) -eq 0 ]];then
      echo -e "\n Trying to reach the index page! \n"
    else
      echo -e "Curl is not installed"
      exit 10
    fi
    curl --noproxy 127.0.0.1 -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36" -s -L 127.0.0.1 | grep "Geoportal" >> /dev/null
    if [ $? -ne 0 ];then
      echo -e "\n ${red}Index page does not look right! Check /var/log/apache2/error.log ${reset}\n"
    else
      echo -e "\n ${green}Index pages seems ok! Have Fun! ${reset}\n"
    fi
  }

  postInstallationChecks(){
    echo -e "Doing some checks!"
    postInstallationChecks_apacheHTTPD
    postInstallationChecks_curlLandingPage
    echo -e "\n Details can be found in $installation_log \n"
  }
  postInstallationChecks

}

update(){

  update_custom_update(){
    if [ -e ${installation_folder}"custom_files.txt" ];then
      if [ "$1" == "save" ];then
        input="${installation_folder}/custom_files.txt"
        while IFS= read -r line
        do
          directory=`echo $line | cut -d / -f 3-`
          filename=`echo $line | cut -d / -f 3- | rev | cut -d / -f -1 | rev`
          directory=${directory%$filename}
          mkdir -p /tmp/custom_files/$directory
          cp -a $line /tmp/custom_files/
        done < "$input"
      fi
      if [ "$1" == "restore" ];then
          cp -a /tmp/custom_files/* ${installation_folder}
      fi
    fi
    if [ "$1" == "script" ];then
      while true; do
          read -p "Do you want to use a custom update script? Should lie under ${installation_folder}custom_update.sh y/n?" yn
          case $yn in
              [Yy]* ) source ${installation_folder}custom_update.sh;break;;
              [Nn]* ) exit;break;;
              * ) echo "Please answer yes or no.";;
          esac
      done
    fi
  }

  external_db_update(){
    psql \
      -X \
      -U $mapbender_database_superuser \
      -h $mapbender_database_host \
      -p $mapbender_database_port \
      -f ${installation_folder}mapbender/resources/db/pgsql/UTF-8/update/update_2.7.4_to_2.8_pgsql_UTF-8.sql \
      --echo-all \
      $mapbender_database_name

      psql_exit_status=$?

      if [ $psql_exit_status != 0 ]; then
        echo "Update of remote Database failed! Exiting." 1>&2
        exit $psql_exit_status
      fi
      echo "sql script successful"
  }

  checkDjangoSettings_fetchSettingsFromRepository(){
    if [ -f /tmp/settings.py ]; then
      /bin/rm /tmp/settings.py
    fi
    wget ${git_django_settingsURL} -P /tmp/
  }

  checkDjangoSettings(){
    echo "Checking differences in config files"
    missing_items=()
    checkDjangoSettings_fetchSettingsFromRepository

    while IFS="" read -r p || [ -n "$p" ]
      do
        h=`printf '%s\n' "$p" | cut -d = -f 1`
        if ! grep -Fq "$h" ${installation_folder}/${installation_subfolder_django}Geoportal/settings.py
        then
            missing_items+=("$h")
          fi
    done < /tmp/settings.py

    if [ ${#missing_items[@]} -ne 0 ]; then
      echo "The following items are present in the masters settings.py but are missing in your local settings.py!"
      printf '%s\n' "${missing_items[@]}"
      while true; do
          read -p "Do you want to continue y/n?" yn
          case $yn in
              [Yy]* ) break;;
              [Nn]* ) exit;break;;
              * ) echo "Please answer yes or no.";;
          esac
      done
    fi
  }

  update_mapbender_copyConfigurations(){
    echo -e "\n Backing up Mapbender Configs \n"
    mkdir -p ${temporaryConfigDirectory}conf/
    mkdir -p ${temporaryConfigDirectory}tools/wms_extent/
    mkdir -p ${temporaryConfigDirectory}http/extensions/mobilemap/
    mkdir -p ${temporaryConfigDirectory}http/extensions/mobilemap2/
    cp -av ${installation_folder}mapbender/conf/*.conf ${temporaryConfigDirectory}conf/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extents.map  ${temporaryConfigDirectory}tools/wms_extent/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extent_service.conf ${temporaryConfigDirectory}tools/wms_extent/
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap ${temporaryConfigDirectory}http/extensions/mobilemap
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap2 ${temporaryConfigDirectory}http/extensions/mobilemap2
  }

  update_mapbender_gitFetch(){
    cd ${installation_folder}mapbender
    git reset --hard
    git pull
  }

  update_mapbender_restoreConfigurations(){
    echo -e "\n Restoring Mapbender Configs \n"
    cp -av ${temporaryConfigDirectory}* ${installation_folder}mapbender/
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully restored Mapbender configurations! ${reset}\n" 
      /bin/rm -rf ${temporaryConfigDirectory}
    else
      echo -e "\n ${red}Restoring Mapbender configurations failed! ${reset}\n"
      exit 14
    fi
  }

  update_mapbender_internationalization(){
    updateI18N
  }

  update_mapbender_setFolderPermissions(){
    chown -R www-data ${installation_folder}mapbender/http/tmp/
    chown -R www-data ${installation_folder}mapbender/log/
    chown -R www-data ${installation_folder}mapbender/http/geoportal/preview/
    chown -R www-data ${installation_folder}mapbender/http/geoportal/news/
    chown -R www-data ${installation_folder}mapbender/metadata/
    chown -R www-data ${installation_folder}mapbender/http/extensions/mobilemap2/
    chmod -R 755 ${installation_folder}mapbender/resources/locale/
  }

  update_mapbender_textReplacements(){
    #cause the path of the login script has another path than the relative pathes must be adopted:
    sed -i "s/LOGIN.\"\/..\/..\/php\/mod_showMetadata.php?resource=layer\&id=\"/str_replace(\"portal\/anmelden.html\",\"\",LOGIN).\"layer\/\"/g" ${installation_folder}mapbender/http/classes/class_wms.php
    sed -i "s/LOGIN.\"\/..\/..\/php\/mod_showMetadata.php?resource=wms\&id=\"/str_replace(\"portal\/anmelden.html\",\"\",LOGIN).\"wms\/\"/g" ${installation_folder}mapbender/http/classes/class_wms.php
    
    #overwrite login url with baseurl for export to openlayers link
    sed -i 's/url = url.replace("http\/frames\/login.php", "");/url = Mapbender.baseUrl + "\/mapbender\/";/g' ${installation_folder}mapbender/http/javascripts/mod_loadwmc.js
    sed -i "s/href = 'http:\/\/www.mapbender.org'/href = 'http:\/\/geoportal.saarland.de'/g" ${installation_folder}mapbender/http/php/mod_wmc2ol.php
    sed -i 's/Mapbender_logo_and_text.png/logo_geoportal_neu.png/g' ${installation_folder}mapbender/http/php/mod_wmc2ol.php
    sed -i 's/$maxResults = 5;/$maxResults = 20;/' ${installation_folder}mapbender/http/php/mod_callMetadata.php
    sed -i 's/\/\/metadataUrlPlaceholder/$metadataUrl="http:\/\/geoportal.saarland.de\/layer\/";/' ${installation_folder}mapbender/http/php/mod_abo_show.php
    sed -i 's/http:\/\/ws.geonames.org\/searchJSON?lang=de&/http:\/\/geoportal.saarland.de\/mapbender\/geoportal\/gaz_geom_mobile.php/' ${installation_folder}mapbender/http/plugins/mod_jsonAutocompleteGazetteer.php
    sed -i 's/options.isGeonames = true;/options.isGeonames = false;/' ${installation_folder}mapbender/http/plugins/mod_jsonAutocompleteGazetteer.php
    sed -i 's/options.helpText = "";/options.helpText = "Orts- und Straßennamen sind bei der Adresssuche mit einem Komma voneinander zu trennen!<br><br>Auch Textfragmente der gesuchten Adresse reichen hierbei aus.<br><br>\&nbsp\&nbsp\&nbsp\&nbsp Beispiel:<br>\&nbsp\&nbsp\&nbsp\&nbsp\&nbsp\\"Am Zehnthof 10 , St. Goar\\" oder<br>\&nbsp\&nbsp\&nbsp\&nbsp\&nbsp\\"zehnt 10 , goar\\"<br><br>Der passende Treffer muss in der erscheinenden Auswahlliste per Mausklick ausgewählt werden!";/' ${installation_folder}mapbender/http/plugins/mod_jsonAutocompleteGazetteer.php
    sed -i "s/#define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/mapbender\/frames\/login.php\");/define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/mapbender\/frames\/login.php\");/g" ${installation_folder}mapbender/conf/mapbender.conf
    sed -i "s/define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/portal\/anmelden.html\");/#define(\"LOGIN\", \"http:\/\/\".\$_SERVER\['HTTP_HOST'\].\"\/portal\/anmelden.html\");/g" ${installation_folder}mapbender/conf/mapbender.conf
  }

  update_django_copyConfigurations(){
    cp -a ${installation_folder}${installation_subfolder_django}Geoportal/settings.py ${installation_folder}settings.py_$(date +"%d_%m_%Y")
    cp -a ${installation_folder}${installation_subfolder_django}useroperations/conf.py ${installation_folder}useroperations_conf.py_$(date +"%d_%m_%Y")
    cp -a ${installation_folder}${installation_subfolder_django}searchCatalogue/utils/url_conf.py ${installation_folder}url_conf.py_$(date +"%d_%m_%Y")
    cp -a ${installation_folder}${installation_subfolder_django}setup/setup.conf ${installation_folder}setup.conf_$(date +"%d_%m_%Y")
  }

  update_django_gitFetch(){
    cd ${installation_folder}${installation_subfolder_django}
    git reset --hard
    git pull
    chmod u+x ${installation_folder}${installation_subfolder_django}geoportal_maintenance.sh
  }

  update_django_restoreConfigurations(){
    cp -a ${installation_folder}settings.py_$(date +"%d_%m_%Y") ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
    cp -a ${installation_folder}useroperations_conf.py_$(date +"%d_%m_%Y") ${installation_folder}${installation_subfolder_django}useroperations/conf.py
    cp -a ${installation_folder}url_conf.py_$(date +"%d_%m_%Y") ${installation_folder}${installation_subfolder_django}searchCatalogue/utils/url_conf.py
    cp -a ${installation_folder}setup.conf_$(date +"%d_%m_%Y") ${installation_folder}${installation_subfolder_django}setup/setup.conf
  }

  update_django_copyScriptsForGeoportalIntegrationToMapbender(){
    cp -av ${installation_folder}${installation_subfolder_django}scripts/guiapi.php ${installation_folder}mapbender/http/local/guiapi.php
    cp -av ${installation_folder}${installation_subfolder_django}scripts/authentication.php ${installation_folder}mapbender/http/geoportal/authentication.php
    cp -av ${installation_folder}${installation_subfolder_django}scripts/delete_inactive_users.sql ${installation_folder}mapbender/resources/db/delete_inactive_users.sql
  }

  update_django_letDjangoDoItsMagic(){
    virtualenv -ppython3 ${installation_folder}env
    source ${installation_folder}env/bin/activate
    cd ${installation_folder}${installation_subfolder_django}
    pip install -r setup/requirements.txt
    python manage.py collectstatic
    python manage.py compilemessages
  }

  promptForDesiredBackup(){
    while true; do
        read -p "Do you want me to make a backup before updating y/n?" yn
        case $yn in
          [Yy]* ) backup; break;;
          [Nn]* ) break;;
          * ) echo "Please answer yes or no.";;
        esac
    done
  }

  update_mapbender(){
    update_mapbender_copyConfigurations
    update_mapbender_gitFetch
    update_mapbender_restoreConfigurations
    update_mapbender_internationalization
    update_mapbender_setFolderPermissions
    update_mapbender_textReplacements
    echo "Mapbender Update Done"
  }

  update_django(){
    echo "Updating Geoportal Project"
    update_django_copyConfigurations
    update_django_gitFetch
    update_django_restoreConfigurations
    update_django_copyScriptsForGeoportalIntegrationToMapbender
    update_django_letDjangoDoItsMagic
    /etc/init.d/apache2 restart
  }

  update_full(){
    promptForDesiredBackup
    update_custom_update "save"
    checkDjangoSettings
    update_mapbender
    update_django
    update_custom_update "restore"
    echo "Update Complete"
  }

  update_full
}

delete(){

  delete_django(){
    rm -r ${installation_folder}env | tee ${deletion_log}
    rm -r ${installation_folder}GeoPortal.rlp | tee ${deletion_log}
  }

  delete_mapbender(){
    rm -R ${installation_folder}mapbender | tee ${deletion_log}
    rm -R ${installation_folder}portal | tee ${deletion_log}
    rm -R ${installation_folder}svn | tee ${deletion_log}
    rm -R ${installation_folder}conf | tee ${deletion_log}
    rm -R ${installation_folder}access | tee ${deletion_log}
    rm -R ${installation_folder}db_backup | tee ${deletion_log}
    rm -r /var/spool/cron/crontabs/root | tee ${deletion_log}
  }

  delete_files(){
    rm -v ${installation_folder}*.sql | tee ${deletion_log}
    rm -v ${installation_folder}*.tar.gz* | tee ${deletion_log}
    rm -v ${installation_folder}geoportal-apache.conf | tee ${deletion_log}
    rm -v ${installation_folder}install.log | tee ${deletion_log}
    rm -vR ${installation_folder}cronjobs | tee ${deletion_log}
    rm -v ${installation_folder}cleanup_geoportal_installation.sh | tee ${deletion_log}
  }

  delete_restore_configs(){
    # APT
    if [ -e "/etc/apt/apt.conf_backup_geoportal" ]; then
      echo "Restoring APT Conf"
      cp /etc/apt/apt.conf_backup_geoportal /etc/apt/apt.conf
    fi

    # HTTPD
    if [ -e "/etc/apache2/apache2.conf_backup_geoportal" ]; then
      echo "Restoring Apache2 Conf"
      cp /etc/apache2/apache2.conf_backup_geoportal /etc/apache2/apache2.conf
    fi
    if [ -e "/etc/apache2/phppgadmin.conf_backup_geoportal" ]; then
      echo "Restoring Apache Conf for PHPPgAdmin"
      cp /etc/apache2/conf-available/phppgadmin.conf_backup_geoportal /etc/apache2/conf-available/phppgadmin.conf
    fi
    if [ -e "/etc/apache2/sites-enabled/geoportal-apache.conf" ]; then
      echo "Restoring Apache Site Conf"
      a2dissite geoportal-apache
      a2ensite 000-default
    fi

    # PHP 7.0
    if [ -e "/etc/php/7.0/apache2/php.ini_geoportal_backup" ]; then
      echo "Restoring Apache2 PHP.ini"
      cp /etc/php/7.0/apache2/php.ini_geoportal_backup /etc/php/7.0/apache2/php.ini
    fi
    if [ -e "/etc/php/7.0/cli/php.ini_geoportal_backup" ]; then
      echo "Restoring CLI PHP.ini"
      cp /etc/php/7.0/cli/php.ini_geoportal_backup /etc/php/7.0/cli/php.ini
    fi
    if [ -e "/etc/phppgadmin/config.inc.php_geoportal_backup" ]; then
      echo "Restoring PHPPgAdmin Conf"
      cp  /etc/phppgadmin/config.inc.php_geoportal_backup /etc/phppgadmin/config.inc.php
    fi

    # Subversion
    if [ -e "/etc/subversion/servers_backup_geoportal" ]; then
      echo "Restoring Subversion Servers"
      cp /etc/subversion/servers_backup_geoportal /etc/subversion/servers
    fi

    service apache2 restart
  }

  delete_postgreSQL_database(){
    # TODO handle variables
    su - postgres -c "dropdb -p $mapbender_database_port $mapbender_database_name"
    # TODO ask for settings to be reset
    cp /etc/postgresql/9.6/main/pg_hba.conf_backup /etc/postgresql/9.6/main/pg_hba.conf
    service postgresql restart
  }

  delete_mysql_database(){
    # TODO check if the variable is set and works
    mysql -uroot -p$mysqlpw -e "DROP DATABASE Geoportal;"
  }

  delete_databases(){
    delete_postgreSQL_database
    delete_mysql_database
  }

  delete_full(){
    delete_django
    delete_mapbender
    delete_files
    delete_restore_configs
    delete_databases
  }

  delete_full
}

main(){
  initializeVariables
  getOptions $@
}

main $@
