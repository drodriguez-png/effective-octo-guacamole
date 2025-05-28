USE SNInterDev;
GO

CREATE SCHEMA log;
GO

CREATE TABLE log.SapDemandCalls (
	LogId INT IDENTITY(1,1) PRIMARY KEY,
	LogDate DATETIME DEFAULT CURRENT_TIMESTAMP,
	ProcCalled VARCHAR(64),

	sap_event_id VARCHAR(50),
	sap_part_name VARCHAR(18),
	work_order VARCHAR(50),
	part_name VARCHAR(100),
	qty INT,
	matl VARCHAR(50),
	process VARCHAR(64),
	state VARCHAR(50),
	dwg VARCHAR(50),
	codegen VARCHAR(50),
	job VARCHAR(50),
	shipment VARCHAR(50),
	op1 VARCHAR(50),
	op2 VARCHAR(50),
	op3 VARCHAR(50),
	mark VARCHAR(50),
	raw_mm VARCHAR(50),
	due_date DATE,
	alloc_id INT
);
CREATE TABLE log.SapInventoryCalls (
	LogId INT IDENTITY(1,1) PRIMARY KEY,
	LogDate DATETIME DEFAULT CURRENT_TIMESTAMP,
	ProcCalled VARCHAR(64),

	sap_event_id VARCHAR(50),
	sheet_name VARCHAR(50),
	sheet_type VARCHAR(64),
	qty INT,
	matl VARCHAR(50),
	thk FLOAT,
	wid FLOAT,
	len FLOAT,
	mm VARCHAR(50),
	notes1 VARCHAR(50),
	notes2 VARCHAR(50),
	notes3 VARCHAR(50),
	notes4 VARCHAR(50)
);
CREATE TABLE log.FeedbackCalls (
	LogId INT IDENTITY(1,1) PRIMARY KEY,
	LogDate DATETIME DEFAULT CURRENT_TIMESTAMP,
	ProcCalled VARCHAR(64),

	feedback_id INT,
	archive_packet_id INT
);
CREATE TABLE log.UpdateProgramCalls (
	LogId INT IDENTITY(1,1) PRIMARY KEY,
	LogDate DATETIME DEFAULT CURRENT_TIMESTAMP,
	ProcCalled VARCHAR(64),

	sap_event_id VARCHAR(50),
	archive_packet_id INT,
	source VARCHAR(64),
	username VARCHAR(64)
);
GO
