-- Purpose: Create stored procedures for interfacing SAP with Sigmanest
USE SNInterDev;
GO

CREATE SCHEMA sap;
GO

CREATE TABLE sap.InterfaceConfig (
	-- All queries of this configuration table use `SELECT TOP 1` to ensure that
	-- 	that the transaction happens against 1 district. It could be catastrophic
	-- 	to post transactions against multiple Sigmanest databases, since each SAP
	-- 	system will have 1 Sigmanest database synced with it.
	-- Essentially, this table should only have 1 entry. Lock ensures that:
	--	https://stackoverflow.com/a/3971669
	Lock TINYINT NOT NULL DEFAULT 1,
	CONSTRAINT PK_CONFIG PRIMARY KEY (Lock),
	CONSTRAINT CK_CONFIG_LOCKED CHECK (Lock=1),

	-- SimTrans district (Sigmanest system) involved with SAP system
	SimTransDistrict INT NOT NULL,

	-- Path format template string to build DXF file
	RemnantDxfPath VARCHAR(255),
	-- Path should be to a windows file system folder without trailing \
	--	(as well as other invalid windows folder name characters)
	CONSTRAINT CK_RemnantDxfPath CHECK (RemnantDxfPath NOT LIKE '%[\/:*?"<>|]'),

	-- Placehold word used heat swap (inserted into Data14 in interface 1).
	-- This might be hardcoded in the Sigmanest post, so check before changing.
	-- Changing this also requires changing the HeatSwap configuration.
	HeatSwapKeyword VARCHAR(64)
);
INSERT INTO sap.InterfaceConfig (SimTransDistrict, RemnantDxfPath, HeatSwapKeyword)
VALUES
	(1, '\\hssieng\SNDataQas\RemSaveOutput\DXF', 'HighHeatNum');
GO

CREATE OR ALTER TRIGGER sap.PostConfigUpdate
ON sap.InterfaceConfig
AFTER UPDATE
NOT FOR REPLICATION
AS
BEGIN
	IF UPDATE(HeatSwapKeyword)
		-- update the HeatSwapKeyword for all current work orders
		-- ensures that Data14 matches the configured keyword
		UPDATE SNDBaseDev.dbo.Part 
		SET Part.Data10=inserted.HeatSwapKeyword
		FROM inserted;
END;
GO

CREATE TABLE sap.RenamedDemandAllocation (
	Id INT PRIMARY KEY,
	SapPartName VARCHAR(50),
	NewPartName VARCHAR(50),
	Job VARCHAR(50),
	Shipment VARCHAR(50),
	Qty INT
);
GO

-- ********************************************
-- *    Interface 1: Demand                   *
-- ********************************************
CREATE OR ALTER PROCEDURE sap.PushSapDemand
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal
	
	-- TODO: impl SAP MM usage to escape truncation due to character limit
	@sap_part_name VARCHAR(18) = NULL,

	@work_order VARCHAR(50),
	@part_name VARCHAR(100),
	@qty INT,
	@matl VARCHAR(50),
	@process VARCHAR(64) = NULL,	-- assembly process (DTE, RA, etc.)

	@state VARCHAR(50) = NULL,
	@dwg VARCHAR(50) = NULL,
	@codegen VARCHAR(50) = NULL,	-- autoprocess instruction
	@job VARCHAR(50) = NULL,
	@shipment VARCHAR(50) = NULL,
	@chargeref VARCHAR(50) = NULL,	-- PART hours order for shipment
	@op1 VARCHAR(50) = NULL,	-- secondary operation 1
	@op2 VARCHAR(50) = NULL,	-- secondary operation 2
	@op3 VARCHAR(50) = NULL,	-- secondary operation 3
	@mark VARCHAR(50) = NULL,	-- part name (Material Master with job removed)
	@raw_mm VARCHAR(50) = NULL
