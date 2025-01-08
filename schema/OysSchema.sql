-- Purpose: OYS posting plugin schema for Interface 3
USE SNDBaseISap;
GO

CREATE SCHEMA oys;
GO

-- Program structure:
--     ????????????      ????????????
--     ? Programs ?<?????? Feedback ?
--     ????????????      ????????????
--     ????????????
--     ?  Sheets  ?
--     ????????????
--     ????????????
-- ????????? ????????????
-- ? Parts ? ? Remnants ?
-- ????????? ????????????
CREATE TABLE oys.Programs (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	ArchivePacketID INT,	-- TODO: can this be removed?
	ProgramName VARCHAR(50),
	RepeatID INT,
	MachineName VARCHAR(50),
	CuttingTime FLOAT
);
CREATE TABLE oys.Sheets (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	Program INT FOREIGN KEY REFERENCES oys.Programs(Id),

	-- For tracking the order of sheets in a slab
	--	- Indexes start at 1
	--	- Indexes represent the order of sheets Left-to-Right in a slab
	SheetIndex INT NOT NULL DEFAULT 1,

	SheetName VARCHAR(50),
	MaterialMaster VARCHAR(50)	-- PrimeCode
);
CREATE TABLE oys.Parts (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	Sheet INT FOREIGN KEY REFERENCES oys.Sheets(Id),
	PartName VARCHAR(100),	-- from Data3 (SAP part name), not PartName
	Qty INT,				-- QtyProgram
	Job VARCHAR(50),		-- Data1
	Shipment VARCHAR(50),	-- Data2
	TrueArea FLOAT,
	NestedArea FLOAT
);
CREATE TABLE oys.Remnants (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	Sheet INT FOREIGN KEY REFERENCES oys.Sheets(Id),
	RemnantName VARCHAR(50),
	Area FLOAT,

	-- For visibility in SAP of whether or not a sheet geometry can be understood
	--	as Length * Width or if inquiry in Sigmanest is required
	IsRectangular BIT
);

-- Program state feedback
CREATE TABLE oys.Feedback (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	Program INT FOREIGN KEY REFERENCES oys.Programs(Id),
	
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