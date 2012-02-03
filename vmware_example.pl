#!/usr/bin/perl
#
#  Copyright (c) 2009-2010 by Dell, Inc. 
# 
# All rights reserved.  This software may not be copied, disclosed, 
# transferred, or used except in accordance with a license granted 
# by Dell, Inc.  This software embodies proprietary information 
# and trade secrets of Dell, Inc. 
#
# Dell EqualLogic installation tool which wraps vihostupdate and performs
# additional management functionality.
#
use strict;
use warnings;

use File::Spec;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;
use WSMan::GenericOps;
use Data::Dumper;
use Config;

# Use the vMA library if available
BEGIN { eval "use VMware::VmaTargetLib" }
my $vma_available = $INC{"VMware/VmaTargetLib.pm"};
my $vma_target;

#===============================================================================
# DELL_EqlHostConnectionManager
#===============================================================================

package DELL_EqlHostConnectionManager;
use WSMan::Stubs::Initializable;
use WSMan::Stubs::CIM_Service;

@DELL_EqlHostConnectionManager::ISA = qw(_Initializable CIM_Service);

sub _init{
    my ($self, %args) = @_;
    $self->CIM_Service::_init();
    $self->{invokableMethods}->{StartService} = { input => [], output => [] };
    $self->{invokableMethods}->{StopService} = { input => [], output => [] };
    # No additional keys beyond those used for CIM_Service.
    @{$self->{id_keys}} = keys %{{ map { $_ => 1 } @{$self->{id_keys}} }};

    if(keys %args){
        $self->_subinit(%args);
    }
}

#===============================================================================
# DELL_EqlHostConnectionManagerSetting
#===============================================================================

package DELL_EqlHostConnectionManagerSetting;
use WSMan::Stubs::Initializable;
use WSMan::Stubs::CIM_SettingData;

@DELL_EqlHostConnectionManagerSetting::ISA = qw(_Initializable CIM_SettingData);

sub _init{
    my ($self, %args) = @_;
    $self->CIM_SettingData::_init();
    $self->{invokableMethods}->{SetValue} = { input => ['Value'], output => [] };
    push @{$self->{id_keys}}, 'Name';
    @{$self->{id_keys}} = keys %{{ map { $_ => 1 } @{$self->{id_keys}} }};
    if(keys %args){
        $self->_subinit(%args);
    }
}

package main;

my $version_prefix = "DELL-eql-mem-";
my $old_version_prefix = "DELL-eql-esx-mpio-";
my $version_num = "1.0.0.130413";
my $initial_build_num = 111844;
my $bundle_name = "dell-eql-mem-1.0.0.130413.zip";
my $required_esx_version = "4.1";
my $required_esx_build = 235786;
my $required_vcli_version = "4.1";

my %opts = (
    query => {
        type => "",
        help => "    Query the status of the Multipathing Extension Module on the ESX/ESXi host.",
        required => 0,
    },
    install => {
        type => "",
        help => "    Install the Multipathing Extension Module on the ESX/ESXi host.  The package will be enabled after reboot.",
        required => 0,
    },
    enable => {
        type => "",
        help => "    Enable the Multipathing Extension Module on the ESX/ESXi host.",
        required => 0,
    },   
    disable => {
        type => "",
        help => "    Disable the Multipathing Extension Module on the ESX/ESXi host.",
        required => 0,
    },
    remove => {
        type => "",
        help => "    Remove the Multipathing Extension Module from the ESX/ESXi host.  A reboot is required to complete the operation.",
        required => 0,
    },
    configure => {
        type => "",
        help => "    Configure networking for iSCSI multipathing.",
        required => 0,
    },
    listparam => {
        type => "",
        help => "    Display Eql Host Connection Manager parameters.",
        required => 0,
    },
    setparam => {
        type => "",
        help => "    Set specified Eql Host Connection Manager parameter.  Use with --name and --value arguments.",
        required => 0,
    },
    bundle => {
        type => "=s",
        help => "    Parameter to specify the location of the multipathing offline bundle.",
        required => 0,
    },
    vswitch  => {
        type     => "=s",
        help     => "    Name for iSCSI vSwitch.",
        required => 0,
        default => "vSwitchISCSI",
    },
    mtu  => {
        type     => "=s",
        help     => "    MTU for iSCSI vSwitch and VMkernel ports.",
        required => 0,
        default => "1500",
    },
    nics  => {
        type     => "=s",
        help     => "    Physical NICs to use for iSCSI.",
        required => 0,
    },
    vmkernel  => {
        type     => "=s",
        help     => "    Prefix to use for VMkernel port names.",
        required => 0,
        default => "iSCSI",
    },
    ips  => {
        type     => "=s",
        help     => "    IP addresses to use for iSCSI VMkernel ports.",
        required => 0,
    },
    netmask  => {
        type     => "=s",
        help     => "    Netmask to use for iSCSI VMkernel ports.",
        required => 0,
        default => "255.255.255.0",
    },
    reboot  => {
        type     => "",
        help     => "    Automatically reboot host after install/uninstall operation.",
        required => 0,
    },
    enableswiscsi  => {
        type     => "",
        help     => "    Enable the Software iSCSI initiator.",
        required => 0,
    },
    nohwiscsi  => {
        type     => "",
        help     => "    Use only the Software iSCSI initiator.",
        required => 0,
    },
    name  => {
        type     => "=s",
        help     => "    Name of parameter to set.",
        required => 0,
    },
    value  => {
        type     => "=s",
        help     => "    Value of parameter to set.",
        required => 0,
    },
    vds => {
        type     => "",
        help     => "    Use a Distributed switch instead of a standard switch.",
        required => 0,
    },
	groupip => {
		type     => "=s",
		help     => "    PS Group IP address to add as an iSCSI Discovery Portal.",
		required => 0,
	},
    vihost => {
        type     => "=s",
        help     => "    Host name.  This parameter is only necessary if the server is a vCenter server.",
        required => 0,
    },
    viusername => {
        type     => "=s",
        help     => "    Host username.  This parameter is only necessary if the server is a vCenter server.",
        required => 0,
    },
    vipassword => {
        type     => "=s",
        help     => "    Host password.  This parameter is only necessary if the server is a vCenter server.",
        required => 0,
	},
	logfile => {
		type     => "=s",
		help     => "    Logfile to use.",
		required => 0,
		default  => "setup.log",
	}
);

Opts::add_options(%opts);
Opts::parse();

# All recognized arguments are removed from ARGV by the parsing code.  If anything is left over it is an unrecognized parameter
# and is likely a typo.
if (scalar(@ARGV) > 0) {
	print("\nUnrecognized parameter '@ARGV'.\nCommand line options must be prefixed with a double dash (--).\nValues provided as a list such as NICs and IP addresses must be separated by commas with no whitespace.\n\n");
    usage();
    exit();
}

# The user must have selected at least one valid operation.  Check before calling validate() so we don't ask for a username.
if (!Opts::get_option('query') && 
    !Opts::get_option('install') && 
    !Opts::get_option('remove') &&
    !Opts::get_option('enable') &&
    !Opts::get_option('disable') &&
    !Opts::get_option('listparam') &&
    !Opts::get_option('setparam') &&
    !Opts::get_option('configure') &&
    !Opts::get_option('help'))
{
    # No valid operation provided.
    usage();
    exit();
}

# Store common options in global vars
my $username = Opts::get_option('username');
my $password = Opts::get_option('password');
my $server = Opts::get_option('server');
my $hostname = Opts::get_option('vihost');
my $hostusername = Opts::get_option('viusername');
my $hostpassword = Opts::get_option('vipassword');
my $reboot = Opts::get_option('reboot');

# If the user is asking for help, we do not need to login to the server.
if (!Opts::option_is_set('help')) {

	# The vSphere CLI may set the server to 'localhost' if not specified by the user
	if (!$server || ($server eq "localhost")) {
		usage();
		VIExt::fail("You must provide the address of an ESX/ESXi host with the --server parameter.");
	}

	# If we are on a vMA, go ahead and login with VI fastpass.
	if ($vma_available) {
		# Connect to the server specified by the user.  This may be a vCenter or ESX/ESXi.
		fastpass_login($server);
	}
	
	# If successful fastpass login, update some variables
	if ($vma_target) {
		# Extract username/password from fastpass even if user provided them.  This ensures we have
		# current credentials.
		my $target;
		eval { $target = VmaTargetLib::query_target($server); };
		if(!$@) {
			$username = $target->username();
			$password = $target->password();
			
			# If the user didn't provide any username/password on the command line but we found one from fastpass, set this in 
			# the config options.  This is necessary to prevent Opts::validate() from prompting the user for a username/password.
			if (!Opts::option_is_set('username')) {
				Opts::set_option('username', $username);
			}
			if (!Opts::option_is_set('password')) {
				Opts::set_option('password', $password);
			}
			
		} else {
			print "Error: " . $@ . "\n";
		}
		
		if (defined($hostname)) {
			
			eval { $target = VmaTargetLib::query_target($hostname); };
			if(!$@) {
				$hostusername = $target->username();
				$hostpassword = $target->password();
			} else {
				print "Error: " . $@ . "\n";
			}
			
			if (!$hostusername || !$hostpassword) {
				VIExt::fail("You must either configure fastpass authentication on the vMA or provide --viusername and --vipassword arguments.");
			}
		}
	}

	# If we still didn't find a username or password, the user will need to enter one.
	if (!Opts::option_is_set('username') || !Opts::option_is_set('password')) {
		print "You must provide the username and password for the server.\n";
	}
}

Opts::validate();


# If the user didn't provide the username and/or password on the command line or via fastpass, the Opts::validate() queried the user for them.
if (!$username) {
    $username = Opts::get_option('username');
}
if (!$password) {
    $password = Opts::get_option('password');
}

# If we are on windows, find the location of vicli binaries, in case they are not in our path
my $path;
if ($Config{osname} =~ /Win32/) {
    my @path = split(';', $ENV{PATH});

    # Add some additional 'good guesses' to the search path
    push(@path, '.');                                                       # Current directory
    push(@path, $ENV{PROGRAMFILES} . "\\VMware\\VMware vSphere CLI\\bin");  # Default install path
    
    foreach (@path) {
        if (-e "$_\\vihostupdate.pl") {
            $path = $_;
            last;
        }
        elsif ($_ =~ /(^.+)\\Perl\\/) {
            # The vSphere CLI installer puts the Perl\bin directory under the vSphere CLI directory by default.
            if (-e "$1\\bin\\vihostupdate.pl") {
                $path = "$1\\bin";
                last;
            }
        }
        else {
            # vSphere CLI binaries do not exist in this path
        }
    }

    unless($path) {
        VIExt::fail("Cannot find vSphere CLI binaries.  Add the vSphere CLI bin directory to your path,\nor run the script from the directory where the CLI binaries are installed.");
    }
}

