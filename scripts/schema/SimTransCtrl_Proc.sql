
USE SNDBaseISap;

-- TODO: move to `integration` schema
-- TODO: change all uses of SapInterfaceConfig to use `integration` schema
CREATE TABLE dbo.SapInterfaceConfig (
	-- Name of SAP system (PRD, QAS, etc.)
	SapSystem VARCHAR(3) PRIMARY KEY,

	-- SimTrans district (Sigmanest system) involved with SAP system
	SimTransDistrict INT NOT NULL,

	-- Path format template string to build DXF file
	-- Must include the substring '<sheet_name>' for sheet_name replacement
	RemnantDxfTemplate VARCHAR(255)

	-- if columns are added that collide with the the following tables,
	-- 	table qualifications for columns will have to be added
	--		- dbo.Stock
	--		- dbo.Program
);
GO

-- TODO: move to `integration` schema
-- TODO: change all uses of ValidateSimTransIsConfiguredForSapSystem to use `integration` schema
CREATE OR ALTER PROCEDURE dbo.ValidateSimTransIsConfiguredForSapSystem
	@sap_system VARCHAR(3)
AS
BEGIN
	-- Validate that SAP system is configured for SimTrans
	-- Because we use `INSERT INTO ... SELECT ... FROM SapInterfaceConfig`,
	--	if an SAP system is not configured, it will silently fail to insert
	--	SimTrans transactions.
	IF NOT EXISTS (
		SELECT 1 FROM dbo.SapInterfaceConfig
		WHERE SapSystem = @sap_system
	)
		RAISERROR(
			N'SAP system `%s` is not configured for the SimTrans',	-- msg template
			10,	-- severity
			1,	-- state
			@sap_system	-- argument for template formatting
		);
END;
GO

-- ********************************************
-- *    Interface 1: Demand                   *
-- ********************************************
-- TODO: move to `integration` schema
CREATE OR ALTER PROCEDURE dbo.PushSapDemand
	@sap_system VARCHAR(3),
	@_sap_event_id NUMERIC(20,0),	-- SAP: numeric 20 positions, no decimal
	
	@work_order VARCHAR(50),
	@part_name VARCHAR(50),
	@qty INT,
	@matl VARCHAR(50),

	-- TODO: validate which of these can truly be NULL
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
	EXEC dbo.ValidateSimTransIsConfiguredForSapSystem @sap_system;
	
	DECLARE @sap_event_id VARCHAR(50)
	SET @sap_event_id = CAST(@_sap_event_id AS VARCHAR(50))

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10)

	-- TODO:
	--	- calculate mark from part name?
	--	- OR calculate part name from job and mark?

	INSERT INTO TransAct
	(
	)
	SELECT
		'SN81',
		SimTransDistrict,
		@trans_id,

		@work_order,
		@part_name,
		@qty,
		@matl,
			TransType,  -- `SN81`
			District,
			TransID,	-- for logging purposes
			OrderNo,	-- work order name
			ItemName,	-- Material Master
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

	FROM dbo.SapInterfaceConfig
	WHERE SapSystem = @sap_system
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
END;
GO

-- ********************************************
-- *    Interface 2: Inventory                *
-- ********************************************
-- TODO: move to `integration` schema
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
	EXEC dbo.ValidateSimTransIsConfiguredForSapSystem @sap_system;
	
	DECLARE @sap_event_id VARCHAR(50)
	SET @sap_event_id = CAST(@_sap_event_id AS VARCHAR(50))

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
		-- This makes sure any sheets in Sigmanest that are not in SAP are removed
		-- 	since SAP will not always tell us that those sheets were removed.
		INSERT INTO dbo.TransAct (
			TransType,
			District,
			TransID,	-- for logging purposes
			ItemName
		)
		SELECT
			'SN96',
			SimTransDistrict,
			@trans_id,
			SheetName
		FROM dbo.Stock, dbo.SapInterfaceConfig
		WHERE dbo.Stock.PrimeCode = @mm
		AND dbo.Stock.BinNumber != @sap_event_id
		AND dbo.SapInterfaceConfig.SapSystem = @sap_system;
	END;

	-- Null @sheet_name means inventory for that material master has no
	-- 	inventory in SAP, so all inventory with the same @mm needs to be
	-- 	removed in Sigmanest.
	-- 	-> handled by [1]
	IF @sheet_name IS NOT NULL
	BEGIN
		-- [2] Delete any staged SimTrans transactions that would
		-- 	delete this sheet before it is added/updated.
		-- This removes transactions added in [1] that are not necessary.
		DELETE FROM dbo.TransAct
		WHERE PrimeCode = @mm
		AND BinNumber = @sap_event_id;
		
		-- [3] Add/Update stock via SimTrans
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
			SimTransDistrict,
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
				WHEN 'Remnant' THEN REPLACE(RemnantDxfTemplate, '<sheet_name>', @sheet_name)
				ELSE NULL
			END
		FROM dbo.SapInterfaceConfig
		WHERE SapSystem = @sap_system
	END;
END;
GO

-- ********************************************
-- *    Interface 3: Create/Delete Nest       *
-- ********************************************
-- TODO: move to `integration` schema
-- TODO: create view

-- ********************************************
-- *    Interface 4: Update Program           *
-- ********************************************
-- TODO: move to `integration` schema
-- TODO: create procedure
CREATE OR ALTER PROCEDURE dbo.PushSapInventory
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
	-- TODO: do we need further validation

	EXEC dbo.ValidateSimTransIsConfiguredForSapSystem @sap_system;
	
	DECLARE @sap_event_id VARCHAR(50)
	SET @sap_event_id = CAST(@_sap_event_id AS VARCHAR(50))

	-- TransID is VARCHAR(10), but @sap_event_id is 20-digits
	-- The use of this as TransID is purely for diagnostic reasons,
	-- 	so truncating it to the 10 least significant digits is OK.
	DECLARE @trans_id VARCHAR(10) = RIGHT(@sap_event_id, 10)

	-- [1] Update program
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
		SimTransDistrict,
		@trans_id,

		ProgramName,
		RepeatId
	FROM dbo.Program, dbo.SapInterfaceConfig
	WHERE SapSystem = @sap_system
	AND ArchivePacketID = @archive_packet_id
END;
GO