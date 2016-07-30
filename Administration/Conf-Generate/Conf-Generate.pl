#!/usr/bin/perl

# Import des modules

use strict;
use warnings;
use Getopt::Std;
use Text::CSV_XS;
use Time::HiRes qw(gettimeofday);
use File::Path qw(make_path remove_tree);
no strict 'refs';

# Definition des variables

my $CsvPath = $ARGV[0] or die "Need to get CSV file on the command line\n";
my $CsvFileClean = "csv_cleaned.txt";
my $OutputFile = "output_file.txt";
my $Host_dir = "./hosts";

# Debut du chrono : TOP !
my $start = Time::HiRes::time();

remove_tree($Host_dir) if ( -d $Host_dir ) ;
make_path($Host_dir) or die "Unable to create destination directory\n";

my $csv = Text::CSV_XS->new({
		sep_char => ';',
		binary => 1,
		allow_whitespace => 1,
		auto_diag => 1
		});

open (my $data, '<', $CsvPath) or die "Could not open : '$CsvPath' $!\n";

my $header = $csv->getline ($data);
my $count_line = "0";

while (my $line = $csv->getline($data)) {
	$count_line++; 
	if ( ${$line}[3] eq '' && ${$line}[5] eq '' ) {
		print "WARNING - Line $count_line ignored : No hostname and no IP found !\n";
	} else { 
		my %host_definition = ();
		my $count_raw = -1;

		foreach (@{$line}) {
			$count_raw++;
			my $param = @{$header}[$count_raw];
			my $value = @{$line}[$count_raw];
			
			if ($param !~ m/!\w*/) {
				$host_definition{$param} = $value if ($value ne '');
				}
			}
			
			my $output_file = "hosts_other-TO_FILL.cfg";
			#print "Output_file : $output_file\n";
			for ( $host_definition{use} ) {
				#print "USE : $host_definition{use}\n\n";
				if (/.*windows.*/i)			{ $output_file = "hosts_windows.cfg" }
				elsif (/.*solaris.*/i)			{ $output_file = "hosts_unix.cfg" }
				elsif (/.*linux.*/i)			{ $output_file = "hosts_unix.cfg" }
				elsif (/.*virtual.*/i) 			{ $output_file = "hosts_virtual.cfg" }
				elsif (/.*bac.*/i) 			{ $output_file = "hosts_backup.cfg" }
				elsif (/.*sto.*/i)			{ $output_file = "hosts_storage.cfg" }
				elsif (/.*esx.*/i)			{ $output_file = "hosts_esx.cfg" }
				elsif (/.*shinken.*/i)			{ $output_file = "shinken_servers.cfg" }
				else					{ $output_file = "hosts_other-TO_FILL.cfg" }
			}
				
			if ( exists( $host_definition{host_name} ) && exists( $host_definition{address} ) ) {
				open my $conf_file,">>", "$Host_dir/$output_file" or die "Could not write '$Host_dir'/'$output_file' $!\n";
				print( $conf_file "define host{\n" ) ;
				print( $conf_file "\thost_name\t\t$host_definition{host_name}\n" ) && delete( $host_definition{host_name} );
				print( $conf_file "\talias\t\t\t$host_definition{alias}\n" ) && delete( $host_definition{alias} );
				print( $conf_file "\taddress\t\t\t$host_definition{address}\n" ) && delete( $host_definition{address} ) ;
				print( $conf_file "\tuse\t\t\t$host_definition{use}\n" ) && delete( $host_definition{use} ) ;
				foreach my $cle (keys %host_definition)	{
					print( $conf_file "\t$cle\t\t$host_definition{$cle}\n" );
					}
				print( $conf_file "\t}\n\n" );
				close $conf_file
			}
			#print "Output_file : $output_file\n==========================\n\n"
	}
}

close $data;

my $stop = Time::HiRes::time();
my $elapsed_time = $stop - $start;
$elapsed_time = sprintf("%0.3f", $elapsed_time);

print "\nDONE : $count_line lines parsed in $elapsed_time sec\n----------------------------------\n";

