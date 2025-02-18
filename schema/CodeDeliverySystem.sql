CREATE TABLE HighSteel.CodeDeliverySystem (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	ProgramName VARCHAR(50),
	CheckedBy VARCHAR(255),
	Printed DATE,
	Notes VARCHAR(255)
);
GO

CREATE OR ALTER VIEW HighSteel.CodeDeliverySystemData AS
WITH
	mm_map AS (
		SELECT DISTINCT
			-- assume that every instance of MaterialMaster has same size
			Data10 AS MaterialMaster,
			-- use MIN() to ensure we only get 1 Size per MaterialMaster
			MIN(Data11) AS Size
		FROM Part
		WHERE Data10 != '' AND Data11 != ''
		GROUP BY Data10
	),
	Completed AS (
		SELECT
			prog.ArchivePacketID AS Id,
			parts.WoNumber,
			parts.PartName,
			parts.Data9 AS Mark,
			parts.QtyProgram AS Qty,
			parts.Data1 AS Job,
			parts.Data2 AS Shipment,

			prog.ProgramName,
			prog.MachineName,

			inv.SheetName,
			inv.Material,
			inv.Thickness,
			inv.Width,
			inv.Length,
			inv.PrimeCode AS MaterialMaster,
			'Completed' AS Status
		FROM PartArchive AS parts
		INNER JOIN ProgArchive AS prog
			ON prog.ArchivePacketID=parts.ArchivePacketID
		INNER JOIN StockArchive AS inv
			ON inv.ArchivePacketID=prog.ArchivePacketID
		WHERE prog.TransType='SN102'
		-- TODO: filter out reposted programs
	),
	InProcess AS (
		SELECT
			Program.ArchivePacketID AS Id,
			Part.WoNumber,
			Part.PartName,
			Part.Data9 AS Mark,
			PIP.QtyInProcess  AS Qty,
			Part.Data1 AS Job,
			Part.Data2 AS Shipment,

			Program.ProgramName,
			Program.MachineName,

			Stock.SheetName,
			Stock.Material,
			Stock.Thickness,
			Stock.Width,
			Stock.Length,
			Stock.PrimeCode AS MaterialMaster,
			'Nested' AS Status
		FROM PIP
		INNER JOIN Part
			ON PIP.WONumber=Part.WONumber
			AND PIP.PartName=Part.PartName
		INNER JOIN Program
			ON Program.ProgramName=PIP.ProgramName
			AND Program.RepeatID=PIP.RepeatID
		INNER JOIN Stock
			ON Stock.SheetName=Program.SheetName
	),
	NeedsNested AS (
		SELECT
			WONumber,
			PartName,
			Data9 AS Mark,
			QtyOrdered-QtyCompleted-QtyInProcess AS Qty,
			Data1 AS Job,
			Data2 AS Shipment,
			'Todo' AS Status
		FROM PartWithQtyInProcess AS parts
		WHERE QtyOrdered-QtyCompleted-QtyInProcess > 0
	)
	SELECT
		AllParts.Id,
		WONumber,
		PartName,
		Mark,
		Qty,
		Job,
		Shipment,

		AllParts.ProgramName,
		HeatSwapConfig.Name AS MachineName,

		SheetName,
		Material,
		Thickness,
		Width,
		Length,
		AllParts.MaterialMaster,
		Size,
		'Todo' AS Status,
		CheckedBy,
		Printed,
		Notes
	FROM (
		SELECT * FROM Completed
		UNION
		SELECT * FROM InProcess
		UNION
		SELECT
			Null AS Id,
			WONumber,
			PartName,
			Mark,
			Qty,
			Job,
			Shipment,

			Null AS ProgramName,
			Null AS MachineName,

			Null AS SheetName,
			Null AS Material,
			Null AS Thickness,
			Null AS Width,
			Null AS Length,
			Null AS MaterialMaster,
			'Todo' AS Status
		FROM NeedsNested
	) AS AllParts
	LEFT JOIN mm_map
		ON mm_map.MaterialMaster=AllParts.MaterialMaster
	LEFT JOIN HighSteel.CodeDeliverySystem
		ON AllParts.ProgramName=CodeDeliverySystem.ProgramName
	LEFT JOIN HighSteel.HeatSwapConfig
		ON AllParts.MachineName=HeatSwapConfig.PostName
	ORDER BY PartName;
GO