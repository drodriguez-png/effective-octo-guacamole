
USE SNDBaseISap;

IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'HighSteel')
	EXEC('CREATE SCHEMA HighSteel AUTHORIZATION dbo');
GO

CREATE FUNCTION HighSteel.GetSimTransDistrictFromSapSystem (@system VARCHAR(3))
RETURNS @district INT
AS
BEGIN
	-- TODO: infer district from system
	--	- 'PRD' -> 2
	--	- 'QAS' -> 1
	--	- 'DEV' -> 1
	--	- 'SBX' -> 1
	CASE @system
		WHEN 'PRD' THEN SET  2
		ELSE SET 1
	END;
END;
GO

CREATE OR ALTER PROCEDURE HighSteel.SapInventory
	@system VARCHAR(3),
	@sheet_name VARCHAR(50),
	@qty INT,
	@matl VARCHAR(50),
	@thk FLOAT,
	@wid FLOAT,
	@len FLOAT,
	@mm VARCHAR(50),
	@file VARCHAR(50)
AS
SET NOCOUNT ON
BEGIN
	DECLARE @district INT;
	SET @district = GetSimTransDistrictFromSapSystem(@system);

	-- TODO : diff data with Sigmanest
	--	- requires full list of transactions for a given material
	--	- or do we have {pre,post}-transaction hooks

	-- TODO: split prime vs remnant paths (or combine into 1 transaction)

	-- Prime(new) stock
	INSERT INTO TransAct
	(
		TransType,  -- `SN91A`
		District,
		ItemName,   -- SheetName
		Qty,
		Material,   -- {spec}-{grade}{test}
		Thickness,  -- Thickness batch characteristic
		Width,
		Length,
		PrimeCode   -- Material Master
	)
	VALUES ('SN91A',1,@sheet_name,@qty,@matl,@thk,@wid,@len,@mm)

	-- Remnant stock
	-- TODO: build DXF filename from SimTrans config and @sheet_name
	INSERT INTO TransAct
	(
		TransType,  -- `SN97`
		District,
		ItemName,   -- SheetName
		Qty,
		Material,   -- {spec}-{grade}{test}
		Thickness,  -- Thickness batch characteristic
		PrimeCode,  -- Material Master
		FileName    -- {remnant geometry folder}\{SheetName}.dxf
	)
	VALUES ('SN97',1,@sheet_name,@qty,@matl,@thk,@mm,@file)
END