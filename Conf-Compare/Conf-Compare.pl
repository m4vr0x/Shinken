#!/usr/bin/perl
# ============================================================================
# ============================== INFO ========================================
# ============================================================================
# Version   : 0.1
# Date      : September 18 2014
# Author    : SRO
#
# ============================================================================
# ============================== VERSIONS ====================================
# ============================================================================
# version 0.1 : First draft
# version 0.2 : 
#  	- adding distinct socket variable for local and destination
#  	- adding distinct configuration folders for local and destination
#
# ============================================================================
# ============================== SUMMARY =====================================
# ============================================================================
# Script  to check host and services differences between 2 shinken platforms
#   - Source platform : localhost
#   - Destination plateform : specify on command line
#
# ============================================================================
# ============================== HELP ========================================
# ============================================================================
# Help : ./confCompare.pl --help
#
# ============================================================================

use warnings;
use strict;
use Getopt::Long;
use Time::Local;
use POSIX qw(strftime);

# ============================================================================
# ============================== GLOBAL VARIABLES ============================
# ============================================================================

my $version					= '0.2';	# Version number of this script
my $socket_l					= undef; 	# shinken local socket
my $socket_d					= undef;	# shinken destination socket
my $host_request 				= "GET hosts\\nColumns: name address\\n";
my $service_request 				= "GET services\\nColumns: host_name description\\n";
my $shinken_conf_l				= undef;
my $shinken_conf_d				= undef;

my $o_shost					= "localhost"; # source host for comparison (localhost for now)
my $o_dhost					= undef;	# destination host to compare with
my $o_statonly				= undef;	# print only number of hosts and svcs on each platform
my $o_sshkeypath			= undef;	# SSH private key path
my $o_help					= undef;	# get help
my $o_version				= undef;	# Print version
my $o_verb					= undef;	# Verbose mode

my @LHP1					= ();	# List of hosts on source platform
my @LHP2					= ();	# List of hosts on destination platform
my @LSP1					= ();	# List of services on source platform
my @LSP2					= ();	# List of services on destination platform

my @HNFIP1					= ();	# List of hosts in dest platform not present in source platform
my @HNFIP2					= ();	# List of hosts in source platform not present in dest platform
my @SNFIP1					= ();	# List of services in dest platform not present in source platform
my @SNFIP2					= ();	# List of services in source platform not present in dest platform

my @REMOTEFILES				= ();	# Result of "cat" of all remote configuration files (in hashes, key = path ; value = content)


# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version { 
	print "$0 version : $version\n"; 
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-V] [-h] [-v] [-n] [-i <path>] -d <destination_host>\n";
}

# Subroutine: Print complete help
sub help {
	print "\nCompare the Shinken configuration (hosts and services) between $o_shost and destination host\nVersion: ",$version,"\n\n";
	print "Requires being able to SSH to remote destination without password with current account\n\n";
	print_usage();
	print <<EOT;

Options:
-V, --version
   Prints version number
-v, --verbose
   Verbose output
-h, --help
   Print this help message
-d, --destination=HOST
   Hostname of host with which to compare configuration from
-i, --sshkeypath=PATH
   Path to the private key corresponding to the public key stored on the remote platform
-n, --statonly
	Print only number of hosts and services on each platform and exits

EOT
}

# checking socket existence
sub check_socket {
	if (-e "/usr/local/shinken/var/rw/live") {
		$socket_l = "/usr/local/shinken/var/rw/live";
	} elsif (-e "/var/run/shinken/rw/live") {
		$socket_l = "/var/run/shinken/rw/live";
	} elsif (-e "/var/run/shinken/rw/live") {
		$socket_l = "/var/run/shinken/rw/live";
	} else {
		print "Shinken local Livestatus socket not found, check the livestatus module configuration!";
		exit 2;
	}

	if ($o_sshkeypath) {
                $socket_d = `ssh -i $o_sshkeypath $o_dhost "find / -wholename '*/rw/live'"`;
        }
        else {
                $socket_d = `ssh $o_dhost "find / -wholename '*/rw/live'"`;
        }

        if (!defined ($socket_d)) {
        	print "Shinken remote Livestatus socket not found, check the livestatus module configuration!";
                exit 2;
        }
}

