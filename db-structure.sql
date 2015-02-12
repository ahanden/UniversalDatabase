DROP TABLE IF EXISTS `discontinued_genes`;
CREATE TABLE `discontinued_genes` (
  `entrez_id` int(10) unsigned NOT NULL,
  `discontinued_id` int(10) unsigned NOT NULL,
  `discontinued_symbol` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`discontinued_id`),
  KEY `discontinued_symbol` (`discontinued_symbol`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `experiment_xrefs`;
CREATE TABLE `experiment_xrefs` (
  `Xref_db` varchar(30) NOT NULL,
  `Xref_id` varchar(10) NOT NULL,
  `experiment_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`Xref_db`,`Xref_id`,`experiment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `experiments`;
CREATE TABLE `experiments` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pmid` int(10) unsigned NOT NULL,
  `detectionMethod` varchar(7) NOT NULL,
  PRIMARY KEY (`pmid`,`detectionMethod`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gene_locations`;
CREATE TABLE `gene_locations` (
  `entrez_id` int(10) unsigned NOT NULL,
  `map_location` varchar(30) NOT NULL,
  PRIMARY KEY (`entrez_id`,`map_location`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gene_synonyms`;
CREATE TABLE `gene_synonyms` (
  `entrez_id` int(10) unsigned NOT NULL,
  `symbol` varchar(30) NOT NULL,
  PRIMARY KEY (`entrez_id`,`symbol`),
  KEY `symbol (symbol)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gene_xrefs`;
CREATE TABLE `gene_xrefs` (
  `entrez_id` int(10) unsigned NOT NULL,
  `Xref_db` varchar(20) NOT NULL,
  `Xref_id` varchar(30) NOT NULL,
  PRIMARY KEY (`entrez_id`,`Xref_db`,`Xref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `genes`;
CREATE TABLE `genes` (
  `entrez_id` int(10) unsigned NOT NULL,
  `symbol` varchar(30) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `tax_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`entrez_id`),
  KEY `symbol` (`symbol`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `go_annotations`;
CREATE TABLE `go_annotations` (
  `entrez_id` int(10) unsigned NOT NULL,
  `go_id` varchar(10) NOT NULL,
  PRIMARY KEY (`entrez_id`,`go_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `go_terms`;
CREATE TABLE `go_terms` (
  `go_id` varchar(10) NOT NULL,
  `go_term` varchar(255) NOT NULL,
  `category` enum('Component','Function','Process') NOT NULL,
  PRIMARY KEY (`go_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `gwas`;
CREATE TABLE `gwas` (
	`pubmed_id` bigint(20) unsigned NOT NULL,
	`trait` varchar(255) NOT NULL,
	`entrez_id` varchar(20) NOT NULL,
	PRIMARY KEY (`pubmed_id`,`trait`,`entrez_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `interaction_xrefs`;
CREATE TABLE `interaction_xrefs` (
  `interaction_id` int(10) unsigned NOT NULL,
  `Xref_db` varchar(30) NOT NULL,
  `Xref_id` varchar(10) NOT NULL,
  `psi_type` varchar(7) NOT NULL,
  PRIMARY KEY (`Xref_db`,`Xref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `interactions`;
CREATE TABLE `interactions` (
  `interaction_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `entrez_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`interaction_id`,`entrez_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `homologs`;
CREATE TABLE `homologs` (
  `h_group` int(10) unsigned NOT NULL,
  `entrez_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`h_group`,`entrez_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `psi_terms`;
CREATE TABLE `psi_terms` (
  `psi_id` varchar(7) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`psi_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `psi_tree`;
CREATE TABLE `psi_tree` (
  `psi_id` varchar(7) NOT NULL,
  `is_a` varchar(7) NOT NULL,
  PRIMARY KEY (`psi_id`,`is_a`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `taxonomies`;
CREATE TABLE `taxonomies` (
  `tax_id` int(10) unsigned PRIMARY KEY,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
