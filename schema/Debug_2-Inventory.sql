
select
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

use SNDBaseDev;
select * from Stock where SheetName in (select itemname from SNDBaseDev.dbo.TransAct)

use SNInterQas;
select * from log.SapInventoryCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00'
;