# getting configuration folder
sub get_config_folder {
        if (-d "/etc/shinken/objects") {
		$shinken_conf_l = "/etc/shinken/objects/";
        } elsif (-d "/usr/local/shinken/configuration") {
                $shinken_conf_l = "/usr/local/shinken/configuration/";
	} else {
                print "Shinken configuration folder not found!";
                exit 2;
        }

        if ($o_sshkeypath) {
		if (!(`ssh -i $o_sshkeypath $o_dhost "test -d '/usr/local/shinken/configuration' || echo $?"`)) {
			$shinken_conf_d = "/usr/local/shinken/configuration/";
		}
		elsif (!(`ssh -i $o_sshkeypath $o_dhost "test -d '/etc/shinken/objects' || echo $?"`)) {
			$shinken_conf_d = "/etc/shinken/objects/";
		}
        }
        else {
                if (!(`ssh $o_dhost "test -d '/usr/local/shinken/configuration' || echo $?"`)) {
                        $shinken_conf_d = "/usr/local/shinken/configuration/";
                }
                elsif (!(`ssh $o_dhost "test -d '/etc/shinken/objects' || echo $?"`)) {
                        $shinken_conf_d = "/etc/shinken/objects/";
		}
        }

        if (!defined ($shinken_conf_d)) {
                print "Shinken remote configuration folder not found!";
                exit 2;
        }
}



# Subroutine: logging
sub verb {
	my $message = shift;
#	my $time = Time::HiRes::time();
	my $ltime = strftime("%H:%M:%S", localtime(time()));
	
	if ($o_verb) {
		print STDERR $ltime.": ".$message." \n";
	}
}

# Subroutine: Check options
sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'		=> \$o_verb,		'verbose'		=> \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'd:s'   => \$o_dhost,		'destination:s'	=> \$o_dhost,
        'n'   	=> \$o_statonly,	'statonly'		=> \$o_statonly,
		'V'		=> \$o_version,		'version'		=> \$o_version,
		'i:s'	=> \$o_sshkeypath,	'sshkeypath:s'	=> \$o_sshkeypath,
	);

	if (defined ($o_help)) {
		help();
		exit 3;
	}
	
	if (defined($o_version)) {
		p_version();
		exit 3;
	}
	
	# Check if -d or -n option is present
	if (!defined($o_dhost)) {
		print "ERROR : -d option required!\n";
		print_usage();
		exit 3;
	}
}

sub get_remote_conf {
	my $srv = $_[0];
	my ($allfiles, $file, $content);
	
	if ($o_sshkeypath) {
		$allfiles = `ssh -i $o_sshkeypath $srv "find $shinken_conf_d -name '*.cfg'"`;
	}
	else {
		$allfiles = `ssh $srv "find $shinken_conf_d -name '*.cfg'"`;
	}
	foreach $file (split /\n/ ,$allfiles) {
		if ($o_sshkeypath) {
			$content = `ssh -i $o_sshkeypath $srv "cat $file"`;
		}
		else {
			$content = `ssh $srv "cat $file"`;
		}
		push @REMOTEFILES, { PATH => $file, CONTENT => $content }; 
	}
}

sub print_remote_conf {
	my $href;
	for $href ( @REMOTEFILES ) {
		print STDERR "{ ";
		print STDERR "PATH=$href->{'PATH'} ";
		print STDERR "}\n";
		print STDERR $href->{'CONTENT'};
	}
}


# Finds the configuration file in which host is declared
sub get_host_config_file {
	my $host = $_[0];
	my $srv = $_[1];
	my ($conf, $allfiles, $file, $match);
	my @matchs = ();
	
	# if local, no need to ssh
	if (($srv eq "localhost") || ($srv eq "127.0.0.1")) {
		# get list of configuration files
		$allfiles = `find $shinken_conf_l -name "*.cfg"`;

		# for each config file, search host definition ; when found, exit loop
		foreach $file (split /\n/ ,$allfiles) {
			open my $fh, '<', $file or die "error opening $file: $!";
			my $content = do { local $/; <$fh> };
			close $fh;
			if ($content =~ /(^define host{[^}]*host_name\s*($host)\n[^}]*})/sgm) {
				$file =~ s/$shinken_conf_l//;
				$conf = $file;
				last;
			}
		}
	}
	# if not local, then go through @REMOTEFILES
	else {
		@matchs = (grep {$_->{"CONTENT"} =~ /(^define host{[^}]*host_name\s*($host)\n[^}]*})/sm} @REMOTEFILES);
		if (scalar @matchs > 0) {
			$match = $matchs[0];
			$conf = $match->{'PATH'};
			$conf =~ s/$shinken_conf_d//;
		}
		else {
			$conf = "CONFIG FILE NOT FOUND";
		}
	}
	chomp($conf);
	return $conf;
}