AS
SET NOCOUNT ON
BEGIN
	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- load SimTrans heatswap keyword from configuration
	DECLARE @heatswap_keyword INT = (
		SELECT TOP 1 HeatSwapKeyword
		FROM sap.InterfaceConfig
	);

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10);

	-- set @mark by stripping @job from @part_name
	IF @mark IS NULL
		SET @mark = REPLACE(@part_name, CONCAT(@job, '-'), '');

	-- Pre-event processing for any group of calls for the same @sap_event_id
	-- Because of this `IF` statement, this will only do anything on the first
	-- 	call for a given SAP event id (which should be for one material master).
	IF @trans_id NOT IN (SELECT DISTINCT TransID FROM SNDBaseDev.dbo.TransAct)
	BEGIN
		-- [1] Preemtively set all parts to be removed for the given @mm
		-- This ensures that any demand in Sigmanest that is not in SAP is
		-- 	removed since SAP will not always tell us that the demand
		-- 	was removed.
		WITH Parts AS (
			SELECT
				PartName,
				WONumber,
				QtyCompleted + (
					SELECT COALESCE(SUM(QtyInProcess), 0)
					FROM SNDBaseDev.dbo.PIP
					WHERE Parts.PartName = PIP.PartName
					AND   Parts.WONumber = PIP.WONumber
				) AS QtyCommited
			FROM SNDBaseDev.dbo.Part AS Parts
			WHERE PartName = @part_name
			-- keeps additional removal transactions from being inserted if the
			--	SimTrans runs in the middle of a data push.187
			AND Data18 != @sap_event_id
		)
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,
			District,
			TransID,	-- for logging purposes
			OrderNo,
			ItemName,
			Qty,
			ItemData18
		)
		SELECT
			CASE Parts.QtyCommited
				WHEN 0 THEN 'SN82'	-- Delete part from work order
				ELSE 'SN81'			-- Modify part in work order
			END,
			@simtrans_district,
			@trans_id,
			Parts.WONumber,
			Parts.PartName,
			Parts.QtyCommited,
			@sap_event_id
		FROM Parts;
	END;

	-- handle parts in archived work orders
	IF @work_order not in (SELECT WoNumber FROM SNDBaseDev.dbo.Wo)
	BEGIN
		SET @qty = @qty - (
			SELECT TOP 1
				SUM(QtyOrdered) AS QtyProduced
			FROM SNDBaseDev.dbo.PartArchive
			WHERE WoNumber = @work_order
			AND PartName = @part_name
			GROUP BY WoNumber, PartName
		);
	END;

	-- @qty = 0 means SAP has no demand for that material master, so all demand
	-- 	with the same @part_name needs to be removed from Sigmanest.
	-- 	-> handled by [1]
	IF @qty > 0
	BEGIN
		-- [2] Delete any staged SimTrans transactions that would
		-- 	delete this demand before it is added/updated.
		-- This removes transactions added in [1] that are not necessary.
		-- This step is optional, but it helps the performance of the SimTrans.
		DELETE FROM SNDBaseDev.dbo.TransAct
		WHERE OrderNo = @work_order
		AND ItemName = @part_name
		AND ItemData18 = @sap_event_id;

		-- [3] Add/Update demand via SimTrans
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,  -- `SN81`
			District,
			TransID,	-- for logging purposes
			OrderNo,	-- work order name
			ItemName,	-- Material Master (part name)
			OnHold,		-- part is available for nesting
			Qty,
			Material,	-- {spec}-{grade}{test}
			Customer,	-- State(occurrence)
			DwgNumber,	-- Drawing name
			Remark,		-- autoprocess instruction
			ItemData1,	-- Job(project)
			ItemData2,	-- Shipment
			ItemData3,	-- Raw material master (from BOM, if exists)
			ItemData4,	-- secondary operation 1
			ItemData5,	-- secondary operation 2
			ItemData6,	-- secondary operation 3
			ItemData9,	-- part name (Material Master with job removed)
			ItemData10,	-- HeatSwap keyword
			ItemData16,	-- PART hours order for shipment
			ItemData17,	-- SAP Part Name (for when PartName needs changed)
			ItemData18	-- SAP event id

			-- Part Data schema
			--	- Data1-9: Primary nesting processes data
			--	- Data10-15: Secondary nesting data (automation required)
			--	- Data16-18: SAP/Ops required metadata
			--	Data1 : Job
			--	Data2 : Shipment
			--	Data3 : Raw material master (from BOM, if exists)
			--	Data4 : Secondary operation 1
			--	Data5 : Secondary operation 2
			--	Data6 : Secondary operation 3
			--	Data7 : <unused>
			--	Data8 : <unused>
			--	Data9 : Part name (Material Master with job removed)
			--	Data10: HeatSwap keyword
			--	Data11: Part requires secondary check (carried from parts list)
			--	Data12: ChildPart relationship (for slabs)
			--	Data13: ChildPart relationship (continued)
			--	Data14: <unused>
			--	Data15: <unused>
			--	Data16: PART hours order for shipment
			--	Data17: SAP Part Name
			--	Data18: SAP event id

			-- Data{19,20} limitations (as of Sigmanest/SimTrans 24.4)
			--	- exist in database
			--	- cannot be interacted with using SimTrans or the Sigmanest GUI
			--	- cannot be added as auto text on nests
			--	Data19: <unused>
			--	Data20: <unused>
		)
		VALUES (
			'SN81',
			@simtrans_district,
			@trans_id,

			@work_order,
			@part_name,
			CASE @process	-- OnHold
				WHEN 'DTE' THEN 1	-- scan plates
				ELSE 0
			END,
			@qty,
			@matl,

			@state,
			@dwg,
			@codegen,	-- autoprocess instruction
			@job,
			@shipment,
			@raw_mm,
			@op1,	-- secondary operation 1
			@op2,	-- secondary operation 2
			@op3,	-- secondary operation 3
			@mark,	-- part name (Material Master with job removed)
			@heatswap_keyword,
			@chargeref,	-- PART hours order for shipment
			@part_name,
			@sap_event_id
		);
	END;
