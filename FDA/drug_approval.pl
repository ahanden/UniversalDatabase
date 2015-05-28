#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl drug_approval.pl [Product.txt]");
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

        use strict;

        # What each code in the Product.txt file represents
        my %code_map = (
            1 => 'prescription',
            2 => 'OTC',
            3 => 'discontinued',
            4 => 'tentative approval'
        );

        # Priority of each code in our local storage
        my %code_priority = (
            1 => 2,
            2 => 1,
            3 => 4,
            4 => 3,
        );

        open(IN,"<$self->{fname}") or die "$!\n";

        $self->log("Reading drug data from FDA\n");
        my %drug_map;
        <IN>; # skip header
        while(<IN>){
            chomp;
            my @fields = split(/\t/,$_);

            my $drug_name   = uc($fields[7]);
            my $drug_status = int($fields[4]);

            # Assign drug status if none is there for the drug
            if(!exists($drug_map{$drug_name})) {
                $drug_map{$drug_name} = $drug_status;
            }
            # Assign the best status otherwise
            else {
                $drug_map{$drug_name} = $code_priority{$drug_status} < $code_priority{$drug_map{$drug_name}} ? $drug_status : $drug_map{$drug_name};
            }
        }
        close IN;

        $self->log("Querying DrugBank drug list\n");
        my %drugs;
        my $sth = $self->{dbh}->prepare("SELECT name, id FROM drugs");
        $sth->execute();
        while(my $ref = $sth->fetch()){
            $drugs{uc($ref->[0])} = $ref->[1];
        }
        $self->log("Updating database\n");
        $sth = $self->{dbh}->prepare("UPDATE drugs SET status = ? WHERE id = ?");
        foreach my $drug(keys(%drugs)) {
            if(exists($drug_map{$drug})) {
#                print "CHECK: $code_map{$drug_map{$drug}}, $drugs{$drug}\n";
                $sth->execute($code_map{$drug_map{$drug}},$drugs{$drug});
            }
        }
        $self->log("Done\n");
    }
}

main();
