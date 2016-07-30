#!/bin/bash

#----------------------------------------------------------------------------------------
#| confAdmin.sh                                  					|
#----------------------------------------------------------------------------------------
#|                                                                      		|
#| 08/03/2013 - David DALLAGO		- First draft                             	|
#| 14/03/2013 - David DALLAGO		- Only synchronizes shinken folder        	|
#| 16/04/2013 - Vincent MAUGEIN 	- Multiple destination nodes support added	|
#| 17/04/2013 - Vincent MAUGEIN 	- Massive improvement				|
#| 01/10/2013 - Vincent MAUGEIN 	- Making work "all servers" mode		|
#| 19/11/2013 - Vincent MAUGEIN		- Tnsname mode added				|
#| 06/12/2013 - David DALLAGO		- Freetds mode added				|
#| 19/12/2013 - David DALLAGO		- Freetds mode finished and validated		|
#| 04/04/2014 - Vincent MAUGEIN 	- Tnsname udated				|
#| 18/07/2014 - Vincent MAUGEIN 	- Adaptation for Shinken 2.0	:	|
#|						* Many verification steps added		|
#|						* Renaming in confAdmin			|
#|						* tnsname.ora (-t) function updated	|					
#| 21/07/2014 - Vincent MAUGEIN			* freetds.conf (-f) function updated	|
#| 31/07/2014 - Vincent MAUGEIN			* Files synchronisation updated 	|
#| 23/10/2014 - Vincent MAUGEIN		- Adaptation for HOST* acceptance cluster	|
#|						* Files sync from HOST01 added	|
#| 27/10/2014 - Vincent MAUGEIN		- Target IP @ replaced by hostname		|
#|						(In DNS we trust)			|
#|					- Cluster Run Mode added			|
#| 02/01/2015 - Stefan ROISSARD		- Add confirmation before stop / start cluster  |
#|                                                                                      |
#|                                                                                      |
#|                                                                                      |
#|--------------------------------------------------------------------------------------|

# Debug toggle
#set -x

# Environment Variables Definition
###################################

DATE=`date +"%Y_%m_%d-%T"`

# Coloration
NORMAL="\\033[0;39m"
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\e[0;34m"

# For configuration files sync
VERBOSE=0
SHINKEN_ETC="/etc/shinken/"
SHINKEN_LIB="/var/lib/shinken/libexec/"
#THRUK="/etc/thruk/"
#THRUK_THEME="/usr/share/thruk/"
#HTTPD="/etc/httpd/"
#SSH_KEY_OPT="-i /etc/ssh/ssh_host_dsa_key"

# For tnsname.ora sync
SGBD_REMOTE_SERVER="BDD-Host"
SGBD_REMOTE_USER="oradba"
TNS_REMOTE_PATH="/oracle/automate/password_management/conf/tns_admin"
SHINKEN_BACKUP="/backup"

# For freetds.conf sync
TDS_ORI_PATH="/usr/local/public/FreeTDS.conf"

# For conf files sync

SOURCE_HOST=$(echo $HOSTNAME | tr 'a-z' 'A-Z')


#-----------------------------------------------#
# Check configuration functions			#
#-----------------------------------------------#

check_conf()
{
	shinken-arbiter -v -c /etc/shinken/shinken.cfg | grep -v "{'configuration_errors':" | grep -v "Warning : The parameter" | grep -v "None" | tee /var/log/shinken/shinken_check.txt
}

#-----------------------------------------------#
# Run cluster functions				#
#-----------------------------------------------#

cluster_start()
{
        echo -e "\nYou are about to start the SHINKEN CLUSTER !\n"
        echo -e "------------------------"
        echo -e "\nDo you confirm ? (y/n)"

        CONFIRMATION=""
        read CONFIRMATION
        while [ "$CONFIRMATION" != "y" ] && [ "$CONFIRMATION" != "n" ]
                do echo "Please type y or n"
                read CONFIRMATION
        done
        case $CONFIRMATION in
                y)
                echo -e "Let's do that"
                ;;
                n)
                echo -e "$RED""START CLUSTER aborted by user\n""$NORMAL"
                exit 31
                ;;
        esac

	echo -e "\n		==========================="
	echo -e "		| Shinken Cluster START ! |"
	echo -e "		==========================="

	echo -e "\nMaster 1 launch on $SOURCE_HOST (localhost) :" 
	echo -e "------------------------------------------------\n"
	/etc/init.d/shinken start

	echo -e "\nMaster 2 launch on $MASTER_2 :"
	echo -e "------------------------------------\n"
	ssh $MASTER_2 '/etc/init.d/shinken start'
	
	echo -e "\nSlave 1 launch on $SLAVE_1 :"
	echo -e "-----------------------------------\n"
	ssh $SLAVE_1 'for d in scheduler poller reactionner receiver; do /etc/init.d/shinken-$d start; done'

	echo -e "\nSlave 2 launch on $SLAVE_2 :"
	echo -e "-----------------------------------\n"
	ssh $SLAVE_2 'for d in scheduler poller reactionner receiver; do /etc/init.d/shinken-$d start; done'
	echo -e "\n"
}

