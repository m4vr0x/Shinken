#!/usr/bin/perl
# ============================================================================
# ============================== INFO ========================================
# ============================================================================
# Version   : 0.1
# Date      : January 29 2015
# Author    : SRO
#
# ============================================================================
# ============================== VERSIONS ====================================
# ============================================================================
# version 0.1 : First draft
#
# ============================================================================
# ============================== SUMMARY =====================================
# ============================================================================
# Script  to check host and services status differences between 2 shinken platforms
#   - Source platform : localhost
#   - Destination plateform : specify on command line
#
# ============================================================================
# ============================== HELP ========================================
# ============================================================================
# Help : ./statusCompare.pl --help
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

my $version                 = '0.1';    # Version number of this script
my $socket_l                    = undef;    # shinken local socket
my $socket_d                    = undef;    # shinken destination socket
my $host_request                = "GET hosts\\nColumns: name address state\\nFilter: state != 0\\n";
my $service_request             = "GET services\\nColumns: host_name description state plugin_output\\nFilter: state >= 2\\n";

my $o_shost                 = "localhost"; # source host for comparison (localhost for now)
my $o_dhost                 = undef;    # destination host to compare with
my $o_statonly              = undef;    # print only number of hosts and svcs on each platform
my $o_sshkeypath            = undef;    # SSH private key path
my $o_help                  = undef;    # get help
my $o_version               = undef;    # Print version
my $o_verb                  = undef;    # Verbose mode
my $o_unknown               = undef;    # Print unknown services
my $o_critical              = undef;    # Print critical services
my $o_sortby                = undef;    # Sort by    
my $o_nooutput              = undef;    # dont print plugin output

my @LHP1                    = ();   # List of hosts on source platform
my @LHP2                    = ();   # List of hosts on destination platform
my @LSP1                    = ();   # List of services on source platform
my @LSP2                    = ();   # List of services on destination platform

my @HNFIP1                  = ();   # List of hosts in dest platform not present in source platform
my @HNFIP2                  = ();   # List of hosts in source platform not present in dest platform
my @SNFIP1                  = ();   # List of services in dest platform not present in source platform
my @SNFIP2                  = ();   # List of services in source platform not present in dest platform

my @REMOTEFILES             = ();   # Result of "cat" of all remote configuration files (in hashes, key = path ; value = content)


# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version { 
    print "$0 version : $version\n"; 
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-V] [-h] [-v] [-n] [-c] [-u] [-i <path>] -d <destination_host>\n";
}

# Subroutine: Print complete help
sub help {
    print "\nCompare the Shinken hosts and services status between $o_shost and destination host\nVersion: ",$version,"\n\n";
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
   Hostname of host with which to compare status from
-i, --sshkeypath=PATH
   Path to the private key corresponding to the public key stored on the remote platform
-n, --statonly
    Print only number of down hosts & critical and unknown services on each platform and exits
-c, --critical
    Print only CRITICAL services and not the UNKNOWN ones ; hosts down are still printed.
    Using -c and -u together is the same as not using them : it is the default choice
-u, --unknown
    Print only UNKNOWN services, and not the CRITICAL ones ; hosts down are still printed
    Using -c and -u together is the same as not using them : it is the default choice
-s, --sortby
    Sort Service array by HOSTNAME | SERVICE | STATE | OUTPUT (default : STATE)
-o, --nooutput
    Dont print plugin output for services

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


# Subroutine: logging
sub verb {
    my $message = shift;
#   my $time = Time::HiRes::time();
    my $ltime = strftime("%H:%M:%S", localtime(time()));
    
    if ($o_verb) {
        print STDERR $ltime.": ".$message." \n";
    }
}

# Subroutine: Check options
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,        'verbose'       => \$o_verb,
        'h'     => \$o_help,        'help'          => \$o_help,
        'd:s'   => \$o_dhost,       'destination:s' => \$o_dhost,
        's:s'   => \$o_sortby,      'sortby:s'      => \$o_sortby,
        'n'     => \$o_statonly,    'statonly'      => \$o_statonly,
        'u'     => \$o_unknown,     'unknown'       => \$o_unknown,
        'c'     => \$o_critical,    'critical'      => \$o_critical,
        'o'     => \$o_nooutput,    'nooutput'      => \$o_nooutput,
        'V'     => \$o_version,     'version'       => \$o_version,
        'i:s'   => \$o_sshkeypath,  'sshkeypath:s'  => \$o_sshkeypath,
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

    if ((!defined($o_unknown) && !defined($o_critical)) || (defined($o_unknown) && defined($o_critical))) {
        $o_unknown = 1;
        $o_critical = 1;
    } elsif (defined($o_unknown)) {
        $o_unknown = 1;
        $o_critical = 0;
        $service_request = "GET services\\nColumns: host_name description state plugin_output\\nFilter: state = 3\\n";
    } elsif (defined($o_critical)) {
        $o_unknown = 0;
        $o_critical = 1;
        $service_request = "GET services\\nColumns: host_name description state plugin_output\\nFilter: state = 2\\n";
    }

    if (!defined($o_sortby)) {
        $o_sortby = "STATE";
    } elsif (($o_sortby ne "HOSTNAME") && ($o_sortby ne "STATE") && ($o_sortby ne "SERVICE") && ($o_sortby ne "OUTPUT")) {
        print "ERROR : -s must be either HOSTNAME or STATE or SERVICE or OUTPUT!\n";
        print_usage();
        exit 3;
    }
}


