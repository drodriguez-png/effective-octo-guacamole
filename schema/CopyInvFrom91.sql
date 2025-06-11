
DECLARE @_job VARCHAR(8) = '1240114A';
DECLARE @_ship INT = 1;

DECLARE @name VARCHAR(50);
DECLARE @mm VARCHAR(50);
DECLARE @qty INT;
DECLARE @matl VARCHAR(50);
DECLARE @thk FLOAT;
DECLARE @wid FLOAT;
DECLARE @len FLOAT;

DECLARE cur_stock CURSOR
FOR
	WITH mm AS (
		SELECT
			PrimeCode AS OldMM,
			CASE
				WHEN PrimeCode LIKE CONCAT(@_job, FORMAT(@_ship, '00'), '-0%')
					THEN REPLACE(PrimeCode, '-0', '-9')
				ELSE PrimeCode
			END AS MatlMaster,
			SUM(Qty) AS Qty
		FROM SNDBase91.dbo.Stock
		GROUP BY PrimeCode
	), MmData AS (
		SELECT DISTINCT
			PrimeCode AS MM,
			Material,
			Thickness,
			Width,
			Length
		FROM SNDBase91.dbo.Stock
	)
	SELECT
		MatlMaster,
		mm.Qty,
		Material,
		Thickness,
		Width,
		Length,
		MatlMaster
	FROM mm
	LEFT JOIN MmData
		ON MmData.MM=mm.OldMM
	WHERE MatlMaster LIKE CONCAT(@_job, FORMAT(@_ship, '00'), '%');

OPEN cur_stock;

FETCH NEXT FROM cur_stock
INTO @name, @qty, @matl, @thk, @wid, @len, @mm;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC sap.PushSapInventory 'preload1', @name, 'New Sheet', @qty, @matl, @thk, @wid, @len, @mm, 'preload from SNDBase91'

	FETCH NEXT FROM cur_stock
	INTO @name, @qty, @matl, @thk, @wid, @len, @mm;
END;

CLOSE cur_stock;
DEALLOCATE cur_stock;

EXEC sap.InventoryPreExec;
EXEC sap.DebugInventory;
