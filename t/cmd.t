#!/usr/local/bin/perl -w
use strict;
use Test::More;
use File::Temp qw/ mktemp /;
use lib qw( ../lib );
use vars qw( $fifo %tst );
BEGIN { plan tests => 79 }

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

$fifo = mktemp( "/var/tmp/NagiosCmdTestXXXXXXXX" );
system( "mknod -m 600 $fifo p" );
if ( $? != 0 ) {
    die "could not create testing fifo: $!";
}

eval { # we must always reach the end of the program to unlink the tempfile

    ok( my $reader = Nagios::Cmd::Read->new( $fifo ), "Cmd::Read->new()" );
    ok( !defined($reader->readcmd()), "readcmd() with no data waiting" );

    ok( my $writer = Nagios::Cmd->new( $fifo ), "Cmd->new()" );
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
if ( $@ ) { warn $@ }
unlink( $fifo );