END;
GO
CREATE OR ALTER PROCEDURE sap.PushRenamedDemand
	@new_part_name VARCHAR(50),
	@sap_part_name VARCHAR(50),
	@qty INT,
	@job VARCHAR(50) = NULL,
	@shipment VARCHAR(50) = NULL
AS
BEGIN
	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- create allocation
	INSERT INTO sap.RenamedDemandAllocation
		(NewPartName, SapPartName, Qty, Job, Shipment)
	VALUES
		(@new_part_name, @sap_part_name, @qty, @job, @shipment);

	-- [CRITICAL] We must guarantee that a given (@part_name, @job, @shipment)
	--	only occurs once (in a single work order). If the system is changed
	--	where this guarantee does not hold, we must change stored procedures:
	--		- PushSapDemand
	--		- PushRenamedDemand (this procedure)

	-- Remove/reduce on-hold demand
	WITH Parts AS (
		SELECT TOP 1
			WONumber,
			PartName,
			QtyOrdered - @qty AS Qty
		FROM SNDBaseDev.dbo.Part
		WHERE PartName = @sap_part_name
		AND Data1 = @job
		AND Data2 = @shipment
	)
	INSERT INTO SNDBaseDev.dbo.TransAct(
		TransType,  -- `SN81`
		District,
		OrderNo,	-- work order name
		ItemName,	-- Material Master (part name)
		Qty
	)
	SELECT
		CASE Qty
			WHEN 0 THEN 'SN82'	-- Delete from work order
			ELSE 'SN81'			-- Update qty
		END,
		@simtrans_district,

		Parts.WONumber,
		@sap_part_name,
		Parts.Qty	-- Ignored for SN82 items
	FROM Parts;

	-- insert SimTrans Transaction
	INSERT INTO SNDBaseDev.dbo.TransAct (
		TransType,  -- `SN81`
		District,
		OrderNo,	-- work order name
		ItemName,	-- Material Master (part name)
		Qty,
		Material,	-- {spec}-{grade}{test}
		-- Customer(State) removed because it is not in the Part table and should
		--	be already set at the work order level
		DwgNumber,	-- Drawing name
		Remark,		-- autoprocess instruction
		ItemData1,	-- Job(project)
		ItemData2,	-- Shipment
		ItemData3,	-- Raw material master (from BOM, if exists)
		ItemData4,	-- secondary operation 1
		ItemData5,	-- secondary operation 2
		ItemData6,	-- secondary operation 3
		ItemData9,	-- part name (Material Master with job removed)
		ItemData10,	-- HeatSwap keyword
		ItemData16,	-- PART hours order for shipment
		ItemData17,	-- SAP Part Name (for when PartName needs changed)
		ItemData18	-- SAP event id
	)
	SELECT TOP 1
		'SN81',
		@simtrans_district,

		WONumber,
		@new_part_name,
		@qty,
		Material,

		DrawingNumber,
		Remark,	-- autoprocess instruction
		Data1,	-- Job(project)
		Data2,	-- Shipment
		Data3,	-- Raw material master (from BOM, if exists)
		Data4,	-- secondary operation 1
		Data5,	-- secondary operation 2
		Data6,	-- secondary operation 3
		Data9,	-- part name (Material Master with job removed)
		Data10,	-- HeatSwap keyword
		Data16,	-- PART hours order for shipment
		@sap_part_name,
		Data18	-- SAP event id
	FROM SNDBaseDev.dbo.Part
	WHERE PartName = @sap_part_name
	AND Data1 = @job
	AND Data2 = @shipment