# Generate command lines for necessary external programs.
my $esxcli_cmd = "esxcli";
my $vihostupdate_cmd = "vihostupdate";
my $suppress = "2>/dev/null";

# On Windows, vSphere CLI commands end with .pl
if ($Config{osname} =~ /Win32/) {
    $vihostupdate_cmd = "\"$path\\vihostupdate.pl\"";
    $esxcli_cmd = "\"$path\\esxcli\"";
    $suppress = "";
}

# Verify the vSphere CLI version is valid
check_vcli_version();

if (!$vma_target) {
    # Either we are not on vMA or fastpass authentication is not set up to the target.  Connect the old way.
    Util::connect();
}

# Determine what we are connected to.
my $service_content = Vim::get_service_content();
if ($service_content && ($service_content->about->name =~ m/vCenter Server/)) {
    if (!defined($hostname)) {
        VIExt::fail("You must provide a --vihost parameter when --server is a vCenter Server.");
    }
}

# esxcli and vihostupdate must be run directly against the ESX host.
my $server_args = "";
if (defined($hostname)) {
    if (!defined($hostusername) || !defined($hostpassword)) {
        VIExt::fail("You must provide the --viusername and --vipassword arguments when you use the --vihost argument.");
    }

    $server_args .= " --server $hostname";
    if (defined($hostusername)) {
        $server_args .= " --username $hostusername";
    }
    if (defined($hostpassword)) {
        $server_args .= " --password $hostpassword";
    }
}
elsif (defined($server) && ($server ne "localhost")) {

    # If the username is not provided on the command line or via fastpass, the Opts::validate() call will prompt the user for it.

    $server_args .= " --server $server";
    if (defined($username)) {
        $server_args .= " --username $username";
    }
    if (defined($password)) {
        $server_args .= " --password $password";
    }
}

my $host_view;
if (!defined($hostname)) {
    # By default assume we are running to the ESX/ESXi host
    $host_view = Vim::find_entity_view(view_type => 'HostSystem');
}
else {
    # Connecting through vCenter, request a specific host view
    $host_view = Vim::find_entity_view(view_type => 'HostSystem',
                                       filter => { name => $hostname } );
}

unless ($host_view) {
   VIExt::fail("Host not found.\n");
}

Opts::assert_usage(defined($host_view), "Invalid host.");

check_host_version($host_view);

my $patch_manager = Vim::get_view(mo_ref => $host_view->configManager->patchManager);
unless ($patch_manager) {
   VIExt::fail("Patch manager not found.\n");
}

# Log file to record our network configuration activity.
my $logfilename = Opts::get_option('logfile');
my $LOGFILE;

