.timer off
/*
 * Feeds configuration
 */
;
/* echo */ select 'creating config storage...';
/* echo */ select 'table Feed';
.timer on

CREATE TABLE IF NOT EXISTS Feed (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	Name		VARCHAR(255) NOT NULL,
	Title		VARCHAR(255) NOT NULL,
	Class		VARCHAR(255) NOT NULL,
	RepositoryId	INT NOT NULL,
	Icon		BLOB,
	
	UNIQUE (Name)
);

CREATE INDEX IF NOT EXISTS iFeedName ON Feed (Name);

.timer off
/* echo */ select 'table Category';
.timer on

CREATE TABLE IF NOT EXISTS Category (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	FeedId		INT NOT NULL,
	ParentId	INT,
	CanContainSelf	INT NOT NULL,
	Name		VARCHAR(255) NOT NULL,
	Title		VARCHAR(255) NOT NULL,
	Icon		BLOB,

	UNIQUE (FeedId, Name)
);

CREATE INDEX IF NOT EXISTS iCategoryName ON Category (FeedId, Name);
CREATE INDEX IF NOT EXISTS iChildCategory ON Category (ParentId, Name);

.timer off
/* echo */ select 'table FeedConfig';
.timer on

CREATE TABLE IF NOT EXISTS FeedConfig (
	FeedId			INT NOT NULL PRIMARY KEY,
	KeepItems		TINYINT NOT NULL DEFAULT 0,
	UnversionableMetaData	TEXT NOT NULL DEFAULT ''
);

.timer off
/*
 * Data storage with version control
 */
;
/* echo */ select 'creating data storage...';
/* echo */ select 'table Repository';
.timer on

CREATE TABLE IF NOT EXISTS Repository (
	id	INTEGER PRIMARY KEY AUTOINCREMENT,
	Name	VARCHAR(255) NOT NULL,
	Title	VARCHAR(255) NOT NULL,

	UNIQUE (Name)
);

CREATE INDEX IF NOT EXISTS iRepositoryName ON Repository (Name);

.timer off
/* echo */ select 'table RevisionInfo';
.timer on

CREATE TABLE IF NOT EXISTS RevisionInfo (
	RepositoryId	INT NOT NULL,
	Revision	INT NOT NULL,
	UpdateTime	TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	CommitMessage	TEXT NOT NULL DEFAULT '',

	PRIMARY KEY (RepositoryId, Revision)
);

CREATE INDEX IF NOT EXISTS iRepositoryRevision ON RevisionInfo (RepositoryId, Revision);

.timer off
/* echo */ select 'table LinkType';
.timer on

CREATE TABLE IF NOT EXISTS LinkType (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	Name		VARCHAR(32) NOT NULL,
	IsAbsolute	TINYINT NOT NULL DEFAULT 1, -- absolute links are always refer to an existing item
	IsPermanent	TINYINT NOT NULL DEFAULT 0, -- permanent links may refer to an item which doesn't exists in the same revision
	Description	TEXT NOT NULL DEFAULT '',

	UNIQUE (Name)
);

CREATE INDEX IF NOT EXISTS iLinkTypeName ON LinkType (Name);

.timer off
/* echo */ select 'tables Item and ItemHistory';
.timer on

CREATE TABLE IF NOT EXISTS Item (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	ParentId	INT,
	CategoryId	INT NOT NULL,
	Name		VARCHAR(255) NOT NULL,
	Title		VARCHAR(255) NOT NULL,

	UNIQUE (ParentId, CategoryId, Name)
);

CREATE INDEX IF NOT EXISTS iItemName ON Item (ParentId, Name, CategoryId);

CREATE TABLE IF NOT EXISTS ItemHistory (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	ItemId		INT NOT NULL,
	StartRevision	INT NOT NULL,
	StopRevision	INT,
	LinkType	INT,
	LinkTarget	INT
);

CREATE INDEX IF NOT EXISTS iItemHistoryState ON ItemHistory (ItemId, StartRevision, StopRevision);

.timer off
/* echo */ select 'tables MetaData and MetaDataHistory';
.timer on

