-- PostgreSQL schema for SapInter system
-- Converted from SQL Server schema files

-- Create database
-- Note: This would typically be run separately as a superuser
-- CREATE DATABASE sapinter;

-- Use the database
-- \c sapinter;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS oys;
CREATE SCHEMA IF NOT EXISTS sap;
CREATE SCHEMA IF NOT EXISTS log;
CREATE SCHEMA IF NOT EXISTS cds;

-- =============================================================================
-- OYS SCHEMA TABLES (from SapInter_OysSchema.sql)
-- =============================================================================

-- Program table
CREATE TABLE oys.program (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    program_guid UUID NOT NULL UNIQUE,
    program_name VARCHAR(50),
    layout_number INTEGER,
    machine_name VARCHAR(50),
    cutting_time DOUBLE PRECISION,
    task_name VARCHAR(50),
    nest_type VARCHAR(64) CHECK (nest_type IN ('Slab', 'Standard', 'Split')),
    ws_name TEXT
);

-- Create index on auto_id (clustered equivalent)
CREATE INDEX ix_program_auto_id ON oys.program(auto_id);

-- ParentPlate table
CREATE TABLE oys.parent_plate (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    program_guid UUID NOT NULL REFERENCES oys.program(program_guid) ON DELETE CASCADE,
    plate_name VARCHAR(50),
    material VARCHAR(50),
    thickness DOUBLE PRECISION,
    area DOUBLE PRECISION
);

-- Create index on auto_id
CREATE INDEX ix_parent_plate_auto_id ON oys.parent_plate(auto_id);

-- ParentPart table
CREATE TABLE oys.parent_part (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    program_guid UUID NOT NULL,
    parent_part_guid UUID NOT NULL,
    sn_part_name VARCHAR(100),
    qty_program INTEGER,
    true_area DOUBLE PRECISION,
    nested_area DOUBLE PRECISION,
    PRIMARY KEY (program_guid, parent_part_guid),
    FOREIGN KEY (program_guid) REFERENCES oys.parent_plate(program_guid) ON DELETE CASCADE
);

-- Create index on auto_id
CREATE INDEX ix_parent_part_auto_id ON oys.parent_part(auto_id);

-- ChildPlate table
CREATE TABLE oys.child_plate (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    program_guid UUID NOT NULL,
    child_plate_guid UUID NOT NULL UNIQUE,
    plate_name VARCHAR(50),
    plate_number INTEGER NOT NULL DEFAULT 1,
    material_master VARCHAR(50),
    material VARCHAR(50),
    thickness DOUBLE PRECISION,
    child_nest_task_name VARCHAR(50),
    child_nest_program_name VARCHAR(50),
    child_nest_repeat_id INTEGER,
    area DOUBLE PRECISION,
    PRIMARY KEY (program_guid, child_plate_guid),
    FOREIGN KEY (program_guid) REFERENCES oys.program(program_guid) ON DELETE CASCADE
);

-- Create index on auto_id
CREATE INDEX ix_child_plate_auto_id ON oys.child_plate(auto_id);

-- ChildPart table
CREATE TABLE oys.child_part (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    child_plate_guid UUID NOT NULL,
    child_part_guid UUID NOT NULL,
    parent_part_guid UUID NOT NULL,
    sn_part_name VARCHAR(100),
    sap_part_name VARCHAR(100),
    qty_program INTEGER,
    job VARCHAR(50),
    shipment VARCHAR(50),
    true_area DOUBLE PRECISION,
    nested_area DOUBLE PRECISION,
    PRIMARY KEY (child_plate_guid, child_part_guid),
    FOREIGN KEY (child_plate_guid) REFERENCES oys.child_plate(child_plate_guid) ON DELETE CASCADE
);

-- Create index on auto_id
CREATE INDEX ix_child_part_auto_id ON oys.child_part(auto_id);

-- Remnant table
CREATE TABLE oys.remnant (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    child_plate_guid UUID NOT NULL,
    remnant_guid UUID NOT NULL,
    remnant_name VARCHAR(50),
    area DOUBLE PRECISION,
    is_rectangular BOOLEAN,
    rect_width DOUBLE PRECISION,
    rect_length DOUBLE PRECISION,
    PRIMARY KEY (child_plate_guid, remnant_guid),
    FOREIGN KEY (child_plate_guid) REFERENCES oys.child_plate(child_plate_guid) ON DELETE CASCADE
);

