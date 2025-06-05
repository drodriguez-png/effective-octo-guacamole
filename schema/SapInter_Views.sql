USE SNInterDev;
GO


CREATE OR ALTER VIEW sap.MatlCompatTable AS
	-- Recusively builds mapping of parent to child
	--       (table)       ->        (view)
	-- +--------+-------+      +--------+-------+
	-- | Parent | Child |      | Parent | Child |
	-- +--------+-------+      +--------+-------+
	-- |   a    |   b   |  ->  |   a    |   b   |
	-- |   b    |   c   |      |   a    |   c   |
	-- +--------+-------+      |   b    |   c   |
	--                         +--------+-------+
	
	WITH
		WithM270Map AS (
			SELECT
				ParentMatl,
				ChildMatl,
				UseIntermediateCompat,
				1 AS UseRecursion
			FROM sap.MatlCompatMap
			UNION
			SELECT
				ChildMatl,
				ParentMatl,
				UseIntermediateCompat,
				0 AS UseRecursion
			FROM sap.MatlCompatMap
			WHERE IsBidirectional = 1
		),
		ExpandedCompat AS (
			SELECT
				ParentMatl,
				ChildMatl,
				UseRecursion
			FROM WithM270Map
			-- so that we can keep intermediate grades from exporting
			WHERE UseIntermediateCompat = 1
			UNION ALL
			SELECT
				BaseCompat.ParentMatl,
				RecursiveCompat.ChildMatl,
				BaseCompat.UseRecursion
			FROM WithM270Map AS BaseCompat
			INNER JOIN ExpandedCompat AS RecursiveCompat
				ON BaseCompat.ChildMatl = RecursiveCompat.ParentMatl
			WHERE BaseCompat.ParentMatl != RecursiveCompat.ChildMatl
			AND RecursiveCompat.UseRecursion = 1
		)
	SELECT DISTINCT
		ParentMatl,
		ChildMatl
	FROM ExpandedCompat;
GO

CREATE OR ALTER VIEW sap.ProgramId
AS
	SELECT DISTINCT
		Program.ProgramGUID,
		Program.NestType,
		ChildPlate.AutoID AS ArchivePacketId,
		CASE Program.NestType
			WHEN 'Slab' THEN 1
			ELSE ChildPlate.ChildNestRepeatID
		END AS RepeatId
	FROM oys.Program
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ProgramGUID=Program.ProgramGUID
	WHERE ChildPlate.PlateNumber=1;	-- same ID for all slab layouts
GO
CREATE OR ALTER VIEW sap.ChildNestId
AS
	SELECT 
		ProgramId.ProgramGUID,
		ProgramId.ArchivePacketId,
		ChildPlate.ChildPlateGUID,
		ChildPlate.PlateNumber AS SheetIndex,
		ChildPlate.ChildNestProgramName AS ProgramName,
		ChildPlate.ChildNestRepeatID AS RepeatId
	FROM oys.ChildPlate
	INNER JOIN sap.ProgramId
		ON ProgramId.ProgramGUID=ChildPlate.ProgramGUID
		AND ProgramId.RepeatId=ChildPlate.ChildNestRepeatID;
GO

CREATE OR ALTER VIEW oys.ActivePrograms
AS
	WITH ActiveGUID AS (
		SELECT ProgramGUID FROM oys.Status
		EXCEPT
		SELECT ProgramGUID FROM oys.Status
		WHERE SigmanestStatus IN ('Updated', 'Deleted') 
	)
	SELECT
		Program.AutoId AS ArchivePacketId,
		Program.ProgramGUID,
		Program.ProgramName,
		Program.MachineName,
		Program.TaskName,
		Program.WSName,
		Program.NestType,

		Status.SigmanestStatus,
		Status.SAPStatus,
		Status.Source,
		Status.UserName
	FROM ActiveGUID
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ActiveGUID.ProgramGUID
	INNER JOIN oys.Status
		ON Status.ProgramGUID=Program.ProgramGUID;
GO

CREATE OR ALTER VIEW oys.PartsOnProgram
AS
	WITH WorkOrderParts AS (
		SELECT
			WONumber,
			PartName,
			ProgramName,
			RepeatID
		FROM SNDBaseDev.dbo.PIP
		UNION
		SELECT
			WONumber,
			PartName,
			ProgramName,
			RepeatID
		FROM SNDBaseDev.dbo.PIPArchive
		WHERE TransType='SN102'
	)
	SELECT
		ChildPart.AutoId AS ChildPartId,
		ChildPart.SAPPartName,
		WorkOrderParts.WONumber,
		ChildPart.SNPartName,
		ChildPart.QtyProgram,

		Program.AutoId AS ArchivePacketId,
		Program.ProgramName,
		Program.MachineName
	FROM oys.ChildPart
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ChildPlateGUID=ChildPart.ChildPlateGUID
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ChildPlate.ProgramGUID
	INNER JOIN WorkOrderParts
		ON WorkOrderParts.ProgramName=ChildPlate.ChildNestProgramName
		AND WorkOrderParts.RepeatID=ChildPlate.ChildNestRepeatID;
GO

CREATE OR ALTER VIEW sap.RenamedDemandAllocationInProcess
AS
	WITH WorkOrderParts AS (
		SELECT
			WONumber,
			PartName,
			QtyInProcess,
			QtyCompleted
		FROM SNDBaseDev.dbo.PartWithQtyInProcess
	)
	SELECT
		Id,
		OriginalPartName,
		NewPartName,
		WorkOrderName,
		Qty - QtyInProcess - QtyCompleted AS QtyRemaining
	FROM sap.RenamedDemandAllocation AS Alloc
	LEFT JOIN WorkOrderParts
		ON  WorkOrderParts.WONumber=Alloc.WorkOrderName
		AND WorkOrderParts.PartName=Alloc.NewPartName;
GO
