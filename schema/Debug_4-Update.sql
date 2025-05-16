use SNInterQas;
go

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

select
	AutoInc,
	TransType,
	District,
	TransID,
	ProgramName,
	ProgramRepeat
from SNDBaseDev.dbo.TransAct
where TransType like 'SN7%'
;

select *
from log.UpdateProgramCalls
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '00:00:00'
;
