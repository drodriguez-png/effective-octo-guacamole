-- Purpose: Create stored procedures for interfacing SAP with Sigmanest
USE SNInterDev;
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

CREATE OR ALTER PROCEDURE sap.CheckMaterialExists
	@matl VARCHAR(50)
AS
BEGIN
	IF @matl IS NULL
		RETURN;

	-- check if material exists in SimTrans input
	IF (
		SELECT 1 FROM SNDBaseDev.dbo.TransAct
		WHERE Material = @matl
		AND TransType = 'SN60'
		AND District = (
			SELECT TOP 1 SimTransDistrict
			FROM sap.InterfaceConfig
		)
	) IS NOT NULL
		RETURN;

	-- check if material exists in Sigmanest
	IF (SELECT 1 FROM SNDBaseDev.dbo.Material WHERE MaterialType = @matl) IS NULL
	BEGIN
		-- load SimTrans district from configuration
		DECLARE @simtrans_district INT = (
			SELECT TOP 1 SimTransDistrict
			FROM sap.InterfaceConfig
		);

		-- add material into Sigmanest
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,
			District,
			Material,
			ItemData1,	-- Material Group
			Param1	-- Density
		)
		SELECT TOP 1
			'SN60',
			@simtrans_district,
			@matl,
			MatGroupName,
			Densityin
		FROM SNDBaseDev.dbo.Material
		INNER JOIN SNDBaseDev.dbo.MaterialGroup
			ON Material.MatGroupID=MaterialGroup.MatGroupID
		-- assume this is the main/first group ("mild steel")
		WHERE MaterialGroup.MatGroupID=1;
	END
END;
GO

