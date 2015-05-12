#!/bin/bash

set -e
RAWFILES=/data01/backup/rawfiles/latest
VERBOSE=false

# Execute getopt on the arguments passed to this program, identified by the special character $@
PARSED_OPTIONS=$(getopt -n "$0"  -o hr:v --long "help,rawfiles:,v"  -- "$@")

#Bad arguments, something has gone wrong with the getopt command.
if [ $? -ne 0 ];
then
  echo "Bad arguments"
    usage
      exit 1
      fi

# A little magic, necessary when using getopt.
eval set -- "$PARSED_OPTIONS"

# Now goes through all the options with a case and using shift to analyse 1 argument at a time.
#$1 identifies the first argument, and when we use shift we discard the first argument, so $2 becomes $1 and goes again through the case.
while true; do
    case "$1" in
        -h|--help)
            usage
            exit
            shift;;
        -r|--rawfiles)
            RAWFILES=$2
            shift 2;;
        -v|--verbose)
            VERBOSE=true
            shift;;
        --)
            shift
            break;;
    esac
done

echo -n "Database: " 1>&2
read DB
echo -n "Username: " 1>&2
read USER
echo -n "Password: " 1>&2
read -s PASS
echo 1>&2


## Download necessary files
if [ $VERBOSE ]; then
    echo -n "Downloading files... "
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz -O $RAWFILES/gene_info.gz
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz -O $RAWFILES/gene_history.gz
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene2accession.gz -O $RAWFILES/gene2accession.gz
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz -O $RAWFILES/gene_refseq_uniprotkb_collab.gz
    wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz -O $RAWFILES/taxdump.tar.gz
    wget ftp://ftp.ncbi.nih.gov/pub/HomoloGene/current/homologene.data -O $RAWFILES/homologene.data
    wget http://www.drugbank.ca/system/downloads/current/drugbank.xml.zip -O $RAWFILES/drugbank.xml.zip
    wget http://www.reactome.org/download/current/biopax.zip -O $RAWFILES/biopax.zip
    echo "Done"
else
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz -O $RAWFILES/gene_info.gz -q
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_history.gz -O $RAWFILES/gene_history.gz -q
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene2accession.gz -O $RAWFILES/gene2accession.gz -q
    wget ftp://ftp.ncbi.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz -O $RAWFILES/gene_refseq_uniprotkb_collab.gz -q
    wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz -O $RAWFILES/taxdump.tar.gz -q
    wget ftp://ftp.ncbi.nih.gov/pub/HomoloGene/current/homologene.data -O $RAWFILES/homologene.data -q
    wget http://www.reactome.org/download/current/biopax.zip -O $RAWFILES/biopax.zip -q
fi


## Decompress files
if [ $VERBOSE ]; then
    echo -n "Decompressing files... "
fi
gunzip $RAWFILES/gene_info.gz
gunzip $RAWFILES/gene_history.gz
gunzip $RAWFILES/gene2accession.gz
gunzip $RAWFILES/gene_refseq_uniprotkb_collab.gz
tar -xzf $RAWFILES/taxdump.tar.gz -C $RAWFILES/ names.dmp
rm $RAWFILES/taxdump.tar.gz
unzip $RAWFILES/drugbank.xml.zip -d $RAWFILES/
rm $RAWFILES/drugbank.xml.zip
# Change this line later for including ALL pathways
unzip $RAWFILES/biopax.zip Homo_sapiens.owl -d $RAWFILES/
rm $RAWFILES/biopax.zip
if [ $VERBOSE ]; then
    echo "Done"
fi

# Setup the database
if [ $VERBOSE ]; then
    echo -n "Setting up database structure... "
fi
mysql -u $USER --password="$PASS" $DB < db-structure.sql
if [ $VERBOSE ]; then
    echo "Done"
fi

# Start the update
if [ $VERBOSE ]; then
    echo -n "Updating database... "
fi
echo -e "$DB\n$USER\n$PASS" | perl NCBI/gene_info.pl $RAWFILES/gene_info
echo -e "$DB\n$USER\n$PASS" | perl NCBI/gene_history.pl $RAWFILES/gene_history
echo -e "$DB\n$USER\n$PASS" | perl NCBI/uniprot.pl $RAWFILES/gene2accession $RAWFILES/gene_refseq_uniprotkb_collab
echo -e "$DB\n$USER\n$PASS" | perl NCBI/tax_names.pl $RAWFILES/names.dmp
echo -e "$DB\n$USER\n$PASS" | perl NCBI/homologene.pl $RAWFILES/homologene.data
echo -e "$DB\n$USER\n$PASS" | perl DrugBank/drugbank.pl $RAWFILES/drugbank.xml
echo -e "$DB\n$USER\n$PASS" | perl REACTOME/biopax.pl $RAWFILES/Homo_sapiens.owl
if [ $VERBOSE ]; then
    echo "Done"
fi