# Open logfile
sub logopen {
	if (!open ($LOGFILE, '>>', $logfilename)) {
		print "Unable to open logfile '$logfilename'.  Output will be directed to the console only.\n";
		undef($LOGFILE);
	}
	else {
		# Put a timestamp in the logfile
		(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime(time);
		printf $LOGFILE "%4d-%02d-%02d %02d:%02d:%02d\n", $year+1900, $mon+1, $mday, $hour, $min, $sec;
	}
}

sub logclose {
	if ($LOGFILE) {
		close($LOGFILE);
		undef($LOGFILE);
	}
}

# Trace a message to the log file and stdout.
sub logmsg {
	my ($msg) = @_;

	# If logfile exists, echo message to it.
	if ($LOGFILE) {
		print $LOGFILE $msg;
	}
	print $msg;
}

# Trace a fatal message to the log file and stdout.
sub logfatal {
	my ($msg) = @_;

	# If logfile exists, echo message to it.
	if ($LOGFILE) {
		print $LOGFILE $msg . "\n";
		logclose();
	}
	VIExt::fail($msg);
}

# Perform the requested operation.
if (Opts::get_option('query')) {
    my $installed_version = query_installed_version($patch_manager);
    if ($installed_version) {
        print "Found Dell EqualLogic Multipathing Extension Module installed: $installed_version\n";

        get_default_psp();
        get_active_psp();
        print_bound_vmknics();
        
    }
    else {
        print "No Dell EqualLogic Multipathing Extension Module found.\n";
    }
} elsif (Opts::get_option('install')) {
    my $installed_version = query_installed_version($patch_manager);
    if (is_same_eql_version($installed_version)) {
        VIExt::fail("\nThe package $installed_version is already installed.");
    }
    elsif (is_old_beta_version($installed_version)) {
        VIExt::fail("\nThe package $installed_version is from a previous beta.  Please uninstall it before installing the new multipathing extension module.");
    }
    elsif (!is_maintenance_mode($host_view)) {
        VIExt::fail("Enter maintenance mode before installing the Dell EqualLogic Multipathing Extension Module.");
    }
    elsif ($installed_version) {
        print "Upgrading from existing Dell EqualLogic Multipathing Extension Module installed: $installed_version\n";
    }
    else {
        print "Clean install of Dell EqualLogic Multipathing Extension Module.\n";
    }

    install_package();

    if ($installed_version) {
        # On an upgrade install, the package is already enabled.
        print "Upgrade install was successful.\n";
    }
    else {
        # On classic ESX or ESXi, we do not enable the package until the PSP is loaded on the first reboot.
        print "Clean install was successful.\n";
    }

    if ($reboot) {
        print "Rebooting host.\n";
        reboot_host($host_view);
    }
    else {
        print "You must reboot before the new version of the Dell EqualLogic Multipathing Extension Module is active.\n";
    }

} elsif (Opts::get_option('remove')) {
    my $installed_version = query_installed_version($patch_manager);

    if (!defined($installed_version)) {
        VIExt::fail("No installed Dell EqualLogic Multipathing Extension Module found");
    }
    elsif (!is_maintenance_mode($host_view)) {
    	VIExt::fail("Enter maintenance mode before removing the Dell EqualLogic Multipathing Extension Module.");
    }
    else {
        print "Uninstalling existing Dell EqualLogic Multipathing Extension Module: $installed_version.\n";
    }

    remove_package($installed_version);

    print "Package removed successfully.\n";

    if ($reboot) {
        print "Rebooting host.\n";
        reboot_host($host_view);
    }
    else {
        print "You must reboot the host to complete the operation.\n";
    }

} elsif (Opts::get_option('enable')) {
    my $installed_version = query_installed_version($patch_manager);
    if (!$installed_version) {
        VIExt::fail("You must install the Dell EqualLogic Multipathing Extension Module before you enable it");
    }
    enable_package();

} elsif (Opts::get_option('disable')) {
    disable_package();

} elsif (Opts::get_option('configure')) {

    if (!is_maintenance_mode($host_view)) {
    	VIExt::fail("Enter maintenance mode before configuring networking for the Dell EqualLogic Multipathing Extension Module.");
    }

	# If the user provided required parameters (ips and nics) proceed directly to configuration
    if (Opts::option_is_set('nics') &&
        Opts::option_is_set('ips'))
    {
		configure_networking();
    }
	elsif (!Opts::option_is_set('nics') &&
		   !Opts::option_is_set('ips') &&
		   !Opts::option_is_set('vsiwtch') &&
		   !Opts::option_is_set('mtu') &&
		   !Opts::option_is_set('vmkernel') &&
		   !Opts::option_is_set('netmask') &&
		   !Opts::option_is_set('enableswiscsi') &&
		   !Opts::option_is_set('nohwiscsi') &&
		   !Opts::option_is_set('vds') &&
		   !Opts::option_is_set('groupip'))
	{
		# The user did not provide the necessary info, go through interview mode	
		configure_networking_interview();
	}
	else
	{
		# The user tried to specify partial parameters, these will be ignored by the interview.
        print "You must provide the --nics and --ips parameters for networking configuration.\n";
		print "Alternatively, you can run the --configure command with no additional parameters to enter interactive mode.\n";
		exit;
    }

} elsif (Opts::get_option('listparam') || Opts::get_option('setparam')) {
    
    # Set connection parameters for CIM queries
    my %args = (
        path => '/wsman',
        port => '80',
        address => defined($hostname) ? $hostname : Opts::get_option ('server'),
        namespace => 'root/cimv2',
        timeout  => '120'
        );

    # Force user to provider username and password for WSMan operations.
    if (!defined($username) || !defined($password)) {
        VIExt::fail("vMA $required_vcli_version requires explicit username and password for this operation");
    }

    # If the user provided a username and password, use them.
    # If using the vihost parameter, use the vihost username/password
    if (defined($hostusername)) {
        $args{ 'username' } = $hostusername;
    }
    elsif (defined($username)) {
        $args{ 'username' } = $username;
    }

    if (defined($hostpassword)) {
        $args{ 'password' } = $hostpassword;
    }
    elsif (defined($password)) {
        $args{ 'password' } = $password;
    }

    my $genclient = WSMan::GenericOps->new(%args);
    my @services = eql_create_objects($genclient->EnumerateInstances(class_name => 'CIM_Service'));

	my $found = 0;
    foreach (@services){
        if ($_->{Name}){
            if($_->{Name} =~ m/DELL_EqlHostConnectionManager/i)
            {
				$found = 1;
                my @settings;
                
                if (Opts::get_option('listparam')) {
                    @settings = eql_create_objects($genclient->EnumerateAssociatedInstances(class_name => $_->{Name},
                                                                                            selectors => $_->get_selectorset->{$_->{epr_name}}));
                }
                elsif (Opts::get_option('setparam')) {
                    if (!defined(Opts::get_option('name')) || !defined(Opts::get_option('value'))) {
                        VIExt::fail("You must provide the --name and --value arguments when setting a parameter.");
                    }
                    
                    my $name = Opts::get_option('name');
                    my $value = Opts::get_option('value');

                    # Test whether value is an integer
                    if ($value !~ /^\d+$/) {
                        VIExt::fail("Value '$value' is invalid, it must be an integer.");
                    }

                    # Enumerate parameters to find the param of interest.
                    @settings = eql_create_objects($genclient->EnumerateAssociatedInstances(class_name => $_->{Name},
                                                                                            selectors => $_->get_selectorset->{$_->{epr_name}}));
                    my $found = 0;
                    foreach my $setting (@settings) {
                        if($setting->{Name} eq $name) {
                            $found = 1;
                            my $max = $setting->{Max};
                            my $min = $setting->{Min};
                            if ($value > $max || $value < $min) {
                                VIExt::fail("Values for parameter '$name' must be between $min and $max.");
                            }
                            last;
                        }
                    }

                    if (!$found) {
                        VIExt::fail("'$name' is not a valid parameter");
                    }
                            
                    print "Setting parameter $name  = $value\n\n";
                    @settings = eql_create_objects($genclient->EnumerateAssociatedInstances(class_name => $_->{Name},
                                                                                            selectors => $_->get_selectorset->{$_->{epr_name}},
                                                                                            role => 'SetParam',
                                                                                            resultclassname => Opts::get_option('name'),
                                                                                            resultrole => Opts::get_option('value')));
                }

                my $format = "%-16.16s%-6.6s%-6.6s%-6.6s%-60.60s\n";
                printf $format, "Parameter Name", "Value", "Max", "Min", "Description";
                printf $format, "--------------", "-----", "---", "---", "-----------";
                foreach (@settings) {
                    printf $format, $_->{Name}, $_->{Value}, $_->{Max}, $_->{Min}, $_->{Description};
                }
                print "\n";
            }
        }
    }

	if (!$found) {
        print "No Dell EqualLogic Multipathing Extension Module found.\n";
    }

} else {
    usage();
    VIExt::fail("Unrecognized operation");
}


#
# Utility routines
#
sub usage {
    print "Supported commands:\n";
    print "  --query       Query whether the Dell EqualLogic Multipathing Extension Module is installed.\n";
    print "  --install     Install the Dell EqualLogic Multipathing Extension Module.\n";
    print "  --remove      Remove the Dell EqualLogic Multipathing Extension Module.\n";
    print "  --enable      Enable the Dell EqualLogic Multipathing Extension Module.\n";
    print "  --disable     Disable the Dell EqualLogic Multipathing Extension Module.\n";
    print "  --configure   Configure networking for iSCSI multipathing.\n";
    print "  --listparam   List EHCM configuration parameters.\n";
    print "  --setparam    Set EHCM configuration parameter.\n";
    print "  --help        Get extended help on script options.\n";
    print "  \n";
    print "Examples:\n";
    print "  Install the module:\n";
    print "    setup.pl --install --server=<hostname> [--bundle=<filename>]\n";
    print "  Configure networking:\n";
    print "    setup.pl --configure --server=<hostname> --nics=<nic1>,<nic2>,... --ips=<ip1>,<ip2>,... [--vswitch=<switchname>] [--mtu=<mtu>] [--vmkernel=<vmkernel port prefix>] [--netmask=<subnet mask>] [--groupip=<EQL group IP>] [--enableswiscsi] [--nohwiscsi] [--vds]\n";
    print "  Set EHCM configuration parameter:\n";
    print "    setup.pl --setparam --server=<hostname> --name=<param name> --value=<param value>\n";
    print "\n";
}

sub check_vcli_version {

    my $result;
    
    # No server args are necessary to check the version
    eval { $result = `$vihostupdate_cmd --version`; };

    if ($@) {
        # Error occurred, assume no support
        VIExt::fail("Unable to determine vSphere CLI version: $@.  This script must be run from a system with the vSphere CLI $required_vcli_version.");
    }
    elsif ($result =~ m/$required_vcli_version/) {
        # Found the required version.
        return;
    }
    else {
        VIExt::fail("Did not find version $required_vcli_version of the vSphere CLI installed:\n$result");
    }
}

sub check_host_version {
   my ($hostview) = @_;
   my $host_version = $hostview->summary->config->product->version;
   my $host_build = $hostview->summary->config->product->build;
   if ($host_version !~ /^$required_esx_version/) {
       VIExt::fail("The Dell EqualLogic Multipathing Extension Module is NOT supported on $host_version platform.");
   }
   # The 4.1 beta build does not contain all required kernel APIs.
   if ($host_build < $required_esx_build) {
       VIExt::fail("The Dell EqualLogic Multipathing Extension Module requires build $required_esx_build or later.");
   }
}

sub is_host_esxi {
    my ($host_type) = @_;
    if ($host_type =~ /embeddedEsx/) {
        # This is an ESXi host.
        return 1;
    }
    else {
        return;
    }
}

sub is_same_eql_version {
    my ($eql_version) = @_;
    if (!$eql_version) {
        return;
    }
    elsif ($eql_version =~ m{$version_num}) {
        # Same version
        return 1;
    }
    else {
        return;
    }
}

sub is_old_beta_version {
    my ($eql_version) = @_;
    if (!$eql_version) {
        return;
    }

    # Parse out the build number.
    if ($eql_version =~ m{1\.0\.0\.(\d+)}) {
        if ($1 < $initial_build_num) {
            # This is prior to the final release.  Force clean uninstall/reinstall.
            return 1;
        }
    }

    return;
}

sub query_installed_version {

    # Call vihostupdate to query for installed packages.
    my $result;

    eval { $result = `$vihostupdate_cmd $server_args --query`; };

    if ($@) {
        # Error occurred, assume not installed.
        return;
    }
    elsif ($result =~ m{($version_prefix\S{1,12})}) {
        # Found a Multipathing Extension Module installed.
        return $1;
    }
    elsif ($result =~ m{($old_version_prefix\S{1,12})}) {
        # Found a beta Multipathing Extension Module installed.
        return $1;
    }
    else {
        return;
    }
}

sub is_maintenance_mode {
    my ($host_view) = @_;

    return $host_view->summary->runtime->inMaintenanceMode;
}

sub reboot_host {
    my ($host_view) = @_;

    # Do not force a reboot if the host is not in maintenance mode.
    return $host_view->RebootHost_Task(force => "false");
}

sub install_package {
    my $bundle = Opts::get_option('bundle');

    if (!$bundle) {
        # Default to the bundle in the same directory as the setup script
        my $bundlepath = dirname(File::Spec->rel2abs( __FILE__ ));
        $bundle = "$bundlepath/$bundle_name";
        print "Defaulting to offline bundle $bundle\n";
    }
    unless (-e $bundle) {
        VIExt::fail("Bundle $bundle not found.  If you are attempting to install a different bundle, specify the location with the --bundle parameter");
    }

    # Call vihostupdate to install the new bundle.
    print "The install operation may take several minutes.  Please do not interrupt it.\n";
    my $result;
    eval { $result = `$vihostupdate_cmd $server_args --install --bundle $bundle`; };

    # Echo the underlying output to the user if an error occur.
    if ($@) {
        print "Install error: $@\n";
    }

    # Check to see if the install succeeded
    my $installed_version = query_installed_version();
    if (!is_same_eql_version($installed_version)) {
        VIExt::fail("\nInstall failed.\n");
    }

    # Install succeeded
}

sub remove_package {
    my ($bulletin) = @_;

    # Call vihostupdate to remove the bundle.
    print "The remove operation may take several minutes.  Please do not interrupt it.\n";
    my $result;
    eval { $result = `$vihostupdate_cmd $server_args --remove --bulletin $bulletin`; };

    if ($@) {
        print "Remove error: $@\n";
    }

    # Check to see if the remove succeeded
    my $installed_version = query_installed_version();
    if ($installed_version) {
        VIExt::fail("\nRemove failed.\n");
    }

    # Remove succeeded
}

sub enable_package {

    set_default_psp("DELL_PSP_EQL_ROUTED");
    set_active_psp("DELL_PSP_EQL_ROUTED");
}

sub disable_package {

    set_default_psp("VMW_PSP_FIXED");
    set_active_psp("VMW_PSP_FIXED");
}

sub set_default_psp {
    my ($psp) = @_;

    my $result = `$esxcli_cmd $server_args nmp satp setdefaultpsp --satp VMW_SATP_EQL --psp $psp`;

    print ("$result");
}

sub set_active_psp {
    my ($psp) = @_;

    my $devlist = `$esxcli_cmd $server_args nmp device list`;
    my @lines = split("\n", $devlist);

    my $naa = "";

    foreach my $line (@lines) {

        # Record any new device we find
        if ($line =~ m{^(naa.\w+)}) {
            # Found a new device.
            $naa = $1;
        }
        elsif ($naa && $line =~ m{VMW_SATP_EQL}) {
            # The device is EQL.
            print("Setting PSP for $naa to $psp.\n");
            my $result = `$esxcli_cmd $server_args nmp device setpolicy --device $naa --psp $psp`;
            
            # Suppress printing on success
            if ($result !~ "true") {
                print ($result);
            }
            $naa = "";
        }
    }
}

sub get_default_psp {
    my $satplist = `$esxcli_cmd $server_args nmp satp list`;
    my @lines = split("\n", $satplist);

    foreach my $line (@lines) {
        if ($line =~ m(^VMW_SATP_EQL)) {
            my @fields = split(" ", $line);
            my $defaultpsp = $fields[1];
            print "Default PSP for EqualLogic devices is $defaultpsp.\n";
            return;
        }
    }
}

sub get_active_psp {
    my $devlist = `$esxcli_cmd $server_args nmp device list`;
    my @lines = split("\n", $devlist);

    my $eql = 0;
    my $naa = "";

    foreach my $line (@lines) {

        # Record any new device we find
        if ($line =~ m{^(naa.\w+)}) {
            # Found a new device.
            $naa = $1;
            $eql = 0;
        }
        elsif ($line =~ m{EQLOGIC iSCSI Disk}) {
            # The device is EQL.
            $eql = 1;
        }
        elsif ($line =~ m{Path Selection Policy: (\w+)}) {
            my $psp = $1;
            # Print it out if it's one of ours
            if ($eql) {
                print("Active PSP for $naa is $psp.\n");
            }
            $naa = "";
            $eql = 0;
        }
    }
}

sub configure_networking {

    # Check for parameters without a default value
    if (!Opts::option_is_set('nics') ||
        !Opts::option_is_set('ips'))
    {
        VIExt::fail("You must provide the --nics and --ips parameters for networking configuration");
    }

    my $vswitchname = Opts::get_option('vswitch');
    my $vds = Opts::get_option('vds');
    my $vswitch;
    my $mtu = Opts::get_option('mtu');
    my @nics = split(/[ ,:]+/, Opts::get_option('nics'));
    my @ips = split(/[ ,:]+/, Opts::get_option('ips'));
    my $netmask = Opts::get_option('netmask');
    my $vmkernel = Opts::get_option('vmkernel');
    my $enableswiscsi = Opts::get_option('enableswiscsi');
    my $nohwiscsi = Opts::get_option('nohwiscsi');
	my $groupip = Opts::get_option('groupip');
    my $result = 1;

    if (scalar(@nics) != scalar(@ips)) {
        VIExt::fail("You must specify an equal number of nics and IP addresses");
    }

    if ($vds && !defined($hostname)) {
        VIExt::fail("When configured iSCSI networking with a vDS, you must connect to the vCenter Server.\nSpecify the vCenter Server with the --server option, and the ESX/ESXi host with the --vihost option\n");
    }

	# Use the log macros to direct this output to stdout and a log file.
	logopen();

    logmsg "\nConfiguring networking for iSCSI multipathing:\n";
    logmsg "\tvswitch = $vswitchname\n";
    logmsg "\tmtu = $mtu\n\tnics = @nics\n\tips = @ips\n\tnetmask = $netmask\n\tvmkernel = $vmkernel\n";
    if ($enableswiscsi) {
        logmsg "\tenableswiscsi = $enableswiscsi\n";
    }
    if ($nohwiscsi) {
        logmsg "\tnohwiscsi = $nohwiscsi\n";
    }
    elsif ($enableswiscsi) {
        $nohwiscsi = 1;
        logmsg "\tnohwiscsi = $nohwiscsi (forced by --enableswiscsi option)\n";
    }
    if ($vds) {
        logmsg "\tvds = 1\n";
    }
	if ($groupip) {
		logmsg "\tEQL group IP = $groupip\n";
	}

    # Step 0: Find the current host networking information
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    my $storage_system = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);

    my @vmhbalist = find_vmhbas($nohwiscsi);
    if (!@vmhbalist && !$enableswiscsi) {
        logfatal("No supported iSCSI adapters found.\nOnly the VMware SW initiator and Broadcom iSCSI adapter are supported.\nTo enable and use the VMware SW initiator, specify the --enableswiscsi parameter.");
    }

    # Step 0A: Validate inputs
    foreach my $ip (@ips) {
        if (!validate_ips($vswitchname, @ips)) {
            logfatal("Invalid IP address.");
        }
    }

    foreach my $nic (@nics) {
        if (!validate_nics($vswitchname, @nics)) {
            logfatal("Invalid Nic.");
        }
    }

    # Step 1: Create a vSwitch (if necessary)
    # Check for standard vswitch
    if (!$vds && ($vswitch = find_vswitch($vswitchname))) {
        logmsg "Using existing vSwitch $vswitchname.\n";
    }
    elsif ($vswitch = find_vdswitch($vswitchname)) {
        if ($vswitch->summary->productInfo->vendor !~ m/VMware/) {
            logfatal("Only distributed virtual switches from VMware are supported.");
        }
        $vds = 1;
        logmsg "Using existing vDS $vswitchname.\n";
    }
    elsif ($vds) {
        create_vdswitch($vswitchname, $mtu);

        $vswitch = find_vdswitch($vswitchname);

        unless ($vswitch) {
            logfatal("Cannot create vDS $vswitchname.  Use the vCenter Client GUI to create the vDS, and relaunch this configuration script.");
        }
    }
    else {
        $vswitch = create_vswitch($vswitchname);
    }
        
    # Step 1B: Set the vSwitch MTU
    my $currentmtu = get_switch_mtu($vds, $vswitch);
    if ($currentmtu && ($currentmtu == $mtu)) {
        # No change needed
        logmsg "vSwitch MTU is already set to $mtu.\n";
    }
    else {
        set_switch_mtu($vds, $vswitch, $mtu);
    }

    my @vmknics;
    if (!$vds) {

        # Build a hash to track the previous active and standby uplink nics for each VMkernel port on the vSwitch.
        my %old_active;
        my %old_standby;

        if ($vswitch->portgroup) {
            foreach my $pgkey (@{ $vswitch->portgroup }) {
                
                my $pg = find_portgroup_by_key($pgkey);
                
                if (!$pg) {
                    # Unexpected error
                    logfatal("Unable to find portgroup with key $pgkey");
                }
                
                if ($pg->spec->policy->{nicTeaming}->{nicOrder}->{activeNic}) {
                    $old_active{$pgkey} = $pg->spec->policy->nicTeaming->nicOrder->activeNic;
                }
                if ($pg->spec->policy->{nicTeaming}->{nicOrder}->{standbyNic}) {
                    $old_standby{$pgkey} = $pg->spec->policy->nicTeaming->nicOrder->standbyNic;
                }
            }
        }
        
        # Step 2: Create VMkernel ports
        my @portgroups;

        my $i = 0;  # Index in IP address array
        my $j = 0;  # Suffix to vmkernel port name

        foreach my $ip (@ips) {
            # Check for an existing vmknic with this IP.
            my $vmknic = find_vmknic_by_ip($ip);
            
            if ($vmknic) {
                
                # Find the portgroup the vmknic is connected to.
                my $portgroupname = $vmknic->spec->portgroup;
                if ($portgroupname !~ m/$vmkernel/) {
                    logfatal("IP address $ip is already used on VMkernel port $portgroupname");
                }

                my $portgroup = find_portgroup($portgroupname);
                
                # We already validated the IP, but double check this vmknic is connected to the same vSwitch.
                if ($portgroup->vswitch ne $vswitch->key) {
                    logfatal("IP address $ip is already used by VMKernel port $portgroupname on vSwitch " . $portgroup->spec->vswitchName);
                }
                
                # Reusing the existing VMkernel port and vmknic
                logmsg "Reusing existing PortGroup $portgroupname with IP $ip.\n";
                push(@portgroups, $portgroup);
                push(@vmknics, $vmknic);
            }
            else {
                # Find a unique portgroup name with the desired prefix.
                while (find_portgroup($vmkernel.$j)) {
                    $j++;
                }

                my $portgroupname = $vmkernel.$j;

                create_portgroup($portgroupname, $vswitchname, 0);
                my $portgroup = find_portgroup($portgroupname);
				
                if ($portgroup) {
                    push(@portgroups, $portgroup);
                }
                else {
                    logfatal("Failed to create Portgroup.");
                }
                
                # Assign the IP address to the new Portgroup
                create_vmknic($ip, $netmask, $mtu, $portgroupname);

                my $vmknic = find_vmknic_by_portgroup($portgroupname);
                unless($vmknic) {
                    logfatal("Failed to create vmknic with IP $ip.");
                }

                push (@vmknics, $vmknic);
            }
            
            $i++;
        }
        
        # Step 3: Add Uplink NICs

        # If the vSwitch has no uplinks, create a bridge.
        if (!defined($vswitch->spec->bridge)) {
            logmsg "Creating new bridge.\n";
            $vswitch->{spec}->{bridge} = new HostVirtualSwitchBondBridge();
        }
        
        foreach my $nic (@nics) {
            
            if (grep (/$nic/, @{$vswitch->spec->bridge->{nicDevice}})) {
                logmsg "Using existing uplink $nic on $vswitchname.\n";
            }
            else {
                logmsg "Adding uplink $nic to $vswitchname.\n";
                push (@{$vswitch->spec->bridge->{nicDevice}}, $nic);
                push (@{$vswitch->spec->policy->nicTeaming->nicOrder->{activeNic}}, $nic);
            }
        }
        
        eval {
            logmsg "Setting new uplinks for $vswitchname.\n";
            $network_system->UpdateVirtualSwitch(vswitchName => $vswitchname, 
                                                 spec => $vswitch->spec);
        };

        if ($@) {
            logfatal($@->fault_string);
        }
        
        # Step 4: Set 1:1 uplink NIC mapping on new nic/portgroup combinations
        # Restore previous uplink NICs for existing portgroups on the switch
        if ($vswitch->portgroup) {
            foreach my $pgkey (@{ $vswitch->portgroup }) {
                
                my $pg = find_portgroup_by_key($pgkey);
                
                if (!$pg) {
                    logfatal("Unable to find portgroup with key $pgkey");
                }
                
                my $pgname = $pg->spec->name;
                
                logmsg "Restoring uplinks to $pgname.\n";
                if (exists($old_active{$pgkey}) || exists($old_standby{$pgkey})) {
                    
                    $pg->spec->policy->nicTeaming->nicOrder(new HostNicOrderPolicy());
                    if (exists($old_active{$pgkey})) {
                        $pg->spec->policy->nicTeaming->nicOrder->activeNic($old_active{$pgkey});
                    }
                    if (exists($old_standby{$pgkey})) {
                        $pg->spec->policy->nicTeaming->nicOrder->standbyNic($old_standby{$pgkey});
                    }
                    
                    my $pgspec = new HostPortGroupSpec (name => $pgname, 
                                                        policy => $pg->spec->policy,
                                                        vlanId => $pg->spec->vlanId, 
                                                        vswitchName => $vswitchname);
                    eval {
                        $network_system->UpdatePortGroup (pgName => $pgname, 
                                                          portgrp => $pgspec);
                    };
                    if ($@) {
                        logfatal($@->fault_string);
                    }
                }
            }
        }

        for (my $i = 0; $i < scalar(@nics); $i++) {
            my $pgname = $portgroups[$i]->spec->name;
            logmsg "Setting uplink for $pgname to $nics[$i].\n";
            
            # Create policies if they don't already exist.
            if (!defined($portgroups[$i]->spec->policy->nicTeaming)) {
                $portgroups[$i]->spec->policy->nicTeaming(new HostNicTeamingPolicy());
            }
            if (!defined($portgroups[$i]->spec->policy->nicTeaming->nicOrder)) {
                $portgroups[$i]->spec->policy->nicTeaming->nicOrder(new HostNicOrderPolicy());
            }
            
            # Set the uplink to the single nic.
            my @nicList = ($nics[$i]);
            $portgroups[$i]->spec->policy->nicTeaming->nicOrder->activeNic(\@nicList);
            
            my $pgspec = new HostPortGroupSpec (name => $pgname, 
                                                policy => $portgroups[$i]->spec->policy,
                                                vlanId => $portgroups[$i]->spec->vlanId,
                                                vswitchName => $vswitchname);
            eval {
                $network_system->UpdatePortGroup (pgName => $pgname, 
                                                  portgrp => $pgspec);
            };
            if ($@) {
                logfatal($@->fault_string);
            }
        }
    }
    else {
        # vDS case.
        my $vds_host = find_vds_host($hostname, $vswitch);
        
        unless($vds_host) {
            add_vds_host($hostname, $vswitch);

            # Reload the vdswitch to pick up the configuration change
            $vswitch = find_vdswitch($vswitchname);

            $vds_host = find_vds_host($hostname, $vswitch);

            unless($vds_host) {
                logfatal("Unable to add the host $hostname to the vDS.  Add it manually using the vCenter client GUI, and relaunch this configuration script.");
            }
        }

        # Iterate through the nic<->IP pairs and assign each to a vDS DVuplink
        my $i = 0;   # Index into nics & IP address arrays
        my $j = 0;   # Suffix to use when creating a DVportgroup
        for ($i = 0; $i < @nics; $i++) {
            my $new_pnic = $nics[$i];
            my $new_ip = $ips[$i];

            # Check to see if the desired Nic is already an uplink for the vDSwitch
            my $pnic;
            if ($vds_host->config) {
                $pnic = find_vds_pnic($vds_host->config->backing->pnicSpec, $new_pnic);
            }

            unless($pnic) {
                add_vds_pnic($vswitch, $vds_host, $new_pnic);
                
                # Reload the vdswitch to pick up the configuration change
                $vswitch = find_vdswitch($vswitchname);
                $vds_host = find_vds_host($hostname, $vswitch);
                $pnic = find_vds_pnic($vds_host->config->backing->pnicSpec, $new_pnic);

                unless($pnic) {
                    logfatal("Unable to add the nic $new_pnic to the uplink portgroup for the vDS $vswitchname.  Add the nic manually using the vSphere client GUI, and relaunch this configuration script.");
                }
            }
                    
            # Find the DVPort for the uplink
            my $dvuplinkport = find_vds_uplink_dvport($pnic, $vswitch);
            unless($dvuplinkport) {
                # This failure is not expected if the pnic is configured as an uplink nic for the vDS.
                logfatal("The uplink port for $new_pnic could not be found.  Use the vCenter client to assign the nic to a vDS uplink port");
            }
            
            # Find a DVPortGroup that has this pNic as its only uplink.
            my $dvpg = find_dvportgroup_with_uplink($dvuplinkport, $vswitch);
            unless($dvpg) {
                # Find a unique name to use for the portgroup.
                while (find_dvportgroup($vmkernel.$j)) {
                    $j++;
                }

                create_dvportgroup_with_uplink($dvuplinkport, $vswitch, $vmkernel.$j);

                $vswitch = find_vdswitch($vswitchname);
                $dvpg = find_dvportgroup_with_uplink($dvuplinkport, $vswitch);
                
                unless($dvpg) {
                    logfatal("Unable to create a Port Group with single uplink to $new_pnic.  Create the Port Group manually, and relaunch this configuration script.");
                }
            }
            
            # Check whether there is already a vmknic with this IP address on the portgroup
            if (find_dvport_with_ip($vswitch, $dvpg, $new_ip)) {
                logmsg "vmknic with IP $new_ip is already assigned to nic $new_pnic.\n";
                next;
            }

            # Find an unused DVPort.
            my $dvport = find_unused_dvport($vswitch, $dvpg);
            unless($dvport) {
                # This is not expected unless the dvPortGroup does not have enough free ports.
                logfatal("No unused DVPort found.");
            }

            # Create a new vmknic and assign it to this DVPort
            create_vds_vmknic($new_ip, $netmask, $mtu, $dvpg, $dvport, $vswitch);

            my $vmknic = find_vmknic_by_ip($new_ip);
            
            unless($vmknic) {
                logfatal("Failed to create a vmknic with IP $new_ip.");
            }

            push(@vmknics, $vmknic);
        }
    }

    # Step 5: Enable iSCSI initiator
    if ($enableswiscsi) {
    @vmhbalist = find_vmhbas(1);
        if (!@vmhbalist) {
            logmsg "Enabling SW initiator.\n";
            enable_swiscsi();
            logmsg "Enabled SW initiator.\n";
        }
        else {
            logmsg "SW initiator is already enabled.\n";
        }
    }

    # Step 5A: Find the iSCSI initiator(s) to use
    @vmhbalist = find_vmhbas($nohwiscsi);
    if (!@vmhbalist) {
        logfatal("No supported iSCSI adapters found.  Only the VMware SW initiator and Broadcom iSCSI adapter are supported.");
    }

    # Step 6: Bind VMkernel ports to the iSCSI initiator
	my %usedhbas = ();
    foreach my $vmk (@vmknics) {
		my $vmkname = $vmk->device;
		
		# Try each adapter on the list.  The list has HW adapters ahead of SW.
		my $success = 0;
		foreach my $vmhba (@vmhbalist) {
			my $vmhbaname = $vmhba->device;
			
			if (!is_hba_vmknic($vmkname, $vmhbaname)) {
				# This vmknic is not usable by this HBA
				next;
			}
			
			if (is_hba_bound_vmknic($vmkname, $vmhbaname)) {
				# This vmknic is already bound to this HBA
				logmsg "$vmkname is already bound to $vmhbaname.\n";
				$success = 1;
				$usedhbas{$vmhbaname}++;
				last;
			}

			eval { $result = `$esxcli_cmd $server_args swiscsi nic add --nic $vmkname --adapter $vmhbaname $suppress`; };
			if (!$result) {
				logmsg "Bound $vmkname to $vmhbaname.\n";
				$success = 1;
				$usedhbas{$vmhbaname}++;
				last;
			}
			else {
				# Continue to other adapters on the list
				logmsg "Failed bind: $result.\n";
			}
		}
		
		if (!$success) {
			logfatal("Could not bind $vmkname to any of the iSCSI adapters.");
		}
	}

	# Step 7: Refresh the host storage subsystem.  This is necessary after binding new vmknics before some
	# adapters will allow us to add a discovery address.
	eval {
		logmsg "Refreshing host storage system.\n";
		$storage_system->RefreshStorageSystem();
	};

	if ($@) {
		logfatal($@->fault_string);
	}

	# Step 8: Add the specified group IP as a discovery address.
	if ($groupip)
	{
		my $discoveryTarget = new HostInternetScsiHbaSendTarget( address => $groupip );

		foreach my $hbaname (keys %usedhbas)
		{
			eval {
				logmsg "Adding discovery address $groupip to storage adapter $hbaname.\n";
				$storage_system->AddInternetScsiSendTargets( iScsiHbaDevice => $hbaname, 
															 targets => [ $discoveryTarget ] );
			};
			
			if ($@) {
				logfatal($@->fault_string);
			}
		}

		# Rescan HBAs after adding the discovery address.
		eval {
			logmsg "Rescanning all HBAs.\n";
			$storage_system->RescanAllHba();
		};
		
		if ($@) {
			logfatal($@->fault_string);
		}
	}

	logmsg "Network configuration finished successfully.\n";

    my $installed_version = query_installed_version($patch_manager);
    if (!$installed_version) {
        logmsg "No Dell EqualLogic Multipathing Extension Module found.\n";
		logmsg "Continue your setup by installing the module with the --install option or through vCenter Update Manager.\n";
    }

	logclose();
}