# print hosts
sub print_hosts_status_diff {
    my @sorted1 = sort { $a->{HOSTNAME} cmp $b->{HOSTNAME} } @HNFIP1;
    my @sorted2 = sort { $a->{HOSTNAME} cmp $b->{HOSTNAME} } @HNFIP2;
    my $i = 0;
    
    print "The following hosts are DOWN on $o_dhost but not on $o_shost :\n";
    foreach my $REC (@sorted1) {
        print "    ".$REC->{"HOSTNAME"}." (".$REC->{"IP"}.") - STATE = ".$REC->{"STATE"}."\n";
        $i = $i + 1;
    }
    if ($i == 0) {
        print "    NO DIFFERENCE DETECTED\n";
    }
    $i = 0;
    print "\nThe following hosts are DOWN on $o_shost but not on $o_dhost :\n";
    foreach my $REC (@sorted2) {
        print "    ".$REC->{"HOSTNAME"}." (".$REC->{"IP"}.") - STATE = ".$REC->{"STATE"}."\n";
        $i = $i + 1;
    }
    if ($i == 0) {
        print "    NO DIFFERENCE DETECTED\n";
    }
}

# print services
sub print_services_status_diff {
    if (scalar @SNFIP1 > 0) {
        my @sorted1 = sort { $a->{$o_sortby} cmp $b->{$o_sortby} } @SNFIP1;
        print "\nThe following services are CRITICAL or UNKNOWN on $o_dhost but not on $o_shost :\n";
        foreach my $REC (@sorted1) {
            if (($o_sortby eq "STATE") || ($o_sortby eq "SERVICE") || ($o_sortby eq "OUTPUT")) {
                if (defined($o_nooutput)) {
                    print "    ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.") - STATE = ".$REC->{"STATE"}."\n";
                } else {
                    print "    ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.") - STATE = ".$REC->{"STATE"}." ; === ".$REC->{"OUTPUT"}." ===\n";
                }
            } elsif ($o_sortby eq "HOSTNAME") {
                if (defined($o_nooutput)) {
                    print "    ".$REC->{"HOSTNAME"}." : ".$REC->{"SERVICE"}." - STATE = ".$REC->{"STATE"}."\n";
                } else {
                    print "    ".$REC->{"HOSTNAME"}." : ".$REC->{"SERVICE"}." - STATE = ".$REC->{"STATE"}." ; === ".$REC->{"OUTPUT"}." ===\n";
                }
            }
        }
    }
    if (scalar @SNFIP2 > 0) {
        my @sorted2 = sort { $a->{$o_sortby} cmp $b->{$o_sortby} } @SNFIP2;
        print "\nThe following services are CRITICAL or UNKNOWN on $o_shost but not on $o_dhost :\n";
        foreach my $REC (@sorted2) {
            if (($o_sortby eq "STATE") || ($o_sortby eq "SERVICE") || ($o_sortby eq "OUTPUT")) {
                if (defined($o_nooutput)) {
                    print "    ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.") - STATE = ".$REC->{"STATE"}."\n";
                } else {
                    print "    ".$REC->{"SERVICE"}." (".$REC->{"HOSTNAME"}.") - STATE = ".$REC->{"STATE"}." ; === ".$REC->{"OUTPUT"}." ===\n";
                }
            } elsif ($o_sortby eq "HOSTNAME") {
                if (defined($o_nooutput)) {
                    print "    ".$REC->{"HOSTNAME"}." : ".$REC->{"SERVICE"}." - STATE = ".$REC->{"STATE"}."\n";
                } else {
                    print "    ".$REC->{"HOSTNAME"}." : ".$REC->{"SERVICE"}." - STATE = ".$REC->{"STATE"}." ; === ".$REC->{"OUTPUT"}." ===\n";
                }
            }
        }
    }
}


