#!/usr/bin/perl

#----------------------------------------------------------------
#| ConfAudit.pl                                  		|
#----------------------------------------------------------------
#|                                                      	|
#| v1.0 12/04/2015 - VMA 	* First draft			|
#|				* Command function added	|
#| v1.1 29/04/2015 - VMA 	* Service function added	|
#| v1.2 23/09/2015 - VMA 	* Host function added		|
#|				* Minor corrections		|
#|								|                                        
#|                                        			|
#| ToDo : Add configuration file type control			|
#|--------------------------------------------------------------|

#--# Import des modules
########################

use strict;
use warnings;

#--# Definition des variables globales
#######################################

#my $file_path = $ARGV[0] or die "Need to get config path file on the command line\n";
my $file_path = "hostTemplates.cfg";

$file_path =~ m/(.+\.)cfg/;
my $output_file = "$1"."csv";

my ( $count_object, $count_line ) = "0";


# Debut du chrono : TOP !
# my $start = Time::HiRes::time();

#--# Fonction d'extraction pour les commandes
##############################################

sub ParseCommandFile {

	#--# Definition des variables locales
	my ( $command_name, $command_line );

	#--# Création du fichier d'entrée et des titres de colonne
	my @colums_title = ("Numero","command_name","command_line");
	my $colums_line = join(";",@colums_title);

	open (FILEOUT, ">$output_file") or die "Could not write '$output_file'\n";
		print( FILEOUT "$colums_line"."\n" );
	close FILEOUT;
	
	#--# Ouverture du fichier d'entree
	open ( FILEIN, "$file_path" ) or die "Could not open : '$file_path' $!\n";
		#--# Parsing des donnees
		while( defined( my $line = <FILEIN> ) ) {
			chomp $line;
			$count_line++;
			#--DEBUG--# Affichage des lignes traitées 
			#print "-- Line : $count_line --\n$line\n";

			#--# Nettoyage des lignes vides et commentees
			next if ( $line !~ m/\w+|\}/ );
			next if ( $line =~ m/\s*#.*/ );
			
			#--# Recherche du début de définition de l'objet
			if ( $line =~ m/define command\{/ ) {
				$count_object++;
				($command_name, $command_line) = "NULL";
				next;
				}

			#--# Recherche des paramètres
			if ( $line =~ m/\s*command_name\s+(.+)\s*/ ) { $command_name = "$1"; next }
			if ( $line =~ m/\s*command_line\s+(.+)\s*/ ) { $command_line = "$1"; next }

			#--# Parametres non traites
			if ( $line !~ m/\}/ ) {
				print ( "$count_object => Reste : $line\n" );
				}	

			#--# Recherche de la fin de définition de l'objet
			if ( $line =~ m/\s*\}\s*/ ) {
				#--# Ecriture du fichier de sortie
				open (FILEOUT, ">>$output_file") or die "Could not write '$output_file'\n";
					print( FILEOUT "$count_object".";"."$command_name".";"."$command_line\n" );
				close FILEOUT;
				}	
			}
	#--# Fermeture du fichier d'éntrée
	close FILEIN;
}

#--# Fonction d'extraction pour les services et les templates de services
###########################################################################