# print missing hosts
sub print_missing_hosts {
	my @sorted1 = sort { $a->{CONF} cmp $b->{CONF} } @HNFIP1;
	my @sorted2 = sort { $a->{CONF} cmp $b->{CONF} } @HNFIP2;
	my $i = 0;
	
	print "The following hosts are present on $o_dhost but not on $o_shost :\n";
	foreach my $REC (@sorted1) {
		print "    ".$REC->{"CONF"}.": ".$REC->{"HOSTNAME"}." (".$REC->{"IP"}.")\n";
		$i = $i + 1;
	}
	if ($i == 0) {
		print "    NO DIFFERENCE DETECTED\n";
	}
	$i = 0;
	print "\nThe following hosts are present on $o_shost but not on $o_dhost :\n";
	foreach my $REC (@sorted2) {
		print "    ".$REC->{"CONF"}.": ".$REC->{"HOSTNAME"}." (".$REC->{"IP"}.")\n";
		$i = $i + 1;
	}
	if ($i == 0) {
                print "    NO DIFFERENCE DETECTED\n";
        }

}

# print missing services
sub print_missing_services {
	if (scalar @SNFIP1 > 0) {
		my @sorted1 = sort { $a->{CONF} cmp $b->{CONF} } @SNFIP1;
		print "\nThe following services are present on $o_dhost but not on $o_shost :\n";
		foreach my $REC (@sorted1) {
			print "    ".$REC->{"CONF"}.": ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.")\n";
		}
	}
	if (scalar @SNFIP2 > 0) {
		my @sorted2 = sort { $a->{CONF} cmp $b->{CONF} } @SNFIP2;
		print "\nThe following services are present on $o_shost but not on $o_dhost :\n";
		foreach my $REC (@sorted2) {
			print "    ".$REC->{"CONF"}.": ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.")\n";
		}
	}
}


# ============================================================================
# ============================== MAIN ========================================
# ============================================================================

verb("Starting script");

check_options();
verb("Options OK, getting configuration folder ...");

get_config_folder();
verb("Config folders OK, checking sockets ...");

check_socket();
verb("Socket OK, getting info on source and destination platforms ...");

# Put all hosts and services from source and dest into arrays :
@LHP1 = split(/\n/, `echo -e "$host_request" | unixcat $socket_l`);
@LSP1 = split(/\n/, `echo -e "$service_request" | unixcat $socket_l`);
if ($o_sshkeypath) {
	@LHP2 = split(/\n/, `ssh -i $o_sshkeypath $o_dhost "echo -e '$host_request' | unixcat $socket_d"`);
	@LSP2 = split(/\n/, `ssh -i $o_sshkeypath $o_dhost "echo -e '$service_request' | unixcat $socket_d"`);
}
else {
	@LHP2 = split(/\n/, `ssh $o_dhost "echo -e '$host_request' | unixcat $socket_d"`);
	@LSP2 = split(/\n/, `ssh $o_dhost "echo -e '$service_request' | unixcat $socket_d"`);
}
verb("hosts and services successfully obtained from $o_shost and $o_dhost");

my ($HOST1, $HOST2, $SVC1, $SVC2, $conf);
my (@HI, @HS);

if (scalar @LHP1 == 0) {
	print "Something went wrong, 0 host detected on $o_shost!\n";
	exit 2;
}
if (scalar @LHP2 == 0) {
	print "Something went wrong, 0 host detected on $o_dhost!\n";
	exit 2;
}
if (scalar @LSP1 == 0) {
	print "Something went wrong, 0 service detected on $o_shost!\n";
	exit 2;
}
if (scalar @LSP2 == 0) {
	print "Something went wrong, 0 service detected on $o_dhost!\n";
	exit 2;
}