cluster_stop()
{
        echo -e "\nYou are about to stop the SHINKEN CLUSTER !\n"
        echo -e "------------------------"
        echo -e "\nDo you confirm ? (y/n)"

        CONFIRMATION=""
        read CONFIRMATION
        while [ "$CONFIRMATION" != "y" ] && [ "$CONFIRMATION" != "n" ]
                do echo "Please type y or n"
                read CONFIRMATION
        done
        case $CONFIRMATION in
                y)
                echo -e "Let's stop the cluster"
                ;;
                n)
                echo -e "$RED""STOP CLUSTER aborted by user\n""$NORMAL"
                exit 31
                ;;
        esac

	echo -e "\n		=========================="
	echo -e "		| Shinken Cluster STOP ! |"
	echo -e "		=========================="

	echo -e "\nSlave 1 halt on $SLAVE_1 :"
	echo -e "---------------------------------\n"
	ssh $SLAVE_1 'for d in receiver reactionner poller scheduler; do /etc/init.d/shinken-$d stop; done'

	echo -e "\n\nSlave 2 halt on $SLAVE_2 :"
	echo -e "---------------------------------\n"
	ssh $SLAVE_2 'for d in receiver reactionner poller scheduler; do /etc/init.d/shinken-$d stop; done'

	echo -e "\n\nMaster 2 halt on $MASTER_2 :"
	echo -e "----------------------------------\n"
	ssh $MASTER_2 '/etc/init.d/shinken stop'
	
	echo -e "\n\nMaster 1 halt on $SOURCE_HOST (localhost) :" 
	echo -e "----------------------------------------------\n"
	/etc/init.d/shinken stop
	echo -e "\n"

}

cluster_state()
{
	echo -e "\n		========================="
	echo -e "		| Shinken Cluster state |"
	echo -e "		========================="

	echo -e "\nMaster 1 halt on $SOURCE_HOST (localhost) :" 
	echo -e "----------------------------------------------\n"
	/etc/init.d/shinken status

	echo -e "\n\nMaster 2 state on $MASTER_2 :"
	echo -e "-----------------------------------\n"
	ssh $MASTER_2 'for d in arbiter broker scheduler poller receiver reactionner; do /etc/init.d/shinken-$d status 2>&1 >/dev/null && echo "State of $d :	RUNNING" || echo "State of $d :	STOPPED"; done'
	
	echo -e "\nSlave 1 state on $SLAVE_1 :"
	echo -e "----------------------------------\n"
	ssh $SLAVE_1 'for d in scheduler poller receiver reactionner; do /etc/init.d/shinken-$d status 2>&1 >/dev/null && echo "State of $d :	RUNNING" || echo "State of $d :	STOPPED"; done'

	echo -e "\n\nSlave 2 state on $SLAVE_2 :"
	echo -e "----------------------------------\n"
	ssh $SLAVE_2 'for d in scheduler poller receiver reactionner; do /etc/init.d/shinken-$d status 2>&1 >/dev/null && echo "State of $d :	RUNNING" || echo "State of $d :	STOPPED"; done'
	echo -e "\n"

}