# ============================================================================
# ============================== MAIN ========================================
# ============================================================================

verb("Starting script");

check_options();
verb("Options OK, checking sockets ...");

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

my ($HOST1, $HOST2, $SVC1, $SVC2, $SVC1_SHORT, $SVC2_SHORT);
my (@HI, @HS1, @HS2);


# if option "-n" is given, print stats and exit
if ($o_statonly) {
    print "Number of hosts down on $o_shost : ".scalar @LHP1."\n";
    print "Number of hosts down on $o_dhost : ".scalar @LHP2."\n";
    print "Number of services critical / unknown on $o_shost : ".scalar @LSP1."\n";
    print "Number of services critical / unknown on $o_dhost : ".scalar @LSP2."\n";
    verb("End of script");
    exit 0;
}

my $FOUND = 0;

# On recherche les hotes DOWN de la source dont le statut diffère sur la destination 
verb("BEGIN searching hosts down on $o_shost and not on $o_dhost");
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
        push @HNFIP2, { HOSTNAME => $HI[0], IP => $HI[1], STATE => $HI[2] };
    }
}
verb("ENDING searching hosts down on $o_shost and not on $o_dhost");

verb("BEGIN searching hosts down on $o_dhost and not on $o_shost");
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
        push @HNFIP1, { HOSTNAME => $HI[0], IP => $HI[1], STATE => $HI[2] };
    }
}
verb("ENDING searching hosts down on $o_dhost and not on $o_shost");


verb("Start printing hosts status differences");
print_hosts_status_diff();
verb("End printing hosts status differences");


# on recherche les services de la source non presents sur la destination
verb("BEGIN searching services critical and unknown on $o_shost and not on $o_dhost");
foreach $SVC1 (@LSP1) {
    $FOUND = 0;
    @HS1 = split(/;/, $SVC1);
    $SVC1_SHORT=$HS1[0].";".$HS1[1].";".$HS1[2];
    foreach $SVC2 (@LSP2) {
        @HS2 = split(/;/, $SVC2);
        $SVC2_SHORT=$HS2[0].";".$HS2[1].";".$HS2[2];
        if ($SVC1_SHORT eq $SVC2_SHORT) {
            $FOUND = 1;
            last;
        }
    }
    if ($FOUND == 0) {
        push @SNFIP2, { HOSTNAME => $HS1[0], SERVICE => $HS1[1], STATE => $HS1[2], OUTPUT => $HS1[3] };
    }
}
verb("ENDING searching services critical and unknown on $o_shost and not on $o_dhost");

# on recherche les services de la destination non presents sur la source
verb("BEGIN searching services critical and unknown on $o_dhost and not on $o_shost");
foreach $SVC2 (@LSP2) {
    $FOUND = 0;
    @HS2 = split(/;/, $SVC2);
    $SVC2_SHORT=$HS2[0].";".$HS2[1].";".$HS2[2];
    foreach $SVC1 (@LSP1) {
        @HS1 = split(/;/, $SVC1);
        $SVC1_SHORT=$HS1[0].";".$HS1[1].";".$HS1[2];
        if ($SVC1_SHORT eq $SVC2_SHORT) {
            $FOUND = 1;
            last;
        }
    }
    if ($FOUND == 0) {
        push @SNFIP1, { HOSTNAME => $HS2[0], SERVICE => $HS2[1], STATE => $HS2[2], OUTPUT => $HS2[3] };
    }
}
verb("ENDING searching services critical and unknown on $o_dhost and not on $o_shost");

verb("Start printing services status differences");
print_services_status_diff();
verb("End printing services status differences");
exit 2;


