
declare @retry_id int = 0;
--set @retry_id = 7;	-- comment this out to skip retry block

-- temp fix for data scheme remapping
update oys.ChildPart set SAPPartName = (
	select top 1 Data17
	from SNDBaseDev.dbo.Part
	where PartName=SNPartName and Data1=Job and Data2=Shipment
	and len(isnull(Data17, '')) > 0
)
where SAPPartName in (
	select distinct PrimeCode
	from SNDBaseDev.dbo.Stock
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
	on Program.ProgramGUID=Status.ProgramGUID;

if @retry_id = 0
	select * from sap.FeedbackQueue;

select * from log.FeedbackCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '08:00:00'
;