END;
GO
CREATE OR ALTER PROCEDURE sap.RemoveRenamedDemand
	@id INT
AS
BEGIN
	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- add on-hold demand
	INSERT INTO SNDBaseDev.dbo.TransAct (
		TransType,  -- `SN81`
		District,
		OrderNo,	-- work order name
		ItemName,	-- Material Master (part name)
		Qty,
		Material,	-- {spec}-{grade}{test}
		-- Customer(State) removed because it is not in the Part table and should
		--	be already set at the work order level
		DwgNumber,	-- Drawing name
		Remark,		-- autoprocess instruction
		ItemData1,	-- Job(project)
		ItemData2,	-- Shipment
		ItemData3,	-- Raw material master (from BOM, if exists)
		ItemData4,	-- secondary operation 1
		ItemData5,	-- secondary operation 2
		ItemData6,	-- secondary operation 3
		ItemData9,	-- part name (Material Master with job removed)
		ItemData10,	-- HeatSwap keyword
		ItemData16,	-- PART hours order for shipment
		ItemData17,	-- SAP Part Name (for when PartName needs changed)
		ItemData18	-- SAP event id
	)
	SELECT
		'SN81',
		@simtrans_district,

		WONumber,
		PartName,
		QtyOrdered + (
			SELECT COALESCE(SUM(QtyOrdered), 0)
			FROM SNDBaseDev.dbo.Part AS OnHoldParts
			WHERE OnHoldParts.PartName = Part.Data3
			AND OnHoldParts.Data1 = Part.Data1
			AND OnHoldParts.Data2 = Part.Data2
		),
		Material,

		DrawingNumber,
		Remark,	-- autoprocess instruction
		Data1,	-- Job(project)
		Data2,	-- Shipment
		Data3,	-- Raw material master (from BOM, if exists)
		Data4,	-- secondary operation 1
		Data5,	-- secondary operation 2
		Data6,	-- secondary operation 3
		Data9,	-- part name (Material Master with job removed)
		Data10,	-- HeatSwap keyword
		Data16,	-- PART hours order for shipment
		Data17,	-- SAP part name
		Data18	-- SAP event id
	FROM SNDBaseDev.dbo.Part
	INNER JOIN RenamedDemandAllocation AS Alloc
		ON Part.PartName = Alloc.NewPartName
		AND Part.Data1 = Alloc.Job
		AND Part.Data2 = Alloc.Shipment
	WHERE Alloc.Id = @id;

	-- remove renamed demand
	INSERT INTO SNDBaseDev.dbo.TransAct(
		TransType,  -- `SN82`
		District,
		OrderNo,	-- work order name
		ItemName	-- Material Master (part name)
	)
	SELECT
		'SN82',	-- Delete from work order
		@simtrans_district,

		WONumber,
		NewPartName
	FROM sap.RenamedDemandAllocation
		INNER JOIN SNDBaseDev.dbo.Part
			ON Part.PartName = RenamedDemandAllocation.NewPartName
		WHERE Id = @id;

	-- delete allocation
	DELETE FROM sap.RenamedDemandAllocation WHERE Id = @id;

