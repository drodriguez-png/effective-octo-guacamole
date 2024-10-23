-- Purpose: Create stored procedures for interfacing SAP with Sigmanest
USE SNDBaseISap;

-- TODO: each district could point to a different SQL server for queries
-- TODO: move the following to `integration` schema
-- 	- dbo.SapInterfaceConfig
-- 	- dbo.PushSapDemand
-- 	- dbo.PushSapInventory
-- 	- dbo.GetProgramFeedback
-- 	- dbo.GetPartFeedback
-- 	- dbo.GetProgramSheets
-- 	- dbo.GetProgramRemnants
-- 	- dbo.DeleteFeedback
-- 	- dbo.UpdateProgram

CREATE TABLE dbo.SapInterfaceConfig (
	-- Name of SAP system (PRD, QAS, etc.)
	SapSystem VARCHAR(3) PRIMARY KEY,

	-- SimTrans district (Sigmanest system) involved with SAP system
	SimTransDistrict INT NOT NULL,

	-- Path format template string to build DXF file
	-- Must include the substring '<sheet_name>' for sheet_name replacement
	RemnantDxfTemplate VARCHAR(255)
);
GO

-- ********************************************
-- *    Interface 1: Demand                   *
-- ********************************************
CREATE OR ALTER PROCEDURE dbo.PushSapDemand
	@sap_system VARCHAR(3),
	@_sap_event_id NUMERIC(20,0),	-- SAP: numeric 20 positions, no decimal

	@work_order VARCHAR(50),
	@part_name VARCHAR(50),
	@qty INT,
	@matl VARCHAR(50),

	@state VARCHAR(50) NULL,
	@dwg VARCHAR(50) NULL,
	@codegen VARCHAR(50) NULL,	-- autoprocess instruction
	@job VARCHAR(50) NULL,
	@shipment VARCHAR(50) NULL,
	@chargeref VARCHAR(50) NULL,	-- PART hours order for shipment
	@op1 VARCHAR(50) NULL,	-- secondary operation 1
	@op2 VARCHAR(50) NULL,	-- secondary operation 2
	@op3 VARCHAR(50) NULL,	-- secondary operation 3
	@mark VARCHAR(50) NULL,	-- part name (Material Master with job removed)
	@raw_mm VARCHAR(50)  NULL
AS
SET NOCOUNT ON
BEGIN
	-- CAST to SimTrans column format
	DECLARE @sap_event_id VARCHAR(50) = CAST(@_sap_event_id AS VARCHAR(50))

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10)

	-- set @mark by stripping @job from @part_name
	IF @mark IS NULL
		SET @mark = REPLACE(@part_name, CONCAT(@job, '-'), '');

	-- Pre-event processing for any group of calls for the same @sap_event_id
	-- Because of this `IF` statement, this will only do anything on the first
	-- 	call for a given SAP event id (which should be for one material master).
	IF @trans_id NOT IN (SELECT DISTINCT TransID FROM TransAct)
	BEGIN
		-- [1] Preemtively set all parts to be removed for the given @mm
		-- This ensures that any demand in Sigmanest that is not in SAP is
		--	removed since SAP will not always tell us that the demand was removed.
		WITH _parts AS (
			SELECT
				PartName,
				WONumber,
				QtyCompleted + (
					SELECT COALESCE(SUM(QtyInProcess), 0)
					FROM dbo.PIP AS _pip
					WHERE _prt.PartName = _pip.PartName
					AND   _prt.WONumber = _pip.WONumber
				) AS QtyCommited
			FROM dbo.Part AS _prt
			WHERE PartName = @part_name
			-- keeps transactions from being inserted if the SimTrans runs in the 
			--	middle of a data push.
			AND Data18 != @sap_event_id
		),
		_cfg AS (
			SELECT SimTransDistrict
			FROM dbo.SapInterfaceConfig
			WHERE SapSystem = @sap_system
		)
		INSERT INTO dbo.TransAct (
			TransType,
			District,
			TransID,	-- for logging purposes
			OrderNo,
			ItemName,
			Qty,
			ItemData18
		)
		SELECT
			CASE
				WHEN _parts.QtyCommited = 0
					THEN 'SN82'	-- Delete part from work order
					ELSE 'SN81'	-- Modify part in work order
			END,
			_cfg.SimTransDistrict,
			@trans_id,
			_parts.WONumber,
			_parts.PartName,
			_parts.QtyCommited,
			@sap_event_id
		FROM _parts, _cfg;
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
		DELETE FROM dbo.TransAct
		WHERE OrderNo = @work_order
		AND ItemName = @part_name
		AND ItemData18 = @sap_event_id;

		-- [3] Add/Update demand via SimTrans
		WITH _cfg AS (
			SELECT SimTransDistrict
			FROM dbo.SapInterfaceConfig
			WHERE SapSystem = @sap_system
		)
		INSERT INTO TransAct
		(
			TransType,  -- `SN81`
			District,
			TransID,	-- for logging purposes
			OrderNo,	-- work order name
			ItemName,	-- Material Master (part name)
			Qty,
			Material,	-- {spec}-{grade}{test}
			Customer,	-- State(occurrence)
			DwgNumber,	-- Drawing name
			Remark,		-- autoprocess instruction
			ItemData1,	-- Job(project)
			ItemData2,	-- Shipment
			ItemData5,	-- PART hours order for shipment
			ItemData6,	-- secondary operation 1
			ItemData7,	-- secondary operation 2
			ItemData8,	-- secondary operation 3
			ItemData9,	-- part name (Material Master with job removed)
			ItemData10,	-- Raw material master (from BOM, if exists)
			ItemData14,	-- `HighHeatNum`
			ItemData18	-- SAP event id
		)
		SELECT
			'SN81',
			_cfg.SimTransDistrict,
			@trans_id,

			@work_order,
			@part_name,
			@qty,
			@matl,

			@state,
			@dwg,
			@codegen,	-- autoprocess instruction
			@job,
			@shipment,
			@chargeref,	-- PART hours order for shipment
			@op1,	-- secondary operation 1
			@op2,	-- secondary operation 2
			@op3,	-- secondary operation 3
			@mark,	-- part name (Material Master with job removed)
			@raw_mm,
			'HighHeatNum',
			@sap_event_id
		FROM _cfg
	END;