sub configure_networking_interview {

	# Query the user in an interactive manner to gather all the configuration options.

	# Whether to use a vDS
	my @choices = ("vSwitch", "vDS");
	my $usevds = lc(prompt_user_choices("Do you wish to use a standard vSwitch or a vNetwork Distributed Switch", \@choices, "vSwitch")) eq 'vds';

	# vSwitch Name
	my $existing;
	if ($usevds) {
		$existing = join(', ', find_all_vds());
	}
	else {
		$existing = join(', ', find_all_vswitches());	
	}
	if ($existing) {
		print "\nFound existing switches $existing.";
	}
	else {
		print "\nNo existing switches found on this host.";
	}
	my $vswitchname = prompt_user_string("vSwitch Name", "vSwitchISCSI");

	# If vSwitch exists, whether to use existing vswitch
	my $vswitch;
    if ((!$usevds && find_vswitch($vswitchname)) ||
		($usevds && find_vdswitch($vswitchname))) 
	{
		my $reuse = prompt_user_yesno("The vSwitch $vswitchname already exists.  Do you wish to reuse this vSwitch", 'yes');
		if ($reuse eq 'no') {
			print "Rerun the configuration and choose a different vSwitch name.\n";
			exit;
		}
	}

	# NICs to use
	my @niclist = find_all_nics();
	my @unusedlist = find_unused_nics();
	my @nics = prompt_user_multichoice("Which nics do you wish to use for iSCSI traffic?", \@niclist, \@unusedlist);

	# IPs to use
	my @ips;
	foreach my $nic(@nics) {
		my $ip = prompt_user_ip("IP address for vmknic using nic $nic", '');
		push(@ips, $ip);
	}

	# netmask to use
	my $netmask = prompt_user_ip('Netmask for all vmknics', '255.255.255.0');

	# MTU to use
	my $mtu = prompt_user_string("What MTU do you wish to use for iSCSI vSwitches and vmknics?  Before increasing\nthe MTU, verify the setting is supported by your NICs and network switches.", '1500');

	# VMKernel prefix to use
	my $vmkernel = prompt_user_string('What prefix should be used when creating VMKernel Portgroups?', 'iSCSI');

	# If HBA exists, whether to use HBA
    my @vmhbalist = find_vmhbas(0);
	my $hwsw = 'sw';

	if ((scalar(@vmhbalist) > 1) || 
		((scalar(@vmhbalist) > 0) && $vmhbalist[0]->driver !~ /iscsi_vmk/)) {
		my @choices = ("sw", "hw");
		$hwsw = prompt_user_choices("Do you wish to use SW iSCSI or HW iSCSI?", \@choices, "HW");
	}
	
	# If using SW initiator, check whether it should be enabled
	my $enableswiscsi = 0;
	if ($hwsw eq 'sw') {
		my @swhbalist = find_vmhbas(1);
		if (scalar(@swhbalist) == 0)
		{
			# If not using HBA and SW iSCSI is not enabled, whether to enable
			if (lc(prompt_user_yesno("The SW iSCSI initiator is not enabled, do you wish to enable it?", 'yes') eq 'no')) {
				print "No iSCSI initiators found to use.\n";
				exit;
			}
			
			$enableswiscsi = 1;
		}
	}

	# Group IP address to add to the Send Targets discovery list
	my $groupip = prompt_user_ip_optional('What PS Group IP address would you like to add as a Send Target discovery address (optional)?', '');

	# Dump out results
	print "Configuring iSCSI networking with following settings:\n";
	if ($usevds) {
		print "\tUsing a vDS '$vswitchname'\n";
	}
	else {
		print "\tUsing a standard vSwitch '$vswitchname'\n";
	}
	print "\tUsing NICs '" . join(',', @nics) . "'\n";
	print "\tUsing IP addresses '" . join (',', @ips) . "'\n";
	print "\tUsing netmask '$netmask'\n";
	print "\tUsing MTU '$mtu'\n";
	print "\tUsing prefix '$vmkernel' for VMKernel Portgroups\n";
	print "\tUsing " . uc($hwsw) . " iSCSI initiator\n";
	if ($enableswiscsi) {
		print "\tEnabling SW iSCSI initiator\n";
	}
	if ($groupip) {
		print "\tAdding PS Series Group IP '$groupip' to Send Targets discovery list\n";
	}

	# Build up the equivalent command line
	my $scriptpath = File::Spec->rel2abs( __FILE__ );
	my $cmd = "$scriptpath --configure --server=$server ";
	if ($hostname) {
		$cmd .= "--vihost $hostname ";
	}
	if ($usevds) {
		$cmd .= "--vds ";
	}
	$cmd .= "--vswitch=$vswitchname ";
	$cmd .= "--mtu=$mtu --nics=" . join(',', @nics) . " --ips=" . join(',', @ips) . " ";
	$cmd .= "--netmask=$netmask --vmkernel=$vmkernel ";
	if (lc($hwsw) eq 'sw') {
		$cmd .= "--nohwiscsi ";
	}
	if ($enableswiscsi) {
		$cmd .= "--enableswiscsi ";
	}
	if ($groupip) {
		$cmd .= "--groupip=$groupip ";
	}

	print "\nThe following command line can be used to perform this configuration:\n$cmd\n";

	if (lc(prompt_user_yesno('Do you wish to proceed with configuration?', 'yes')) eq 'no') {
		print "\n";
		exit;
	}
	
	# Load parameters as CLI options
	Opts::set_option('vswitch', $vswitchname);
	Opts::set_option('vds', $usevds);
	Opts::set_option('mtu', $mtu);
	Opts::set_option('nics', join(',', @nics));
	Opts::set_option('ips', join(',', @ips));
	Opts::set_option('netmask', $netmask);
	Opts::set_option('vmkernel', $vmkernel);
	Opts::set_option('nohwiscsi', lc($hwsw) eq 'sw');
	Opts::set_option('enableswiscsi', $enableswiscsi);
	Opts::set_option('groupip', $groupip);

	# Proceed with configuration
	configure_networking();
}