-- Create index on auto_id
CREATE INDEX ix_remnant_auto_id ON oys.remnant(auto_id);

-- Status table
CREATE TABLE oys.status (
    auto_id BIGSERIAL PRIMARY KEY,
    db_entry_datetime TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    program_guid UUID NOT NULL,
    status_guid UUID NOT NULL,
    sigmanest_status VARCHAR(64) CHECK (sigmanest_status IN ('Created', 'Released', 'Deleted', 'Updated')),
    sap_status VARCHAR(64),
    source VARCHAR(64) CHECK (source IN ('SAPPost', 'Split', 'CodeMover', 'Boomi', 'ProgramDelete')),
    user_name VARCHAR(64),
    PRIMARY KEY (program_guid, status_guid),
    FOREIGN KEY (program_guid) REFERENCES oys.program(program_guid) ON DELETE CASCADE
);

-- Create index on auto_id
CREATE INDEX ix_status_auto_id ON oys.status(auto_id);

-- =============================================================================
-- SAP SCHEMA TABLES (from SapInter_HssSchema.sql)
-- =============================================================================

-- InterfaceConfig table (singleton pattern with check constraint)
CREATE TABLE sap.interface_config (
    lock SMALLINT NOT NULL DEFAULT 1 CHECK (lock = 1),
    simtrans_district INTEGER NOT NULL,
    remnant_dxf_path VARCHAR(255) CHECK (remnant_dxf_path !~ '[\/:*?"<>|]'),
    heat_swap_keyword VARCHAR(64),
    log_procedure_calls BOOLEAN,
    PRIMARY KEY (lock)
);

-- InterfaceVersion table (singleton pattern)
CREATE TABLE sap.interface_version (
    lock SMALLINT NOT NULL DEFAULT 1 CHECK (lock = 1),
    major INTEGER NOT NULL,
    minor INTEGER NOT NULL,
    patch INTEGER NOT NULL,
    PRIMARY KEY (lock)
);

-- MatlCompatMap table
CREATE TABLE sap.matl_compat_map (
    id SERIAL PRIMARY KEY,
    parent_matl VARCHAR(50),
    child_matl VARCHAR(50),
    use_intermediate_compat BOOLEAN,
    is_bidirectional BOOLEAN,
    CHECK (parent_matl != child_matl)
);

-- DemandQueue table
CREATE TABLE sap.demand_queue (
    id BIGSERIAL PRIMARY KEY,
    sap_event_id VARCHAR(50),
    sap_part_name VARCHAR(18),
    work_order VARCHAR(50),
    part_name VARCHAR(100),
    qty INTEGER,
    matl VARCHAR(50),
    on_hold BOOLEAN,
    state VARCHAR(50),
    dwg VARCHAR(50),
    codegen VARCHAR(50),
    job VARCHAR(50),
    shipment VARCHAR(50),
    op1 VARCHAR(50),
    op2 VARCHAR(50),
    op3 VARCHAR(50),
    mark VARCHAR(50),
    raw_material_master VARCHAR(50),
    due_date DATE
);

-- RenamedDemandAllocation table
CREATE TABLE sap.renamed_demand_allocation (
    id BIGSERIAL PRIMARY KEY,
    original_part_name VARCHAR(50),
    new_part_name VARCHAR(50),
    work_order_name VARCHAR(50),
    qty INTEGER,
    CHECK (original_part_name != new_part_name)
);

-- PartOperations table
CREATE TABLE sap.part_operations (
    id BIGSERIAL PRIMARY KEY,
    part_name VARCHAR(50),
    operation2 VARCHAR(50),
    operation3 VARCHAR(50),
    operation4 VARCHAR(50),
    auto_process_instruction VARCHAR(50)
);

-- InventoryQueue table
CREATE TABLE sap.inventory_queue (
    id BIGSERIAL PRIMARY KEY,
    sap_event_id VARCHAR(50),
    sheet_name VARCHAR(50),
    sheet_type VARCHAR(64),
    qty INTEGER,
    matl VARCHAR(50),
    thk DOUBLE PRECISION,
    width DOUBLE PRECISION,
    length DOUBLE PRECISION,
    material_master VARCHAR(50),
    notes1 VARCHAR(50),
    notes2 VARCHAR(50),
    notes3 VARCHAR(50),
    notes4 VARCHAR(50)
);

