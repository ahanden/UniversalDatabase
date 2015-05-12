#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

#
# The names.dmp is contained in a tarball.
# The tarball can be found at ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
# To extract the names file, run
#     tar -xvzf taxdump.tar.gz names.dmp
#

sub main {
    my $usage = "Usage: perl tax_names.pl [names.dmp]";
    my $updater = myUpdate->new("usage" => $usage);
    $updater->update();
}

{
    BEGIN {
        unshift(@INC,'/home/adam/UniversalDatabase/');
    }
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        my $verbose = 0;
        if(GetOptions("verbose" => \$verbose) && @ARGV == 1) {
            $self->{verbose} = $verbose;
            $self->{fname} = $ARGV[0];
            return 1;
        }
        return 0;
    }
    
    sub exec_main {
        my $self = shift;
        open(IN,"<$self->{fname}") or die "Failed to open $self->{fname}: $!\n";

        $self->log("Populating database...\n");

        my $sth = $self->{dbh}->prepare("INSERT INTO taxonomies (tax_id, name) VALUES (? ,?)");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;
        
        while (my $line = <IN>) {
            $self->logProgress();
            next if $line =~ m/^#/;
            chomp $line;
            my ($tax_id, $name, $unique, $class) = split(/\t\|\t/,$line);
            $class =~ s/\t\|$//;
            if($class eq "scientific name") {
                $sth->execute($tax_id,$name);
            }
        }
        close IN;
        $self->log("\nDone\n");
    }
}
main();
