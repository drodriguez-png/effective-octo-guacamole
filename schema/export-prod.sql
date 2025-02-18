
declare @part_mask varchar(50) = '1230169%';

-- Programs
select
	ArchivePacketID,
	ProgramName,
	RepeatID,
	MachineName,
	CuttingTime
from ProgArchive where ArchivePacketID in (
	select distinct ArchivePacketID
	from PartArchive where PartName like @part_mask
);

-- Sheets
select
	ArchivePacketID,
	1 as SheetIndex,
	SheetName,
	PrimeCode as MaterialMaster
from StockArchive where ArchivePacketID in (
	select distinct ArchivePacketID
	from PartArchive where PartName like @part_mask
);

-- Parts
select
	ArchivePacketID,
	1 as SheetIndex,
	PartName,
	QtyProgram as PartQty,
	Data1 as Job,
	Data2 as Shipment,
	TrueArea,
	NestedArea
from PartArchive where PartName like @part_mask;

-- Remnants
select
	ArchivePacketID,
	1 as SheetIndex,
	RemnantName,
	Area,
	case
		when abs(Length * Width - Area) < 1 then 1
		else 0
	end as IsRectangular
from RemArchive where ArchivePacketID in (
	select distinct ArchivePacketID
	from PartArchive where PartName like @part_mask
);