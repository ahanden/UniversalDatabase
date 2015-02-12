DROP TABLE IF EXISTS `taxonomies`;
CREATE TABLE `taxonomies` (
  `tax_id` int(10) unsigned PRIMARY KEY,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

