#!/usr/bin/perl
use strict;
use warnings;

=head1 Author:

Marcelle Bonterre 9/18/2013

=head2 Purpose:

Parallelize the timeconsuming sas job for examining cpu utilization and determining peak hour per week

=cut
my %running;
my @children;
my @pdbs = (
	'pdb=case',
	'pdb=marhub',
	'pdb=citrix',
	'pdb=dfs',
	'pdb=ebpsprod',
	'pdb=elsevier',
	'pdb=esbprod',
	'pdb=evolve',
	'pdb=fastprod',
	'pdb=isprod',
	'pdb=mlprod',
	'pdb=server',
	'pdb=vmhosts,dstype=vmhost',
	'pdb=winent',
	'pdb=winfab',
	'pdb=winprod',
	'pdb=elsehs',
	'pdb=rocunix,dstype=roc',
	'pdb=roclinux,dstype=roc',
	'pdb=rocwindows,dstype=roc',
	'pdb=dfs,dom=cert',
	'pdb=ebpscert,dom=cert',
	'pdb=elsevier,dom=cert',
	'pdb=esbcert,dom=cert',
	'pdb=fastcert,dom=cert',
	'pdb=marhub,dom=cert',
	'pdb=mlcert,dom=cert',
	'pdb=network,dom=cert',
	'pdb=server,dom=cert',
	'pdb=wincert,dom=cert',
	'pdb=oxford,dstype=vmstat,dom=oxf' );

sub main;
sub get_data;
sub check_forked_processes_finished;
sub merge_all_write_csv;

# run whole script
main;

sub main {
	get_data;
	if(check_forked_processes_finished eq 'true') {
		merge_all_write_csv;
	}
	exit 0;
}

sub get_data {
	foreach my $pdb ( @pdbs ) {
		my $pid = fork;

		if($pid) {
			push @children, $pid;
			$running{$pid} = $pdb;
		} elsif( 0 == $pid) {
			system("sas","get_data.sas","-sysparm $pdb");
			exit 0;
		} else {
			print "$pdb couldn't fork: $!\n";
		}
	}
}


sub check_forked_processes_finished {
	my $child;
	do {
		$child = waitpid(-1,0);
		print "pid: $child name: $running{$child} has exited.\n";
	} while( $child > 0 );
	return 'true';	
}

sub merge_all_write_csv {
	system("sas","merge_all.sas");
}
