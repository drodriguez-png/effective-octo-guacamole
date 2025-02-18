
insert into TransAct (
	TransType,  -- `SN81`
	District,
	OrderNo,	-- work order name
	ItemName,	-- Material Master (part name)
	Qty,
	Material,	-- {spec}-{grade}{test}
	DwgNumber,	-- Drawing name
	Remark,		-- autoprocess instruction
	ItemData1,	-- Job(project)
	ItemData2,	-- Shipment
	ItemData3,	-- Raw material master (from BOM, if exists)
	ItemData4,	-- secondary operation 1
	ItemData5,	-- secondary operation 2
	ItemData6,	-- secondary operation 3
	ItemData9,	-- part name (Material Master with job removed)
	ItemData10,	-- HeatSwap keyword
	ItemData16,	-- PART hours order for shipment
	ItemData17	-- SAP Part Name (for when PartName needs changed)
)
select
	'SN81',
	3,
	p.WoNumber,
	p.PartName,
	p.qty,
	Material,
	DrawingNumber,
	Remark,
	Data1,
	Data2,
	Data10,
	Data6,
	Data7,
	Data8,
	Data9,
	'HighHeatNum',
	Data5,
	Data3
from (
	select WoNumber, PartName, sum(QtyProgram) as qty
	from PartArchive
	where WONumber like '1230169%'
	group by WoNumber, PartName
) as p
left join (
	select distinct
		WoNumber,
		PartName,
		Material,
		DrawingNumber,
		Remark,
		Data1,
		Data2,
		Data10,
		Data6,
		Data7,
		Data8,
		Data9,
		Data5,
		Data3
	from PartArchive
) as pa
	on p.WoNumber=pa.WoNumber
	and p.PartName=pa.PartName
	order by p.WoNumber, p.PartName

--update TransAct
--set
--	District=2,
--	TransType='SN84',
--	ErrorTag=0
--where OrderNo like '1230169%'
update TransAct set ErrorTag=0 where ErrorTag=1