#!/bin/bash

env=$1
file="../conf/mft.conf"
InstallDir="/"
STstopscript="/app/Axway/SecureTransport/bin/stop_all"

export TEMPORARY_DIR="$HOME"

if [ -f "$STstopscript" ]
then
  echo "$STstopscript found hence stop all ST processes"
  $STstopscript
  rm -rf /app/Axway/
else
  echo "$STstopscript not found hence NOTHING TO DO"
fi

if [ -f "$file" ]
then
  echo "$file found."
  
  dt=$(date '+%d%m%Y%H%M%S');
  mkdir -p ../../deploy/deployPkg_$dt
  cp ../conf/Install_Axway_Installer_V4.8.0.properties ../../deploy/deployPkg_$dt/
  cp ../conf/Install_SecureTransport_V5.4.properties ../../deploy/deployPkg_$dt/
  
  # This needs to be improved to avoid using multiple sed commands.....     
  while IFS=' = ' read -r key value
  do
    if [ $key == 'InstallDir' ]
    then
        echo "$value" | sed -r 's/\\//g'
        InstallDir=${value//\\/}
        echo Install Directory: $InstallDir
	elif [ $key == 'InstallTempDir' ]
	then
		echo 'Install Temp Directory '$value
		echo "$value" | sed -r 's/\\//g'
		#export TEMPORARY_DIR="${value//\\/}"
		#echo 'Temp DIR: '$TEMPORARY_DIR
    fi
    key_temp=_$key"_"
    echo key: $key_temp ":" $value
    sed -i 's/'$key_temp'/'$value'/g' ../../deploy/deployPkg_$dt/Install_Axway_Installer_V4.8.0.properties
    sed -i 's/'$key_temp'/'$value'/g' ../../deploy/deployPkg_$dt/Install_SecureTransport_V5.4.properties
	
  done < "$file"

else
  echo "$file not found."
fi

# Actual: should get MFT installation binary from Artifactory by Octopus tool. 
# Dummy: for testing in the lab or in AWS, this needs to be available from ~/st54/SecureTransport_5.4.0_Install_linux-x86-64_BN1125.zip
mkdir -p ../../deploy/deployPkg_$dt/install_binary
unzip ~/st54/SecureTransport_5.4.0_Install_linux-x86-64_BN1125.zip -d ../../deploy/deployPkg_$dt/install_binary/
cp ../license/*.license ../../deploy/deployPkg_$dt/install_binary/

cd ../../deploy/deployPkg_$dt/install_binary/
ls

./setup.sh -s ../Install_Axway_Installer_V4.8.0.properties

echo "listening PORT for admin "netstat -nlt | grep 8444

echo "Location for bin folder: "$InstallDir
echo "Place license file then stop and restart processes"
cp *.license $InstallDir/SecureTransport/conf/
$InstallDir/SecureTransport/bin/stop_all
sleep 5
$InstallDir/SecureTransport/bin/start_all

echo 'checking Temp Install: '$TEMPORARY_DIR

