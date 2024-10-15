
USE SNDBaseISap;

IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'HighSteel')
	EXEC('CREATE SCHEMA HighSteel AUTHORIZATION dbo');
GO

DROP TABLE IF EXISTS HighSteel.SapInventory
DROP TABLE IF EXISTS HighSteel.SapDemand
DROP TABLE IF EXISTS HighSteel.SapExecuted
DROP TABLE IF EXISTS HighSteel.Config
GO

CREATE TABLE HighSteel.SapInventory (
	-- Control data that does not enter Sigmanest
	Id INT IDENTITY(1,1) PRIMARY KEY,
	SapSystem VARCHAR(8),	-- SAP system (PRD,QAS,DEV,SBX,etc.) for Sigmanest target district
	SheetType VARCHAR(64),
	
	-- Sigmanest related values
	-- data types match SimTrans documentation
	SheetName VARCHAR(50),
	Qty INT,
	Grade VARCHAR(50),
	MaterialMaster VARCHAR(50),
	Thickness FLOAT,
	Width FLOAT,
	Length FLOAT,
)
CREATE TABLE HighSteel.SapDemand (
	-- Control data that does not enter Sigmanest
	Id INT IDENTITY(1,1) PRIMARY KEY,
	SapSystem VARCHAR(8),	-- SAP system (PRD,QAS,DEV,SBX,etc.) for Sigmanest target district
	
	-- Sigmanest related values
	-- data types match SimTrans documentation
	WorkOrder VARCHAR(50),
	PartName VARCHAR(100),
	Qty INT,
	Grade VARCHAR(50),
	Customer VARCHAR(50),
	DwgNumber VARCHAR(50),
	Remark VARCHAR(80),
	Job VARCHAR(50),
	Shipment VARCHAR(50),
	ChargeRef VARCHAR(50),
	Op1 VARCHAR(50),
	Op2 VARCHAR(50),
	Op3 VARCHAR(50),
	Mark VARCHAR(50),
	RawMaterial VARCHAR(50)
)
CREATE TABLE HighSteel.SapExecuted (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	SapSystem VARCHAR(8),	-- SAP system (PRD,QAS,DEV,SBX,etc.) for Sigmanest target district
	ArchivePacketId INT,
)
CREATE TABLE HighSteel.Config (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	SapSystem VARCHAR(8),	-- SAP system (PRD,QAS,DEV,SBX,etc.) for Sigmanest target district
	Name VARCHAR(255),
	IntVal INT,
	StrVal VARCHAR(255)
)
GO