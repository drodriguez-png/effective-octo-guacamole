
USE SNInterDev;
GO

-- Queries:
-- - log
-- - Queue
-- - SimTrans
-- - Part
-- - Demand Allocation

DECLARE @start DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00';

SELECT * FROM (SELECT NULL AS Log) AS _, log.SapDemandCalls WHERE LogDate > @start;

SELECT * FROM (SELECT NULL AS Queue) AS _, sap.DemandQueue;

SELECT
	NULL AS SimTrans,
	AutoInc,
	TransType,
	District,
	TransID,
	OrderNo AS WorkOrder,
	ItemName AS PartName,
	OnHold,		-- part is available for nesting
	Qty,
	Material,	-- {spec}-{grade}{test}
	Customer,	-- State(occurrence)
	DwgNumber,	-- Drawing name
	Remark,		-- autoprocess instruction
	ItemData1 AS Job,	-- Job(project)
	ItemData2 AS Shipment,	-- Shipment
	ItemData3 AS RawMaterialMaster,
	ItemData4 AS Operation1,
	ItemData5 AS Operation2,
	ItemData6 AS Operation3,
	ItemData9 AS Mark,	-- part name (Material Master with job removed)
	ItemData10 AS HeatSwapKeyword,
	ItemData16 AS PartHoursOrder,
	ItemData17 AS SapPartName,
	ItemData18 AS SapEventId,
	AddedDate
FROM SNDBaseDev.dbo.TransAct
WHERE TransType LIKE 'SN8%';

SELECT *
FROM (SELECT NULL AS Part) AS _, SNDBaseDev.dbo.Part
WHERE PartName IN (
	SELECT ItemName FROM SNDBaseDev.dbo.TransAct
	UNION
	SELECT PartName FROM sap.DemandQueue
	UNION
	SELECT part_name FROM log.SapDemandCalls WHERE LogDate > @start
)
OR Data17 in (
	SELECT ItemData17 FROM SNDBaseDev.dbo.TransAct
	UNION
	SELECT SapPartName FROM sap.DemandQueue
	UNION
	SELECT sap_part_name FROM log.SapDemandCalls WHERE LogDate > @start
)

SELECT * FROM (SELECT NULL AS RenamedAlloc) AS _, sap.RenamedDemandAllocation;
