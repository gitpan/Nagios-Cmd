###########################################################################
#                                                                         #
# Nagios::Cmd::Read                                                       #
# Written by Albert Tobey <albert.tobey@priority-health.com>              #
# Copyright 2003, Albert P Tobey                                          #
#                                                                         #
# This program is free software; you can redistribute it and/or modify it #
# under the terms of the GNU General Public License as published by the   #
# Free Software Foundation; either version 2, or (at your option) any     #
# later version.                                                          #
#                                                                         #
# This program is distributed in the hope that it will be useful, but     #
# WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       #
# General Public License for more details.                                #
#                                                                         #
###########################################################################
package Nagios::Cmd::Read;
use vars qw( @ISA );
use Fcntl qw(:flock SEEK_SET);
use Carp;
use IO::File;
require Exporter;
@ISA   = qw( Exporter Nagios::Cmd );
$debug = undef;

sub new {
    my( $type, $cmdfile ) = @_;

    croak "$cmdfile does not exist!"
        unless ( -e $cmdfile );
    croak "$cmdfile is not a pipe and debugging is not enabled!"
        unless ( -p $cmdfile || defined($debug) );

    my $fh = new IO::File;
    sysopen( $fh, $cmdfile, O_RDONLY|O_NONBLOCK|O_EXCL )
        || croak "could not sysopen $cmdfile for reading: $!";

    my $self = [ $cmdfile, $fh ];
    return( bless($self, $type) );
}

sub readcmd {
    my $self = shift;
    flock( $self->[1], LOCK_EX );
    $self->[1]->sysseek( 0, SEEK_SET );
    my $rv = $self->[1]->getline();
    flock( $self->[1], LOCK_UN );
    return $rv;
}

sub DESTROY {
    print "closing command file ...\n" if ( $debug );
    $_[0]->[1]->close();
}

1;

__END__

=head1 NAME

Nagios::Cmd::Read

=head1 DESCRIPTION

This module is mostly for testing Nagios::Cmd programs and the module itself.  It makes it
trivial to set up a consumer of Nagios commands.

Example:

 > mkfifo -m 600 /var/tmp/my_test_fifo
 > perl -I./lib -MNagios::Cmd::Read <<EOF
 > my \$reader = Nagios::Cmd::Read->new( "/var/tmp/my_test_fifo" );
 > while (1) { print \$reader->readcmd() }
 > EOF

 ... a test to see if it's working before blaming your Nagios::Cmd script
 > echo "[000000000000] FOO_BAR_COMMAND;yes" >>/var/tmp/my_test_fifo

 > rm -f /var/tmp/my_test_fifo

=head1 LICENSE

GPL

=head1 AUTHOR

Al Tobey <tobeya@tobert.org>

=head1 WARNINGS

See AUTHOR.

=cut