-- ********************************************
-- *    Interface 1: Demand                   *
-- ********************************************
-- Note on SimTrans transactions used
--	- SN81B: sets the "qty to nest"
--	- SN82: remove the part from the work order
-- The use of the SN81B means that if the qty is 0, the part remains in the
--	work order with no demand.
CREATE OR ALTER PROCEDURE sap.PushSapDemand
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal
	@sap_part_name VARCHAR(18),

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
	-- log procedure call
	INSERT INTO log.SapDemandCalls (
		ProcCalled,
		sap_event_id,
		sap_part_name,
		work_order,
		part_name,
		qty,
		matl,
		process,
		state,
		dwg,
		codegen,
		job,
		shipment,
		chargeref,
		op1,
		op2,
		op3,
		mark,
		raw_mm
	)
	SELECT
		'PushSapDemand',
		@sap_event_id,
		@sap_part_name,
		@work_order,
		@part_name,
		@qty,
		@matl,
		@process,
		@state,
		@dwg,
		@codegen,
		@job,
		@shipment,
		@chargeref,
		@op1,
		@op2,
		@op3,
		@mark,
		@raw_mm
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- load SimTrans heatswap keyword from configuration
	DECLARE @heatswap_keyword VARCHAR(64) = (
		SELECT TOP 1 HeatSwapKeyword
		FROM sap.InterfaceConfig
	);

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10);

	-- set @mark by stripping @job from @part_name
	IF @mark IS NULL AND @part_name LIKE @job + '[-_]%'
		SET @mark = SUBSTRING(@part_name,LEN(@job)+2,LEN(@part_name)-LEN(@job)-1);

	-- Pre-event processing for any group of calls for the same @sap_event_id
	-- Because of this `IF` statement, this will only do anything on the first
	-- 	call for a given SAP event id (which should be for one material master).
	IF @trans_id NOT IN (
		SELECT DISTINCT TransID
		FROM SNDBaseDev.dbo.TransAct
		WHERE ItemName = @part_name
	)
	BEGIN
		-- [1] Preemtively set all parts to be removed for the given @mm
		-- This ensures that any demand in Sigmanest that is not in SAP is
		-- 	removed since SAP will not always tell us that the demand
		-- 	was removed.
		WITH Parts AS (
			SELECT PartName, WONumber
			FROM SNDBaseDev.dbo.Part AS Parts
			WHERE Data17 = @sap_event_id
			-- keeps additional removal transactions from being inserted if the
			--	SimTrans runs in the middle of a data push.
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
			'SN81B',	-- Modify part in work order
			@simtrans_district,
			@trans_id,
			Parts.WONumber,
			Parts.PartName,
			0,
			@sap_event_id
		FROM Parts;
	END;

	-- handle on-hold
	DECLARE @onhold BIT = CASE @process
		WHEN 'DTE' THEN 1
		ELSE 0
	END;

	-- reduce by renamed demand
	SET @qty = @qty - ISNULL((
		SELECT SUM(Qty)
		FROM sap.RenamedDemandAllocation
		WHERE OriginalPartName = @part_name
		AND WorkOrderName  = @work_order
	), 0);

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
		WHERE OrderNo = CONCAT(@work_order, CHOOSE(@onhold, '-onhold'))
		AND ItemName = @part_name
		AND ItemData18 = @sap_event_id;

		-- [3.1] Check if material exists in Sigmanest
		EXEC sap.CheckMaterialExists @matl;

		-- [3.2] Add/Update demand via SimTrans
		INSERT INTO SNDBaseDev.dbo.TransAct (
			TransType,  -- `SN81B`
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
			'SN81B',
			@simtrans_district,
			@trans_id,

			-- put on-hold parts in their own work order, since on-hold is a
			--	work order level option
			CONCAT(@work_order, CHOOSE(@onhold, '-onhold')),
			@part_name,
			@onhold,
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
			@sap_part_name,
			@sap_event_id
		);
	END;

	-- recursively call procedure for Renamed Demand
	DECLARE RenamedDemandCursor CURSOR
		LOCAL FORWARD_ONLY READ_ONLY
	FOR
		SELECT
			NewPartName,
			WorkOrderName,
			Qty
		FROM sap.RenamedDemandAllocation
		WHERE OriginalPartName = @part_name
		AND WorkOrderName = @work_order;

	OPEN RenamedDemandCursor;
	FETCH NEXT FROM RenamedDemandCursor
		INTO @part_name, @work_order, @qty;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC sap.PushSapDemand
			@sap_event_id,
			@sap_part_name,
			@work_order,
			@part_name,
			@qty,
			@matl,
			NULL,	-- Process: we don't want these on hold
			@state,
			@dwg,
			@codegen,
			@job,
			@shipment,
			@chargeref,
			@op1,
			@op2,
			@op3,
			@mark,
			@raw_mm;

		FETCH NEXT FROM RenamedDemandCursor
			INTO @part_name, @work_order, @qty;
	END;

	CLOSE RenamedDemandCursor;
	DEALLOCATE RenamedDemandCursor;
END;
GO
CREATE OR ALTER PROCEDURE sap.PushRenamedDemand
	@event_id VARCHAR(50) NULL,
	@original_part_name VARCHAR(50),
	@new_part_name VARCHAR(50),
	@work_order VARCHAR(50),
	@qty INT
AS
BEGIN
	-- log procedure call
	INSERT INTO log.SapDemandCalls (
		ProcCalled,
		sap_event_id,
		sap_part_name,
		part_name,
		work_order,
		qty
	)
	SELECT
		'PushRenamedDemand',
		@event_id,
		@original_part_name,
		@new_part_name,
		@work_order,
		@qty
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- update/create allocation
	UPDATE sap.RenamedDemandAllocation
	SET Qty=Qty + @qty
	WHERE NewPartName=@new_part_name
	AND WorkOrderName=@work_order;
	IF @@ROWCOUNT = 0
	BEGIN
		INSERT INTO sap.RenamedDemandAllocation (
			OriginalPartName,
			NewPartName,
			WorkOrderName,
			Qty
		)
		VALUES (
			@original_part_name,
			@new_part_name,
			@work_order,
			@qty
		)
	END;

	-- trigger interface 1 to push demand (if not already in the queue)
	INSERT INTO sap.FeedbackQueue
		(DataSet, ArchivePacketId, PartName)
	SELECT TOP 1
		'Demand', 0, Data17
	FROM SNDBaseDev.dbo.Part
	LEFT JOIN sap.FeedbackQueue
		ON FeedbackQueue.PartName = Part.Data17
	WHERE Part.PartName = @original_part_name
		AND FeedbackQueue.FeedBackId IS NULL;
END;
GO
CREATE OR ALTER PROCEDURE sap.RemoveRenamedDemand
	@event_id VARCHAR(50) NULL,
	@id INT,
	@qty INT
AS
BEGIN
	-- log procedure call
	INSERT INTO log.SapDemandCalls (
		ProcCalled, sap_event_id, alloc_id, qty
	)
	SELECT
		'RemoveRenamedDemand', @event_id, @id, @qty
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;
	
	-- reduce allocation
	UPDATE sap.RenamedDemandAllocation
	SET Qty = Qty - @qty
	WHERE Id = @id;

	-- trigger interface 1 to push demand (if not already in the queue)
	INSERT INTO sap.FeedbackQueue
		(DataSet, ArchivePacketId, PartName)
	SELECT TOP 1
		'Demand', 0, Data17
	FROM SNDBaseDev.dbo.Part
	INNER JOIN RenamedDemandAllocation AS Alloc
		ON Part.PartName = Alloc.OriginalPartName
	LEFT JOIN sap.FeedbackQueue
		ON FeedbackQueue.PartName = Part.Data17
	WHERE Alloc.Id = @id
		AND FeedbackQueue.FeedBackId IS NULL;
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
	@notes1 VARCHAR(50) = NULL,
	@notes2 VARCHAR(50) = NULL,
	@notes3 VARCHAR(50) = NULL,
	@notes4 VARCHAR(50) = NULL
AS
SET NOCOUNT ON
BEGIN
	-- log procedure call
	INSERT INTO log.SapInventoryCalls(
		ProcCalled,
		sap_event_id,
		sheet_name,
		sheet_type,
		qty,
		matl,
		thk,
		wid,
		len,
		mm,
		notes1,
		notes2,
		notes3,
		notes4
	)
	SELECT
		'PushSapInventory',
		@sap_event_id,
		@sheet_name,
		@sheet_type,
		@qty,
		@matl,
		@thk,
		@wid,
		@len,
		@mm,
		@notes1,
		@notes2,
		@notes3,
		@notes4
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- load dxf path template from configuration and interpolate @sheet_name
	DECLARE @dxf_file VARCHAR(255);
	IF @sheet_type = 'Remnant'
	BEGIN
		-- Having an invalid filepath character in @sheet_name is catastrophic
		--	to the process because we cannot establish a link to the geometry file
		IF @sheet_name LIKE '%[\/:*?"<>|]%'
		BEGIN
			RAISERROR(
				'SheetName `%s` contains an invalid path character',
				16, -- severity
				1,	-- state
				@sheet_name
			);
			-- do not need to ROLLBACK TRANSACTION because nothing changed
			--	and we still want to log the transaction call
			RETURN;
		END;

		SET @dxf_file = (
			SELECT TOP 1
				-- CONCAT(RemnantDxfPath, '\', @sheet_name, '.dxf')
				CONCAT(RemnantDxfPath, CHAR(92), @sheet_name, '.dxf')
			FROM sap.InterfaceConfig
		);
	END;
	 

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
			ItemName,
			Qty,
			Material,
			Thickness,
			Length,
			Width
		)
		SELECT
			'SN91A',
			@simtrans_district,
			@trans_id,
			Stock.SheetName,
			ISNULL(InProcess.QtyInProcess, 0),
			Material,
			Thickness,
			Length,
			Width
		FROM SNDBaseDev.dbo.Stock
		LEFT JOIN (
			SELECT
				SheetName,
				SUM(QtyInProcess) AS QtyInProcess
			FROM SNDBaseDev.dbo.SIP
			GROUP BY SheetName
		) AS InProcess
			ON Stock.SheetName=InProcess.SheetName
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

		-- [3.1] Check if material exists in Sigmanest
		EXEC sap.CheckMaterialExists @matl;

		-- [3.2] Add/Update stock via SimTrans
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
				-- SN91A works for everything, but requires special SimTrans options
				ELSE 'SN91A' -- fails if @qty=0, which is handled by IF statement
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
CREATE OR ALTER PROCEDURE sap.ConsolidateFeedback
AS
BEGIN
	-- remove(defer) reposts
	--	- Created -> Deleted
	--	- Released -> Deleted
	--		not (Created: pushed to SAP) -> Released -> Deleted
	--	- Any Program with SigmanestStatus = 'Deleted' and Program not in SAP
	WITH
		Updates AS (
			-- Records that need to be sent to SAP
			SELECT
				ProgramGUID, SigmanestStatus
			FROM oys.Status
			WHERE SapStatus IS NULL
		),
		SentToSap AS (
			-- Records that have been exported* to SAP
			--	*may or may not be successful
			SELECT
				ProgramGUID
			FROM oys.Status
			WHERE SapStatus = 'Complete'
		)
	UPDATE oys.Status SET SapStatus = 'Skipped'
	WHERE ProgramGUID IN (
		SELECT ProgramGUID FROM Updates WHERE SigmanestStatus = 'Deleted'

		-- remove items in SAP
		EXCEPT SELECT ProgramGUID FROM SentToSap
	);
END;
GO
CREATE OR ALTER PROCEDURE sap.GetFeedback
AS
BEGIN
	EXEC sap.ConsolidateFeedback;

	-- set feedback to processing
	-- This ensures that if feedback items are added in the middle of processing,
	--	partial data sets do not get  uploaded to SAP
	--	(i.e. Parts list, but not Program header)
	DECLARE @ExportStatus VARCHAR(16) = 'Processing';
	UPDATE oys.Status SET SapStatus = @ExportStatus
	WHERE SapStatus IS NULL;

	-- update NestType for split plate nests
	WITH ProgramToChildPart AS (
		SELECT
			Program.ProgramGUID,
			ChildPart.SNPartName,
			Program.NestType,
			Status.SapStatus
		FROM oys.Program
		INNER JOIN oys.Status
			ON Program.ProgramGUID=Status.ProgramGUID
		INNER JOIN oys.ChildPlate
			ON Program.ProgramGUID=ChildPlate.ProgramGUID
		INNER JOIN oys.ChildPart
			ON ChildPlate.ChildPlateGUID=ChildPart.ChildPlateGUID
	)
	UPDATE ProgramToChildPart SET NestType='Split'
		WHERE SNPartName='GHOST'
		AND SapStatus IS NULL;

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
		UPPER(SigmanestStatus) AS Status,
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
		CASE
			WHEN Program.NestType = 'Split' THEN 'SPLIT'
			ELSE UPPER(MachineName)
		END AS MachineName,
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
	WHERE Status.SapStatus = @ExportStatus
		AND Status.ProgramGUID NOT IN (
			SELECT ProgramGUID
			FROM oys.Status
			WHERE SapStatus='Complete'
		);

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
		ChildPart.Shipment,	-- TODO: zero pad (01)
		ROUND(ChildPart.TrueArea, 3),	-- SAP is 3 decimals
		ROUND(ChildPart.NestedArea, 3)	-- SAP is 3 decimals
	FROM oys.ChildPart
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ChildPlateGUID=ChildPart.ChildPlateGUID
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	INNER JOIN oys.Status
		ON Status.ProgramGUID=Program.ProgramGUID
	WHERE Status.SapStatus = @ExportStatus
		AND ChildPart.SAPPartName != ''	-- no parts for split plate
		AND Status.ProgramGUID NOT IN (
			SELECT ProgramGUID
			FROM oys.Status
			WHERE SapStatus='Complete'
		);

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
	WHERE Status.SapStatus = @ExportStatus
		AND Status.ProgramGUID NOT IN (
			SELECT ProgramGUID
			FROM oys.Status
			WHERE SapStatus='Complete'
		);

	-- update oys.Status.SapStatus = 'Complete'
	UPDATE oys.Status SET SapStatus = 'Complete'
	WHERE SapStatus = @ExportStatus;

	SELECT * FROM sap.FeedbackQueue;
END;
GO
CREATE OR ALTER PROCEDURE sap.MarkFeedbackSapUploadComplete
	@feedback_id INT = NULL,
	@archive_packet_id INT = NULL
AS
BEGIN
	-- Marks feedback items as successfully uploaded to SAP.
	-- Feedback items that are not removed will continue to push to SAP

	-- log procedure call
	INSERT INTO log.FeedbackCalls (
		ProcCalled, feedback_id, archive_packet_id
	)
	SELECT
		'MarkFeedbackSapUploadComplete', @feedback_id, @archive_packet_id
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- Delete feedback item(s) from queue
	--	FeedBackId and ArchivePacketId should never be null,
	--	so we don't need to validate our arguments
	DELETE FROM sap.FeedbackQueue WHERE FeedBackId=@feedback_id;
	DELETE FROM sap.FeedbackQueue WHERE ArchivePacketId=@archive_packet_id;
END;
GO


-- ***************************************************
-- *    Interface 4: Release/Delete/Update Program   *
-- ***************************************************
CREATE OR ALTER PROCEDURE sap.ReleaseProgram
	@archive_packet_id INT,
	@source VARCHAR(64) = 'CodeMover',
	@username VARCHAR(64) = NULL
AS
SET NOCOUNT ON
BEGIN
	-- log procedure call
	INSERT INTO log.UpdateProgramCalls (
		ProcCalled, archive_packet_id, source, username
	)
	SELECT
		'ReleaseProgram', @archive_packet_id, @source, @username
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- Push a new entry into oys.Status with SigmanestStatus = 'Updated'
	--	to simulate a program update
	INSERT INTO oys.Status (
		DBEntryDateTime,
		ProgramGUID,
		StatusGUID,
		SigmanestStatus,
		Source,
		UserName
	)
	SELECT
		GETDATE(),
		ProgramGUID,
		NEWID(),
		'Released',
		@source,
		ISNULL(@username, CURRENT_USER)
	FROM oys.Program
	WHERE Program.AutoId = @archive_packet_id;
END;
GO
CREATE OR ALTER PROCEDURE sap.UpdateProgram
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal

	@archive_packet_id INT,
	@source VARCHAR(64) = 'Boomi',
	@username VARCHAR(64) = NULL
AS
SET NOCOUNT ON
BEGIN
	-- Expected Condition:
	-- 	It is expected that the program with the given AutoId exists.
	-- 	If program update in Sigmanest is disabled and all Interface 3
	-- 		transactions have posted, then this should hold
	--	For a slab nest, we only have to update the child nests, because the slab
	--		nest has no work order parts and therefore was not written to the database

	-- log procedure call
	INSERT INTO log.UpdateProgramCalls (
		ProcCalled, sap_event_id, archive_packet_id, source, username
	)
	SELECT
		'UpdateProgram', @sap_event_id, @archive_packet_id, @source, @username
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

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
		'SN70',
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
		SigmanestStatus,
		SAPStatus,
		Source,
		UserName
	)
	SELECT
		GETDATE(),
		ProgramGUID,
		NEWID(),
		'Updated',
		'Complete',
		@source,
		ISNULL(@username, CURRENT_USER)
	FROM oys.Program
	WHERE Program.AutoId = @archive_packet_id;
