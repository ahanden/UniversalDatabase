#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;

sub main {
    my $usage = "Usage: perl homologene.pl [homologene.data]";
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
        if(GetOptions('verbose' => \$verbose)  && @ARGV == 1) {
            $self->{fname} = $ARGV[0];
            $self->{verbose} = $verbose;
            return 1;
        }
        return 0;
    }


    sub exec_main {
        my $self = shift;

        # Read the homology file (found at ftp://ftp.ncbi.nih.gov/pub/HomoloGene/current/homologene.data)
        #
        #homologene.data is a tab delimited file containing the following
        #columns:
        
        #1) HID (HomoloGene group id)
        #2) Taxonomy ID
        #3) Gene ID
        #4) Gene Symbol
        #5) Protein gi
        #6) Protein accession
        $self->log("Reading file...\n");
        open(IN,"<$self->{fname}") or die "Failed to open homology file $self->{fname}: $!\n";
        my %hom_map;
        while(<IN>) {
            chomp;
            my($hid,$tax_id,$gene_id,$gene_symbol,$p_gi,$p_ac) = split(/\t/,$_);
            if(!exists($hom_map{$hid})) {
                $hom_map{$hid} = [];
            }
            push(@{$hom_map{$hid}},$gene_id);
        }
        close IN;

        # Insert all the data we found
        $self->log("Inserting data...\n");
        my $sth = $self->{dbh}->prepare("INSERT IGNORE INTO homologs (h_group, entrez_id) VALUES (?, ?)");
        while ( my ($hid, $eids) = each %hom_map ) {
            foreach my $eid(@$eids) {
                $sth->execute($hid,$eid);
            }
        }

        $self->log("Cleaning up bad Entrez IDs...\n");
        # Deal with bad Entrez IDs (seems no NCBI database is perfectly consistent)
        my $discontinued_query = <<EOF;
        SELECT entrez_id, missing.eid
        FROM discontinued_genes
        JOIN (
            SELECT DISTINCT homologs.entrez_id AS eid
            FROM homologs
            LEFT JOIN genes
            ON homologs.entrez_id = genes.entrez_id
            WHERE genes.entrez_id IS NULL
        ) AS missing
        ON discontinued_genes.discontinued_id = missing.eid;
EOF
        $sth = $self->{dbh}->prepare($discontinued_query);
        $sth->execute();
        my $update_query = $self->{dbh}->prepare("UPDATE IGNORE homologs SET entrez_id = ? WHERE entrez_id = ?");
        while(my $row = $sth->fetch()) {
            $update_query->execute($row->[0],$row->[1]);
        }

        my $missing_query = <<EOF;
        SELECT homologs.entrez_id
        FROM homologs
        LEFT JOIN genes
        ON homologs.entrez_id = genes.entrez_id
        WHERE genes.entrez_id IS NULL;
EOF
        $sth = $self->{dbh}->prepare($missing_query);
        $sth->execute();
        my $delete_query = $self->{dbh}->prepare("DELETE FROM homologs WHERE entrez_id = ?");
        while(my $row = $sth->fetch()) {
            $delete_query->execute($row->[0]);
        }
    }
}


main();
