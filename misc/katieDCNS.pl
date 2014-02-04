#!/usr/bin/perl

use strict;
use warnings;

=head2 Author:

Marcelle Bonterre

=head3 Purpose:

Purpose here

=cut

sub check_contains;
sub check_ends_with;
sub check_begins_with;
sub main;

my %contains = (
'dev' => 'Dev',
'int' => 'Int',
'prod' => 'Prod',
'prd' => 'Prod',
'cert' => 'Cert',
'crt' => 'Cert',
'test' => 'Test',
'uat' => 'UAT',
'Clup' => 'Prod',
'Clud' => 'Dev',
'Cluc' => 'Cert',
'Clua' => 'Cert',
'clut' => 'Test'
);

my %startsWith = (
'Drp' => 'DR',
'Drlp' => 'DR',
'pnt' => 'Prod',
'Psc' => 'Prod',
'Psdb' => 'Prod',
'Psml' => 'Prod',
'P1ml' => 'Prod',
'P1se' => 'Prod',
'Dvd' => 'Dev',
'dvc' => 'Dev',
'Lab' => 'Lab',
'Tpdb' => 'Test',
'Tpc' => 'Test',
'Tpw' => 'Test',
'tpn' => 'Test',
'Oxp' => 'Prod',
'oxlp' => 'prod',
'Oxc' => 'Cert',
'Oxlc' => 'Cert',
'Oxd' => 'Dev',
'Oxld' => 'Dev',
'Oxt' => 'Test',
'Oxlt' => 'Test',
'Cnt' => 'Cert',
'Cpweb' => 'Cert',
'Cpml' => 'Cert',
'Cpn' => 'Cert',
'Cpdb' => 'Cert',
'Cpc' => 'Cert',
'Cltukp' => 'Prod',
'Clleb' => 'DR',
'Cl' => 'Cert',
'Cp' => 'Cert',
'Dv' => 'Dev',
'Dco' => 'Dev',
'Ps' => 'Prod'
);


my @serverTrialList = qw/ Appdev2 Intd3bapp02b Webspprod1 Asappprd1 Certhome1 Asappcrt1 Cbstest5 cispyuat drprac002b drlpinf001v elsamsclup02p1 elsoxfclud01p2 elsoxfcluc01p2 elsoxfclua01p1 retoxfclut01p2 pntd2bapp109a psc111619 psdb111109 psmlb4406 p1mlw-cr02 dvdb77547 dvc88602 lab77227 tpdb22519 tpc87770 tpweb4401 tpn3005 oxpaps16a oxlpora002 oxcaps39a oxlcrac001a oxdaps24l oxldora004v oxtaps61bl2 oxltaps001v cntd1b0101 cpweb1473 cpml1a662 cpn2003 cpdb111174 cpc111743 cltukpapp6 cllebapb4 elsamsbesp002 elsda2appc001 elsda2appd005 elsoxfappt081 c1sde-ds01 clsdevmnts2 cpc1673 d1mkp-as01 dvwebz7452 dcops4 p1mde-as01 psc11817 t4-01-dc1-ld2 retredbesp010 rehwkgappp001 /;

# call main
main;

sub check_begins_with {
    my ($server) = @_;
    
    
    my $cert = qr/^C\d/i;
    my $dev = qr/^D\d/i;
    my $prod = qr/^P\d/i;
    my $test = qr/^T\d/i;

    my %regexes = (
        'cert' => $cert,
        'dev' => $dev,
        'prod' => $prod,
        'test' => $test
    );
    
    foreach my $key ( keys %startsWith ) {
        if( $server =~ /^$key/i) {
            return $startsWith{$key};
        }
    }
    
    foreach my $regex ( keys %regexes ) {
        if( $server =~ $regexes{$regex} ){
            return $regex;
        }
    }
     
    return "none";
}

sub check_contains {
    my ($server) = @_;
    
    foreach my $key ( keys %contains ) {
        if( $server =~ /$key/i) {
            return $contains{$key};
        }
    }
    
    if( ($server =~ /...red.+?/i) || ($server =~ /...wkg.+?/i)) {
        return "DR";
    }
    
    return "none";
}

sub check_ends_with {
    my ($server) = @_;
    
    my $prod = qr/P\d{3}$/i;
    my $cert = qr/C\d{3}$/i;
    my $dev = qr/D\d{3}$/i;
    my $test = qr/T\d{3}$/i;
    my $cert2 = qr/A\d{3}$/i;

    my %regexes = (
        'prod' => $prod,
        'cert' => $cert,
        'dev' => $dev,
        'test' => $test,
        'cert2' => $cert2
    );

    foreach my $regex ( keys %regexes ) {
        if( $server =~ $regexes{$regex} ){
            return $regex;
        }
    }
    return "none";
}

sub main {
        foreach my $server ( @serverTrialList ) {
            my $doesBeginWith = check_begins_with($server);
            my $doesContian = check_contains($server);
            my $doesEndWith = check_ends_with($server);
            
            print "server: $server doesBeginWith: $doesBeginWith doesContian: $doesContian doesEndWith: $doesEndWith\n";
        }
                
}