#-----------------------------------------------#
# tnsname.ora synchronisation functions		#
#-----------------------------------------------#

#---# Backup present tnsames.ora
backup_tns()
{
	if [[ ! -d $SHINKEN_BACKUP ]]; then
		echo -e "$RED""ERROR - $SHINKEN_BACKUP doesn't exist\n""$NORMAL"
		exit 11
	else
		cd $SHINKEN_ETC/resources
		[[ -e tnsnames.ora ]] && tar -cf  $SHINKEN_BACKUP/tnsnames.ora_$DATE.tar ./tnsnames.ora
	fi
}

#---# Copy DBA's tnsames.ora from their server
copy_tns_from_server()
{
	[[ -d $SHINKEN_ETC/scripts/tns_tmp ]] && rm -rf $SHINKEN_ETC/scripts/tns_tmp
	rsync -n $SGBD_REMOTE_USER@$SGBD_REMOTE_SERVER:/dev/zero /dev/zero 1>/dev/null
	if [[ $? = 0 ]]; then
		mkdir $SHINKEN_ETC/scripts/tns_tmp && chmod 777 $SHINKEN_ETC/scripts/tns_tmp
		rsync -avz --delete $SGBD_REMOTE_USER@$SGBD_REMOTE_SERVER:$TNS_REMOTE_PATH/TNSNAMES_EP.ora $SHINKEN_ETC/scripts/tns_tmp/TNSNAMES_EP.ora 1>/dev/null
		rsync -avz --delete $SGBD_REMOTE_USER@$SGBD_REMOTE_SERVER:$TNS_REMOTE_PATH/TNSNAMES_FILIALE.ora $SHINKEN_ETC/scripts/tns_tmp/TNSNAMES_FILIALE.ora 1>/dev/null
		rsync -avz --delete $SGBD_REMOTE_USER@$SGBD_REMOTE_SERVER:$TNS_REMOTE_PATH/TNSNAMES_FILIALE.ora.inc $SHINKEN_ETC/scripts/tns_tmp/TNSNAMES_FILIALE.ora.inc 1>/dev/null
	else
		echo -e "$RED""\nERROR - rsync connection problem\n""$NORMAL"
		exit 12
	fi
}

#---# Format tnsames.ora for Shinken with explicit SID
format_tns()
{
	rsync -avz --delete $SGBD_REMOTE_USER@$SGBD_REMOTE_SERVER:/home/oradba/svn_repo/scripts/trunk/MOD-DBA_TOOLS/shinken/gen_tnsnames.sh $SHINKEN_ETC/scripts/tns_tmp/gen_tnsnames.sh 1>/dev/null
	cd $SHINKEN_ETC/scripts/tns_tmp/
	chmod +x gen_tnsnames.sh
	/bin/ksh gen_tnsnames.sh TNSNAMES_EP.ora > sup_TNSNAMES_EP.ora || { echo -e "$RED""\nERROR - formating sup_TNSNAMES_EP.ora problem\n""$NORMAL"; exit 13; }
	/bin/ksh gen_tnsnames.sh TNSNAMES_FILIALE.ora > sup_TNSNAMES_FILIALE.ora || { echo -e "$RED""\nERROR - formating sup_TNSNAMES_FILIALE.ora problem\n""$NORMAL"; exit 14; }
	cat sup_TNSNAMES_EP.ora sup_TNSNAMES_FILIALE.ora > tnsnames.ora || { echo -e "$RED""\nERROR - merging tnsnames.ora problem\n""$NORMAL"; exit 15; }
	mv tnsnames.ora $SHINKEN_ETC/resources
}