-- FeedbackQueue table
CREATE TABLE sap.feedback_queue (
    feedback_id BIGSERIAL PRIMARY KEY,
    data_set VARCHAR(64),
    archive_packet_id BIGINT,
    status VARCHAR(64),
    program_name VARCHAR(50),
    repeat_id INTEGER,
    machine_name VARCHAR(50),
    cutting_time INTEGER,
    sheet_index INTEGER,
    sheet_name VARCHAR(50),
    material_master VARCHAR(50),
    part_name VARCHAR(100),
    part_qty INTEGER,
    job VARCHAR(50),
    shipment VARCHAR(50),
    true_area DOUBLE PRECISION,
    nested_area DOUBLE PRECISION,
    remnant_name VARCHAR(50),
    length INTEGER,
    width INTEGER,
    area DOUBLE PRECISION,
    is_rectangular CHAR(1)
);

-- MoveCodeQueue table
CREATE TABLE sap.move_code_queue (
    id BIGSERIAL PRIMARY KEY,
    machine_name VARCHAR(50),
    program_name VARCHAR(50)
);

-- =============================================================================
-- LOG SCHEMA TABLES (from SapInter_LogsSchema.sql)
-- =============================================================================

-- SapDemandCalls log table
CREATE TABLE log.sap_demand_calls (
    log_id SERIAL PRIMARY KEY,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    proc_called VARCHAR(64),
    sap_event_id VARCHAR(50),
    sap_part_name VARCHAR(18),
    work_order VARCHAR(50),
    part_name VARCHAR(100),
    qty INTEGER,
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
    alloc_id INTEGER
);

-- SapInventoryCalls log table
CREATE TABLE log.sap_inventory_calls (
    log_id SERIAL PRIMARY KEY,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    proc_called VARCHAR(64),
    sap_event_id VARCHAR(50),
    sheet_name VARCHAR(50),
    sheet_type VARCHAR(64),
    qty INTEGER,
    matl VARCHAR(50),
    thk DOUBLE PRECISION,
    wid DOUBLE PRECISION,
    len DOUBLE PRECISION,
    mm VARCHAR(50),
    notes1 VARCHAR(50),
    notes2 VARCHAR(50),
    notes3 VARCHAR(50),
    notes4 VARCHAR(50)
);

-- FeedbackCalls log table
CREATE TABLE log.feedback_calls (
    log_id SERIAL PRIMARY KEY,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    proc_called VARCHAR(64),
    feedback_id INTEGER,
    archive_packet_id INTEGER
);

-- UpdateProgramCalls log table
CREATE TABLE log.update_program_calls (
    log_id SERIAL PRIMARY KEY,
    log_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    proc_called VARCHAR(64),
    sap_event_id VARCHAR(50),
    archive_packet_id INTEGER,
    source VARCHAR(64),
    username VARCHAR(64)
);

-- =============================================================================
-- CDS SCHEMA TABLES (implied from SapInter_CdsProc.sql)
-- =============================================================================

-- ShopNestData table (implied from procedures)
CREATE TABLE cds.shop_nest_data (
    id SERIAL PRIMARY KEY,
    program_name VARCHAR(50),
    date_printed TIMESTAMP WITH TIME ZONE,
    printed_by VARCHAR(255)
);

-- =============================================================================
-- VIEWS (from SapInter_Views.sql, converted to PostgreSQL syntax)
-- =============================================================================

-- InterCfgState view
CREATE OR REPLACE VIEW sap.inter_cfg_state AS
SELECT
    REPLACE(CURRENT_DATABASE(), 'sninter', '')::VARCHAR(3) AS environment,
    CONCAT('v', major, '.', minor, '.', patch) AS version,
    simtrans_district,
    log_procedure_calls
FROM sap.interface_config, sap.interface_version;

