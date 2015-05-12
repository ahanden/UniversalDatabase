#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $usage = "Usage: perl gene_history.pl [gene_history]";
    my $updater = myUpdate->new(usage => $usage);
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
        if( GetOptions('verbose' => \$verbose) && @ARGV == 1 ) {
            $self->{fname} = $ARGV[0];
            $self->{verbose} = $verbose;
            return 1;
        }
        return 0;
    }

    sub exec_main {
        my $self = shift;
        
        my $sth = $self->{dbh}->prepare("INSERT INTO discontinued_genes (entrez_id, discontinued_id, discontinued_symbol) VALUES (?, ?, ?)");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        open(IN,"<$self->{fname}") or die "Failed to open $self->{fname}: $!\n";
        while (my $line = <IN>) {
            $self->logProgress();
            next if $line =~ m/^#/; # discard comments
            next if $line !~ m/^9606\t/; #ignore non-human genes

            chomp $line;
            my @terms = split(/\t/,$line);

            my $id          = $terms[1] eq "-" ? undef : $terms[1];
            my $dis_id      = $terms[2] eq "-" ? undef : $terms[2];
            my $dis_symbol  = $terms[3] eq "-" ? undef : $terms[3];

            if($id) {
                $sth->execute($id,$dis_id,$dis_symbol);
            }
        }
        close IN;
        $self->log("\nDone\n");
    
    }
}

main();
