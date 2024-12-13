
CREATE OR ALTER PROCEDURE #GetFeedback
AS
BEGIN
	DECLARE @created VARCHAR(50) = 'SN100';
	DECLARE @deleted VARCHAR(50) = 'SN101';

	-- remove reposts (SN100 and SN101 exist for the same ArchivePacketID)
	DELETE FROM STPrgArc
	WHERE ArchivePacketID IN (
		SELECT ArchivePacketID FROM STPrgArc WHERE TransType = @created
		INTERSECT
		SELECT ArchivePacketID FROM STPrgArc WHERE TransType = @deleted
	);

	-- clear unused feedback
	DELETE FROM dbo.STPrgArc
		WHERE TransType NOT IN (@deleted, @created);	-- discard updates
	DELETE FROM dbo.STPIPArc;
	DELETE FROM dbo.STPrtArc;
	DELETE FROM dbo.STRemArc;
	DELETE FROM dbo.STShtArc;
	DELETE FROM dbo.STWOArc;

	-- programs
	SELECT
		AutoID AS FeedbackId,
		ArchivePacketID,
		CASE TransType
			WHEN @created THEN 'Created'
			WHEN @deleted THEN 'Deleted'
		END AS Status,
		ProgramName,
		MachineName,
		CuttingTime
	FROM dbo.STPrgArc

	-- parts
	SELECT
		Programs.ArchivePacketID,
		1 AS SheetIndex,	-- TODO: implement for slabs
		Parts.PartName,
		Parts.QtyInProcess AS PartQty,
		PartData.Data1 AS Job,
		PartData.Data2 AS Shipment,
		Parts.TrueArea,
		Parts.NestedArea
	FROM STPrgArc AS Programs
	INNER JOIN dbo.PIP AS Parts
		ON  Programs.ProgramName = Parts.ProgramName
		AND Programs.RepeatID    = Parts.RepeatID
	INNER JOIN dbo.Part AS PartData
		ON  Parts.PartName = PartData.PartName
		AND Parts.WONumber = PartData.WONumber
	WHERE Programs.TransType = @created;	-- program post

	-- sheet(s)
	SELECT
		Programs.ArchivePacketID,
		1 AS SheetIndex,	-- TODO: implement for slabs
		Sheets.SheetName,
		Sheets.PrimeCode AS MaterialMaster
	FROM STPrgArc AS Programs
	INNER JOIN SIP
		ON Programs.ProgramName = SIP.ProgramName
		AND Programs.RepeatID = SIP.RepeatID
	INNER JOIN Stock AS Sheets
		-- cannot match on SheetName because when sheets are combined, they will differ
		ON SIP.SheetName = Sheets.SheetName
	WHERE Programs.TransType = @created;	-- program post

	-- remnant(s)
	SELECT
		Programs.ArchivePacketID,
		1 AS SheetIndex,	-- TODO: implement for slabs
		Remnants.RemnantName,
		Remnants.Area
	FROM STPrgArc AS Programs
	INNER JOIN Remnant AS Remnants
		ON  Programs.ProgramName = Remnants.ProgramName
		AND Programs.RepeatID    = Remnants.RepeatID
	WHERE Programs.TransType = @created;	-- program post
END;
GO

CREATE OR ALTER PROCEDURE #DeleteFeedback
	@feedback_id INT
AS
BEGIN
	DELETE FROM dbo.STPrgArc WHERE AutoID=@feedback_id
END;
GO

exec #GetFeedback;
--exec #GetFeedback 103;

drop procedure #GetFeedback;
drop procedure #DeleteFeedback;
go