#---# Main : backup, synchronise and format tnsname.ora
tnsnames_sync()
{
	[[ -f $ORACLE_HOME/bin/tnsping ]] || { echo -e "$RED""\nERROR - tnsping must be installed for this mode\n""$NORMAL"; exit 16; }
	[[ -f $ORACLE_HOME/network/mesg/tnsus.msb ]] || { echo -e "$RED""\nERROR - $ORACLE_HOME/network/mesg/tnsus.msb must exists for this mode\n""$NORMAL"; exit 17; }

	echo -e "\nBackuping present tnsnames :"
	backup_tns && echo -e "$GREEN""OK""$NORMAL"
	echo -e "\nSynchronising from DBA's Server :"
	copy_tns_from_server && echo -e "$GREEN""OK""$NORMAL"
	echo -e "\nFormating new tnsnames : ( Warning : This step takes ~20 min )"
	format_tns && echo -e "$GREEN""OK""$NORMAL"
	rm -rf $SHINKEN_ETC/scripts/tns_tmp
	echo -e "$GREEN""\nSUCCESS - tnsnames has been synchronised\n""$NORMAL"
}


#---------------------------------------------#
# freetds.conf synchronisation functions      #
#---------------------------------------------#

#---# Backup present freetds.conf
backup_freetds()
{
        if [[ ! -d $SHINKEN_BACKUP ]]; then
                echo -e "$RED""ERROR - $SHINKEN_BACKUP doesn't exist\n""$NORMAL"
                exit 21
	else
		cd $SHINKEN_ETC/resources
		[[ -f freetds.conf ]] && tar -cf $SHINKEN_BACKUP/freetds_$DATE.tar freetds.conf
	fi
}

#---# Format freetds.conf from DBA's file on shared directory
format_freetds()
{
	[[ -f $SHINKEN_ETC/scripts/freetds.conf-tmp ]] && rm -f $SHINKEN_ETC/scripts/freetds.conf-tmp

	if [[ ! -f $TDS_ORI_PATH ]]; then
		echo -e "$RED""\nERROR - Source file : $TDS_ORI_PATH doesn't exist\n""$NORMAL"
		exit 22
	else
		TDS_CONTENT=`cat $TDS_ORI_PATH`
		echo -e "$TDS_CONTENT" > $SHINKEN_ETC/scripts/freetds.conf-tmp
		tr -d '\b\r' < $SHINKEN_ETC/scripts/freetds.conf-tmp > $SHINKEN_ETC/resources/freetds.conf
	fi
}

#---# Main : backup, synchronise and format freetds.conf
freetds_sync()
{
	echo -e "\nBackuping present freetds :"
	backup_freetds && echo -e "$GREEN""OK""$NORMAL"
	echo -e "\nFormating freetds :"
	format_freetds && echo -e "$GREEN""OK""$NORMAL"
	[[ -f $SHINKEN_ETC/scripts/freetds.conf-tmp ]] && rm -f $SHINKEN_ETC/scripts/freetds.conf-tmp
	echo -e "$GREEN""\nSUCCESS : freetds file has been formated and replaced\n""$NORMAL"
}

#---------------------------------------------#
# Configuration file synchronisation function #
#---------------------------------------------#

files_sync_confirm()
{
	echo -e "\nYou are about to synchronise Shinken configuration files !\n"
	echo -e "-----------------"
	echo -e "Source :"
	echo -e ""$BLUE""$SOURCE_HOST""$NORMAL""
	echo -e "		"
	echo -e "	|	"
	echo -e "	|	"
	echo -e "	|	"
	echo -e "	V	"
	echo -e "		"
	echo -e "Destination(s) :"
		for host in $DEST_HOST_LIST; do echo -e ""$RED""$host""$NORMAL""; done
	echo -e "-----------------"
	echo -e "\nDo you confirm ? (y/n)"
	
	CONFIRMATION=""
	read CONFIRMATION
	while [ "$CONFIRMATION" != "y" ] && [ "$CONFIRMATION" != "n" ]
		do echo "Please type y or n"
		read CONFIRMATION
	done
	case $CONFIRMATION in
		y)
		echo -e "Let's do that"
		;;
		n)
		echo -e "$RED""Sync aborted by user\n""$NORMAL"
		exit 31 
		;;
	esac
}

