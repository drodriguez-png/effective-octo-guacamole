
--delete from SNDBaseDev.dbo.TransAct
--where TransType='SN60'
--and ( Material is null or Material like '%NA%' );

--delete from SNDBaseDev.dbo.TransAct;

--select * from SNDBaseDev.dbo.TransAct;
select
	AutoInc,
	TransType,  -- `SN81`
	District,
	TransID,	-- for logging purposes
	OrderNo,	-- work order name
	ItemName,	-- Material Master (part name)
	OnHold,		-- part is available for nesting
	Qty,
	Material,	-- {spec}-{grade}{test}
	Customer,	-- State(occurrence)
	DwgNumber,	-- Drawing name
	Remark,		-- autoprocess instruction
	ItemData1 as Job,	-- Job(project)
	ItemData2 as Shipment,	-- Shipment
	ItemData3 as RawMM,	-- Raw material master (from BOM, if exists)
	ItemData4 as Operation1,	-- secondary operation 1
	ItemData5 as Operation2,	-- secondary operation 2
	ItemData6 as Operation3,	-- secondary operation 3
	ItemData9 as Mark,	-- part name (Material Master with job removed)
	ItemData10 as HeatSwapKeyword,	-- HeatSwap keyword
	ItemData16 as PartHours,	-- PART hours order for shipment
	ItemData17 as SapPartName,	-- SAP Part Name (for when PartName needs changed)
	ItemData18 as EventId	-- SAP event id
from SNDBaseDev.dbo.TransAct
where TransType like 'SN8_'
--and ItemName like '%-%'
--order by SapPartName
;

select *
from log.SapDemandCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '11:00:00'
and part_name like '%-%';