-- MatlCompatTable view (recursive CTE)
CREATE OR REPLACE VIEW sap.matl_compat_table AS
WITH RECURSIVE
    with_m270_map AS (
        SELECT
            parent_matl,
            child_matl,
            use_intermediate_compat,
            1 AS use_recursion
        FROM sap.matl_compat_map
        UNION
        SELECT
            child_matl,
            parent_matl,
            use_intermediate_compat,
            0 AS use_recursion
        FROM sap.matl_compat_map
        WHERE is_bidirectional = true
    ),
    expanded_compat AS (
        SELECT
            parent_matl,
            child_matl,
            use_recursion
        FROM with_m270_map
        WHERE use_intermediate_compat = true
        UNION ALL
        SELECT
            base_compat.parent_matl,
            recursive_compat.child_matl,
            base_compat.use_recursion
        FROM with_m270_map AS base_compat
        INNER JOIN expanded_compat AS recursive_compat
            ON base_compat.child_matl = recursive_compat.parent_matl
        WHERE base_compat.parent_matl != recursive_compat.child_matl
        AND recursive_compat.use_recursion = 1
    )
SELECT DISTINCT
    parent_matl,
    child_matl
FROM expanded_compat;

-- ProgramId view
CREATE OR REPLACE VIEW sap.program_id AS
SELECT DISTINCT
    program.program_guid,
    program.nest_type,
    child_plate.auto_id AS archive_packet_id,
    CASE program.nest_type
        WHEN 'Slab' THEN 1
        ELSE child_plate.child_nest_repeat_id
    END AS repeat_id
FROM oys.program
INNER JOIN oys.child_plate
    ON child_plate.program_guid = program.program_guid
WHERE child_plate.plate_number = 1;

-- ChildNestId view
CREATE OR REPLACE VIEW sap.child_nest_id AS
SELECT 
    program_id.program_guid,
    program_id.archive_packet_id,
    child_plate.child_plate_guid,
    child_plate.plate_number AS sheet_index,
    child_plate.child_nest_program_name AS program_name,
    child_plate.child_nest_repeat_id AS repeat_id
FROM oys.child_plate
INNER JOIN sap.program_id
    ON program_id.program_guid = child_plate.program_guid
    AND program_id.repeat_id = child_plate.child_nest_repeat_id;

-- ProgramStatus view
CREATE OR REPLACE VIEW sap.program_status AS
WITH last_status AS (
    SELECT
        MAX(status.auto_id) AS status_id
    FROM oys.status
    INNER JOIN oys.program ON program.program_guid = status.program_guid
    GROUP BY program.program_name
)
SELECT
    status_id,
    status.program_guid,
    sigmanest_status,
    program_name
FROM last_status
INNER JOIN oys.status
    ON status.auto_id = last_status.status_id
INNER JOIN oys.program
    ON program.program_guid = status.program_guid;

-- CodeDeliveryList view
CREATE OR REPLACE VIEW sap.code_delivery_list AS
SELECT
    status_id AS id,
    program.program_name,
    program.machine_name,
    parent_part.sn_part_name AS parent_part,
    parent_part.qty_program,
    job,
    shipment
FROM sap.program_status
INNER JOIN oys.program
    ON program.program_guid = program_status.program_guid
INNER JOIN oys.parent_part
    ON parent_part.program_guid = program_status.program_guid
LEFT JOIN oys.child_plate
    ON child_plate.program_guid = program_status.program_guid
INNER JOIN oys.child_part
    ON child_part.child_plate_guid = child_plate.child_plate_guid;

-- PartsOnProgram view
CREATE OR REPLACE VIEW sap.parts_on_program AS
SELECT
    program_name,
    sigmanest_status AS program_status,
    sn_part_name AS part_name
FROM sap.program_status
INNER JOIN oys.child_plate
    ON child_plate.program_guid = program_status.program_guid
INNER JOIN oys.child_part
    ON child_part.child_plate_guid = child_plate.child_plate_guid;

-- ActivePrograms view
CREATE OR REPLACE VIEW sap.active_programs AS
WITH active_guid AS (
    SELECT program_guid FROM oys.status
    EXCEPT
    SELECT program_guid FROM oys.status
    WHERE sigmanest_status IN ('Updated', 'Deleted') 
)
SELECT
    program_id.archive_packet_id,
    program.db_entry_datetime AS post_datetime,
    program.program_guid,
    program.program_name,
    program.machine_name,
    program.task_name,
    program.ws_name,
    program.nest_type,
    status.sigmanest_status,
    status.sap_status,
    status.source,
    status.user_name
