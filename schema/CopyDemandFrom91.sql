
DECLARE @_job VARCHAR(8) = '1220169B';
DECLARE @_ship INT = 2;

DECLARE @sap_name VARCHAR(50);
DECLARE @name VARCHAR(50);
DECLARE @mm VARCHAR(50);
DECLARE @qty INT;
DECLARE @matl VARCHAR(50);
DECLARE @job VARCHAR(50);
DECLARE @ship VARCHAR(50);
DECLARE @mark VARCHAR(50);
DECLARE @ap VARCHAR(50);
DECLARE @op1 VARCHAR(50);
DECLARE @op2 VARCHAR(50);
DECLARE @op3 VARCHAR(50);

DECLARE cur_demand CURSOR
FOR
	SELECT
		PartName,
		DrawingNumber AS SapPartName,
		Material,
		QtyOrdered,
		Data1 AS Job,
		Data2 AS Shipment,
		Data9 AS Mark,
		REPLACE(REPLACE(Data10, '-03', '-93'), '-04', '-94') AS MatlMaster,
		Remark,
		Data6 AS Op1,
		Data7 AS Op2,
		Data8 AS Op3
	FROM SNDBase91.dbo.Part
	WHERE WONumber IN (
		CONCAT(@_job, '-', @_ship, '-WEBS'),
		CONCAT(@_job, '-', @_ship, '-FLGS')
	)
	ORDER BY PartName;

OPEN cur_demand;

FETCH NEXT FROM cur_demand
INTO @name, @sap_name, @matl, @qty, @job, @ship, @mark, @mm, @ap, @op1, @op2, @op3;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC sap.PushSapDemand 'preload1', @sap_name, 'D-1220169-02', @name, @qty, @matl, null, null, null, @job, @ship, @ap, @op1, @op2, @op3, @mark, @mm;

	FETCH NEXT FROM cur_demand
	INTO @name, @sap_name, @matl, @qty, @job, @ship, @mark, @mm, @ap, @op1, @op2, @op3;
END;


CLOSE cur_demand;
DEALLOCATE cur_demand;

EXEC sap.DemandPreExec;
INSERT INTO SNDBase91.dbo.TransAct (TransType, District, OrderNo, ItemData1)
VALUES ('SN87', 5, 'D-1220169-02', 'preload from SNDBase91');

EXEC sap.DebugDemand;
