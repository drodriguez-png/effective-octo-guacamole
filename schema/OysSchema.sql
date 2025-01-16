-- Purpose: OYS posting plugin schema for Interface 3
USE SNDBaseISap;
GO

CREATE SCHEMA oys;
GO

CREATE TABLE oys.Program (
	AutoId INT IDENTITY(1,1),
	ProgramGUID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
	ProgramName VARCHAR(50),
	RepeatID INT,
	MachineName VARCHAR(50),
	CuttingTime FLOAT,
	TaskName VARCHAR(50),
	NestType VARCHAR(64),	-- 'Slab' or 'NormalNest'
	Status VARCHAR(64),	-- 'Created', 'Released', or 'Deleted'
	WSName NVARCHAR(300),
	EntryDateTime DateTime
);
CREATE TABLE oys.ParentPlate(
	AutoId INT IDENTITY(1,1),
	ProgramGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.Program(ProgramGUID) ON DELETE CASCADE,
	ParentPlateGUID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
	PlateName VARCHAR(50),	-- TODO: If using Layout, do we need this?
	Material VARCHAR(50),
	Thickness FLOAT
);
CREATE TABLE oys.ParentPart(
	AutoId INT IDENTITY(1,1) PRIMARY KEY,
	ProgramGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.Program(ProgramGUID) ON DELETE CASCADE,
	PartName VARCHAR(100),	-- from Data3 (SAP part name), not PartName
	PartQty INT,			-- QtyProgram
	Job VARCHAR(50),		-- Data1, TODO: do we need this?
	Shipment VARCHAR(50),	-- Data2, TODO: do we need this?
	TrueArea FLOAT,			-- TODO: do we need this?
	NestedArea FLOAT		-- TODO: do we need this?
);
CREATE TABLE oys.ChildPlate (
	AutoId INT IDENTITY(1,1),
	ProgramGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.Program(ProgramGUID) ON DELETE CASCADE,
	ChildPlateGUID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
	
	PlateName VARCHAR(50),
	-- For tracking the order of sheets in a slab
	--	- Indexes start at 1
	--	- Indexes represent the order of sheets Left-to-Right in a slab
	PlateIndex INT NOT NULL DEFAULT 1,

	MaterialMaster VARCHAR(50),	-- PrimeCode
	Material VARCHAR(50),
	Thickness FLOAT,
	ChildNestTaskName VARCHAR(50),
	ChildNestProgramName VARCHAR(50),
	ChildNestRepeatID INT
);
CREATE TABLE oys.ChildPart (
	AutoId INT IDENTITY(1,1) PRIMARY KEY,
	ChildPlateGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.ChildPlate(ChildPlateGUID) ON DELETE CASCADE,
	PartName VARCHAR(100),	-- from Data3 (SAP part name), not PartName
	PartQty INT,			-- QtyProgram
	Job VARCHAR(50),		-- Data1
	Shipment VARCHAR(50),	-- Data2
	TrueArea FLOAT,
	NestedArea FLOAT
);
CREATE TABLE oys.Remnant (
	AutoId INT IDENTITY(1,1) PRIMARY KEY,
	ChildPlateGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.ChildPlate(ChildPlateGUID) ON DELETE CASCADE,
	RemnantName VARCHAR(50),
	Area FLOAT,

	-- For visibility in SAP of whether or not a sheet geometry can be understood
	--	as Length * Width or if inquiry in Sigmanest is required
	IsRectangular BIT
);

-- Program state feedback
CREATE TABLE oys.Feedback (
	AutoId INT IDENTITY(1,1) PRIMARY KEY,
	ProgramGUID UNIQUEIDENTIFIER
		FOREIGN KEY REFERENCES oys.Program(ProgramGUID) ON DELETE CASCADE,

	-- Status of the program
	--	- Created: program posting (SN100)
	--	- Deleted: program delete (SN101)
	--	- Released: program was checked (where applicable)
	SigmanestStatus VARCHAR(64),	-- 'Created', 'Released', or 'Deleted'

	-- For tracking status of data pushed to SAP
	--	- Initially this should be null
	--	- Boomi and the procedures Boomi calls will update this column
	--	- TODO[High]: do we set a 'Complete' status or delete feedback
	SapStatus VARCHAR(64) NULL	-- 'Sent' or some Boomi status
);
GO