FROM active_guid
INNER JOIN oys.program
    ON program.program_guid = active_guid.program_guid
INNER JOIN sap.program_id
    ON program_id.program_guid = program.program_guid
INNER JOIN sap.program_status
    ON program_status.program_guid = program.program_guid
INNER JOIN oys.status
    ON status.auto_id = program_status.status_id;

-- JobShipments view
CREATE OR REPLACE VIEW cds.job_shipments AS
SELECT DISTINCT
    CONCAT(job, '-', shipment) AS job_shipment,
    job,
    shipment
FROM oys.child_part;

-- =============================================================================
-- INITIAL DATA INSERTS
-- =============================================================================

-- Insert default configuration
INSERT INTO sap.interface_config (
    simtrans_district, 
    remnant_dxf_path, 
    heat_swap_keyword, 
    log_procedure_calls
) VALUES (
    1,
    '\\hssieng\SNDataDev\RemSaveOutput\DXF',
    'HighHeatNum',
    false
);

-- Insert default version
INSERT INTO sap.interface_version (major, minor, patch)
VALUES (0, 0, 0);

-- Insert material compatibility mappings
INSERT INTO sap.matl_compat_map (
    parent_matl, child_matl, use_intermediate_compat, is_bidirectional
) VALUES
    ('50/50WF2',   'A709-50WF2', true, false),
    ('50/50WF2',   'A709-50F2',  true, false),
    ('50/50WF2',   '50/50WT2',   false, false),
    ('50/50WT2',   'A709-50WT2', true, false),
    ('50/50WT2',   'A709-50T2',  true, false),
    ('50/50WT2',   '50/50W',     false, false),
    ('50/50W',     'A709-50W',   true, false),
    ('50/50W',     'A709-50',    true, false),
    ('A709-50WF2', 'A709-50WT2', true, false),
    ('A709-50WT2', 'A709-50W',   true, false),
    ('A709-50F2',  'A709-50T2',  true, false),
    ('A709-50T2',  'A709-50',    true, false),
    -- A709 -> M270 bidirectional mappings
    ('A709-50WF2', 'M270-50WF2', true, true),
    ('A709-50WT2', 'M270-50WT2', true, true),
    ('A709-50W',   'M270-50W',   true, true),
    ('A709-50F2',  'M270-50F2',  true, true),
    ('A709-50T2',  'M270-50T2',  true, true),
    ('A709-50',    'M270-50',    true, true);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Additional indexes for common query patterns
CREATE INDEX idx_child_part_job_shipment ON oys.child_part(job, shipment);
CREATE INDEX idx_status_program_guid ON oys.status(program_guid);
CREATE INDEX idx_status_sap_status ON oys.status(sap_status);
CREATE INDEX idx_program_program_name ON oys.program(program_name);
CREATE INDEX idx_demand_queue_sap_part_name ON sap.demand_queue(sap_part_name);
CREATE INDEX idx_inventory_queue_sheet_name ON sap.inventory_queue(sheet_name);
CREATE INDEX idx_feedback_queue_archive_packet_id ON sap.feedback_queue(archive_packet_id);

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON SCHEMA oys IS 'OYS (Optimization Yield System) schema containing program, plate, part, and remnant data';
COMMENT ON SCHEMA sap IS 'SAP interface schema containing queues, configuration, and mapping tables';
COMMENT ON SCHEMA log IS 'Logging schema for procedure call tracking and debugging';
COMMENT ON SCHEMA cds IS 'CDS (Custom Data Store) schema for shop floor operations';

COMMENT ON TABLE oys.program IS 'Main program table storing nesting program information';
COMMENT ON TABLE oys.status IS 'Program status tracking for SAP synchronization';
COMMENT ON TABLE sap.interface_config IS 'Singleton configuration table for SAP interface settings';
COMMENT ON TABLE sap.demand_queue IS 'Queue for SAP demand/work order processing';
COMMENT ON TABLE sap.inventory_queue IS 'Queue for SAP inventory/sheet processing';
COMMENT ON TABLE sap.feedback_queue IS 'Queue for sending program results back to SAP';