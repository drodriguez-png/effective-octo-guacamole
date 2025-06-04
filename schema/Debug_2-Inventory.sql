
use SNInterDev;
go

-- Queries:
-- - log
-- - Queue
-- - SimTrans
-- - Stock
-- - StockCompatibility

declare @start datetime = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00';

select * from (select null as Log) as _, log.SapInventoryCalls where LogDate > @start;

select * from (select null as Queue) as _, sap.InventoryQueue;

select
	null as SimTrans,
	TransType,
	District,
	TransID,	-- for logging purposes
	ItemName as SheetName,
	Qty,
	Material,	-- {spec}-{grade}{test}
	Thickness,
	Width,
	Length,
	PrimeCode as MaterialMaster,
	BinNumber as SapEventId,	-- SAP event id
	ItemData1 as Notes1,
	ItemData2 as Notes2,
	ItemData3 as Notes3,
	ItemData4 as Notes4,
	FileName	-- {remnant geometry folder}\{SheetName}.dxf
from SNDBaseDev.dbo.TransAct
	where TransType like 'SN9%'
	or TransType like 'SN6%'
;

select
	null as Stock,
	SheetName,
	Qty,
	QtyAvailable,
	Material,
	Thickness,
	Width,
	Length,
	PrimeCode as MaterialMaster,
	SheetData1,
	SheetData2,
	SheetData3,
	SheetData4,

	SheetType,
	BinNumber as SapEventId,
	DateCreated,
	DateCreated
from SNDBaseDev.dbo.Stock
where SheetName in (
	select ItemName from SNDBaseDev.dbo.TransAct
	union
	select SheetName from sap.InventoryQueue
	union
	select sheet_name from log.SapInventoryCalls where LogDate > @start
)
or PrimeCode in (
	select PrimeCode from SNDBaseDev.dbo.TransAct
	union
	select MaterialMaster from sap.InventoryQueue
	union
	select mm from log.SapInventoryCalls where LogDate > @start
);
select *
from (select null as StockCompatibility) as _,
	 SNDBaseDev.dbo.StockCompatibility
where SheetName in (
	select ItemName from SNDBaseDev.dbo.TransAct
	union
	select SheetName from sap.InventoryQueue
	union
	select sheet_name from log.SapInventoryCalls where LogDate > @start
);
