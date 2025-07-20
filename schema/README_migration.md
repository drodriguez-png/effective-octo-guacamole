# SapInter Database Migration

This directory contains scripts to migrate data from SQL Server to PostgreSQL.

## Files

- `postgres_schema.sql` - PostgreSQL schema definition
- `export_sqlserver_data.py` - Python script to export data from SQL Server
- `import_postgresql_data.py` - Python script to import data into PostgreSQL
- `migrate_data.sh` - Linux/macOS automation script
- `migrate_data.bat` - Windows automation script
- `requirements.txt` - Python dependencies

## Prerequisites

### Python Dependencies
```bash
pip install -r requirements.txt
```

### Database Drivers

**SQL Server:**
- Install ODBC Driver 17 for SQL Server
- Linux: `sudo apt-get install mssql-tools unixodbc-dev` (Ubuntu/Debian)
- Windows: Download from Microsoft

**PostgreSQL:**
- Client tools for schema creation
- Linux: `sudo apt-get install postgresql-client`
- Windows: Download from PostgreSQL.org

## Usage

### Full Migration (Automated)

**Linux/macOS:**
```bash
./migrate_data.sh \
  --sql-server SQLSERVER01 \
  --pg-host postgres.example.com \
  --pg-database sapinter \
  --pg-username sapinter_user \
  --pg-password mypassword \
  --clear all
```

**Windows:**
```cmd
migrate_data.bat ^
  --sql-server SQLSERVER01 ^
  --pg-host postgres.example.com ^
  --pg-database sapinter ^
  --pg-username sapinter_user ^
  --pg-password mypassword ^
  --clear all
```

### Manual Steps

#### 1. Create PostgreSQL Database and Schema
```sql
CREATE DATABASE sapinter;
\c sapinter;
\i postgres_schema.sql
```

#### 2. Export Data from SQL Server
```bash
python export_sqlserver_data.py \
  --server SQLSERVER01 \
  --database SNInterDev \
  --output-dir ./export_data
```

#### 3. Import Data to PostgreSQL
```bash
python import_postgresql_data.py \
  --host postgres.example.com \
  --database sapinter \
  --username sapinter_user \
  --password mypassword \
  --input-dir ./export_data \
  --clear all
```

## Configuration Options

### Export Options
- `--server` - SQL Server instance name (required)
- `--database` - Source database name (default: SNInterDev)
- `--username/--password` - SQL Server credentials (optional, uses trusted connection by default)
- `--output-dir` - Export directory (default: ./export_data)

### Import Options
- `--host` - PostgreSQL host (required)
- `--port` - PostgreSQL port (default: 5432)
- `--database` - Target database name (required)
- `--username/--password` - PostgreSQL credentials (required)
- `--input-dir` - Import directory (default: ./export_data)
- `--clear` - Clear existing data mode:
  - `none` - Don't clear any data (default)
  - `all` - Clear all data including configuration
  - `config` - Clear only configuration tables
  - `data` - Clear data tables but keep configuration
- `--batch-size` - Insert batch size (default: 1000)

### Automation Script Options
- `--export-only` - Only export, don't import
- `--import-only` - Only import, don't export
- `--skip-schema` - Skip schema creation (assume it exists)

## Data Flow

1. **Export Phase:**
   - Connects to SQL Server using pyodbc
   - Exports each table to CSV format
   - Handles data type conversions (GUID → UUID, BIT → Boolean, etc.)
   - Creates manifest file with export statistics

2. **Import Phase:**
   - Creates PostgreSQL schemas and tables
   - Imports data in dependency order
   - Converts data types for PostgreSQL compatibility
   - Resets sequences to correct values
   - Creates import statistics

## Data Type Conversions

| SQL Server | PostgreSQL | Notes |
|------------|------------|-------|
| BIGINT IDENTITY | BIGSERIAL | Auto-incrementing sequences |
| INT IDENTITY | SERIAL | Auto-incrementing sequences |
| UNIQUEIDENTIFIER | UUID | Preserved as UUID strings |
| DATETIME | TIMESTAMP WITH TIME ZONE | Timezone-aware timestamps |
| FLOAT | DOUBLE PRECISION | Double precision floating point |
| BIT | BOOLEAN | Boolean values |
| NVARCHAR(MAX) | TEXT | Variable length text |

## Schema Differences

### Table Names
- SQL Server: `CamelCase` → PostgreSQL: `snake_case`
- Schema prefixes preserved: `oys.Program` → `oys.program`

### Constraints
- Primary keys and foreign keys preserved
- Check constraints converted to PostgreSQL syntax
- Unique constraints maintained

### Indexes
- Clustered indexes converted to regular indexes
- Non-clustered indexes preserved
- Additional performance indexes added

## Troubleshooting

### Common Issues

**Connection Errors:**
- Verify SQL Server allows remote connections
- Check PostgreSQL pg_hba.conf for authentication
- Ensure firewall allows database ports

**Data Type Errors:**
- Check for NULL values in non-nullable columns
- Verify date formats are valid
- Ensure GUID fields contain valid UUIDs

**Memory Issues:**
- Reduce batch size for large tables
- Increase available memory for Python process

**Performance:**
- Use `--batch-size` to optimize insert performance
- Consider running export/import separately for large datasets

### Log Files
- `migration.log` - Detailed migration log
- `export_manifest.json` - Export statistics and file list
- `import_stats.json` - Import statistics and row counts

## Security Considerations

- Store passwords in environment variables rather than command line
- Use least-privilege database accounts
- Secure export directory with appropriate file permissions
- Consider encrypting sensitive data during transport

## Environment Variables

Set passwords via environment variables for security:
```bash
export SQL_PASSWORD="your_sql_password"
export PG_PASSWORD="your_pg_password"
```

## Examples

### Development Migration
```bash
# Export from dev SQL Server
./migrate_data.sh --sql-server DEV-SQL01 --export-only

# Import to local PostgreSQL
./migrate_data.sh --pg-host localhost --pg-database sapinter_dev \
  --pg-username dev_user --pg-password dev_pass --import-only --clear all
```

### Production Migration
```bash
# Full production migration with configuration backup
./migrate_data.sh \
  --sql-server PROD-SQL01 \
  --sql-database SNInterProd \
  --pg-host prod-postgres.company.com \
  --pg-database sapinter \
  --pg-username sapinter_prod \
  --pg-password $PG_PASSWORD \
  --clear data \
  --batch-size 5000
```

### Incremental Updates
```bash
# Only import new data without clearing existing
./migrate_data.sh \
  --sql-server PROD-SQL01 \
  --pg-host prod-postgres.company.com \
  --pg-database sapinter \
  --pg-username sapinter_prod \
  --pg-password $PG_PASSWORD \
  --clear none
```