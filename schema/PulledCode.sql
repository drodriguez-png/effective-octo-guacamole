-- Code blocks removed from SimTransCtrl_Proc
use SNInterDev;
go

-- I don't think we want to remove entries from oys.Status
--	except for when we are doing a (yearly) archive
CREATE OR ALTER TRIGGER oys.PostFeedbackUpdate
ON oys.Status
AFTER UPDATE
NOT FOR REPLICATION
AS
BEGIN
	IF UPDATE(SapStatus)
		-- Move 'Complete' and 'Skipped' items to archive
		DELETE FROM oys.Status
		OUTPUT
			deleted.AutoId,
			deleted.DBEntryDateTime,
			deleted.ProgramGUID,
			deleted.SigmanestStatus,
			deleted.SapStatus
		INTO oys.StatusArchive (
			AutoId,
			DBEntryDateTime,
			ProgramGUID,
			SigmanestStatus,
			SapStatus
		)
		WHERE SapStatus IN ('Complete', 'Skipped');
END;
GO