END;
GO

-- ********************************************
-- *    Interface 2: Inventory                *
-- ********************************************
CREATE OR ALTER PROCEDURE sap.PushSapInventory
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal

	@sheet_name VARCHAR(50),
	@sheet_type VARCHAR(64),
	@qty INT,
	@matl VARCHAR(50),
	@thk FLOAT,
	@wid FLOAT,
	@len FLOAT,
	@mm VARCHAR(50),
	@notes1 VARCHAR(50) NULL,
	@notes2 VARCHAR(50) NULL,
	@notes3 VARCHAR(50) NULL,
	@notes4 VARCHAR(50) NULL
AS
SET NOCOUNT ON
BEGIN
	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);
	-- load dxf path template from configuration and interpolate @sheet_name
	DECLARE @dxf_file INT = (
		SELECT TOP 1
			-- CONCAT(RemnantDxfPath, '\', @sheet_name, '.dxf')
			CONCAT(RemnantDxfPath, CHAR(92), @sheet_name, '.dxf')
		FROM sap.InterfaceConfig
	);

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10);

	-- Pre-event processing for any group of calls for the same @sap_event_id
	-- Because of this `IF` statement, this will only do anything on the first
	-- 	call for a given SAP event id (which should be for one material master).
	IF @trans_id NOT IN (SELECT DISTINCT TransID FROM SNDBaseDev.dbo.TransAct)
	BEGIN
		-- [1] Preemtively set all sheets to be removed for the given @mm
		-- (excluding any sheets that are part of active nests). This makes
		-- sure any sheets in Sigmanest that are not in SAP are removed since
		-- SAP will not always tell us that those sheets were removed.
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,
			District,
			TransID,	-- for logging purposes
			ItemName
		)
		SELECT
			'SN92',
			@simtrans_district,
			@trans_id,
			SheetName
		FROM SNDBaseDev.dbo.Stock
		WHERE SNDBaseDev.dbo.Stock.PrimeCode = @mm
		-- keeps transactions from being inserted if the SimTrans runs
		--	in the middle of a data push.
		AND SNDBaseDev.dbo.Stock.BinNumber != @sap_event_id
	END;

	-- @sheet_name is Null and @qty = 0 means SAP has no inventory for that
	-- 	material master, so all inventory with the same @mm needs to be removed
	-- 	from Sigmanest.
	-- 	-> handled by [1]
	IF @qty > 0
	BEGIN
		-- [2] Delete any staged SimTrans transactions that would delete/update
		-- this sheet before it is added/updated.
		-- This removes transactions added in [1] that are not necessary.
		-- This step is optional, but it helps the performance of the SimTrans.
		DELETE FROM SNDBaseDev.dbo.TransAct WHERE ItemName = @sheet_name;

		-- [3] Add/Update stock via SimTrans
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,	-- `SN91A or SN97`
			District,
			TransID,	-- for logging purposes
			ItemName,	-- SheetName
			Qty,
			Material,	-- {spec}-{grade}{test}
			Thickness,	-- Thickness batch characteristic
			Width,
			Length,
			PrimeCode,	-- Material Master
			BinNumber,	-- SAP event id
			ItemData1,	-- Notes line 1
			ItemData2,	-- Notes line 2
			ItemData3,	-- Notes line 3
			ItemData4,	-- Notes line 4
			FileName	-- {remnant geometry folder}\{SheetName}.dxf
		)
		VALUES (
			-- SimTrans transaction
			CASE @sheet_type
				WHEN 'Remnant' THEN 'SN97'
				ELSE 'SN91A'
			END,
			@simtrans_district,
			@trans_id,

			@sheet_name,
			@qty,
			@matl,
			@thk,
			@wid,
			@len,
			@mm,
			@sap_event_id,

			-- SAP short text notes
			@notes1,
			@notes2,
			@notes3,
			@notes4,

			-- sheet geometry DXF file (remnants only)
			@dxf_file
		);
	END;
