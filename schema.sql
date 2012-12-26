use wildlife;
create table sightings (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    species varchar(50) not null,
    date datetime NOT NULL,
    date_end datetime,
    activity varchar(100),
    notes text,
    username varchar(100) not null,
    latitude DECIMAL(9,6) not null,
    longitude DECIMAL(9,6) not null,
    latitude_end DECIMAL(9,6),
    longitude_end DECIMAL(9,6),
    image text,
    image_width int,
    image_height int,
    male int,
    female int,
    calf int,
    yearling int,
    immature int,
    mature int,
    unknown int
);
CREATE TABLE landmarks (
	id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name varchar(200) NOT NULL,
	latitude DECIMAL(9,6) NOT NULL,
	longitude DECIMAL(9,6) NOT NULL,
	notes text,
	image varchar(300)
);
CREATE TABLE auth_user (
	userid char(32) NOT NULL PRIMARY KEY,
	username varchar(30) NOT NULL,
	passwd varchar(30) NOT NULL,
	admin int,
	moderator int,
	post int,
        landmarks int,
        password_change int,
	UNIQUE username (username)
);
CREATE TABLE news (
	id int not null auto_increment primary key,
	date timestamp,
	public int default '0',
	html text not null,
	author varchar(100)
);
create table sighting_creator (
	sightingid int not null,
	sessionid char(32),
	ts timestamp,
	t varchar(40)
);
CREATE TABLE weather (
	id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
	date datetime NOT NULL,
	username varchar(30),
	location_name varchar(50) NOT NULL,
	latitude DECIMAL(9,6) not null,
	longitude DECIMAL(9,6) not null,
	temp double,
	temp_min double,
	temp_max double,
	temp_avg double,
	humidity double,
	pressure double,
	wind_speed double,
	wind_direction char(10),
	wind_gust double,
	precip double,
	snow_depth double,
	snow_water_equiv double,
	conditions varchar(50),
	image varchar(255),
	notes text
);
CREATE TABLE layer (
	id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(100) NOT NULL,
	url VARCHAR(300) NOT NULL,
	visible int default 0,
        cgi int default 0
);
CREATE TABLE config (
	name VARCHAR(50) NOT NULL,
	value VARCHAR(200) NOT NULl
);
CREATE TABLE `parcels` (
  `ParcelID` varchar(30) NOT NULL,
  `owner_code` int(11) DEFAULT NULL,
  `date_mod` int(11) DEFAULT NULL,
  `source` int(11) DEFAULT NULL,
  `mapper` int(11) DEFAULT NULL,
  `county_code` int(11) DEFAULT NULL,
  `county` varchar(40) DEFAULT NULL,
  `gis_acre` varchar(40) DEFAULT NULL,
  `owner_name` varchar(300) DEFAULT NULL,
  `care_of` varchar(300) DEFAULT NULL,
  `access` varchar(100) DEFAULT NULL,
  `township` varchar(20) DEFAULT NULL,
  `legal_desc` varchar(300) DEFAULT NULL,
  `total_acre` decimal(7,5) DEFAULT NULL,
  `property_address` varchar(200) DEFAULT NULL,
  `mail_addr` varchar(200) DEFAULT NULL,
  `mail_city` varchar(200) DEFAULT NULL,
  `mail_state` varchar(3) DEFAULT NULL,
  `mail_zip` varchar(10) DEFAULT NULL,
  `source_desc` varchar(200) DEFAULT NULL,
  `mapper_desc` varchar(200) DEFAULT NULL,
  `doing_business` varchar(200) DEFAULT NULL,
  `buffalo_friendly` int(11) DEFAULT NULL,
  `cows` int(11) DEFAULT NULL,
  `notes` varchar(200) DEFAULT NULL,
  `poly` polygon DEFAULT NULL
);


CREATE TABLE log (
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operator VARCHAR(50),
    message VARCHAR(255),
    important BOOL
);

INSERT INTO `config` VALUES ('icon uri','images/markers/'),('default species','bison'),('timezone','America/Boise'),('tempdir','/home/wildlifedb/tmp'),('template dir','templates'),('anonymous exclude file','/home/wildlifedb/wildlife-database/anonymous_exclude'),('base url','http://wildlife.buffalofieldcampaign.org/'),('default zoom','12'),('default latitude','44.795'),('default longitude','-111.181'),('first year','2001'),('image uri','uploadedimages/'),('max image size','300'),('base dir','/home/wildlifedb/wildlife-database/'),('backup dir','backup'),('image dir','web/uploadedimages/'),('time warning','6'),('graph size y','400'),('graph size x','800'),('graph_web_dir','graphs/'),('graph_dir','web/graphs/'),('max sightings per query','500'),('sighting_distance','15'),('max sightings on map','1000'),('count_fields','female,male,calf,yearling,immature,mature,unknown');