# Query the user for the answer to a yes/no question.  Keep asking if the user
# does not provide valid input.
sub prompt_user_yesno {
	my ($prompt, $default) = @_;

	for (;;) {
		my $answer = prompt_user($prompt, $default);
		
		if (lc($answer) =~ /^y(es)?$/) {
			return 'yes';
		}
		
		if (lc($answer) =~ /^n(o)?$/) {
			return 'no';
		}

		# The answer is not valid
		print "The answer must be 'yes' or 'no'\n";
    }
}

# Query the user for a choice among a list of values.  Keep asking if the user
# does not provide valid input.
sub prompt_user_choices {
	my ($prompt, $choices, $default) = @_;

	my $choicestring = join('/', @$choices);
	
	if ($choicestring ne '') {
		$prompt = $prompt . " ($choicestring)";
	}

	for (;;) {
		my $answer = prompt_user($prompt, $default);
		
		foreach my $choice (@$choices) {
			my $lcchoice = lc($choice);
			if (lc($answer) =~ /^$lcchoice$/) {
				return lc($answer);
			}
		}

		# The answer is not valid
		print "The answer must be one of $choicestring.\n";
    }
}

# Query the user for choices among a list of values.  The user may choose one
# or more values on the list.
sub prompt_user_multichoice {
	my ($prompt, $choices, $defaults) = @_;

	my $choicestring = join('/', @$choices);
	my $defaultstring = join(' ', @$defaults);

	for (;;) {
		my $answers = prompt_user($prompt, $defaultstring);

		# Split the answer on typical delimiters
		my @answerlist = split(/[ ,.\n\t:;]+/, $answers);
		my $allvalid = 1;

		foreach my $answer (@answerlist) {
			my $valid = 0;

			foreach my $choice (@$choices) {
				my $lcchoice = lc($choice);
				if (lc($answer) =~ /^$lcchoice$/) {
					# This answer is ok, proceed to the next on the list
					$valid = 1;
					last;
				}
			}

			# If no match for this answer, bail out.
			if (!$valid) {
				$allvalid = 0;
				last;
			}
		}

		# The answers are all valid
		if ($allvalid && (scalar(@answerlist)) > 0) {
			return @answerlist;
		}

		print "The answers must be from $choicestring.\n";
    }
}