END;
GO
CREATE OR ALTER PROCEDURE sap.DeleteProgram
	@sap_event_id VARCHAR(50) NULL,	-- SAP: numeric 20 positions, no decimal

	@archive_packet_id INT,
	@source VARCHAR(64) = 'ProgramDelete',
	@username VARCHAR(64) = NULL
AS
SET NOCOUNT ON
BEGIN
	-- log procedure call
	INSERT INTO log.UpdateProgramCalls (
		ProcCalled, sap_event_id, archive_packet_id, source, username
	)
	SELECT
		'DeleteProgram', @sap_event_id, @archive_packet_id, @source, @username
	FROM sap.InterfaceConfig
	WHERE LogProcedureCalls = 1;

	-- load SimTrans district from configuration
	DECLARE @simtrans_district INT = (
		SELECT TOP 1 SimTransDistrict
		FROM sap.InterfaceConfig
	);

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10);

	-- [1] Delete program (child programs in case of a slab)
	INSERT INTO SNDBaseDev.dbo.TransAct (
		TransType,		-- `SN76`
		District,
		TransID,		-- for logging purposes
		ProgramName,	-- Program name/number
		ProgramRepeat	-- Repeat ID of the program
	)
	SELECT
		'SN74',
		@simtrans_district,
		@trans_id,
		ChildNestProgramName,
		ChildNestRepeatID
	FROM oys.Program
	INNER JOIN oys.ChildPlate
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	WHERE Program.AutoId = @archive_packet_id;

	-- Push a new entry into oys.Status with SigmanestStatus = 'Deleted'
	--	to simulate a program delete
	INSERT INTO oys.Status (
		DBEntryDateTime,
		ProgramGUID,
		StatusGUID,
		SigmanestStatus,
		Source,
		UserName
	)
	SELECT
		GETDATE(),
		ProgramGUID,
		NEWID(),
		'Deleted',
		@source,
		ISNULL(@username, CURRENT_USER)
	FROM oys.Program
	WHERE Program.AutoId = @archive_packet_id;
END;
GO