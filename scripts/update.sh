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
#Parse -f --folder option
#################################################################
parseFolderOption()
{

ESCAPED_ARG='"'$1'"'
STARTS_WITH=`echo "$ESCAPED_ARG" | cut -c1,2`
if [ "$ESCAPED_ARG" = '""' -o $# -eq 0 -o "$STARTS_WITH" = "\"-" ] ; then
	echo "Missing value for [-f|--folder] option" 1>&2
	exit 1
fi 

REPOSITORY=$1
CONSOLE="TRUE"
ARGUMENTS="instmode console -f"
AUTOMATED="automated true"
FOLDER_OPTION="TRUE"

#calculate the relative path starting from the user working directory
STARTS_WITH=`echo "$REPOSITORY" | cut -c1,1`
if [ "$STARTS_WITH" != "/" ] ; then
	REPOSITORY="$USER_WORKING_DIR/$REPOSITORY"
fi
NORMALIZED_REPOSITORY=`normalize_path "$REPOSITORY"`

# check that the folder exists and is not empty
if [ ! -d "$NORMALIZED_REPOSITORY" ] ; then
	echo "$NORMALIZED_REPOSITORY does not exist" 1>&2
	exit 1
else
	if [ ! "$(ls -A "$NORMALIZED_REPOSITORY")" ]; then
		echo "$NORMALIZED_REPOSITORY is empty" 1>&2
		exit 1
	fi
fi

}

#################################################################
#Parse -i --install option
#################################################################
parseInstallOption()
{

ESCAPED_ARG='"'$1'"'
STARTS_WITH=`echo "$ESCAPED_ARG" | cut -c1,2`
if [ "$ESCAPED_ARG" = '""' -o $# -eq 0 -o "$STARTS_WITH" = "\"-" ] ; then
	echo "Missing value for [-i|--install] option" 1>&2
	exit 1
fi

UPDATE=$1
ARGUMENTS="instmode console -i"
CONSOLE="TRUE"
INSTALL_OPTION="TRUE"

#calculate the relative path starting from the user working directory
STARTS_WITH=`echo "$UPDATE" | cut -c1,1`
if [ "$STARTS_WITH" != "/" ] ; then
	UPDATE="$USER_WORKING_DIR/$UPDATE"
fi
NORMALIZED_UPDATE=`normalize_path "$UPDATE"`
# check that the file exists and it's not a directory

if [ ! -f "$NORMALIZED_UPDATE" ] ; then
	echo "$NORMALIZED_UPDATE does not exist" 1>&2
	exit 1
fi

}

#################################################################
#Parse -u --uninstall option
#################################################################
parseUninstallOption()
{
ESCAPED_ARG='"'$1'"'
STARTS_WITH=`echo "$ESCAPED_ARG" | cut -c1,2`
if [ "$ESCAPED_ARG" = '""' -o $# -eq 0 -o "$STARTS_WITH" = "\"-" ] ; then
	echo "Missing value for [-u|--unistall] option" 1>&2
	exit 1
fi

GREP_TOOL=grep
if [ -x /usr/xpg4/bin/grep ] ; then
	GREP_TOOL=/usr/xpg4/bin/grep
fi

#check if the parameter is a Composite
if [ `echo "$1" |$GREP_TOOL -c ":"` -eq 0 ] ; then
	INSTALLED_COMPONENTS_FILE="$WORKING_DIR/synInstall/scripts/display"
	if [ `cat $INSTALLED_COMPONENTS_FILE |$GREP_TOOL -i -c -E "Composite: $1($|[[:space:]])"` -eq 1 ] ; then
		ARGUMENTS="instmode console -u"
		CONSOLE="TRUE"
		UNINSTALL_VALUE=$1;
		UNINSTALL_OPTION="TRUE"
	else 
		echo "Composite $1 is not installed." 1>&2
		exit 1
	fi
else	
	#add : at the end in order to parse even if the command receive a bad parameter
	ARG="$1:"
	COMPONENT_NAME=`echo $ARG |cut -d':' -f1`
	UPDATE_NAME=`echo $ARG |cut -d':' -f2`
	DISPLAY_RESULT=`${WORKING_DIR}/display.sh -n "$COMPONENT_NAME"`
	
	IS_SOLTION_DISABLE_VIEW=`echo $DISPLAY_RESULT |$GREP_TOOL -c -i -E "(^|[[:space:]])unknown option($|[[:space:]]|:)"`
	
	if [ $IS_SOLTION_DISABLE_VIEW -gt 0 ] ; then
		#IF solution with disable comp view run display with no arg and only look at first line
		DISPLAY_RESULT=`${WORKING_DIR}/display.sh`
	fi
			
	#echo "D=$DISPLAY C=$COMPONENT_NAME U=$UPDATE_NAME"
	IS_COMPONENT_NOT_FOUND=`echo $DISPLAY_RESULT | $GREP_TOOL  -c -i "$COMPONENT_NAME V"`
	IS_UPDATE_INSTALLED=`echo -e"$DISPLAY_RESULT" | $GREP_TOOL -v -i -E "(^|[[:space:]])$COMPONENT_NAME($|[[:space:]])" | $GREP_TOOL -c -i -E "(^|[[:space:]])$UPDATE_NAME($|[[:space:]])"`
	
	if [ "$UPDATE_NAME" = "" ] ; then
		echo "Invalid format for update value. Use -h or --help for update format." 1>&2
		exit 1
	fi
			
	if [ $IS_COMPONENT_NOT_FOUND -eq 0 ] ; then
		echo "Product $COMPONENT_NAME not found." 1>&2
		exit 1
	fi
			
	if [ $IS_UPDATE_INSTALLED -eq 0 ] ; then
		echo "Update $UPDATE_NAME is not installed." 1>&2
		exit 1
	fi

	ARGUMENTS="instmode console -u"
	CONSOLE="TRUE"
	UNINSTALL_VALUE=$1;
	UNINSTALL_OPTION="TRUE"
fi

}

#################################################################
#Copy Installer Library jars to temporary directory
#Changes IPATHJARS to point to the folder Installer in temp dir
#################################################################
copyInstallerLibToTemp()
{
#copy the installer libraries in the temporary directory
touch "${WORKING_DIR}"/Tools/test.file 1>/dev/null 2>/dev/null
eval cp -rf "${WORKING_DIR}"/Installer/ "${TEMPORARY_DIR}"
IPATHJARS=${TEMPORARY_DIR}/Installer/
chmod -R 777 ${IPATHJARS} 1>/dev/null 2>/dev/null
}

#################################################################
#Launches installer with given arguments 
#################################################################
launchInstaller()
{

# First option is needed launch the installer in debug mode on a remote machine. Uncomment the line and comment the default one.
#${JAVA_BIN} ${JAVA_ARGUMENTS} -Djava.compiler=NONE -Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,server=y,address=8000 com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" ${ARGUMENTS}

#do checks do see what option was provided in order to enclose in " " names with blank spaces
if [ $UNINSTALL_OPTION = "TRUE" ] ; then
"${JAVA_PATH}/${JAVA_BIN}" ${JAVA_ARGUMENTS} ${JAVA_XMS_ARG} ${JAVA_XMX_ARG} com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" $ARGUMENTS "$UNINSTALL_VALUE" $OPTIONS
elif [ $INSTALL_OPTION = "TRUE" ] ; then
"${JAVA_PATH}/${JAVA_BIN}" ${JAVA_ARGUMENTS} ${JAVA_XMS_ARG} ${JAVA_XMX_ARG} com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" $ARGUMENTS "$UPDATE" "$AUTOMATED" $OPTIONS
else 
"${JAVA_PATH}/${JAVA_BIN}" ${JAVA_ARGUMENTS} ${JAVA_XMS_ARG} ${JAVA_XMX_ARG} com.axway.synchronyInstaller.engine.SynMain ${ACTION} "${TEMPORARY_FILE}" "$WORKING_DIR" $ARGUMENTS "$REPOSITORY" $OPTIONS
fi
return $?
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
. "${WORKING_DIR}/synInstall/scripts/utils.sh"

#VARS
ACTION="update"
JAVA_ARGUMENTS="-Djava.net.preferIPv6Addresses=true"
JAVA_BIN=java
CONSOLE="FALSE"
USER_INTERACT="FALSE"
OPTIONS=""
ARGUMENTS=""
COMPONET_NAME=""
CONFIG_DIR=$WORKING_DIR/Configuration
INSTALLER_VERSION=`getInstallerVersion`
JAVA_XMS_ARG=""
JAVA_XMX_ARG="-Xmx256m"
INSTALL_OPTION="FALSE"
UNINSTALL_OPTION="FALSE"
USAGE_FILE="$WORKING_DIR/synInstall/scripts/${ACTION}_usage"
LOG_FILE=${WORKING_DIR}/install.log
LOG_FILE_OPTION=""
IS_DEBUG="FALSE"
REPOSITORY=""
AUTOMATED=""

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
	# The -f/--folder option is meant to specify a local repository. All the updates found in the directory will be added. The update will be done in silent mode.
	if [ "$CURRENT_ARG" = "-f" -o "$CURRENT_ARG" = "--folder" ] ; then
		#LOCAL function
		parseFolderOption "$1"
		shift ;
		continue;
	fi
	# The -i/--install option is meant to specify single update. The update found in the directory will be added in silent mode.
	if [ "$CURRENT_ARG" = "-i" -o "$CURRENT_ARG" = "--install" ] ; then
		#LOCAL function
		parseInstallOption "$1"
		shift ;
		continue;
	fi

	# The -u/--uninstall option is meant to specify single update. The update will be uninstalled in silent mode.
	if [ "$CURRENT_ARG" = "-u" -o "$CURRENT_ARG" = "--uninstall" ] ; then
		parseUninstallOption "$1"
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

startLogSession
appendToLog "$DF_WARN"
appendToLog "$TEMP_WARN"
appendToLog "DEBUG Temporary directory set to :$TEMPORARY_DIR"
if [ "$DF_WARN" = "" ] ; then 
	DF_OUTPUT=`freeSpaceExists $TEMPORARY_DIR "TRUE"`
	appendToLog "DEBUG Available freespace on temporary directory is:$DF_OUTPUT bytes"
fi

if [ "${TEMPORARY_DIR}" != "" ] ; then
    JAVA_ARGUMENTS="-Djava.io.tmpdir=${TEMPORARY_DIR} ${JAVA_ARGUMENTS}"
fi
checkTools
appendToLog "DEBUG Platform:$PLATFORM-$ARCHITECTURE-$ARCHITECTURE_32_64"

#call function from utils.sh
launchSplash

if [ "${CONSOLE}" = "TRUE" ] ; then 
	JAVA_ARGUMENTS="${JAVA_ARGUMENTS} -Djava.awt.headless=true"
fi

#copy the installer libraries in the temporary directory and Sets IPATHJARS
#LOCAL function
copyInstallerLibToTemp

#call function from utils.sh
exportPaths
appendToLog "DEBUG Java path:${JAVA_PATH}"

#LOCAL function
launchInstaller
RETURN_PROGRAM_VALUE=$?

CURRENT_DIR=`pwd`
cd ${TEMPORARY_DIR}/..
#TMP_PARENT=`pwd`
TMP_PARENT=$TEMPORARY_DIR
cd ${CURRENT_DIR}/..

ID_CMD="id"
if [ -x "/usr/xpg4/bin/id" ]
then
    ID_CMD="/usr/xpg4/bin/id"
fi
USER_NAME=`$ID_CMD -un`

#run a cleanup script to remove files that can't be deleted while the JVM is running
if [ -f "$TMP_PARENT/_update_$USER_NAME.sh" ] ; then
	chmod 777 "$TMP_PARENT/_update_$USER_NAME.sh"
	"$TMP_PARENT/_update_$USER_NAME.sh" &
fi
removeTemp "FALSE"

if [ $RETURN_PROGRAM_VALUE -eq 0 ] ; then
	exit 0
else
	echo "An error has occured and Installer process will exit." 1>&2
	exit 1
fi
