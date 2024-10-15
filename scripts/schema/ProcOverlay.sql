
IF EXISTS (SELECT name FROM sys.procedures WHERE name = 'PreparePartOverlay')
	DROP PROCEDURE PreparePartOverlay;
IF EXISTS (SELECT name FROM sys.triggers WHERE name = 'PreSimTrans')
	DROP TRIGGER PreSimTrans;
IF EXISTS (SELECT name from sys.tables WHERE name = 'HssSimTrans')
	DROP TABLE HssSimTrans;
GO

CREATE TABLE HssSimTrans (
	Id INT PRIMARY KEY IDENTITY(1,1),
	Timestamp DATETIME NOT NULL DEFAULT(GETDATE()),
	Message VARCHAR(255)
);
GO

CREATE PROCEDURE PreparePartOverlay
	@PartName VARCHAR(255)
AS
	SELECT @PartName
GO

CREATE OR ALTER TRIGGER PreSimTrans
	ON TransAct
	INSTEAD OF INSERT
AS
BEGIN
	DECLARE @tcode VARCHAR(255);
	DECLARE @sheet VARCHAR(255);

	INSERT INTO HssSimTrans(Message)
	VALUES (FORMATMESSAGE('INSERT Trigger fired with rows: %d', @@ROWCOUNT))

	DECLARE cur CURSOR FORWARD_ONLY FOR
		SELECT TransType, ItemName
		FROM inserted
		WHERE TransType IN ('SN91A', 'SN70');
	OPEN cur;

	WHILE (1=1)
	BEGIN
		FETCH NEXT FROM cur INTO @tcode, @sheet;
		IF (@@FETCH_STATUS < 0)
			BREAK;

		PRINT 'Found HSS transaction: `' + @tcode + '` <sheet ' + @sheet + '>'
		INSERT INTO HssSimTrans(Message)
		VALUES
			('Found HSS transaction: `' + @tcode + '` <sheet ' + @sheet + '>');

		-- pre-overlay
		IF NOT EXISTS (SELECT * FROM TransAct WHERE TransType='SN95')
			INSERT INTO TransAct (TransType, District) VALUES ('SN95', 1)
		IF NOT EXISTS (SELECT * FROM TransAct WHERE TransType='SN95R')
			INSERT INTO TransAct (TransType, District) VALUES ('SN95R', 1)

		-- insert row into SimTrans input
		INSERT INTO TransAct(TransType,District,ItemName,Qty,Material,Thickness,Width,Length,PrimeCode)
		VALUES (@tcode,1,'N001',1,'MS',1.0,44,55,'test');
	END

	CLOSE cur;
	DEALLOCATE cur;
END
GO

--EXEC PreparePartOverlay @PartName='test'
--EXEC PreparePartOverlay @PartName='test'

select * from sys.triggers where name like '%SimTrans%' or name like '%Hss%'