# if option "-n" is given, print stats and exit
if ($o_statonly) {
	print "Number of host on $o_shost : ".scalar @LHP1."\n";
	print "Number of host on $o_dhost : ".scalar @LHP2."\n";
	print "Number of services on $o_shost : ".scalar @LSP1."\n";
	print "Number of services on $o_dhost : ".scalar @LSP2."\n";
	verb("End of script");
	exit 0;
}

if ((scalar @LHP1 == scalar @LHP2) && (scalar @LSP1 == scalar @LSP2)) {
	print "Plateform match perfectly! Congratulation!\n";
	verb("End of script");
	exit 0;
}
else {
	my $FOUND = 0;
	verb("BEGIN storing remote configuration from $o_dhost");
	get_remote_conf($o_dhost);
	verb("ENDING storing remote configuration from $o_dhost");
	# Si le nombre d'hote est le meme entre chaque plateforme, on compare directement les services
	if (scalar @LHP1 != scalar @LHP2) {
		# On recherche les hotes de la source non presents sur la destination 
		verb("BEGIN searching host from $o_shost not on $o_dhost");
		foreach $HOST1 (@LHP1) {
			$FOUND = 0;
			foreach $HOST2 (@LHP2) {
				if ($HOST1 eq $HOST2) {
					$FOUND = 1;
					last;
				}
			}
			if ($FOUND == 0) {
				@HI = split(/;/, $HOST1);
				$conf = get_host_config_file($HI[0], $o_shost);
				push @HNFIP2, { HOSTNAME => $HI[0], IP => $HI[1], CONF => $conf };
			}
		}
		verb("ENDING searching host from $o_shost not on $o_dhost");
		verb("BEGIN searching host from $o_dhost not on $o_shost");
		# On recherche les hotes de la destination non presents sur la source (instantané)
		foreach $HOST2 (@LHP2) {
			$FOUND = 0;
			foreach $HOST1 (@LHP1) {
				if ($HOST1 eq $HOST2) {
					$FOUND = 1;
					last;
				}
			}
			if ($FOUND == 0) {
				@HI = split(/;/, $HOST2);
				$conf = get_host_config_file($HI[0], $o_dhost);
				push @HNFIP1, { HOSTNAME => $HI[0], IP => $HI[1], CONF => $conf };
			}
		}
		verb("ENDING searching host from $o_dhost not on $o_shost");
		verb("Start printing missing hosts");
		print_missing_hosts();
		verb("End printing missing hosts");
	}
	# on recherche les services de la source non presents sur la destination
	verb("BEGIN searching services from $o_shost not on $o_dhost");
	foreach $SVC1 (@LSP1) {
		$FOUND = 0;
		foreach $SVC2 (@LSP2) {
			if ($SVC1 eq $SVC2) {
				$FOUND = 1;
				last;
			}
		}
		@HS = split(/;/, $SVC1);
		if (($FOUND == 0) && (!grep { $_->{"HOSTNAME"} eq $HS[0] } @HNFIP2)) {
			$conf = get_host_config_file($HS[0], $o_shost);
			push @SNFIP2, { HOSTNAME => $HS[0], SERVICE => $HS[1], CONF => $conf };
		}
	}
	verb("ENDING searching services from $o_shost not on $o_dhost");
	# on recherche les services de la destination non presents sur la source
	verb("BEGIN searching services from $o_dhost not on $o_shost");
	foreach $SVC2 (@LSP2) {
		$FOUND = 0;
		foreach $SVC1 (@LSP1) {
			if ($SVC1 eq $SVC2) {
				$FOUND = 1;
				last;
			}
		}
		@HS = split(/;/, $SVC2);
		if (($FOUND == 0) && (!grep {$_->{"HOSTNAME"} eq $HS[0]} @HNFIP1)) {
			$conf = get_host_config_file($HS[0], $o_dhost);
			push @SNFIP1, { HOSTNAME => $HS[0], SERVICE => $HS[1], CONF => $conf };
		}
	}
	verb("ENDING searching services from $o_dhost not on $o_shost");
	verb("Start printing missing services");
	print_missing_services();
	verb("End printing missing hosts");
	exit 2;
}
