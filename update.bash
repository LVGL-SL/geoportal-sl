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
  cd ${installation_folder}mapbender/tools/
  /bin/sh ${installation_folder}mapbender/tools/i18n_update_mo.sh
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
      rm /tmp/settings.py
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
        if ! grep -Fq "$h" ${installation_folder}${installation_subfolder_django}Geoportal/settings.py
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
    mkdir -p ${temporaryConfigDirectory}mapbender/conf/
    mkdir -p ${temporaryConfigDirectory}mapbender/mapserver/
    mkdir -p ${temporaryConfigDirectory}mapbender/tools/wms_extent/
    mkdir -p ${temporaryConfigDirectory}mapbender/http/extensions/mobilemap/
    mkdir -p ${temporaryConfigDirectory}mapbender/http/extensions/mobilemap2/
    cp -av ${installation_folder}mapbender/conf/*.conf ${temporaryConfigDirectory}mapbender/conf/
    cp -av ${installation_folder}mapbender/mapserver/spatial_security.map ${temporaryConfigDirectory}mapbender/mapserver/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extents.map  ${temporaryConfigDirectory}mapbender/tools/wms_extent/
    cp -av ${installation_folder}mapbender/tools/wms_extent/extent_service.conf ${temporaryConfigDirectory}mapbender/tools/wms_extent/
    cp -av ${installation_folder}mapbender/tools/monitorCapabilities.bash ${temporaryConfigDirectory}mapbender/tools/
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap ${temporaryConfigDirectory}mapbender/http/extensions/mobilemap
    cp -av ${installation_folder}mapbender/http/extensions/mobilemap2 ${temporaryConfigDirectory}mapbender/http/extensions/mobilemap2
  }

  update_mapbender_gitFetch(){
    cd ${installation_folder}mapbender
    git reset --hard
    git checkout ${git_mapbender_repositoryBranch}
    git pull
  }

  update_mapbender_restoreConfigurations(){
    echo -e "\n Restoring Mapbender Configs \n"
    cp -av ${temporaryConfigDirectory}mapbender/* ${installation_folder}mapbender/
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully restored Mapbender configurations! ${reset}\n" 
      /bin/rm -rf ${temporaryConfigDirectory}mapbender/
    else
      echo -e "\n ${red}Restoring Mapbender configurations failed! ${reset}\n"
      exit 14
    fi
  }

  update_mapbender_restoreExtensions(){
    cp -av ${installation_folder}backup/geoportal_backup_$(date +"%d_%m_%Y")/mapbender/http/extensions/* ${installation_folder}mapbender/http/extensions/
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
    echo -e "\n Backing up Django Configs \n"
    mkdir -p ${temporaryConfigDirectory}django/Geoportal/
    mkdir -p ${temporaryConfigDirectory}django/useroperations/
    mkdir -p ${temporaryConfigDirectory}django/searchCatalogue/
    mkdir -p ${temporaryConfigDirectory}django/setup/
    cp -av  ${installation_folder}${installation_subfolder_django}Geoportal/settings.py ${temporaryConfigDirectory}django/Geoportal/
    cp -av  ${installation_folder}${installation_subfolder_django}useroperations/conf.py ${temporaryConfigDirectory}django/useroperations/
    cp -av  ${installation_folder}${installation_subfolder_django}searchCatalogue/settings.py ${temporaryConfigDirectory}django/searchCatalogue/
    cp -av  ${installation_folder}${installation_subfolder_django}searchCatalogue/url_conf.py ${temporaryConfigDirectory}django/searchCatalogue/
    cp -av  ${installation_folder}${installation_subfolder_django}setup/setup.conf ${temporaryConfigDirectory}django/setup/
  }

  update_django_gitFetch(){
    cd ${installation_folder}${installation_subfolder_django}
    git reset --hard
    git checkout ${git_django_repositoryBranch}
    git pull
    chmod u+x ${installation_folder}${installation_subfolder_django}geoportal_maintenance.sh
    chmod u+x ${installation_folder}${installation_subfolder_django}update.bash
  }

  update_django_restoreConfigurations(){
    echo -e "\n Restoring Django Configs \n"
    cp -av ${temporaryConfigDirectory}django/* ${installation_folder}${installation_subfolder_django}
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully restored Django configurations! ${reset}\n" 
      /bin/rm -rf ${temporaryConfigDirectory}django/
    else
      echo -e "\n ${red}Restoring Django configurations failed! ${reset}\n"
      exit 14
    fi
  }

  update_django_restoreConfigurations(){
    echo -e "\n Restoring GeoPortal Configs \n"
    cp -av ${temporaryConfigDirectory}django/* ${installation_folder}${installation_subfolder_django}
    if [ $? -eq 0 ];then
      echo -e "\n ${green}Successfully restored GeoPortal configurations! ${reset}\n" 
    else
      echo -e "\n ${red}Restoring GeoPortal configurations failed! ${reset}\n"
      exit 14
    fi
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
    update_mapbender_restoreExtensions
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

main(){
  initializeVariables
  getOptions $@
}

main $@
