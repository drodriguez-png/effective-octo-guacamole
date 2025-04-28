
use SNInterQas;
go

--delete from SNDBaseDev.dbo.TransAct
--where TransType='SN60'
--and ( Material is null or Material like '%NA%' );

--delete from SNDBaseDev.dbo.TransAct where OrderNo NOT like 'D-1236169%'
--update SNDBaseDev.dbo.TransAct set ItemName=ItemData17 where TransType like 'SN8%';

--select * from SNDBaseDev.dbo.TransAct;
select
	AutoInc,
	TransType,
	District,
	TransID,
	OrderNo as WorkOrder,
	ItemName as PartName,
	OnHold,		-- part is available for nesting
	Qty,
	Material,	-- {spec}-{grade}{test}
	Customer,	-- State(occurrence)
	DwgNumber,	-- Drawing name
	Remark,		-- autoprocess instruction
	ItemData1 as Job,	-- Job(project)
	ItemData2 as Shipment,	-- Shipment
	ItemData3 as RawMaterialMaster,
	ItemData4 as Operation1,
	ItemData5 as Operation2,
	ItemData6 as Operation3,
	ItemData9 as Mark,	-- part name (Material Master with job removed)
	ItemData10 as HeatSwapKeyword,
	ItemData16 as PartHoursOrder,
	ItemData17 as SapPartName,
	ItemData18 as SapEventId,
	AddedDate
from SNDBaseDev.dbo.TransAct
where TransType like 'SN8%'
;

--select * from sap.RenamedDemandAllocation;

select *
from log.SapDemandCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00'
;
