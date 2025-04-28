
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
;

--select * from SNDBaseDev.dbo.TransAct;
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
where LogDate > CAST(CAST(GETDATE() AS DATE) AS DATETIME) + '08:00:00'
;
