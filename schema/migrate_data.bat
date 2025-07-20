@echo off
setlocal enabledelayedexpansion

REM SapInter Data Migration Script for Windows
REM Automates the process of exporting from SQL Server and importing to PostgreSQL

REM Default configuration
set "SCRIPT_DIR=%~dp0"
set "EXPORT_DIR=.\export_data"
set "LOG_FILE=.\migration.log"

REM SQL Server configuration
set "SQL_SERVER="
set "SQL_DATABASE=SNInterDev"
set "SQL_TRUSTED=true"
set "SQL_USERNAME="
set "SQL_PASSWORD="

REM PostgreSQL configuration
set "PG_HOST="
set "PG_PORT=5432"
set "PG_DATABASE="
set "PG_USERNAME="
set "PG_PASSWORD="

REM Options
set "CLEAR_MODE=none"
set "BATCH_SIZE=1000"
set "EXPORT_ONLY=false"
set "IMPORT_ONLY=false"
set "SKIP_SCHEMA=false"

REM Parse command line arguments
:parse_args
if "%~1"=="" goto validate_args
if "%~1"=="-h" goto show_help
if "%~1"=="--help" goto show_help
if "%~1"=="--sql-server" (
    set "SQL_SERVER=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--sql-database" (
    set "SQL_DATABASE=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--sql-username" (
    set "SQL_USERNAME=%~2"
    set "SQL_TRUSTED=false"
    shift & shift & goto parse_args
)
if "%~1"=="--sql-password" (
    set "SQL_PASSWORD=%~2"
    set "SQL_TRUSTED=false"
    shift & shift & goto parse_args
)
if "%~1"=="--sql-trusted" (
    set "SQL_TRUSTED=true"
    shift & goto parse_args
)
if "%~1"=="--pg-host" (
    set "PG_HOST=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--pg-port" (
    set "PG_PORT=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--pg-database" (
    set "PG_DATABASE=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--pg-username" (
    set "PG_USERNAME=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--pg-password" (
    set "PG_PASSWORD=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--export-dir" (
    set "EXPORT_DIR=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--clear" (
    set "CLEAR_MODE=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--batch-size" (
    set "BATCH_SIZE=%~2"
    shift & shift & goto parse_args
)
if "%~1"=="--export-only" (
    set "EXPORT_ONLY=true"
    shift & goto parse_args
)
if "%~1"=="--import-only" (
    set "IMPORT_ONLY=true"
    shift & goto parse_args
)
if "%~1"=="--skip-schema" (
    set "SKIP_SCHEMA=true"
    shift & goto parse_args
)
if "%~1"=="--log-file" (
    set "LOG_FILE=%~2"
    shift & shift & goto parse_args
)
echo ERROR: Unknown option: %~1
exit /b 1

:show_help
echo SapInter Data Migration Script for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo OPTIONS:
echo     -h, --help              Show this help message
echo.
echo     SQL Server Options:
echo     --sql-server SERVER     SQL Server instance name (required)
echo     --sql-database DB       SQL Server database name (default: SNInterDev)
echo     --sql-username USER     SQL Server username (for non-trusted connections)
echo     --sql-password PASS     SQL Server password (for non-trusted connections)
echo     --sql-trusted           Use trusted connection (default: true)
echo.
echo     PostgreSQL Options:
echo     --pg-host HOST          PostgreSQL host (required)
echo     --pg-port PORT          PostgreSQL port (default: 5432)
echo     --pg-database DB        PostgreSQL database name (required)
echo     --pg-username USER      PostgreSQL username (required)
echo     --pg-password PASS      PostgreSQL password (required)
echo.
echo     Migration Options:
echo     --export-dir DIR        Export directory (default: .\export_data)
echo     --clear MODE            Clear existing data: none, all, config, data (default: none)
echo     --batch-size SIZE       Batch size for imports (default: 1000)
echo     --export-only           Only export data, don't import
echo     --import-only           Only import data, don't export
echo     --skip-schema           Skip schema creation (assume it exists)
echo.
echo     Logging:
echo     --log-file FILE         Log file path (default: .\migration.log)
echo.
echo EXAMPLES:
echo     REM Full migration with trusted connection
echo     %~nx0 --sql-server SQLSERVER01 ^
echo           --pg-host postgres.example.com ^
echo           --pg-database sapinter ^
echo           --pg-username sapinter_user ^
echo           --pg-password mypassword ^
echo           --clear all
echo.
echo     REM Export only
echo     %~nx0 --sql-server SQLSERVER01 --export-only
echo.
echo ENVIRONMENT VARIABLES:
echo     You can also set credentials via environment variables:
echo     SQL_PASSWORD, PG_PASSWORD
echo.
exit /b 0

:validate_args
REM Check for environment variable passwords
if "%SQL_PASSWORD%"=="" if not "%SQL_PASSWORD_ENV%"=="" set "SQL_PASSWORD=%SQL_PASSWORD_ENV%"
if "%PG_PASSWORD%"=="" if not "%PG_PASSWORD_ENV%"=="" set "PG_PASSWORD=%PG_PASSWORD_ENV%"

REM Validate required parameters
if "%EXPORT_ONLY%"=="false" if "%IMPORT_ONLY%"=="false" (
    REM Full migration - need both SQL Server and PostgreSQL info
    if "%SQL_SERVER%"=="" (
        echo ERROR: SQL Server instance name is required (--sql-server)
        exit /b 1
    )
    if "%PG_HOST%"=="" (
        echo ERROR: PostgreSQL host is required (--pg-host)
        exit /b 1
    )
    if "%PG_DATABASE%"=="" (
        echo ERROR: PostgreSQL database is required (--pg-database)
        exit /b 1
    )
    if "%PG_USERNAME%"=="" (
        echo ERROR: PostgreSQL username is required (--pg-username)
        exit /b 1
    )
    if "%PG_PASSWORD%"=="" (
        echo ERROR: PostgreSQL password is required (--pg-password)
        exit /b 1
    )
) else if "%EXPORT_ONLY%"=="true" (
    REM Export only - need SQL Server info
    if "%SQL_SERVER%"=="" (
        echo ERROR: SQL Server instance name is required for export (--sql-server)
        exit /b 1
    )
) else if "%IMPORT_ONLY%"=="true" (
    REM Import only - need PostgreSQL info
    if "%PG_HOST%"=="" (
        echo ERROR: PostgreSQL host is required for import (--pg-host)
        exit /b 1
    )
    if "%PG_DATABASE%"=="" (
        echo ERROR: PostgreSQL database is required for import (--pg-database)
        exit /b 1
    )
    if "%PG_USERNAME%"=="" (
        echo ERROR: PostgreSQL username is required for import (--pg-username)
        exit /b 1
    )
    if "%PG_PASSWORD%"=="" (
        echo ERROR: PostgreSQL password is required for import (--pg-password)
        exit /b 1
    )
)

goto main

:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
echo [%date% %time%] %~1
exit /b 0

:error
echo ERROR: %~1 >> "%LOG_FILE%"
echo ERROR: %~1
exit /b 1

:info
echo INFO: %~1 >> "%LOG_FILE%"
echo INFO: %~1
exit /b 0

:success
echo SUCCESS: %~1 >> "%LOG_FILE%"
echo SUCCESS: %~1
exit /b 0

:check_python_deps
call :info "Checking Python dependencies..."

if "%EXPORT_ONLY%"=="false" if "%IMPORT_ONLY%"=="true" (
    REM Only need PostgreSQL dependencies
    python -c "import psycopg2" 2>nul || (
        call :error "psycopg2 not installed. Run: pip install psycopg2-binary"
        exit /b 1
    )
) else if "%EXPORT_ONLY%"=="true" if "%IMPORT_ONLY%"=="false" (
    REM Only need SQL Server dependencies
    python -c "import pyodbc" 2>nul || (
        call :error "pyodbc not installed. Run: pip install pyodbc"
        exit /b 1
    )
) else (
    REM Need both
    python -c "import pyodbc" 2>nul || (
        call :error "pyodbc not installed. Run: pip install pyodbc"
        exit /b 1
    )
    python -c "import psycopg2" 2>nul || (
        call :error "psycopg2 not installed. Run: pip install psycopg2-binary"
        exit /b 1
    )
)

call :success "Python dependencies OK"
exit /b 0

:create_schema
if "%SKIP_SCHEMA%"=="true" (
    call :info "Skipping schema creation"
    exit /b 0
)

call :info "Creating PostgreSQL schema..."

set "PGPASSWORD=%PG_PASSWORD%"

psql -h "%PG_HOST%" -p "%PG_PORT%" -U "%PG_USERNAME%" -d "%PG_DATABASE%" -f "%SCRIPT_DIR%postgres_schema.sql" >> "%LOG_FILE%" 2>&1
if !errorlevel! equ 0 (
    call :success "Schema created successfully"
) else (
    call :error "Failed to create schema. Check log file for details."
    exit /b 1
)
exit /b 0

:export_data
call :info "Exporting data from SQL Server..."

REM Build export command
set "export_cmd=python "%SCRIPT_DIR%export_sqlserver_data.py" --server "%SQL_SERVER%" --database "%SQL_DATABASE%" --output-dir "%EXPORT_DIR%""

if "%SQL_TRUSTED%"=="false" (
    set "export_cmd=!export_cmd! --username "%SQL_USERNAME%" --password "%SQL_PASSWORD%""
    set "export_cmd=!export_cmd! --no-trusted"
)

call :info "Running export command..."
!export_cmd! >> "%LOG_FILE%" 2>&1
if !errorlevel! equ 0 (
    call :success "Data exported successfully"
) else (
    call :error "Failed to export data. Check log file for details."
    exit /b 1
)
exit /b 0

:import_data
call :info "Importing data to PostgreSQL..."

REM Build import command
set "import_cmd=python "%SCRIPT_DIR%import_postgresql_data.py" --host "%PG_HOST%" --port "%PG_PORT%" --database "%PG_DATABASE%" --username "%PG_USERNAME%" --password "%PG_PASSWORD%" --input-dir "%EXPORT_DIR%" --clear "%CLEAR_MODE%" --batch-size "%BATCH_SIZE%""

call :info "Running import command..."
!import_cmd! >> "%LOG_FILE%" 2>&1
if !errorlevel! equ 0 (
    call :success "Data imported successfully"
) else (
    call :error "Failed to import data. Check log file for details."
    exit /b 1
)
exit /b 0

:main
call :log "Starting SapInter data migration"
call :log "======================================="

REM Create export directory
if not exist "%EXPORT_DIR%" mkdir "%EXPORT_DIR%"

REM Check dependencies
call :check_python_deps
if !errorlevel! neq 0 exit /b 1

if "%IMPORT_ONLY%"=="false" (
    REM Export data
    call :export_data
    if !errorlevel! neq 0 exit /b 1
)

if "%EXPORT_ONLY%"=="false" (
    REM Create schema and import data
    call :create_schema
    if !errorlevel! neq 0 exit /b 1
    
    call :import_data
    if !errorlevel! neq 0 exit /b 1
)

call :success "Migration completed successfully!"

REM Show summary
echo.
echo Migration Summary:
echo ==================
echo Export directory: %EXPORT_DIR%
echo Log file: %LOG_FILE%

if exist "%EXPORT_DIR%\export_manifest.json" (
    echo Export manifest: %EXPORT_DIR%\export_manifest.json
)

if exist "%EXPORT_DIR%\import_stats.json" (
    echo Import stats: %EXPORT_DIR%\import_stats.json
)

call :log "Migration process completed"
exit /b 0