#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl gene_info.pl [gene_info]");
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
        if(GetOptions('verbose' => \$verbose)  && @ARGV == 1) {
            $self->{fname} = $ARGV[0];
            $self->{verbose} = $verbose;
            return 1;
        }
        return 0;
    }
    
    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database. This may take several minutes...\n");

        my $genes_query    = $self->{dbh}->prepare("INSERT INTO genes (entrez_id, symbol, name, tax_id) VALUES (?, ?, ?, ?)");
        my $location_query = $self->{dbh}->prepare("INSERT IGNORE INTO gene_locations (entrez_id, map_location) VALUES (?, ?)");
        my $xref_query     = $self->{dbh}->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id) VALUES (?, ?, ?)");
        my $synonym_query  = $self->{dbh}->prepare("INSERT IGNORE INTO gene_synonyms (entrez_id, symbol) VALUES (?, ?)");

        my $wc_out = `wc -l $self->{fname}`;
        my ($total) = $wc_out =~ /(^\d+)/;
        $self->{prog_total} = $total;
        while (my $line = <$IN>) {
            $self->logProgress();
            $progress++;

            next if $line =~ m/^#/;
            chomp $line;
            my @terms = split(/\t/,$line);

            my $tax         = $terms[0];
            my $id          = $terms[1];
            my @synonyms    = $terms[4] eq "-" ? () : split(/\|/,$terms[4]);
            my @xrefs       = $terms[5] eq "-" ? () : split(/\|/,$terms[5]);
            my @map_locs    = $terms[7] eq "-" ? () : split(/\|/,$terms[7]);
            my $symbol      = $terms[10] eq "-" ? undef : $terms[10];
            my $name        = $terms[11] eq "-" ? undef : $terms[11];
            if($terms[2] ne "-" && ($terms[10] eq "-" || $terms[2] ne $terms[10])) {
                push(@synonyms,$terms[2]);
            }

            $genes_query->execute($id,$symbol,$name,$tax);

            foreach my $location(@map_locs) {
                $location_query->execute($id,$location);
            }

            foreach my $xref(@xrefs) {
                $xref =~ /(.*):(.*)/;
                $xref_query->execute($id,$1,$2);
            }

            foreach my $synonym(@synonyms) {
                $synonym_query->execute($id,$synonym);
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
