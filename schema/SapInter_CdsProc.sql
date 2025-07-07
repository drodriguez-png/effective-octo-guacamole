
USE SNInterDev;
GO

CREATE OR ALTER PROCEDURE cds.GetNests
	@job VARCHAR(50),
	@shipment VARCHAR(50)
AS
BEGIN
	WITH ProgramParts AS (
		SELECT
			ProgramName,
			STRING_AGG(
				REPLACE(ParentPart.SNPartName, @job+'_', ''), ','
			) WITHIN GROUP (ORDER BY ParentPart.SNPartName) AS Parts
		FROM sap.ProgramStatus
		INNER JOIN oys.ParentPart
			ON ParentPart.ProgramGUID=ProgramStatus.ProgramGUID
		WHERE ParentPart.ParentPartGUID IN (
			SELECT ParentPartGUID
			FROM oys.ChildPart
			WHERE ChildPart.Job=@job
			AND ChildPart.Shipment = @shipment
		)
		GROUP BY ProgramName
	)
		SELECT
			ProgramParts.ProgramName,
			Program.MachineName,
			SigmanestStatus AS ProgramStatus,
			CASE
				WHEN Program.NestType = 'Slab'
					THEN ParentPlate.PlateName
				ELSE ChildPlate.MaterialMaster
			END AS MaterialMaster,
			ParentPlate.Material AS Grade,
			ParentPlate.Thickness,
			Parts,
			DatePrinted
		FROM ProgramParts
		LEFT JOIN cds.ShopNestData
			ON ProgramParts.ProgramName=ShopNestData.ProgramName
		INNER JOIN sap.ProgramStatus
			ON ProgramParts.ProgramName=ProgramStatus.ProgramName
		INNER JOIN oys.Program
			ON Program.ProgramGUID=ProgramStatus.ProgramGUID
		INNER JOIN oys.ParentPlate
			ON ParentPlate.ProgramGUID=ProgramStatus.ProgramGUID
		LEFT JOIN oys.ChildPlate
			ON ChildPlate.ProgramGUID=ProgramStatus.ProgramGUID;
END;
GO

CREATE OR ALTER PROCEDURE cds.GetNestParts
	@job VARCHAR(50),
	@shipment INT
AS
BEGIN
	SELECT
		ProgramStatus.ProgramName,
		Program.MachineName,
		SigmanestStatus AS ProgramStatus,
		ChildPlate.MaterialMaster,
		ChildPlate.Material AS Grade,
		ChildPlate.Thickness,
		REPLACE(ChildPart.SNPartName, @job+'_', '') AS PartName,
		ChildPart.QtyProgram AS Qty,
		DatePrinted
	FROM sap.ProgramStatus
	LEFT JOIN cds.ShopNestData
		ON ProgramStatus.ProgramName=ShopNestData.ProgramName
	INNER JOIN oys.Program
		ON Program.ProgramGUID=ProgramStatus.ProgramGUID
	INNER JOIN oys.ChildPlate
		ON ChildPlate.ProgramGUID=ProgramStatus.ProgramGUID
	INNER JOIN oys.ChildPart
		ON ChildPart.ChildPlateGUID=ChildPlate.ChildPlateGUID
	WHERE ChildPart.Job=@job AND ChildPart.Shipment = @shipment;
END;
GO

CREATE OR ALTER PROCEDURE cds.UnmarkNestPrinted
	@nest VARCHAR(50)
AS
BEGIN
	DELETE FROM cds.ShopNestData WHERE ProgramName=@nest;
END;
GO
CREATE OR ALTER PROCEDURE cds.MarkNestPrinted
	@nest VARCHAR(50),
	@when DATETIME,
	@username VARCHAR(255)
AS
BEGIN
	-- delete existing
	EXEC cds.UnmarkNestPrinted @nest;
	
	-- insert new
	INSERT INTO cds.ShopNestData (ProgramName, DatePrinted, PrintedBy)
	VALUES (@nest, @when, @username);
END;
GO