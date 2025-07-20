#!/bin/bash

# SapInter Data Migration Script
# Automates the process of exporting from SQL Server and importing to PostgreSQL

set -e  # Exit on any error

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="./export_data"
LOG_FILE="./migration.log"

# SQL Server configuration
SQL_SERVER=""
SQL_DATABASE="SNInterDev"
SQL_TRUSTED="true"
SQL_USERNAME=""
SQL_PASSWORD=""

# PostgreSQL configuration
PG_HOST=""
PG_PORT="5432"
PG_DATABASE=""
PG_USERNAME=""
PG_PASSWORD=""

# Options
CLEAR_MODE="none"
BATCH_SIZE="1000"
EXPORT_ONLY="false"
IMPORT_ONLY="false"
SKIP_SCHEMA="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

# Help function
show_help() {
    cat << EOF
SapInter Data Migration Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    
    SQL Server Options:
    --sql-server SERVER     SQL Server instance name (required)
    --sql-database DB       SQL Server database name (default: SNInterDev)
    --sql-username USER     SQL Server username (for non-trusted connections)
    --sql-password PASS     SQL Server password (for non-trusted connections)
    --sql-trusted           Use trusted connection (default: true)
    
    PostgreSQL Options:
    --pg-host HOST          PostgreSQL host (required)
    --pg-port PORT          PostgreSQL port (default: 5432)
    --pg-database DB        PostgreSQL database name (required)
    --pg-username USER      PostgreSQL username (required)
    --pg-password PASS      PostgreSQL password (required)
    
    Migration Options:
    --export-dir DIR        Export directory (default: ./export_data)
    --clear MODE            Clear existing data: none, all, config, data (default: none)
    --batch-size SIZE       Batch size for imports (default: 1000)
    --export-only           Only export data, don't import
    --import-only           Only import data, don't export
    --skip-schema           Skip schema creation (assume it exists)
    
    Logging:
    --log-file FILE         Log file path (default: ./migration.log)

EXAMPLES:
    # Full migration with trusted connection
    $0 --sql-server SQLSERVER01 \\
       --pg-host postgres.example.com \\
       --pg-database sapinter \\
       --pg-username sapinter_user \\
       --pg-password mypassword \\
       --clear all

    # Export only
    $0 --sql-server SQLSERVER01 --export-only

    # Import only (assumes data already exported)
    $0 --pg-host postgres.example.com \\
       --pg-database sapinter \\
       --pg-username sapinter_user \\
       --pg-password mypassword \\
       --import-only --clear data

ENVIRONMENT VARIABLES:
    You can also set credentials via environment variables:
    SQL_PASSWORD, PG_PASSWORD

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --sql-server)
            SQL_SERVER="$2"
            shift 2
            ;;
        --sql-database)
            SQL_DATABASE="$2"
            shift 2
            ;;
        --sql-username)
            SQL_USERNAME="$2"
            SQL_TRUSTED="false"
            shift 2
            ;;
        --sql-password)
            SQL_PASSWORD="$2"
            SQL_TRUSTED="false"
            shift 2
            ;;
        --sql-trusted)
            SQL_TRUSTED="true"
            shift
            ;;
        --pg-host)
            PG_HOST="$2"
            shift 2
            ;;
        --pg-port)
            PG_PORT="$2"
            shift 2
            ;;
        --pg-database)
            PG_DATABASE="$2"
            shift 2
            ;;
        --pg-username)
            PG_USERNAME="$2"
            shift 2
            ;;
        --pg-password)
            PG_PASSWORD="$2"
            shift 2
            ;;
        --export-dir)
            EXPORT_DIR="$2"
            shift 2
            ;;
        --clear)
            CLEAR_MODE="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --export-only)
            EXPORT_ONLY="true"
            shift
            ;;
        --import-only)
            IMPORT_ONLY="true"
            shift
            ;;
        --skip-schema)
            SKIP_SCHEMA="true"
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check for environment variable passwords
if [[ -z "$SQL_PASSWORD" && -n "$SQL_PASSWORD_ENV" ]]; then
    SQL_PASSWORD="$SQL_PASSWORD_ENV"
fi

if [[ -z "$PG_PASSWORD" && -n "$PG_PASSWORD_ENV" ]]; then
    PG_PASSWORD="$PG_PASSWORD_ENV"
fi