conf_files_sync()
{
	for host in $DEST_HOST_LIST; do
		rsync -n -e "ssh -l root $SSH_KEY_OPT" /dev/zero $host:/dev/zero 1>/dev/null

		if [[ $? = 0 ]]; then
			echo -e "\nSending to $host"
			echo -e "------------------------"
			for DIR_TO_SYNC in \
				$SHINKEN_ETC \
				$SHINKEN_LIB \
				/usr/share/thruk/themes/ \
				/usr/share/thruk/templates/ 
	#			$SHINKEN_ETC/modules \
	#			$SHINKEN_ETC/realms \
	#			$SHINKEN_ETC/resources \
	#			$SHINKEN_ETC/shinken.cfg
			do
				rsync -az --delete -e "ssh -l root $SSH_KEY_OPT" --exclude 'retention' $DIR_TO_SYNC $host:$DIR_TO_SYNC && echo -e "- $DIR_TO_SYNC synchronised"
			done
		else
			echo -e "$RED""\nERROR - rsync connection problem to $host\n""$NORMAL"
			exit 2
		fi
	done
}

configuration_sync()
{
	files_sync_confirm
	echo -e "\nBegining synchronisation :"
	conf_files_sync && echo -e "$GREEN""\nOK""$NORMAL"
	echo -e "$GREEN""\nSUCCESS : All files have been synchronised\n""$NORMAL"
}


#---------------#
# Main function #
#---------------#

#---# Hostname detection safety

host_detection()
{
	case $SOURCE_HOST in
		HOST-QUAL02)
			DEST_HOST_LIST="HOST-QUAL09"
			TARGET_COUNT=1
			;;
#		HOST-QUAL09)
#			DEST_HOST_LIST=HOST-QUAL02
#			TARGET_COUNT=1
#			;;
		HOST01)
			MASTER_2="HOST01"	
			SLAVE_1="HOST09"
			SLAVE_2="HOST09"	
			DEST_HOST_LIST="$SLAVE_1 $MASTER_2 $SLAVE_2"
			TARGET_COUNT=3
			;;
#		HOST-QUAL01|HOST-QUAL08|HOST-QUAL09|LPSUP09|LPSUP01|LPSUP09|HOST09|HOST01|HOST09)
		*)
			echo -e "$RED""\nERROR - This script is not supposed to run from $SOURCE_HOST\n""$NORMAL"
			exit 2
			;;
	esac
}

#---# Print how-to
print_usage()
{
        echo -e "\nSyntax : -v [optional:verbose]\n"

        echo -e "\n	-c	Check object configuration"
        echo -e "\n	-i	Display Shinken Cluster state information"

	echo -e "\n	-o	Start Shinken Cluster"
	echo -e "\n	-p	Halt Shinken Cluster"
        echo -e "\n	-s	Synchronizes object configuration"
        echo -e "\n	-t	Synchronises tnsnames.ora from source file on remote server"
        echo -e "\n	-f	Synchronises freetds from source file on remote server"
        
	echo -e "\n	Print this help : -h\n"
}

#---# Arguments definition

if [[ $# -ge 1 ]]; then 
	while getopts hvsctfopi args
	do
		case $args in
			h)
			print_usage
			exit 0
			;;
			v)
			VERBOSE=1
			;;
			c)
			check_conf
			;;
			s)
			host_detection
			configuration_sync
			;;
			t)
			host_detection
			tnsnames_sync
			;;
			f)
			host_detection
			freetds_sync
			;;
			o)
			host_detection
			cluster_start
			;;
			p)
			host_detection
			cluster_stop
			;;
			i)
			host_detection
			cluster_state
			;;
			*)
			echo -e "\n	Error : Bad argument"
			print_usage
			exit 3
			;;
		esac
	done
else
	echo -e "\n	Error : Argument needed"
	print_usage
	exit 4
fi
