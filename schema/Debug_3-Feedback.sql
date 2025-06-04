
use SNInterQas;
go

--exec sap.MarkFeedbackSapUploadComplete 164;
--exec sap.MarkFeedbackSapUploadComplete 175;

-- Queries:
-- - log
-- - Status/Program
-- - Queue
declare @start datetime = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00';

select * from (select null as Log) as _, log.FeedbackCalls
where LogDate > @start;

select distinct
	null as Status,
	Status.AutoId as StatusId,
	Status.DBEntryDateTime,
	Status.SigmanestStatus,
	Status.SapStatus,

	Status.ProgramGUID,
	Program.AutoId as ProgramId,
	ChildNestId.ArchivePacketId,
	Program.ProgramName,
	Program.NestType,
	Program.TaskName,
	Program.LayoutNumber,
	Program.MachineName,
	Program.WSName,
	Status.Source,
	Status.UserName
from oys.Status
left join oys.Program
	on Program.ProgramGUID=Status.ProgramGUID
left join sap.ChildNestId
	on ChildNestId.ProgramGUID=Program.ProgramGUID
where Status.DBEntryDateTime > @start
or SapStatus not in ('Complete', 'Skipped')
order by Status.AutoId;

select * from (select null as Queue) as _, sap.FeedbackQueue;