# Query the user for an IPv4 address.  Do some basic checking of the string
# to make sure it is of the correct format.
sub prompt_user_ip_optional {
	my ($prompt, $default) = @_;

	for (;;) {
		my $answer = prompt_user($prompt, $default);

		my $valid = 1;
		# Check basic syntax
		if (!defined($answer) || ($answer eq '')) {
			# Allow empty IP address
			$valid = 1;
		}
		elsif ($answer !~ /^([\d]+)\.([\d]+)\.([\d]+)\.([\d]+)$/) {
			$valid = 0;
		}
		else {
			# Check that each octet is 0 <= x <= 255
			foreach my $s (($1, $2, $3, $4)) {
				if ($s < 0 || $s > 255) {
					$valid = 0;
					last;
				}
			}
		}

		if ($valid) {
			return $answer;
		}
		
		print "A valid IPv4 address must be specified in the form x.x.x.x.\n";
    }
}

# Query the user for an IPv4 address.  Do some basic checking of the string
# to make sure it is of the correct format.
sub prompt_user_ip {
	my ($prompt, $default) = @_;

	for (;;) {
		my $answer = prompt_user_ip_optional($prompt, $default);

		# If the IP address was provided it was validated.
		# Disallow empty IP addresses.
		if (!defined($answer) || ($answer eq '')) {
			print "A valid IPv4 address must be specified in the form x.x.x.x.\n";
		}
		else {
			return $answer;
		}
    }
}

# Query the user for a string.
sub prompt_user_string {
	my ($prompt, $default) = @_;

	for (;;) {
		my $answer = prompt_user($prompt, $default);

		# No error checking on this prompt.
		return $answer;
    }
}

# Query the user for input.  Returns the user provided input or default.
sub prompt_user {
	my ($prompt, $default) = @_;
	my $def_prompt = $default eq '' ? '' : ' [' . $default . ']';
	
	print "\n$prompt$def_prompt: ";

    my  $reply = <STDIN>;
	$reply = '' unless defined($reply);
	chomp($reply);

	if (!defined($reply) || ($reply eq '')) {
		$reply = $default;
	}

	return $reply;
}

sub find_vswitch {
    my ($vswitchname) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    
    my $vswitchlist = $network_system->networkInfo->vswitch;
    foreach my $vswitch (@$vswitchlist) {
        if ($vswitch->name eq $vswitchname) {
            return $vswitch;
        }
    }

    # Return undefined if we could not find the vswitch.
    return;
}

sub find_all_vswitches {
	my @names;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    
    my $vswitchlist = $network_system->networkInfo->vswitch;
    foreach my $vswitch (@$vswitchlist) {
		push(@names, $vswitch->name);
    }

	# Return list of vswitch names
    return @names;
}

sub find_vdswitch {

    my ($vdswitchname) = @_;
    my $vds_view = Vim::find_entity_view(view_type => 'DistributedVirtualSwitch',
                                         filter => { 'name' => $vdswitchname } );

    # Return undefined if we could not find the vdswitch.
    return $vds_view;
}

sub find_all_vds {

	my @names;
    my $vds_view = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch');

	foreach my $vds (@$vds_view) {
		push(@names, $vds->name);
	}

    # Return list of dvs names
    return @names;
}

sub create_vdswitch {
    my ($vswitchname, $mtu) = @_;

    logmsg "Creating vDS $vswitchname.\n";

    my $datacenter_view = Vim::find_entity_view(view_type => 'Datacenter');
    my $network_folder = Vim::get_view(mo_ref => $datacenter_view->networkFolder);

    my $config = new VMwareDVSConfigSpec( name => $vswitchname,
                                          maxMtu => $mtu);
    my $spec = new DVSCreateSpec( configSpec => $config );

    eval { $network_folder->CreateDVS( spec => $spec ); };

    if ($@) {
        logfatal($@->fault_string);
    }

    return;
}

sub create_vswitch {
    my ($vswitchname) = @_;

    logmsg "Creating vSwitch $vswitchname.\n";
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    eval {$network_system->AddVirtualSwitch ('vswitchName' => $vswitchname);};
    if ($@) {
        logfatal($@->fault_string);
    }
    
    # Look up the vswitch object we just created
    my $vswitch = find_vswitch($vswitchname);
    
    if (!$vswitch) {
        logfatal("Failure creating new vSwitch.");
    }

    return $vswitch;
}

sub remove_vswitch {
    my ($vswitchname) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    
    logmsg "Removing vSwitch $vswitchname.\n";
    eval {$network_system->RemoveVirtualSwitch ('vswitchName' => $vswitchname);};
    if ($@) {
        logfatal($@->fault_string);
    }
}    

# This routine handles both standard and distributed switches.
sub get_switch_mtu {
    my ($vds, $vswitch) = @_;
    
    if (!$vds) {
        return $vswitch->{spec}->{mtu};
    }
    else {
        return $vswitch->{config}->{maxMtu};
    }
}

# This routine handles both standard and distributed switches.
sub set_switch_mtu {
    my ($vds, $vswitch, $mtu) = @_;

    if (!$vds) {
        logmsg "Setting vSwitch MTU to $mtu.\n";
        # Reload the networking information to pick up any configuration change.
        my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
        $vswitch->{spec}->{mtu} = $mtu;
        eval {
            $network_system->UpdateVirtualSwitch(vswitchName => $vswitch->name, spec => $vswitch->spec);
        };
        if ($@) {
            logfatal($@->fault_string);
        }
    }
    else {
        logfatal("The vDS is not using the specified MTU ($mtu).  If you wish to change the MTU, you must do this with the vCenter client.");
    }

    return;
}    

sub find_portgroup {
    my ($portgroupname) = @_;
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    my $portgrouplist = $network_system->networkInfo->portgroup;
    foreach my $portgroup (@$portgrouplist) {
        if ($portgroup->spec->name eq $portgroupname) {
            return $portgroup;
        }
    }

    # Return undefined if we could not find the port group.
    return;
}

sub find_portgroup_by_key {
    my ($portgroupkey) = @_;
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    foreach my $portgroup (@{ $network_system->networkInfo->portgroup }) {
        if ($portgroup->key eq $portgroupkey) {
            return $portgroup;
        }
    }

    # Return undefined if we could not find the port group.
    return;
}

sub find_vmknic_by_portgroup {
    my ($portgroupname) = @_;
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    my $vmkniclist = $network_system->networkInfo->vnic;
    foreach my $vmknic (@$vmkniclist) {
        if ($vmknic->portgroup eq $portgroupname) {
            return $vmknic;
        }
    }

    # Return undefined if we could not find the port group.
    return;
}

sub find_vmknic_by_vds_portgroup {
    my ($portkey, $portgroupkey) = @_;
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    my $vmkniclist = $network_system->networkInfo->vnic;
    foreach my $vmknic (@$vmkniclist) {
        if ($vmknic->spec->distributedVirtualPort &&
            $vmknic->spec->distributedVirtualPort->portKey eq $portkey &&
            $vmknic->spec->distributedVirtualPort->portgroupKey eq $portgroupkey)
        {
            return $vmknic;
        }
    }

    # Return undefined if we could not find the port group.
    return;
}