END;
GO

-- ********************************************
-- *    Interface 3: Create/Delete Nest       *
-- ********************************************
-- Boomi table for results
CREATE TABLE sap.FeedbackQueue (
	FeedBackId BIGINT IDENTITY(1,1) PRIMARY KEY,
	DataSet VARCHAR(64),
		
	-- Program
	ArchivePacketId BIGINT,
	Status VARCHAR(64),
	ProgramName VARCHAR(50),
	RepeatId INT,
	MachineName VARCHAR(50),
	CuttingTime INT,

	-- Sheet(s)
	SheetIndex INT,
	SheetName VARCHAR(50),
	MaterialMaster VARCHAR(50),

	-- Part(s)
	PartName VARCHAR(100),
	PartQty INT,
	Job VARCHAR(50),
	Shipment VARCHAR(50),
	TrueArea FLOAT,
	NestedArea FLOAT,

	-- Remnant(s)
	RemnantName VARCHAR(50),
	Length INT,
	Width INT,
	Area FLOAT,
	IsRectangular BIT
);
GO
CREATE OR ALTER PROCEDURE sap.GetFeedback
AS
BEGIN
	-- status constants
	DECLARE @ExportStatus VARCHAR(16) = 'Processing';

	-- remove(defer) reposts
	UPDATE oys.Status SET SapStatus = 'Skipped'
	WHERE ProgramGUID IN (
		SELECT ProgramGUID FROM oys.Status WHERE SigmanestStatus = 'Created'
		INTERSECT
		SELECT ProgramGUID FROM oys.Status WHERE SigmanestStatus = 'Deleted'
	);

	-- set feedback to processing
	-- This ensures that if feedback items are added in the middle of processing,
	--	partial data sets do not get  uploaded to SAP
	--	(i.e. Parts list, but not Program header)
	UPDATE oys.Status SET SapStatus = @ExportStatus
	WHERE SapStatus IS NULL;

	-- programs
	INSERT INTO sap.FeedbackQueue (
		DataSet,
		ArchivePacketId,
		Status,
		ProgramName,
		RepeatId,
		MachineName,
		CuttingTime
	) SELECT
		'Program' AS DataSet,
		Program.AutoId AS ArchivePacketId,
		SigmanestStatus AS Status,
		ProgramName,
		CASE Program.NestType
			-- ChildPlate.ChildNestRepeatID for Regular nests, 1 for slabs
			WHEN 'Standard' THEN (
				SELECT TOP 1 ChildNestRepeatID
				FROM oys.ChildPlate
				WHERE ChildPlate.ProgramGUID=Program.ProgramGUID
			)
			ELSE 1
		END AS RepeatId,
		MachineName,
		CuttingTime	-- This is seconds, FeedbackQueue will round
	FROM oys.Status
	INNER JOIN oys.Program
		ON Status.ProgramGUID = Program.ProgramGUID
	WHERE Status.SapStatus = @ExportStatus;

	-- sheet(s)
	INSERT INTO sap.FeedbackQueue (
		DataSet,
		ArchivePacketId,
		SheetIndex,
		SheetName,
		MaterialMaster
	) SELECT
		'Sheets' AS DataSet,
		Program.AutoId AS ArchivePacketId,
		ChildPlate.PlateNumber AS SheetIndex,
		ChildPlate.PlateName AS SheetName,
		ChildPlate.MaterialMaster
	FROM oys.ChildPlate
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	INNER JOIN oys.Status
		ON Status.ProgramGUID=Program.ProgramGUID
	WHERE Status.SapStatus = @ExportStatus;

	-- part(s)
	INSERT INTO sap.FeedbackQueue (
		DataSet,
		ArchivePacketId,
		SheetIndex,
		PartName,
		PartQty,
		Job,
		Shipment,
		TrueArea,
		NestedArea
	) SELECT
		'Parts' AS DataSet,
		Program.AutoId AS ArchivePacketId,
		ChildPlate.PlateNumber AS SheetIndex,
		ChildPart.SAPPartName AS PartName,
		ChildPart.QtyProgram AS PartQty,
		ChildPart.Job,
		ChildPart.Shipment,
		ROUND(ChildPart.TrueArea, 3),	-- SAP is 3 decimals
		ROUND(ChildPart.NestedArea, 3)	-- SAP is 3 decimals
	FROM oys.ChildPart
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ChildPlateGUID=ChildPart.ChildPlateGUID
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	INNER JOIN oys.Status
		ON Status.ProgramGUID=Program.ProgramGUID
	WHERE Status.SapStatus = @ExportStatus;

	-- remnant(s)
	INSERT INTO sap.FeedbackQueue (
		DataSet,
		ArchivePacketId,
		SheetIndex,
		RemnantName,
		Width,
		Length,
		Area,
		IsRectangular
	) SELECT
		'Remnants' AS DataSet,
		Program.AutoId AS ArchivePacketId,
		ChildPlate.PlateNumber AS SheetIndex,
		Remnant.RemnantName,
		Remnant.RectWidth,	-- for batch reference: FeedbackQueue will round
		Remnant.RectLength,	-- for batch reference: FeedbackQueue will round
		ROUND(Remnant.Area, 3),
		Remnant.IsRectangular
	FROM oys.Remnant
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ChildPlateGUID=Remnant.ChildPlateGUID
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	INNER JOIN oys.Status
		ON Status.ProgramGUID=Program.ProgramGUID
	WHERE Status.SapStatus = @ExportStatus;

	SELECT * FROM sap.FeedbackQueue;

	-- update oys.Status.SapStatus = 'Complete'
	UPDATE oys.Status SET SapStatus = 'Complete'
	WHERE SapStatus = @ExportStatus;
