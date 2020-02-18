# CBA_MFT_CICD

Silent installation – 
A silent installation method is available. This method of installation allows you to carry out an installation without any questions being asked by the installer. To perform a silent installation: 
1. Start the SecureTransport install in normal mode. 
2. Complete the installer dialog screens up until the point of installation (for example, before clicking Install). 
3. Create a copy of the two .properties files under <installation_root_directory>\SilentFile\<date_and_time>_install\ to a temp folder. 
4. Quit the installation in normal mode. 
5. Run the installation with the following switches for silent install:# ./setup.sh -s /path/to/Install_Axway_Installer_<version>.properties 
Note Use the Axway Installer properties file for the silent install, not the SecureTransport properties file. 
Note Always provide the full path to the properties file, instead of a relative one.”

Example:
1. Install using setup script with properties
	./setup.sh -s /app/Install_Axway_Installer_V4.8.0.properties
	```
	Initialization in progress
	..........
	Please wait while execution process is being prepared!
	..................................................................................................................................................................................................................................................................

	----------------------------------------

	Summary
	----------------------------------------
	The information below summarizes the installation status. Refer to install.log
	for more details.

	------------------------------------------------------------------------------
	Axway_Installer_V4.8.0
	Installed in /app/Axway/
	Axway_Installer_4.8.0_SP3 has been applied successfully.
	------------------------------------------------------------------------------
	Product: SecureTransport_V5.4
	Installed in /app/Axway/SecureTransport/
	JRE7 is not officially supported on the current OS
	distribution/version(CentOSLinux 7.7.1908) by its vendor.
	------------------------------------------------------------------------------
	You have new mail in /var/spool/mail/mftcba
	```
2. Validate setup