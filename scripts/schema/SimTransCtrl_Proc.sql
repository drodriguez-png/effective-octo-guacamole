
USE SNDBaseISap;

-- TODO: move to `integration` schema
-- TODO: change all uses of SapInterfaceConfig to use `integration` schema
CREATE TABLE dbo.SapInterfaceConfig (
	SapSystem VARCHAR(3) PRIMARY KEY,
	SimTransDistrict INT NOT NULL,
	RemnantDxfPath VARCHAR(255)
);
GO

-- TODO: move to `integration` schema
CREATE OR ALTER PROCEDURE dbo.PushSapInventory
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
	SELECT @district = SimTransDistrict FROM SapInterfaceConfig WHERE SapSystem = @system;

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
END;
GO