END;
GO
CREATE OR ALTER PROCEDURE sap.MarkFeedbackSapUploadComplete
	@feedback_id INT
AS
BEGIN
	-- Marks feedback items as successfully uploaded to SAP.
	-- Feedback items that are not removed will continue to push to SAP

	-- Delete feedback item from queue
	DELETE FROM sap.FeedbackQueue WHERE FeedBackId=@feedback_id;
END;
GO


-- ********************************************
-- *    Interface 4: Update Program           *
-- ********************************************
CREATE OR ALTER PROCEDURE sap.UpdateProgram
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal

	@archive_packet_id INT
AS
SET NOCOUNT ON
BEGIN
	-- Expected Condition:
	-- 	It is expected that the program with the given AutoId exists.
	-- 	If program update in Sigmanest is disabled and all Interface 3
	-- 		transactions have posted, then this should hold
	--	For a slab nest, we only have to update the child nests, because the slab
	--		nest has no work order parts and therefore was not written to the database

	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10);

	-- [1] Update program (child programs in case of a slab)
	INSERT INTO SNDBaseDev.dbo.TransAct (
		TransType,		-- `SN76`
		District,
		TransID,		-- for logging purposes
		ProgramName,	-- Program name/number
		ProgramRepeat	-- Repeat ID of the program
	)
	SELECT
		'SN76',
		@simtrans_district,
		@trans_id,
		ChildNestProgramName,
		ChildNestRepeatID
	FROM oys.Program
	INNER JOIN oys.ChildPlate
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	WHERE Program.AutoId = @archive_packet_id;

	-- Push a new entry into oys.Status with SigmanestStatus = 'Updated'
	--	to simulate a program update
	INSERT INTO oys.Status (
		DBEntryDateTime,
		ProgramGUID,
		StatusGUID,
		SigmanestStatus
	)
	SELECT
		GETDATE(),
		ProgramGUID,
		NEWID(),
		'Updated'
	FROM oys.Program
	WHERE Program.AutoId = @archive_packet_id;
END;
GO