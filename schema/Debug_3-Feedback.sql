
use SNInterQas;

declare @retry_id int = 0;
declare @archive_feedback bit = 0;
--set @retry_id = 16;	-- comment this out to skip retry block

-- clear sap.FeedbackQueue
if @archive_feedback = 1
begin
	DECLARE @ArchivePacketId INT
	DECLARE packet_cursor CURSOR FOR
		SELECT DISTINCT ArchivePacketId 
		FROM sap.FeedbackQueue;
	OPEN packet_cursor;
	FETCH NEXT FROM packet_cursor INTO @ArchivePacketId;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC sap.MarkFeedbackSapUploadComplete @archive_packet_id = @ArchivePacketId;
		FETCH NEXT FROM packet_cursor INTO @ArchivePacketId;
	END
	CLOSE packet_cursor;
	DEALLOCATE packet_cursor;
end;

-- temp fix for data scheme remapping
update oys.ChildPart set SAPPartName = (
	select top 1 Data17
	from SNDBaseQas.dbo.Part
	where PartName=SNPartName and Data1=Job and Data2=Shipment
	and len(isnull(Data17, '')) > 0
)
where SAPPartName in (
	select distinct PrimeCode
	from SNDBaseQas.dbo.Stock
)
;

if @retry_id > 0
begin
	exec sap.MarkFeedbackSapUploadComplete @archive_packet_id=@retry_id;
	with stat as (
		select top 1 * from oys.Status
		where ProgramGUID in (
			select ProgramGUID from oys.Program where AutoId=@retry_id
		)
		order by Status.AutoId desc
	) update stat set SapStatus = null;
	exec sap.GetFeedback;
end;

select
	Status.AutoId as StatusId,
	Status.DBEntryDateTime,
	Status.StatusGUID,
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
	Program.CuttingTime,
	Program.WSName,
	Status.Source,
	Status.UserName
from oys.Status
left join oys.Program
	on Program.ProgramGUID=Status.ProgramGUID
left join sap.ChildNestId
	on ChildNestId.ProgramGUID=Program.ProgramGUID
where Status.DBEntryDateTime > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00'
order by Status.AutoId;

if @retry_id = 0
	select * from sap.FeedbackQueue;

select * from log.FeedbackCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00'
;