END;
GO

-- ********************************************
-- *    Interface 2: Inventory                *
-- ********************************************
CREATE OR ALTER PROCEDURE dbo.PushSapInventory
	@sap_system VARCHAR(3),
	@_sap_event_id NUMERIC(20,0),	-- SAP: numeric 20 positions, no decimal

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
	-- CAST to SimTrans column format
	DECLARE @sap_event_id VARCHAR(50) = CAST(@_sap_event_id AS VARCHAR(50))

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10)

	-- Pre-event processing for any group of calls for the same @sap_event_id
	-- Because of this `IF` statement, this will only do anything on the first
	-- 	call for a given SAP event id (which should be for one material master).
	IF @trans_id NOT IN (SELECT DISTINCT TransID FROM TransAct)
	BEGIN
		-- [1] Preemtively set all sheets to be removed for the given @mm
		-- (excluding any sheets that are part of active nests). This makes
		-- sure any sheets in Sigmanest that are not in SAP are removed since
		-- SAP will not always tell us that those sheets were removed.
		WITH _sheets AS (
			SELECT
				SheetName,
				Material,
				Thickness,
				Width,
				Length
			FROM dbo.Stock
			WHERE dbo.Stock.PrimeCode = @mm
			-- keeps transactions from being inserted if the SimTrans runs in the 
			--	middle of a data push.
			AND dbo.Stock.BinNumber != @sap_event_id
		),
		_cfg AS (
			SELECT SimTransDistrict
			FROM dbo.SapInterfaceConfig
			WHERE SapSystem = @sap_system
		)
		INSERT INTO dbo.TransAct (
			TransType,
			District,
			TransID,	-- for logging purposes
			ItemName,
			Qty,
			Material,	-- required by SimTrans for SN91A
			Thickness,	-- required by SimTrans for SN91A
			Length,		-- required by SimTrans for SN91A
			Width		-- required by SimTrans for SN91A
		)
		SELECT
			'SN91A',
			_cfg.SimTransDistrict,
			@trans_id,
			_sheets.SheetName,
			0,
			_sheets.Material,
			_sheets.Thickness,
			_sheets.Length,
			_sheets.Width
		FROM _sheets, _cfg
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
		DELETE FROM dbo.TransAct WHERE ItemName = @sheet_name;

		-- [3] Add/Update stock via SimTrans
		WITH _cfg AS (
			SELECT
				RemnantDxfTemplate,
				SimTransDistrict
			FROM dbo.SapInterfaceConfig
			WHERE SapSystem = @sap_system
		)
		INSERT INTO dbo.TransAct (
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
		SELECT
			-- SimTrans transaction
			CASE @sheet_type
				WHEN 'Remnant' THEN 'SN97'
				ELSE 'SN91A'
			END,
			_cfg.SimTransDistrict,
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
			CASE @sheet_type
				WHEN 'Remnant'
					THEN REPLACE(_cfg.RemnantDxfTemplate, '<sheet_name>', @sheet_name)
				ELSE NULL
			END
		FROM _cfg
	END;
END;
GO

-- ********************************************
-- *    Interface 3: Create/Delete Nest       *
-- ********************************************
CREATE OR ALTER VIEW dbo.GetProgramFeedback
AS
	SELECT
		AutoID,
		ArchivePacketID,
		CASE TransType
			WHEN 'SN100' THEN 'Created'
			WHEN 'SN101' THEN 'Deleted'
			WHEN 'SN102' THEN 'Updated' -- not used
			ELSE '<unreachable>'
		END AS Status,
		ProgramName,
		MachineName,
		CuttingTime
	FROM dbo.STPrgArc
	WHERE TransType IN ('SN100', 'SN101');
GO
CREATE OR ALTER VIEW dbo.GetPartFeedback
AS
	SELECT
		_pip.AutoID,
		_pip.ArchivePacketID,
		CASE _pip.TransType
			WHEN 'SN100' THEN 'Created'
			WHEN 'SN101' THEN 'Deleted'
			WHEN 'SN102' THEN 'Updated' -- not used
			ELSE '<unreachable>'
		END AS Status,
		_pip.PartName,
		_pip.QtyInProcess AS PartQty,
		_prt.Data1 AS Job,
		_prt.Data2 AS Shipment,
		_pip.TrueArea,
		_pip.NestedArea
	FROM dbo.STPIPArc AS _pip
	INNER JOIN dbo.Part AS _prt
		ON  _pip.PartName = _prt.PartName
		AND _pip.WONumber = _prt.WONumber
	WHERE _pip.TransType IN ('SN100', 'SN101');
GO
CREATE OR ALTER VIEW dbo.GetProgramSheets
AS
	-- TODO: add ArchivePacketID
	SELECT
		_prg.ProgramName,
		_stock.SheetName,
		_stock.PrimeCode AS MaterialMaster
	FROM STPrgArc AS _prg
	INNER JOIN Stock AS _stock
		ON _prg.SheetName = _stock.SheetName
GO
CREATE OR ALTER VIEW dbo.GetProgramRemnants
AS
	-- TODO: add ArchivePacketID
	SELECT
		_prg.ProgramName,
		_remnant.RemnantName,
		_remnant.Area
	FROM STPrgArc AS _prg
	INNER JOIN Remnant AS _remnant
		ON  _prg.ProgramName = _remnant.ProgramName
		AND _prg.RepeatID    = _remnant.RepeatID
GO
CREATE OR ALTER PROCEDURE dbo.DeleteFeedback
	@archive_packet_id VARCHAR(50)
AS
SET NOCOUNT ON
BEGIN
	DELETE FROM STPrgArc WHERE ArchivePacketID = @archive_packet_id;
	DELETE FROM STPIPArc WHERE ArchivePacketID = @archive_packet_id;
END;
GO

-- ********************************************
-- *    Interface 4: Update Program           *
-- ********************************************
CREATE OR ALTER PROCEDURE dbo.UpdateProgram
	@sap_system VARCHAR(3),
	@_sap_event_id NUMERIC(20,0),	-- SAP: numeric 20 positions, no decimal

	@archive_packet_id VARCHAR(50)
AS
SET NOCOUNT ON
BEGIN
	-- Expected Condition:
	-- 	It is expected that the program with the given ArchivePacketID exists.
	-- 	If program update in Sigmanest is disabled and all Interface 3
	-- 		transactionshave posted, then this should hold

	-- CAST to SimTrans column format
	DECLARE @sap_event_id VARCHAR(50) = CAST(@_sap_event_id AS VARCHAR(50))

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10)

	-- [1] Update program
	WITH _program AS (
		SELECT
			ProgramName,
			RepeatID
		FROM dbo.Program
		WHERE ArchivePacketID = @archive_packet_id
	),
	_cfg AS (
		SELECT SimTransDistrict
		FROM dbo.SapInterfaceConfig
		WHERE SapSystem = @sap_system
	)
	INSERT INTO TransAct
	(
		TransType,		-- `SN76`
		District,
		TransID,		-- for logging purposes
		ProgramName,	-- Program name/number
		ProgramRepeat	-- Repeat ID of the program
	)
	SELECT
		'SN76',
		_cfg.SimTransDistrict,
		@trans_id,
		_program.ProgramName,
		_program.RepeatId
	FROM _program, _cfg
END;
GO