use strict;
use XML::Parser;
use DBI;
use IO::Handle;
use Term::ReadKey;

# Queries
my $get_eid;
my $drug_insert_query;
my $target_insert_query;
my $atc_insert_query;

# Data
my $drugbank_id;
my $drug_name;
my @targets;
my @atcs;

# Progress data
my $total_drugs;
my $progress = 0;
my $location;

# Also, check that I'm using EXISTS in relevant SQL queries in other scripts.
sub main {
    STDOUT->autoflush(1);

    print STDERR "Database: ";
    my $database = <STDIN>;
    chomp $database;
    print STDERR "Username: ";
    my $username = <STDIN>;
    chomp $username;
    print STDERR "Password: ";
    ReadMode('noecho');
    my $password = <STDIN>;
    chomp $password;
    ReadMode('restore');
    print STDERR "\n";

    my $dbh = DBI->connect("dbi:mysql:$database:localhost",$username,$password,
        {RaiseError => 1, AutoCommit => 0}) or die "Connection Error: $DBI::errstr\n";

    my ($fname) = @ARGV;


    parse($dbh, $fname);

    if ($@) {
        print STDERR "Error encountered: rolling back changes.\n";
        $dbh->rollback();
        exit 1;
    }
    else {
        $dbh->commit();
        print "\nDone.\n";
        exit 0;
    }
}

sub char_handler {
    my($expat,$content) = @_;
    chomp $content;
    if($expat->current_line() == 4975921 ) {
        print "$content\n";
    }
    if($expat->in_element("drugbank-id") && $expat->depth() == 3) {
        if($content =~ m/^DB\d+$/){
            $drugbank_id = $content;
        }
        # This condition is because of ridiculous strange formatting in the drugbank XML file that is beyond explanation
        elsif((!defined($drugbank_id) && $content =~ m/^D$/) || $expat->current_line() == $location) {
            $location = $expat->current_line();
            $drugbank_id .= $content;
        }

    }
    elsif($expat->in_element("name") && $expat->depth() == 3){
        $drug_name = $content;
    }
    elsif($expat->in_element("identifier") && $expat->within_element("target") && $content =~ m/HGNC:(\d+)/){
        $get_eid->execute("HGNC:HGNC", $1);
        while(my $ref = $get_eid->fetch()) {
            push(@targets,$ref->[0]);
        }
    }
    elsif($expat->in_element("identifier") && $expat->within_element("target") && $content =~ m/[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}/){
        $get_eid->execute("UniProtKB/Swiss-Prot", $content);
        while(my $ref = $get_eid->fetch()) {
            push(@targets,$ref->[0]);
        }
    }
}
sub end_tag {
    my($expat,$name) = @_;
    if($name eq "drug" && $expat->depth() == 1){
        if(!$drugbank_id){print STDERR "\nLocation: ".$expat->current_line()."\n";}
        if(defined($drugbank_id)) {
            $drug_insert_query->execute($drug_name,$drugbank_id);
            my $local_id = $drug_insert_query->{mysql_insertid};
            foreach my $target(@targets){
                $target_insert_query->execute($target,$local_id);
            }
            foreach my $atc(@atcs){
                $atc_insert_query->execute($local_id,$atc);
            }
        }
        @targets = ();
        @atcs = ();
        $drug_name = undef;
        $drugbank_id = undef;
        $progress++;
        print STDERR "$progress/$total_drugs processed\r";
    }
}
sub start_tag {
    my $expat = shift @_;
    my $name = shift @_;
    if($name eq "atc-code") {
        my %attrs = @_;
        push(@atcs, $attrs{"code"});
    }
}
sub parse {
    my($dbh,$fname) = @_;

    $get_eid = $dbh->prepare("SELECT entrez_id FROM gene_xrefs WHERE Xref_db = ? AND Xref_id = ?");
    $drug_insert_query = $dbh->prepare("INSERT INTO drugs (`name`, `database`, `external_id`) VALUES (?, 'drugbank', ?)");
    $target_insert_query = $dbh->prepare("INSERT IGNORE INTO drug_targets (entrez_id, drug_id) VALUES (?, ?)");
    $atc_insert_query = $dbh->prepare("INSERT INTO atc_codes (drug_id, atc) VALUES(?, ?)");

    $total_drugs = `grep -c "<drug " $fname`;
    chomp $total_drugs;

    my $parser = XML::Parser->new(Style => 'Subs',Handlers => {Char=>\&char_handler,End=>\&end_tag,Start=>\&start_tag});
    $parser->parsefile($fname);
}

main();