sub find_vmknic_by_ip {
    my ($ip) = @_;
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    my $vmkniclist = $network_system->networkInfo->vnic;
    foreach my $vmknic (@$vmkniclist) {
        if ($vmknic->spec->ip->ipAddress eq $ip) {
            return $vmknic;
        }
    }

    # Return undefined if we could not find a vmknic with the IP.
    return;
}

sub create_vmknic {
    my ($ip, $netmask, $mtu, $portgroupname) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    # Assign the IP address to the new Portgroup
    logmsg "Assigning IP address $ip to $portgroupname.\n";
    
    my $ip_config = new HostIpConfig(dhcp => 0,
                                     ipAddress => $ip,
                                     subnetMask => $netmask);
    my $vnic_spec = new HostVirtualNicSpec(ip => $ip_config,
                                           mtu => $mtu);
    eval { $network_system->AddVirtualNic(portgroup => $portgroupname,
                                          nic => $vnic_spec); };
    if ($@) {
        logfatal($@->fault_string);
    }
}

sub create_portgroup {
    my ($portgroupname, $vswitchname, $vlan) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    logmsg "Creating portgroup $portgroupname on vSwitch $vswitchname.\n";

    # Create Portgroup using default network policy and the specified VLAN ID.
    my $policy = new HostNetworkPolicy();
    
    my $spec = new HostPortGroupSpec (name => $portgroupname,
                                      vlanId => $vlan,
                                      policy => $policy,
                                      vswitchName => $vswitchname);
    eval {$network_system->AddPortGroup ( portgrp => $spec); };
    if ($@) {
        logfatal($@->fault_string);
    }
}

sub remove_portgroup {
    my ($portgroupname) = @_;
    
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    logmsg "Removing portgroup $portgroupname.\n";
    
    eval {$network_system->RemovePortGroup ( pgName => $portgroupname ); };
    if ($@) {
        logfatal($@->fault_string);
    }
}    

sub create_vds_vmknic {
    my ($ip, $netmask, $mtu, $dvpg, $dvport, $dvswitch) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    # Assign the IP address to the new Portgroup
    logmsg "Creating vmknic with IP address $ip.\n";

    my $ip_config = new HostIpConfig(dhcp => 0,
                                     ipAddress => $ip,
                                     subnetMask => $netmask);
    my $dvp_config = new DistributedVirtualSwitchPortConnection( portgroupKey => $dvpg->key,
                                                                 switchUuid => $dvswitch->uuid );
    my $vnic_spec = new HostVirtualNicSpec(ip => $ip_config,
                                           mtu => $mtu,
                                           distributedVirtualPort => $dvp_config);

    eval { $network_system->AddVirtualNic( portgroup => "",
                                           nic => $vnic_spec); };
    if ($@) {
        logfatal($@->fault_string);
    }
}

sub find_vmhbas {
    my ($swiscsionly) = @_;
    # Reload the storage system information to pick up any configuration change.
    my $storage_system = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);
	$storage_system->RefreshStorageSystem();
    
    my @vmhbalist;
    my $hbalist = $storage_system->storageDeviceInfo->hostBusAdapter;
    foreach my $vmhba (@$hbalist) {

        # Check to see if this is an iSCSI HBA
        if (ref($vmhba) eq "HostInternetScsiHba")
        {
            if ($vmhba->driver eq "iscsi_vmk") {
                # This is the VMware SW iSCSI initiator.  Add it to the end of the list.
                push(@vmhbalist, $vmhba);
            }
            elsif (!$swiscsionly && ($vmhba->isSoftwareBased)) {
                # This is a HW iSCSI initiator which uses host networking.  Add it to the front of the list.
                unshift(@vmhbalist, $vmhba);
            }
        }
    }

    return @vmhbalist;
}

# Return 1 if the vmknic is available to the hba
sub is_hba_vmknic {
    my ($vmknicname, $vmhbaname) = @_;
    
    my $result;
    eval { $result = `$esxcli_cmd $server_args swiscsi vmknic list --adapter $vmhbaname $suppress`; };

    # See whether the list of vmknics for this hba includes the nic in question.
    if ($@) {
        # esxcli reports no vmknics
        return 0;
    }
    elsif ($result =~ m{$vmknicname}) {
        return 1;
    }
    else {
        return 0;
    }
}

# Return 1 if the vmknic is bound to the hba
sub is_hba_bound_vmknic {
    my ($vmknicname, $vmhbaname) = @_;
    
    my $result;
    eval { $result = `$esxcli_cmd $server_args swiscsi nic list --adapter $vmhbaname $suppress`; };

    # See whether the list of vmknics for this hba includes the nic in question.
    if ($@) {
        # esxcli reports no bound nics
        return 0;
    }
    elsif ($result =~ m{$vmknicname}) {
        return 1;
    }
    else {
        return 0;
    }
}

sub enable_swiscsi {
    # Reload the storage system information to pick up any configuration change.
    my $storage_system = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);
	$storage_system->RefreshStorageSystem();

    if ($storage_system->storageDeviceInfo->softwareInternetScsiEnabled) {
		logfatal("Software iSCSI is already reported as enabled, but the corresponding hba is not properly reported.\nReboot the ESX server to correct this configuration.");
    }
    else {
        $storage_system->UpdateSoftwareInternetScsiEnabled(enabled => 1);

        if ($@) {
            logfatal("Operation failed : " . $@->fault_string);
        }
    }
}

sub print_bound_vmknics {
    
    # Get a list of all iscsi hbas
    my @vmhbalist = find_vmhbas(0);
    if (!@vmhbalist) {
        print("No supported iSCSI adapters found.\n");
        return;
    }

    # Build a list of all bound vmknics
    my @boundvmknics;
    foreach my $vmhba (@vmhbalist) {
        my $vmhbaname = $vmhba->device;
        my $niclist;
        eval { $niclist = `$esxcli_cmd $server_args swiscsi nic list --adapter $vmhbaname $suppress`; };
        if (!$niclist) {
            VIExt::fail("Error retrieving bound vmknics for $vmhbaname.");
        }
        
        # Just read out the vmknic name
        my @lines = split("\n", $niclist);
        
        foreach my $line (@lines) {
            if ($line =~ m{^(vmk\w+)}) {
                push (@boundvmknics, $1);
            }
        }
    }

    if (!@boundvmknics) {
        print "No VMkernel ports bound for use by iSCSI multipathing.\n";
    }
    else {
        print "Found the following VMkernel ports bound for use by iSCSI multipathing: ";
        foreach my $vmknic (@boundvmknics) {
            print "$vmknic ";
        }
        print "\n";
    }
}

sub find_vds_host() {
    my ($hostname, $vswitch) = @_;
    
    if ($vswitch->config->host) {
        foreach(@{$vswitch->config->host}) {
            my $vds_host = Vim::get_view(mo_ref => $_->config->host);
            if ($vds_host->{'name'} eq $hostname) {
                return $_;
            }
        }
    }

    # Not found
    return;
}

sub add_vds_host() {
    my ($hostname, $vdswitch) = @_;

    logmsg "Adding host $hostname to the vDS " . $vdswitch->summary->name . ".\n";

    my $hostspec = new DistributedVirtualSwitchHostMemberConfigSpec( operation => 'add',
                                                                     host => $host_view);

    my $dvsspec = new DVSConfigSpec( configVersion => $vdswitch->config->configVersion,
                                     host => [ $hostspec ] );
    
    eval { $vdswitch->ReconfigureDvs( spec => $dvsspec ); };
    if ($@) {
        logfatal($@->fault_string);
    }

    return;
}

sub find_vds_pnic() {
    my ($pnics, $pnicname) = @_;

    foreach (@$pnics) {
        if ($_->pnicDevice eq $pnicname) {
            return $_;
        }
    }

    # Not found
    return;
}

sub add_vds_pnic() {
    my ($vdswitch, $vds_host, $pnicname) = @_;

    logmsg "Adding nic $pnicname to the vDS " . $vdswitch->summary->name . " uplink portgroup.\n";
    
    my $hostbacking = $vds_host->config->backing;
    
    my $pnicspec = new DistributedVirtualSwitchHostMemberPnicSpec( pnicDevice => $pnicname );
    if (defined($hostbacking->pnicSpec)) {
        push(@{$hostbacking->pnicSpec}, $pnicspec);
    }
    else {
        $hostbacking->{pnicSpec} = [ $pnicspec ];
    }

    my $hostspec = new DistributedVirtualSwitchHostMemberConfigSpec( operation => 'edit',
                                                                     host => $host_view,
                                                                     backing => $hostbacking);

    my $dvsspec = new DVSConfigSpec( configVersion => $vdswitch->config->configVersion,
                                     host => [ $hostspec ] );
    
    eval { $vdswitch->ReconfigureDvs( spec => $dvsspec ); };
    if ($@) {
        logfatal($@->fault_string);
    }

    return;
}

sub find_vds_uplink_dvport() {
    my ($pnic, $dvswitch) = @_;

    # Fetch all DV ports and look for the key of the uplink port
    my $criteria = new DistributedVirtualSwitchPortCriteria( uplinkPort => 1,
                                                             portgroupKey => [ $pnic->uplinkPortgroupKey ],
                                                             portKey => [ $pnic->uplinkPortKey ]);
    
    my $dvports = $dvswitch->FetchDVPorts( criteria => $criteria );
    foreach(@$dvports) {
        return $_;
    }
    
    # Not found
    return;
}

sub find_dvportgroup() {
    my ($dvpgname) = @_;

	my $dvswitches = Vim::find_entity_views(
		view_type => 'DistributedVirtualSwitch');

	foreach my $dvswitch (@$dvswitches)
	{
		if ($dvswitch->portgroup) {
			foreach (@{ $dvswitch->portgroup }) {
				my $dvpg = Vim::get_view(mo_ref => $_);
				
				if ($dvpg->summary->name eq $dvpgname) {
					return $dvpg;
				}
			}
        }
    }

    # Not found
    return;
}