CREATE TABLE IF NOT EXISTS MetaData (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	ItemId		INT NOT NULL,
	Name		VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS iMetaDataName ON MetaData (ItemId, Name);

CREATE TABLE IF NOT EXISTS MetaDataHistory (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	MetaDataId	INT NOT NULL,
	StartRevision	INT NOT NULL,
	StopRevision	INT,
	DataType	VARCHAR(255) NOT NULL,
	Value		TEXT
);

CREATE INDEX IF NOT EXISTS iMetaDataHistoryState ON MetaDataHistory (MetaDataId, StartRevision, StopRevision);

.timer off
/*
 * Vampire worker
 */
;
/* echo */ select 'creating worker''s info storage...';
/* echo */ select 'table RunSession';
.timer on

CREATE TABLE IF NOT EXISTS RunSession (
	id	INT NOT NULL PRIMARY KEY,
	Session VARCHAR(32) NOT NULL,
	Data	TEXT NOT NULL DEFAULT ''
);

.timer off
/*
 * TaskManager
 */
;
/* echo */ select 'creating task manager storage...';
/* echo */ select 'table Task';
.timer on

CREATE TABLE IF NOT EXISTS Task (
	id	INTEGER PRIMARY KEY AUTOINCREMENT,
	State	VARCHAR(32),
	FeedId	INT NOT NULL,
	Item	VARCHAR(255) NOT NULL,
	Action	VARCHAR(32) NOT NULL,
	Data	TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS iTaskState ON Task (State);


.timer off
/*
 * Create repos
 */
;
/* echo */ select 'adding repositories...';
/* echo */ select '+theatre';
.timer on

INSERT OR IGNORE INTO Repository (id, Name, Title) VALUES (1, 'theatre', '');

.timer off
/*
 * Create dictionary LinkType
 */
;
/* echo */ select 'adding link types...';
/* echo */ select '+hardlink';
.timer on

INSERT OR IGNORE INTO LinkType (id, Name, IsAbsolute, IsPermanent, Description) VALUES (1, 'hardlink', 1, 0, '');
.timer off
/* echo */ select '+reference';
.timer on
INSERT OR IGNORE INTO LinkType (id, Name, IsAbsolute, IsPermanent, Description) VALUES (2, 'reference', 1, 1, '');
.timer off
/* echo */ select '+symlink';
.timer on
INSERT OR IGNORE INTO LinkType (id, Name, IsAbsolute, IsPermanent, Description) VALUES (3, 'symlink', 0, 0, '');
.timer off
/* echo */ select '+symref';
.timer on
INSERT OR IGNORE INTO LinkType (id, Name, IsAbsolute, IsPermanent, Description) VALUES (4, 'symref', 0, 1, '');

.timer off
/*
 * Create feeds
 */
;
/* echo */ select 'adding feeds...';
/* echo */ select '+fmr';
.timer on

INSERT OR IGNORE INTO Feed (id, Name, Title, Class, RepositoryId) VALUES (1, 'fmr', 'Foto mail.ru', 'DataSource::FMR', 1);
INSERT OR IGNORE INTO FeedConfig (FeedId, KeepItems, UnversionableMetaData) VALUES (1, 1, '');

INSERT OR IGNORE INTO Category (id, FeedId, ParentId, CanContainSelf, Name, Title) VALUES (1, 1, NULL, 0, 'user', 'Пользователь');
INSERT OR IGNORE INTO Category (id, FeedId, ParentId, CanContainSelf, Name, Title) VALUES (2, 1, 1, 0, 'album', 'Альбом');
INSERT OR IGNORE INTO Category (id, FeedId, ParentId, CanContainSelf, Name, Title) VALUES (3, 1, 2, 0, 'photo', 'Фото');
INSERT OR IGNORE INTO Category (id, FeedId, ParentId, CanContainSelf, Name, Title) VALUES (4, 1, 3, 0, 'image', 'Файл изображения');
INSERT OR IGNORE INTO Category (id, FeedId, ParentId, CanContainSelf, Name, Title) VALUES (5, 1, 3, 0, 'exif', 'Exif');