sub ParseServiceFile {

	#--# Definition des variables locales
	my ( $host_template, $service_description, $service_name, $check_command, $use, $hostname, $max_check_attempts, $normal_check_interval, $retry_check_interval, $check_period, $notification_period, $notification_options, $contact_groups, $register, $warning, $critical, $macros );
	my @host_tpl_tab = undef;
	my @macro_tab = undef;

	#--# Création du fichier d'éntrée et des titres de colonne
	open (FILEOUT, ">$output_file") or die "Could not write '$output_file'\n";
		print( FILEOUT "Numero".";"."host_name".";"."TEMPLATE-HOST-LINK".";"."service_name".";"."service_description".";"."Est un template".";"."check_command".";"."use".";"."max_check_attempts".";"."normal_check_interval".";"."retry_check_interval".";"."check_period".";"."notification_period".";"."notification_options".";"."contact_groups".";"."warning".";"."critical".";"."macros"."\n" );
	close FILEOUT;
		
	#--# Ouverture du fichier d'éntrée
	open ( FILEIN, "$file_path" ) or die "Could not open : '$file_path' $!\n";
		#--# Parsing des donnees
		while( defined( my $line = <FILEIN> ) ) {
			chomp $line;
			$count_line++;
			#--DEBUG--# Affichage des lignes traitées 
			#print "-- Line : $count_line --\n$line\n";
			
			#--# Nettoyage des lignes vides et commentees
			next if ( $line !~ m/\w+|\}/ );
			next if ( $line =~ m/\s*#.*/ );
			
			#--# Recherche du début de définition de l'objet et reinitialisation des paramètres
			if ( $line =~ m/define service\{/ ) {
				$count_object++;
				$hostname = "NULL";
				$host_template = "NULL";
				$service_name = "NULL";
				$service_description = "NULL";
				$register = "NON";
				$check_command = "NULL";
				$use = "NULL";
				$max_check_attempts = "NULL";
				$normal_check_interval = "NULL";
				$retry_check_interval = "NULL";
				$check_period = "NULL";
				$notification_period = "NULL";
				$notification_options = "NULL";
				$contact_groups = "NULL";
				$warning = "NULL";
				$critical = "NULL";
				@host_tpl_tab = undef;
				@macro_tab = undef;
				next;	
				}

			#--# Nettoyage des lignes propres a Centreon
			#next if ( $line =~ m/_SERVICE_ID/ );

			#--# Recherche des paramètres
			if ( $line =~ m/\s*host_name\s+(.+)\s*/ ) { $hostname = "$1"; next }
			if ( $line =~ m/\s*name\s+(.+)\s*/ ) { $service_name = "$1"; next }
			if ( $line =~ m/\s*service_description\s+(.+)\s*/ ) { $service_description = "$1"; next }
			if ( $line =~ m/\s*check_command\s+(.+)\s*/ ) { $check_command = "$1"; next }
			if ( $line =~ m/\s*use\s+(.+)\s*/ ) { $use = "$1"; next }
			if ( $line =~ m/\s*max_check_attempts\s+(.+)\s*/ ) { $max_check_attempts = "$1"; next }
			if ( $line =~ m/\s*normal_check_interval\s+(.+)\s*/ ) { $normal_check_interval = "$1"; next }
			if ( $line =~ m/\s*retry_check_interval\s+(.+)\s*/ ) { $retry_check_interval = "$1"; next }
			if ( $line =~ m/\s*check_period\s+(.+)\s*/ ) { $check_period = "$1"; next }
			if ( $line =~ m/\s*notification_period\s+(.+)\s*/ ) { $notification_period = "$1"; next }
			if ( $line =~ m/\s*notification_options\s+(.+)\s*/ ) { $notification_options = "$1"; next }
			if ( $line =~ m/\s*contact_groups\s+(.+)\s*/ ) { $contact_groups = "$1"; next }

			#--# Parametres specifiques pour Centreon
			if ( $line =~ m/\s*_WARNING\s+(.+)\s*/ ) { $warning = "$1"; next }
			if ( $line =~ m/\s*_CRITICAL\s+(.+)\s*/ ) { $critical = "$1"; next }
			
			if ( $line =~ m/\s*;TEMPLATE-HOST-LINK\s+(.+)\s*/ ) {
				if ( defined( $host_tpl_tab[0] ) ) {
					push(@host_tpl_tab,"$1");
				} else {
					@host_tpl_tab = ($1);
				}
			next;
			}
		
			if ( $line =~ m/\s+_(\S+)\s+(.+)\s*/ ) {
				if ( defined( $macro_tab[0] ) ) {
					push(@macro_tab,"$1=>$2");
				} else {
					@macro_tab = ("$1=>$2");
				}
			next;
			}
				
			#--# Si template
			if ( $line =~ m/\s*register\s+(.+)\s*/ ) {
				if ( "$1" eq 0 ) { $register = "OUI" }
				next;
			}

			#--# Parametre non traites
			if ( $line !~ m/\}/ ) {
				print ( "$count_object => Reste : $line\n" );
				}

			#--# Recherche de la fin de définition de l'objet
			if ( $line =~ m/\s*\}\s*/ ) {
				#--DEBUG--# Affichage de la ligne de sortie 
				#print "$count_object".";"."$service_description".";"."$check_command\n";
				# Concatenation des tableaux
				if ( defined( $host_tpl_tab[0] ) ) {
					$host_template = join("|+|",@host_tpl_tab);
				} else {
				$host_template = "NULL";
				}
				#--DEBUG--#		
				#print ( "-- TPL : $host_template\n" ); 				
				if ( defined( $macro_tab[0] ) ) {
					$macros = join("|+|",@macro_tab);
				} else {
				$macros = "NULL";
				}		
				#--DEBUG--#		
				#print ( "-- MACROS : $macros\n" ); 				
	
				#--# Ecriture de la ligne dans le fichier de sortie
				open (FILEOUT, ">>$output_file") or die "Could not write '$output_file'\n";
					print( FILEOUT "$count_object".";"."$hostname".";"."$host_template".";"."$service_name".";"."$service_description".";"."$register".";"."$check_command".";"."$use".";"."$max_check_attempts".";"."$normal_check_interval".";"."$retry_check_interval".";"."$check_period".";"."$notification_period".";"."$notification_options".";"."$contact_groups".";"."$warning".";"."$critical".";"."$macros"."\n" );
				close FILEOUT;
				}	
			}
	#--# Fermeture du fichier d'éntrée
	close FILEIN;
}

