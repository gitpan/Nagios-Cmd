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
@ISA       = qw( Exporter Nagios::Cmd );
$debug = undef;

##
## NOTE: the sys* functions are used to better resemble what Nagios actually does
## and to avoid problems with buffering.  Although seek() is useless when working
## with fifo's, it is necessary when using a regular file.  This is used for doing
## testing and debugging.  The seek() does not cause any problems when used on a
## fifo.
##

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

=head1 NAME

Nagios::Cmd

=head1 DESCRIPTION

=cut

1;
