#!/bin/sh
#
# Copyright (c) 2011 by Axway Software
# All rights reserved.
# This document and the software described in this document are the confidential and proprietary
# intellectual property of Axway Software and are protected as Axway Software trade secrets.
# No part of this software or this document may be reproduced or disseminated in any form or
# by any means without the prior written permission of Axway Software.
#

#################################################################
# return working directory
# get working directory before locating utils.sh located somewhere in working directory
#################################################################
getWorkingDir()
{
DIRNAME=`dirname "$0"`
cd $DIRNAME
WORKING_DIR=`pwd`
echo $WORKING_DIR
}

#################################################################
#Copy Installer Library jars to temporary directory only when there is an installer update to install
#Changes IPATHJARS to point to the folder Installer in temp dir
#################################################################
copyInstallerLibToTemp()
{
IPATHJARS=${WORKING_DIR}/Installer/
if [ "$INSTALLER_UPDATE" != "" ] ; then
    #copy the installer libraries in the temporary directory
    eval cp -rf "${WORKING_DIR}"/Installer/ "${TEMPORARY_DIR}"
    IPATHJARS=${TEMPORARY_DIR}/Installer/
fi
chmod -R 777 ${IPATHJARS} 1>/dev/null 2>/dev/null
}

#################################################################
#Copy Installer jar to temporary directory a new one
#from an update should be used
#################################################################
copyInstallerJarToTemp()
{
if [ "$INSTALLER_UPDATE" != "" ] ; then
    if [ -d ${TEMPORARY_DIR}/update/component/Installer/ ] ; then
        if [ `ls -1A ${TEMPORARY_DIR}/update/component/Installer/ | wc -l` -gt 0 ] ; then
            cp ${TEMPORARY_DIR}/update/component/Installer/* ${IPATHJARS}/
        fi
    fi
fi
}

#################################################################
#Launches installer with given arguments 
#################################################################
launchInstaller()
{

#Move working dir to Components on lauching java
setWorkingDirToComponents

# First option is needed launch the installer in debug mode on a remote machine. Uncomment the line and comment the default one.
#${JAVA_BIN} ${JAVA_ARGUMENTS} -Djava.compiler=NONE -Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,server=y,address=8000 com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" ${ARGUMENTS}

#check to see if is silent option or requiers user interaction
if [ $USER_INTERACT = "TRUE" ] ; then
"${JAVA_PATH}/${JAVA_BIN}" ${JAVA_ARGUMENTS} ${JAVA_XMS_ARG} ${JAVA_XMX_ARG} com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" $ARGUMENTS $OPTIONS
else 
"${JAVA_PATH}/${JAVA_BIN}" ${JAVA_ARGUMENTS} ${JAVA_XMS_ARG} ${JAVA_XMX_ARG} com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" $ARGUMENTS "$NORMALIZED_SILENTFILE" $OPTIONS
fi

RETURN_PROGRAM_VALUE=$?

touchTemporaryFile
}

#################################################################
#Creates updates list for update in chain
#Unzips Installer's update in the temporary directory
#################################################################
getInstallerUpdateToApplyInChain()
{
	UPDATES_LIST=`ls "${WORKING_DIR}"/Components/Axway_Installer_V$INSTALLER_VERSION/Updates 2>/dev/null | grep .*Axway_Installer.*$INSTALLER_VERSION.*SP.*.jar`
	if [ "$UPDATES_LIST" != "" ] ; then
		for i in $UPDATES_LIST ; do
			INSTALLER_UPDATE=$i
		done
	fi
	if [ "$INSTALLER_UPDATE" != "" ] ; then
		if [ ! -d ${TEMPORARY_DIR}/update ] ; then
			mkdir ${TEMPORARY_DIR}/update
		fi
		"$WORKING_DIR/Tools/unzip/unzip$JAVA_DIR_PART-$TOOLS_EXTENSION" -q -o "$WORKING_DIR/Components/Axway_Installer_V$INSTALLER_VERSION/Updates/$INSTALLER_UPDATE" -d $TEMPORARY_DIR/update
		find ${TEMPORARY_DIR}/update -exec chmod 755 {} \;
	fi
}

#################################################################
#Retrieves installer's version
#################################################################
getInstallerVersion()
{
	AXWAY_CONF_FILE_NAME=`ls -1 $CONFIG_DIR | grep Install_Axway_Installer_V`
	AXWAY_CONF_FILE_PATH=$CONFIG_DIR/$AXWAY_CONF_FILE_NAME
	INSTALLER_VERSION=`cat $AXWAY_CONF_FILE_PATH | grep Component.Version | cut -d\= -f2 | cut -d ' ' -f2`
	#Removes last character in $INSTALLER_VERSION which is \r
	INSTALLER_VERSION=`echo $INSTALLER_VERSION | sed 's/.$//'`
	echo $INSTALLER_VERSION
}

#################################################################
# MAIN
#################################################################
if [ -x '/usr/xpg4/bin/sh' ] ; then
  if [ {$1} != {--xpg4} ] ; then
    exec /usr/xpg4/bin/sh $0 --xpg4 "$@"
    exit $?
  fi
fi

USER_WORKING_DIR=`pwd`
#SET working directory and include utils.sh
WORKING_DIR=`getWorkingDir`
cd "$WORKING_DIR"
CONFIG_DIR=$WORKING_DIR/Components/Configuration
INSTALLER_VERSION=`getInstallerVersion`
. "${WORKING_DIR}/Components/Axway_Installer_V$INSTALLER_VERSION/scripts/utils.sh"

#VARS
ACTION="install"
JAVA_ARGUMENTS="-Djava.net.preferIPv6Addresses=true"
JAVA_BIN=java
CONSOLE="FALSE"
USER_INTERACT="FALSE"
OPTIONS=""
ARGUMENTS=""
COMPONET_NAME=""
JAVA_XMS_ARG=""
JAVA_XMX_ARG=""
INSTALL_OPTION="FALSE"
UNINSTALL_OPTION="FALSE"
USAGE_FILE="$WORKING_DIR/Components/Axway_Installer_V$INSTALLER_VERSION/scripts/setup_usage"
LOG_FILE=""
LOG_FILE_OPTION=""
IS_DEBUG="FALSE"

REPOSITORY=""
AUTOMATED=""
INSTALLER_UPDATE=""

initialize
# The usage file is needed.
checkFileExists $USAGE_FILE

#check icompatible options
fiindImcompatbibleActionOptions "$USAGE_FILE" "$@"
#Parse Arguments
while [ $# -gt 0 ] ; do
	CURRENT_ARG=$1
	#call function from utils.sh
	searchOptionInUsage "$1" "$USAGE_FILE"
	shift ;
		
	# The -m/--mode option is meant to set the display mode for the installer. The options are gui and console. This argument is passed to the installer when it is launched.
	if [ "$CURRENT_ARG" = "-m" -o "$CURRENT_ARG" = "--mode" ] ; then
		#call function from utils.sh with arguments
		parseModeOption "$1"
		shift ;
		continue;
	fi
	
	# The -u/--upload option is meant to specify that the installer will start in upload mode. A proper argument is passed to the installer when it is launched.
	if [ "$CURRENT_ARG" = "-u" -o "$CURRENT_ARG" = "--upload" ] ; then
		ACTION="upload"
		continue;
	fi
	
	# The -s/--silent option is meant to specify a silent file. The components found in the directory will be installed in silent mode.
	if [ "$CURRENT_ARG" = "-s" -o "$CURRENT_ARG" = "--silent" ] ; then
		#LOCAL function
		parseSilentOption "$1"
		shift ;
		continue;
	fi
	
	# The -l/--log option is meant to specify the path where the log will be copied
	if [ "$CURRENT_ARG" = "-l" -o "$CURRENT_ARG" = "--log" ] ; then
		#call function from utils.sh
		parseLogOption "$1"
		shift ;
		continue;
	fi

	# Debug option - sets the Log4J DEBUG log level. This argument is passed to the installer when it is launched.
	if [ "$CURRENT_ARG" = "-d" -o "$CURRENT_ARG" = "--debug" ] ; then
		OPTIONS="${OPTIONS}debug "
		IS_DEBUG="TRUE" 	
		continue;
	fi
	#-Xms option
	if [ "$CURRENT_ARG" = "-Xms" ] ; then
		#call function from utils.sh
		parseXmsOption "$1"
		shift ;
		continue;	
	fi

	#-Xmx option
	if [ "$CURRENT_ARG" = "-Xmx" ] ; then
		#call function from utils.sh
		parseXmxOption "$1"
		shift ;
		continue;	
	fi

	# Help option - displayes the content on the usage file.
	if [ "$CURRENT_ARG" = "-h" -o "$CURRENT_ARG" = "--help" ] ; then
		cat $USAGE_FILE
		exit 0 	
	fi
	
	if [ "`toLower $CURRENT_ARG`" = "-javaargument" ] ; then
		JAVA_ARGUMENTS="$JAVA_ARGUMENTS $1"
		shift;
		continue;
	fi
	
	if [ "$CURRENT_ARG" = "--xpg4" ] ; then
		continue;
	fi
	# Unknown option
	echo "Unknown option:$CURRENT_ARG. Use -h or --help for the list of available options." 1>&2
	exit 1
		
done
createTemp

LOG_FILE="$TEMPORARY_DIR/install.log"
startLogSession

appendToLog "INFO  Installer V${INSTALLER_VERSION} start on:"
appendToLog "INFO  OS      : $OSName"
appendToLog "INFO  Version : `logOSVersionString $OSName $OSVersion`"
appendToLog "INFO  Arch    : $ProcessorType"
appendToLog "INFO  Platform: $JAVA_DIR_PART-$Architecture_32_64"
appendToLog "$DF_WARN"
appendToLog "$TEMP_WARN"
appendToLog "DEBUG Temporary directory set to :$TEMPORARY_DIR"
if [ "$DF_WARN" = "" ]; then 
	DF_OUTPUT=`freeSpaceExists $TEMPORARY_DIR "TRUE"`
	appendToLog "DEBUG Available freespace on temporary directory is:$DF_OUTPUT bytes"
fi

checkTools
appendToLog "DEBUG Platform:$PLATFORM-$ARCHITECTURE-$ARCHITECTURE_32_64"
#call function from utils.sh
launchSplash

#prepare the updates list for update in chain and unzips Installer's update in the temporary directory
getInstallerUpdateToApplyInChain

#copy the installer libraries in the temporary directory and Sets IPATHJARS
#LOCAL function
copyInstallerLibToTemp

#copy the installer jar from the unzipped updated to the new installer classpath from temp
copyInstallerJarToTemp

#call function from utils.sh
exportPaths
appendToLog "DEBUG Java path:${JAVA_PATH}"
if [ "$INSTALLER_UPDATE" != "" ] ; then
	appendToLog "DEBUG Installer update jar:$TEMPORARY_DIR/update/$INSTALLER_UPDATE"
fi
#LOCAL function
launchInstaller

#call function from utils.sh
killSplash

#check to see if we keep the log file on upload error
if [ "$ACTION" = "upload" -a $RETURN_PROGRAM_VALUE -gt 0 ] ; then
	removeTemp "TRUE"
else 
	removeTemp "FALSE"
fi
if [ $RETURN_PROGRAM_VALUE -eq 0 ] ; then
	exit 0
else
	echo "An error has occured and Installer process will exit." 1>&2
	exit 1
fi
