
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


END;
GO