# Validate required parameters
if [[ "$EXPORT_ONLY" == "false" && "$IMPORT_ONLY" == "false" ]]; then
    # Full migration - need both SQL Server and PostgreSQL info
    if [[ -z "$SQL_SERVER" ]]; then
        error "SQL Server instance name is required (--sql-server)"
    fi
    if [[ -z "$PG_HOST" || -z "$PG_DATABASE" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" ]]; then
        error "PostgreSQL connection info is required (--pg-host, --pg-database, --pg-username, --pg-password)"
    fi
elif [[ "$EXPORT_ONLY" == "true" ]]; then
    # Export only - need SQL Server info
    if [[ -z "$SQL_SERVER" ]]; then
        error "SQL Server instance name is required for export (--sql-server)"
    fi
elif [[ "$IMPORT_ONLY" == "true" ]]; then
    # Import only - need PostgreSQL info
    if [[ -z "$PG_HOST" || -z "$PG_DATABASE" || -z "$PG_USERNAME" || -z "$PG_PASSWORD" ]]; then
        error "PostgreSQL connection info is required for import (--pg-host, --pg-database, --pg-username, --pg-password)"
    fi
fi

# Check for required Python packages
check_python_deps() {
    info "Checking Python dependencies..."
    
    if [[ "$EXPORT_ONLY" == "false" && "$IMPORT_ONLY" == "true" ]]; then
        # Only need PostgreSQL dependencies
        python3 -c "import psycopg2" 2>/dev/null || error "psycopg2 not installed. Run: pip install psycopg2-binary"
    elif [[ "$EXPORT_ONLY" == "true" && "$IMPORT_ONLY" == "false" ]]; then
        # Only need SQL Server dependencies
        python3 -c "import pyodbc" 2>/dev/null || error "pyodbc not installed. Run: pip install pyodbc"
    else
        # Need both
        python3 -c "import pyodbc" 2>/dev/null || error "pyodbc not installed. Run: pip install pyodbc"
        python3 -c "import psycopg2" 2>/dev/null || error "psycopg2 not installed. Run: pip install psycopg2-binary"
    fi
    
    success "Python dependencies OK"
}

# Create PostgreSQL schema
create_schema() {
    if [[ "$SKIP_SCHEMA" == "true" ]]; then
        info "Skipping schema creation"
        return
    fi
    
    info "Creating PostgreSQL schema..."
    
    export PGPASSWORD="$PG_PASSWORD"
    
    if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USERNAME" -d "$PG_DATABASE" -f "$SCRIPT_DIR/postgres_schema.sql" >> "$LOG_FILE" 2>&1; then
        success "Schema created successfully"
    else
        error "Failed to create schema. Check log file for details."
    fi
}

# Export data from SQL Server
export_data() {
    info "Exporting data from SQL Server..."
    
    # Build export command
    export_cmd="python3 \"$SCRIPT_DIR/export_sqlserver_data.py\" --server \"$SQL_SERVER\" --database \"$SQL_DATABASE\" --output-dir \"$EXPORT_DIR\""
    
    if [[ "$SQL_TRUSTED" == "false" ]]; then
        export_cmd="$export_cmd --username \"$SQL_USERNAME\" --password \"$SQL_PASSWORD\" --no-trusted"
    fi
    
    info "Running export command..."
    if eval "$export_cmd" >> "$LOG_FILE" 2>&1; then
        success "Data exported successfully"
    else
        error "Failed to export data. Check log file for details."
    fi
}

# Import data to PostgreSQL
import_data() {
    info "Importing data to PostgreSQL..."
    
    # Build import command
    import_cmd="python3 \"$SCRIPT_DIR/import_postgresql_data.py\" --host \"$PG_HOST\" --port \"$PG_PORT\" --database \"$PG_DATABASE\" --username \"$PG_USERNAME\" --password \"$PG_PASSWORD\" --input-dir \"$EXPORT_DIR\" --clear \"$CLEAR_MODE\" --batch-size \"$BATCH_SIZE\""
    
    info "Running import command..."
    if eval "$import_cmd" >> "$LOG_FILE" 2>&1; then
        success "Data imported successfully"
    else
        error "Failed to import data. Check log file for details."
    fi
}

# Main execution
main() {
    log "Starting SapInter data migration"
    log "======================================="
    
    # Create export directory
    mkdir -p "$EXPORT_DIR"
    
    # Check dependencies
    check_python_deps
    
    if [[ "$IMPORT_ONLY" == "false" ]]; then
        # Export data
        export_data
    fi
    
    if [[ "$EXPORT_ONLY" == "false" ]]; then
        # Create schema and import data
        create_schema
        import_data
    fi
    
    success "Migration completed successfully!"
    
    # Show summary
    echo
    echo "Migration Summary:"
    echo "=================="
    echo "Export directory: $EXPORT_DIR"
    echo "Log file: $LOG_FILE"
    
    if [[ -f "$EXPORT_DIR/export_manifest.json" ]]; then
        echo "Export manifest: $EXPORT_DIR/export_manifest.json"
    fi
    
    if [[ -f "$EXPORT_DIR/import_stats.json" ]]; then
        echo "Import stats: $EXPORT_DIR/import_stats.json"
    fi
    
    log "Migration process completed"
}

# Run main function
main "$@"