sub find_dvportgroup_with_uplink() {
    my ($dvuplinkport, $dvswitch) = @_;
    
    foreach (@{ $dvswitch->portgroup }) {
        my $dvpg = Vim::get_view(mo_ref => $_);
        
        my $portconfig = $dvpg->config->defaultPortConfig->uplinkTeamingPolicy->uplinkPortOrder;
        
        # See whether there are too many active and standby ports.
        if (!defined($portconfig->activeUplinkPort)) {
            # Ignore portgroup with no uplinks
            next;
        }
        
        if ($portconfig->activeUplinkPort) {
            if (scalar @{ $portconfig->activeUplinkPort } != 1) {
                print "DVPortgroup " . $dvpg->name . " has too many active uplink ports, ignoring.\n";
                next;
            }
        }
        if ($portconfig->standbyUplinkPort) {
            if (scalar @{ $portconfig->standbyUplinkPort } != 0) {
                print "DVPortgroup " . $dvpg->name . " has too many standby uplink ports, ignoring.\n";
                next;
            }
        }
        
        # If we got here there is exactly 1 active uplink port and 0 standby uplink ports
        if (  @{ $portconfig->activeUplinkPort }[0] eq $dvuplinkport->config->name) {
            return $dvpg;
        }
        else {
            # Keep looking
            next;
        }
    }

    # Not found
    return;
}

sub create_dvportgroup_with_uplink() {
    my ($uplinkport, $vdswitch, $dvpgname) = @_;

    logmsg "Creating DV PortGroup $dvpgname.\n";

    my $uplinkorder = new VMwareUplinkPortOrderPolicy( activeUplinkPort => [ $uplinkport->config->name ],
                                                       inherited => 'false');
    my $teamingpolicy = new VmwareUplinkPortTeamingPolicy( uplinkPortOrder => $uplinkorder,
                                                           inherited => 'false');
    my $pgconfig = new VMwareDVSPortSetting( uplinkTeamingPolicy => $teamingpolicy);
    my $pgspec = new DVPortgroupConfigSpec( name => $dvpgname,
                                            type => 'earlyBinding',
                                            numPorts => 128,
                                            defaultPortConfig => $pgconfig );

    eval { $vdswitch->AddDVPortgroup( spec => [ $pgspec ] ); };
    if ($@) {
        logfatal($@->fault_string);
    }

    return;
}

sub find_dvport_with_ip() {
    my ($dvswitch, $dvpg, $ip) = @_;

    # Enumerate the DVPorts in this portgroup
    my $criteria = new DistributedVirtualSwitchPortCriteria( uplinkPort => 0 ,
                                                             portgroupKey => [ $dvpg->key ]);
    my $dvports = $dvswitch->FetchDVPorts( criteria => $criteria );
    foreach(@$dvports) {
        
        if (!$_->connectee) {
            # Unused DVPort
            next;
        }
        
        my $vmknic = find_vmknic_by_vds_portgroup($_->key, $dvpg->key);
        if (!$vmknic) {
            # vmknic is not using this uplink dvport.
            next;
        }
        
        if ($vmknic->spec->ip->ipAddress eq $ip) {
            return $_;
        }
    }

    # None found
    return;
}

sub find_unused_dvport() {
    my ($dvswitch, $dvpg) = @_;

    # Enumerate the DVPorts in this portgroup
    my $criteria = new DistributedVirtualSwitchPortCriteria( uplinkPort => 0 ,
                                                             portgroupKey => [ $dvpg->key ]);
    my $dvports = $dvswitch->FetchDVPorts( criteria => $criteria );

    foreach(@$dvports) {
        if (!$_->connectee) {
            return $_;
        }
    }

    # None found
    return;
}

sub validate_ips() {
    my ($vswitchname, @ips) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
    my $storage_system = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);

    my %seen = ();

    foreach my $ip (@ips) {

        # Test for duplicate input
        if ($seen{$ip}++) {
            logmsg "IP $ip was provided multiple times.\n";
            return 0;
        }

        # Test against IPs on service consoles
        my $servicevniclist = $network_system->networkConfig->consoleVnic;
        foreach my $servicevnic (@$servicevniclist) {
            if ($ip eq $servicevnic->spec->ip->ipAddress) {
                logmsg "IP $ip is in use by a service console.\n";
                return 0;
            }
        }
        
        # Test against IPs on existing vmkernel ports on OTHER vswitches
        my $vniclist = $network_system->networkConfig->vnic;
        foreach my $vnic (@$vniclist) {
            if ($ip eq $vnic->spec->ip->ipAddress) {
                if ($vnic->spec->portgroup) {
                    # vnic is on a standard switch
                    my $portgroup = find_portgroup($vnic->spec->portgroup);
                    if ($portgroup && ($portgroup->spec->vswitchName ne $vswitchname)) {
                        logmsg "IP $ip is in use by an existing VMkernel port.\n";
                        return 0;
                    }
                }
                elsif ($vnic->spec->distributedVirtualPort) {
                    #vnic is on a dvs, see if it is our dvs
                    my $dvswitch = find_vdswitch($vswitchname);
                    
                    if (!$dvswitch || ($dvswitch->uuid ne $vnic->spec->distributedVirtualPort->switchUuid)) {
                        logmsg "IP $ip is in use by an existing dvPort.\n";
                        return 0;
                    }
                }
            }
        }

		# Test against IPs configured on other independent HBAs
		my $hbalist = $storage_system->storageDeviceInfo->hostBusAdapter;
		foreach my $hba (@$hbalist) {
			
			# Check to see if this is an iSCSI HBA
			if (ref($hba) eq "HostInternetScsiHba")
			{
				if ($hba->{ipProperties}->{address}) {
					if ($hba->ipProperties->address eq $ip) {
						logmsg "IP $ip is in use by another HBA.\n";
						return 0;
					}
				}
			}
		}
    }
    
    # IPs are ok
    return 1;
}

sub validate_nics() {
    my ($vswitchname, @nics) = @_;

    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

    my %seen = ();

    foreach my $nic (@nics) {

        # Test for duplicate input
        if ($seen{$nic}++) {
            logmsg "Nic $nic was provided multiple times.\n";
            return 0;
        }

        # Make sure nic exists
        my $found = 0;
        my $pniclist = $network_system->networkConfig->pnic;
        foreach my $pnic (@$pniclist) {
            if ($pnic->device eq $nic) {
                # Found it
                $found = 1;
                last;
            }
        }

        if (!$found) {
            logmsg "NIC $nic does not exist.\n";
            return 0;
        }

        # Make sure nic is not assigned to another vswitch
        my $vswitchlist = $network_system->networkInfo->vswitch;
        foreach my $vswitch (@$vswitchlist) {
            if ($vswitch->name eq $vswitchname) {
                next;
            }

            if ($vswitch->spec && $vswitch->spec->bridge) {
                my $uplinklist = $vswitch->spec->bridge->nicDevice;
                foreach my $uplink (@$uplinklist) {
                    if ($uplink eq $nic) {
                        my $currentvswitchname = $vswitch->name;
                        logmsg "NIC $nic is already assigned to vswitch $currentvswitchname.\n";
                        return 0;
                    }
                }
            }
        }

        # Make sure nic is not assigned to another vDSwitch
        if ($network_system->networkInfo->proxySwitch) {
            foreach my $vds (@{ $network_system->networkInfo->proxySwitch }) {
                if ($vds->dvsName eq $vswitchname) {
                    next;
                }
                
                if ($vds->spec && $vds->spec->backing && $vds->spec->backing->pnicSpec) {
                    foreach (@{ $vds->spec->backing->pnicSpec }) {
                        if ($_->pnicDevice eq $nic) {
                            logmsg "NIC $nic is already assigned to vDS " . $vds->dvsName. ".\n";
                            return 0;
                        }
                    }
                }
            }
        }
    }
    
    # Nics are ok
    return 1;
}

sub find_all_nics() {
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

	# Iterate over all pnics in the server
	my $pniclist = $network_system->networkConfig->pnic;
	my @niclist;

	foreach my $pnic (@$pniclist) {
		push(@niclist, $pnic->device);
	}

	return @niclist;
}

sub find_unused_nics() {
    # Reload the networking information to pick up any configuration change.
    my $network_system = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

	# Iterate over all pnics in the server
	my $pniclist = $network_system->networkConfig->pnic;
	my @unusedlist;

	foreach my $pnic (@$pniclist) {

		my $used = 0;
		my $nic = $pnic->device;

        # See if nic is already assigned to a vswitch
        my $vswitchlist = $network_system->networkInfo->vswitch;
        foreach my $vswitch (@$vswitchlist) {
			if ($used) { last; }
            if ($vswitch->spec && $vswitch->spec->bridge) {
                my $uplinklist = $vswitch->spec->bridge->nicDevice;
                foreach my $uplink (@$uplinklist) {
					if ($used) { last; }
                    if ($uplink eq $nic) {
						$used = 1;
                    }
                }
            }
        }

        # Make sure nic is not assigned to another vDSwitch
        if ($network_system->networkInfo->proxySwitch) {
            foreach my $vds (@{ $network_system->networkInfo->proxySwitch }) {
				if ($used) { last; }
                if ($vds->spec && $vds->spec->backing && $vds->spec->backing->pnicSpec) {
                    foreach (@{ $vds->spec->backing->pnicSpec }) {
						if ($used) { last; }
                        if ($_->pnicDevice eq $nic) {
							$used = 1;
                        }
                    }
                }
            }
        }

		if (!$used) {
			push(@unusedlist, $nic);
		}
    }
    
    return @unusedlist;
}

sub fastpass_login{
    my ($targetname) = @_;

    if ($vma_available) {
        # Close any open fastpass session
        if ($vma_target) {
            eval { $vma_target->logout(); };
            if ($@) {
                VIExt::fail("Unable to close existing fastpass session: " . $@);
            }
        }

        my @targets = VmaTargetLib::enumerate_targets();

        foreach my $target (@targets) {
            if ($target->name() eq $targetname) {
                eval { $target->login(); };
                if ($@) {
                    VIExt::fail("Cannot authenticate to $targetname using fastpass.  Verify that the host is running and reachable from this vMA.\nFailure message: " . $@);
                }

                $vma_target = $target;
                return;
            }
        }

        print "Use of the vMA fastpass is recommended, see the 'vifp' command for more information.\n";
        $vma_target = 0;
    }
    else {
        VIExt::fail("fastpass library is not available.");
    }
}

# Define a local version of eql_create_objects to allow for special handling for DELL CIM objects.
sub eql_create_objects{
    my(@hashes) = @_;
    if(!@hashes){
	return ();
    }
    my @objects;
    
    foreach my $ref (@hashes){
        my $string = (keys %{$ref})[0];
	my $lower_case = lc($string);
        # Only build objects for DELL EQL services.
        if($lower_case =~ m/dell_eqlhostconnectionmanager/i) {
            push @objects, (keys %{$ref})[0]->new(%{$ref->{(keys %{$ref})[0]}},
                                                  epr_name => (keys %{$ref})[0]);
        }
    }
    
    return @objects;
}


__END__
