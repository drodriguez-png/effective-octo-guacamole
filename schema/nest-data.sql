--update Part
--set
--	Material=ta.Material,	-- {spec}-{grade}{test}
--	DrawingNumber=ta.DwgNumber,	-- Drawing name
--	Remark=ta.Remark,		-- autoprocess instruction
--	Data1=ta.ItemData1,	-- Job(project)
--	Data2=ta.ItemData2,	-- Shipment
--	Data3=ta.ItemData3,	-- Raw material master (from BOM, if exists)
--	Data4=ta.ItemData4,	-- secondary operation 1
--	Data5=ta.ItemData5,	-- secondary operation 2
--	Data6=ta.ItemData6,	-- secondary operation 3
--	Data9=ta.ItemData9,	-- part name (Material Master with job removed)
--	Data10=ta.ItemData10,	-- HeatSwap keyword
--	Data16=ta.ItemData16,	-- PART hours order for shipment
--	Data17=ta.ItemData17	-- SAP Part Name (for when PartName needs changed)
--from Part
--inner join [HIISQLSERV5].SNDBase91.dbo.TransActLog as ta
--	on Part.WONumber=ta.OrderNo
--	and Part.PartName=ta.ItemName
--where OrderNo like '1230169%'

--update part
--set Data3='50/50WT2-1'
--where data3 = '50/50W-0100'

select
	ArchivePacketId,
	'Created' AS Status,
	ProgramName,
	RepeatId,
	MachineName,
	CuttingTime
from Program
order by ArchivePacketID

select
	ArchivePacketId,
	1 AS SheetIndex,
	Stock.SheetName,
	Stock.PrimeCode as MaterialMaster
from Stock
inner join Program on Program.SheetName=Stock.SheetName
order by ArchivePacketID, SheetName

select
	ArchivePacketId,
	1 AS SheetIndex,
	Part.Data17 AS PartName,
	PIP.QtyInProcess AS PartQty,
	Part.Data1 as Job,
	Part.Data2 as Shipment,
	TrueArea,
	NestedArea
from PIP
inner join Part on PIP.PartName=Part.PartName
inner join Program on PIP.ProgramName=Program.ProgramName
where PIP.SheetName != ''
order by ArchivePacketID, PartName

select
	ArchivePacketId,
	1 AS SheetIndex,
	Remnant.RemnantName,
	Remnant.Area,
	Remnant.Width,
	Remnant.Length,
	case
		when abs(Length * Width - Area) < 1.0 then 'true'
		else 'false'
	end as IsRectangular
from Remnant
inner join Program
	on Program.ProgramName=Remnant.ProgramName
	and Program.RepeatID=Remnant.RepeatID
order by ArchivePacketID, RemnantName
	