#--# Fonction d'extraction pour les hotes et les templates d'hote
##################################################################

sub ParseHostFile {

	#--# Definition des variables locales
	my ( $hostname, $alias, $use, $icon, $register, $macros );
	my @macro_tab = undef;

	#--# Création du fichier d'éntrée et des titres de colonne
	open (FILEOUT, ">$output_file") or die "Could not write '$output_file'\n";
		print( FILEOUT "Numero".";"."Host".";"."alias".";"."use".";"."Icone".";"."Est un template".";"."macros"."\n" );
	close FILEOUT;
		
	#--# Ouverture du fichier d'éntrée
	open ( FILEIN, "$file_path" ) or die "Could not open : '$file_path' $!\n";
		#--# Parsing des donnees
		while( defined( my $line = <FILEIN> ) ) {
			chomp $line;
			$count_line++;
			#--DEBUG--# Affichage des lignes traitées 
			#print "-- Line : $count_line --\n$line\n";
			
			#--# Nettoyage des lignes vides et commentees
			next if ( $line !~ m/\w+|\}/ );
			next if ( $line =~ m/\s*#.*/ );
			
			#--# Recherche du début de définition de l'objet et reinitialisation des paramètres
			if ( $line =~ m/define host\{/ ) {
				$count_object++;
				$hostname = "NULL";
				$alias = "NULL";
				$use = "NULL";
				$register = "NON";
				$use = "NULL";
				$icon = "NULL";
				@macro_tab = undef;
				next;	
				}

			#--# Recherche des paramètres
			if ( $line =~ m/\s*name\s+(.+)\s*/ ) { $hostname = "$1"; next }
			if ( $line =~ m/\s*alias\s+(.+)\s*/ ) { $alias = "$1"; next }
			if ( $line =~ m/\s*use\s+(.+)\s*/ ) { $alias = "$1"; next }
			if ( $line =~ m/\s*icon_image\s+(.+)\s*/ ) { $icon = "$1"; next }

			if ( $line =~ m/\s+_(\S+)\s+(.+)\s*/ ) {
				if ( defined( $macro_tab[0] ) ) {
					push(@macro_tab,"$1=>$2");
				} else {
					@macro_tab = ("$1=>$2");
				}
			next;
			}
				
			#--# Si template
			if ( $line =~ m/\s*register\s+(.+)\s*/ ) {
				if ( "$1" eq 0 ) { $register = "OUI" }
				next;
			}

			#--# Parametre non traites
			if ( $line !~ m/\}/ ) {
				print ( "$count_object => Reste : $line\n" );
				}

			#--# Recherche de la fin de définition de l'objet
			if ( $line =~ m/\s*\}\s*/ ) {
				#--DEBUG--# Affichage de la ligne de sortie 
				#print "$count_object".";"."$service_description".";"."$check_command\n";

				if ( defined( $macro_tab[0] ) ) {
					$macros = join("|+|",@macro_tab);
				} else {
				$macros = "NULL";
				}		
				#--DEBUG--#		
				#print ( "-- MACROS : $macros\n" ); 				
	
				#--# Ecriture de la ligne dans le fichier de sortie
				open (FILEOUT, ">>$output_file") or die "Could not write '$output_file'\n";
					print( FILEOUT "$count_object".";"."$hostname".";"."$alias".";"."$use".";"."$icon".";"."$register".";"."$macros"."\n" );
				close FILEOUT;
				}	
			}
	#--# Fermeture du fichier d'éntrée
	close FILEIN;
}

#--# Fonction Pricipale 
########################


#ParseCommandFile;
#ParseServiceFile; 
ParseHostFile; 
