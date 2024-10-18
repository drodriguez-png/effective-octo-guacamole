
USE SNDBaseISap;

-- TODO: move to `integration` schema
-- TODO: change all uses of SapInterfaceConfig to use `integration` schema
CREATE TABLE dbo.SapInterfaceConfig (
	SapSystem VARCHAR(3) PRIMARY KEY,
	SimTransDistrict INT NOT NULL,
	RemnantDxfPath VARCHAR(255)

	-- if columns are added that collide with the dbo.Stock table,
	-- 	table qualifications will have to be added in step [1]
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
	EXEC dbo.ValidateSimTransIsConfiguredForSapSystem @sap_system = @sap_system;
	
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
			TransType,  -- `SN91A or SN97`
			District,
			TransID,	-- for logging purposes
			ItemName,   -- SheetName
			Qty,
			Material,   -- {spec}-{grade}{test}
			Thickness,  -- Thickness batch characteristic
			Width,
			Length,
			PrimeCode,  -- Material Master
			BinNumber,	-- SAP event id
			ItemData1,	-- Notes line 1
			ItemData2,	-- Notes line 2
			ItemData3,	-- Notes line 3
			ItemData4,	-- Notes line 4
			FileName    -- {remnant geometry folder}\{SheetName}.dxf
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
				WHEN 'Remnant' THEN CONCAT(RemnantDxfPath, '\', @sheet_name, '.dxf')
				ELSE NULL
			END
		FROM dbo.SapInterfaceConfig
		WHERE SapSystem = @sap_system
	END;
END;
GO