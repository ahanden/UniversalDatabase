use strict;
use XML::Parser;
use DBI;
use IO::Handle;
use Term::ReadKey;

# Memory elements
my %pathways;
my %reactions;
my %xrefs;
my %complexes;
my %proteins;
my %protein_references;
my %protein_sources;
my %organisms;

# Pathway Vairables (temp)
my $pathway_organism;
my $pathway_name;
my $pathway_id;
my @pathway_components;
my @pathway_xrefs;

# Reaction Variables (temp)
my $reaction_id;
my @reaction_entities;

# Protein Complex Variables (temp)
my $complex_id;
my @complex_components;

# Protein Variables (temp)
my $protein_id;
my $protein_reference_id;

# Protein Reference Variables (temp)
my $pr_id;
my $pr_organism;
my @pr_names;

# Organisms (temp)
my $organism_id;
my $organism_name;

# Xrefs (temp)
my $xref_bp_id;
my $xref_db_id;

my $updater;

# Also, check that I'm using EXISTS in relevant SQL queries in other scripts.
sub main {
   $updater = myUpdate->new("usage" => "Usage: biopax.pl [biopax_file.owl]");
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

        my $parser = XML::Parser->new(Style => 'Subs',Handlers => {Char=>\&char_handler,End=>\&end_tag,Start=>\&start_tag});
        $self->log("Parsing file...\n");
        $parser->parsefile($self->{fname});
        $self->{prog_total} = scalar(keys(%pathways));

        $self->log("Updating database...\n");
        my $pathway_query     = $self->{dbh}->prepare("INSERT INTO pathways (`name`, `database`, `external_id`) VALUES (?, 'REACTOME', ?)");
        my $uniprot_query     = $self->{dbh}->prepare("SELECT entrez_id FROM gene_xrefs WHERE Xref_db = 'UniProt' AND Xref_id = ?");
        my $symbol_query      = $self->{dbh}->prepare("SELECT entrez_id FROM genes WHERE symbol = ? AND tax_id = (SELECT tax_id FROM taxonomies WHERE name = ?)");
        my $participant_query = $self->{dbh}->prepare("INSERT IGNORE INTO pathway_participants (pathway_id, entrez_id) VALUES (?, ?)");
        
        foreach my $pathway(values(%pathways)) {
            $self->logProgress();
            my $name = $pathway->{"name"};
            my $id = undef;
            foreach my $xref(@{$pathway->{"xrefs"}}){
                if(exists($xrefs{$xref})) {
                    $id = $xrefs{$xref};
                }
            }
            if($id) {
                $pathway_query->execute($name,$id);
                my $db_id = $pathway_query->{mysql_insertid};

                my @components;
                foreach my $component(@{$pathway->{"components"}}){
                    push(@components,@{getComponents($component)});
                }

                my @genes;
                foreach my $component(@components) {
                    push(@genes,@{getGenes($component)});
                }

                foreach my $gene(@genes) {
                    my $eid = undef;
                    if($gene->{'id'} =~ m/UniProt:(.*)/) {
                        $uniprot_query->execute($1);
                        my $ref = $uniprot_query->fetch();
                        if($ref){ $eid = $ref->[0]; }
                    }
                    else{
                        $symbol_query->execute($gene->{'id'},$gene->{'organism'});
                        my $ref = $symbol_query->fetch();
                        if($ref){ $eid = $ref->[0]; }
                    }
                    if($eid) {
                        $participant_query->execute($db_id,$eid);
                    }
                }
            }
        }
        $self->log("\nUpdate complete.\n");
    }

    sub char_handler {
        my($expat,$content) = @_;
        chomp $content;
        if($expat->within_element("bp:Pathway") && $expat->in_element("bp:displayName")){
            $pathway_name = $content;
        }
        elsif($expat->within_element("bp:ProteinReference") && $expat->in_element("bp:name")) {
            push(@pr_names,split(/\s+/,$content));
        }
        elsif($expat->within_element("bp:BioSource") && $expat->in_element("bp:name")) {
            $organism_name = $content;
        }
        elsif($expat->within_element("bp:UnificationXref") && $expat->in_element("bp:id") && $content =~ m/^REACT_/) {
            $xref_db_id = $content;
        }
    }
    sub end_tag {
        my($expat,$name) = @_;
        if($name eq "bp:Pathway") {
            my @t_components = @pathway_components;
            my @t_xrefs = @pathway_xrefs;

            $pathways{$pathway_id} = {
                "name"=> $pathway_name,
                "organism"=>$pathway_organism,
                "components"=>\@t_components,
                "xrefs"=>\@t_xrefs
            };
            $pathway_id         = undef;
            $pathway_name       = undef;
            $pathway_organism   = undef;
            @pathway_components = ();
            @pathway_xrefs      = ();
        }
        elsif($name eq "bp:BiochemicalReaction") {
            my @t_entities = @reaction_entities;

            $reactions{$reaction_id} = \@t_entities;

            $reaction_id = undef;
            @reaction_entities = ();
        }
        elsif($name eq "bp:Complex") {
            my @t_components = @complex_components;

            $complexes{$complex_id} = \@t_components;

            $complex_id = undef;
            @complex_components = ();
        }
        elsif($name eq "bp:Protein") {
            if($protein_reference_id) {
                $proteins{$protein_id} = $protein_reference_id;
            }

            $protein_id = undef;
            $protein_reference_id = undef;
        }
        elsif($name eq "bp:ProteinReference") {
            my @t_pr_names = @pr_names;
            $pr_organism =~ s/^#//;

            $protein_references{$pr_id} = \@t_pr_names;
            $protein_sources{$pr_id} = $pr_organism;

            $pr_id = undef;
            @pr_names = ();
            $pr_organism = undef;
        }
        elsif($name eq "bp:BioSource") {
            $organisms{$organism_id} = $organism_name;

            $organism_name = undef;
            $organism_id = undef;
        }
        elsif($name eq "bp:UnificationXref") {
            if($xref_db_id) {
                $xrefs{$xref_bp_id} = $xref_db_id;
            }
            $xref_bp_id = undef;
            $xref_db_id = undef;
        }
    }
    sub start_tag {
        my $expat = shift @_;
        my $name = shift @_;
        my %attributes = @_;
        if($name eq "bp:Pathway") {
            $pathway_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:BiochemicalReaction") {
            $reaction_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:Complex") {
            $complex_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:Protein") {
            $protein_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:ProteinReference") {
            $pr_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:BioSource") {
            $organism_id = $attributes{"rdf:ID"};
        }
        elsif($name eq "bp:UnificationXref") {
            $xref_bp_id = $attributes{"rdf:ID"};
        }
        elsif($expat->within_element("bp:Pathway")) {
            if($name eq "bp:organism") {
                $pathway_organism = $attributes{"rdf:resource"};
            }
            elsif($name eq "bp:pathwayComponent") {
                push(@pathway_components,$attributes{"rdf:resource"});
            }
            elsif($name eq "bp:xref") {
                if($attributes{"rdf:resource"} =~ /UnificationXref/) {
                    $attributes{"rdf:resource"} =~ s/^#//;
                    push(@pathway_xrefs,$attributes{"rdf:resource"});
                }
            }
        }
        elsif($expat->within_element("bp:BiochemicalReaction")) {
            if($name eq "bp:left" || $name eq "bp:right") {
                push(@reaction_entities,$attributes{"rdf:resource"});
            }
        }
        elsif($expat->within_element("bp:Complex")) {
            if($name eq "bp:Component") {
                push(@complex_components,$attributes{"rdf:resource"});
            }
        }
        elsif($expat->within_element("bp:Protein")) {
            if($name eq "bp:entityReference") {
                $protein_reference_id = $attributes{"rdf:resource"};
            }
        }
        elsif($expat->within_element("bp:ProteinReference")) {
            if($name eq "bp:organism") {
                $pr_organism = $attributes{"rdf:resource"};
            }
        }
    }

    sub getGenes {
        my ($component) = @_;
        $component =~ s/^#//;

        my @proteins;

        if(exists($complexes{$component})) {
            foreach my $protein(@{$complexes{$component}}) {
                push(@proteins,@{getGenes($protein)});
            }
        }
        elsif(exists($proteins{$component})) {
            my $ref_id = $proteins{$component};
            $ref_id =~ s/^#//;
            foreach my $protein(@{$protein_references{$ref_id}}) {
                push(@proteins,{'id' => $protein,'organism' => $protein_sources{$protein}});
            }
#        push(@proteins,@{$protein_references{$ref_id}});
        }
        return \@proteins;
    }

    sub getComponents {
        my ($component) = @_;
        $component =~ s/^#//;
        my @comps;
        if(exists($pathways{$component})) {
            foreach my $sub_com(@{$pathways{$component}->{"components"}}) {
                push(@comps,@{getComponents($sub_com)});
            }
        }
        elsif(exists($reactions{$component})) {
            @comps = @{$reactions{$component}};
        }
        return \@comps;
    }
}
main();
