#!/usr/local/bin/perl -w
use strict;
use Test::More;
use File::Temp qw/ mktemp /;
use lib qw( ./lib ../lib );
use vars qw( $fifo %tst );
BEGIN { plan tests => 87 }

%tst = (
    host                   => 'localhost',
    persistent             => 0,
    author                 => "Al Tobey",
    comment                => "The sky is falling!",
    comment_id             => 7,
    service                => 'Nagios',
    next_notification_time => time,
    next_check_time        => time,
    time                   => time,
    return_code            => 1,
    plugin_output          => 'OK - foo is bar'
);

$SIG{INT} = $SIG{QUIT} = sub { unlink($fifo) if ( length($fifo) ) };

use_ok( 'Nagios::Cmd' );
use_ok( 'Nagios::Cmd::Read' );

# run a quick test to /dev/null to make sure the AUTOLOAD works
ok( my $devnull = Nagios::Cmd->new_anyfile( '/dev/null' ), "Nagios::Cmd->new_anyfile()" );
ok( $devnull->START_EXECUTING_SVC_CHECKS,
    "submit a command to /dev/null to make sure it works" );
ok( $devnull->service_check('SSH', 'localhost', 0, 'version 1 waiting'),
    "Nagios::Cmd->service_check()" );
ok( $devnull->host_check('localhost', 0, 'Up and Running'),
    "Nagios::Cmd->host_check()" );

# attempt to create a fifo (pipe) with either mknod or mkfifo
# try mkfifo first, since FreeBSD and Darwin don't seem to allow creating
# named pipes with mknod
$fifo = mktemp( "/var/tmp/NagiosCmdTestXXXXXXXX" );
if ( system( "mkfifo -m 600 $fifo" ) ) { system( "mknod -m 600 $fifo p" ); }

SKIP: {
    skip "could not create fifo for testing", 77 unless -p $fifo;

	eval { # we must always reach the end of the program to unlink the tempfile
	
	    ok( my $reader = Nagios::Cmd::Read->new( $fifo ), "Nagios::Cmd::Read->new()" );
	    ok( !defined($reader->readcmd()), "readcmd() with no data waiting" );
	
	    ok( my $writer = Nagios::Cmd->new( $fifo ), "Nagios::Cmd->new()" );
	    ok( $writer->START_EXECUTING_SVC_CHECKS(), "START_EXECUTING_SVC_CHECKS()" );
	    
	    like( $reader->readcmd(), qr/START_EXECUTING_SVC_CHECKS/, "read the command back" );
	
	    { # no waringins in this block so we can cheat and dig into
	      # Nagios::Cmd::commands to automatically generate some tests
	        no warnings;
	        while ( my($cmd,$arglist) = each(%Nagios::Cmd::commands) ) {
	            my @args = ();
	            if ( defined($arglist) ) {
	                @args = @tst{@$arglist}
	            }
	            ok( $writer->$cmd( @args ), "$cmd( ".join(', ',@args)." )" );
	            like( $reader->readcmd(), qr/$cmd/, "read command from previous test" );
	        }
	    }
	
	}; # end of eval

    unlink( $fifo );
} # end of SKIP
if ( $@ ) { warn $@ }

SKIP: {
    skip "cannot write to file", 4 if system( "touch $fifo" );

    diag(" ");
    diag( "Simulate an event storm to a regular file" );
    diag( "by forking 20 child processes, which will submit 10 commands each." );
    diag( "This could take a while, depending on the performance of your fork()." );

    ok( my $cmd = Nagios::Cmd->new_anyfile( $fifo ), "Nagios::Cmd->new_anyfile()" );
    my @pids = ();
    for (1..20) {
        my $pid = fork();
        if ( $pid ) {
            push( @pids, $pid );
            next;
        }
        else {
            for (1..10) {
                $cmd->service_check( 'SSH', 'localhost', 0, 'version 1 waiting' );
            }
            exit 0;
        }
    }
    # wait for all pids to exit before continuing
    foreach ( @pids ) { waitpid( $_, 0 ); }

    open( TMPFILE, "<$fifo" );
    1 while ( <TMPFILE> );
    is( $., 200, "flooding still results in 50 lines of commands" );
    close( TMPFILE );

    unlink( $fifo );
}

exit 0;
