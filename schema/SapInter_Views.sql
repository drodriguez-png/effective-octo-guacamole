USE SNInterDev;
GO

CREATE OR ALTER VIEW sap.InterCfgState
AS
	SELECT
		CAST(REPLACE(DB_NAME(), 'SNInter', '') AS VARCHAR(3)) AS Environment,
		CONCAT('v', Major, '.', Minor, '.', Patch) AS Version,
		SimTransDistrict,
		LogProcedureCalls
	FROM sap.InterfaceConfig, sap.InterfaceVersion;
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
