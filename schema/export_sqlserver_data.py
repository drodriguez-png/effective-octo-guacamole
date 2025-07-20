#!/usr/bin/env python3
"""
SQL Server Data Export Script
Exports data from SapInter database to CSV files for PostgreSQL import
"""

import pyodbc
import csv
import os
import json
from datetime import datetime
from pathlib import Path
import argparse
import sys

# Table definitions with their schemas and columns
TABLES_TO_EXPORT = {
    'oys.Program': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ProgramGUID', 'ProgramName', 'LayoutNumber', 
                   'MachineName', 'CuttingTime', 'TaskName', 'NestType', 'WSName'],
        'order_by': 'AutoId'
    },
    'oys.ParentPlate': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ProgramGUID', 'PlateName', 'Material', 
                   'Thickness', 'Area'],
        'order_by': 'AutoId'
    },
    'oys.ParentPart': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ProgramGUID', 'ParentPartGUID', 'SNPartName', 
                   'QtyProgram', 'TrueArea', 'NestedArea'],
        'order_by': 'AutoId'
    },
    'oys.ChildPlate': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ProgramGUID', 'ChildPlateGUID', 'PlateName', 
                   'PlateNumber', 'MaterialMaster', 'Material', 'Thickness', 'ChildNestTaskName', 
                   'ChildNestProgramName', 'ChildNestRepeatID', 'Area'],
        'order_by': 'AutoId'
    },
    'oys.ChildPart': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ChildPlateGUID', 'ChildPartGUID', 'ParentPartGUID', 
                   'SNPartName', 'SAPPartName', 'QtyProgram', 'Job', 'Shipment', 'TrueArea', 'NestedArea'],
        'order_by': 'AutoId'
    },
    'oys.Remnant': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ChildPlateGUID', 'RemnantGUID', 'RemnantName', 
                   'Area', 'CAST(IsRectangular AS INT) as IsRectangular', 'RectWidth', 'RectLength'],
        'order_by': 'AutoId'
    },
    'oys.Status': {
        'columns': ['AutoId', 'DBEntryDateTime', 'ProgramGUID', 'StatusGUID', 'SigmanestStatus', 
                   'SAPStatus', 'Source', 'UserName'],
        'order_by': 'AutoId'
    },
    'sap.InterfaceConfig': {
        'columns': ['Lock', 'SimTransDistrict', 'RemnantDxfPath', 'HeatSwapKeyword', 
                   'CAST(LogProcedureCalls AS INT) as LogProcedureCalls'],
        'order_by': 'Lock'
    },
    'sap.InterfaceVersion': {
        'columns': ['Lock', 'Major', 'Minor', 'Patch'],
        'order_by': 'Lock'
    },
    'sap.MatlCompatMap': {
        'columns': ['Id', 'ParentMatl', 'ChildMatl', 'CAST(UseIntermediateCompat AS INT) as UseIntermediateCompat', 
                   'CAST(IsBidirectional AS INT) as IsBidirectional'],
        'order_by': 'Id'
    },
    'sap.DemandQueue': {
        'columns': ['Id', 'SapEventId', 'SapPartName', 'WorkOrder', 'PartName', 'Qty', 'Matl', 
                   'CAST(OnHold AS INT) as OnHold', 'State', 'Dwg', 'Codegen', 'Job', 'Shipment', 
                   'Op1', 'Op2', 'Op3', 'Mark', 'RawMaterialMaster', 'DueDate'],
        'order_by': 'Id'
    },
    'sap.RenamedDemandAllocation': {
        'columns': ['Id', 'OriginalPartName', 'NewPartName', 'WorkOrderName', 'Qty'],
        'order_by': 'Id'
    },
    'sap.PartOperations': {
        'columns': ['Id', 'PartName', 'Operation2', 'Operation3', 'Operation4', 'AutoProcessInstruction'],
        'order_by': 'Id'
    },
    'sap.InventoryQueue': {
        'columns': ['Id', 'SapEventId', 'SheetName', 'SheetType', 'Qty', 'Matl', 'Thk', 'Width', 
                   'Length', 'MaterialMaster', 'Notes1', 'Notes2', 'Notes3', 'Notes4'],
        'order_by': 'Id'
    },
    'sap.FeedbackQueue': {
        'columns': ['FeedBackId', 'DataSet', 'ArchivePacketId', 'Status', 'ProgramName', 'RepeatId', 
                   'MachineName', 'CuttingTime', 'SheetIndex', 'SheetName', 'MaterialMaster', 'PartName', 
                   'PartQty', 'Job', 'Shipment', 'TrueArea', 'NestedArea', 'RemnantName', 'Length', 
                   'Width', 'Area', 'IsRectangular'],
        'order_by': 'FeedBackId'
    },
    'sap.MoveCodeQueue': {
        'columns': ['Id', 'MachineName', 'ProgramName'],
        'order_by': 'Id'
    },
    'log.SapDemandCalls': {
        'columns': ['LogId', 'LogDate', 'ProcCalled', 'sap_event_id', 'sap_part_name', 'work_order', 
                   'part_name', 'qty', 'matl', 'process', 'state', 'dwg', 'codegen', 'job', 'shipment', 
                   'op1', 'op2', 'op3', 'mark', 'raw_mm', 'due_date', 'alloc_id'],
        'order_by': 'LogId'
    },
    'log.SapInventoryCalls': {
        'columns': ['LogId', 'LogDate', 'ProcCalled', 'sap_event_id', 'sheet_name', 'sheet_type', 
                   'qty', 'matl', 'thk', 'wid', 'len', 'mm', 'notes1', 'notes2', 'notes3', 'notes4'],
        'order_by': 'LogId'
    },
    'log.FeedbackCalls': {
        'columns': ['LogId', 'LogDate', 'ProcCalled', 'feedback_id', 'archive_packet_id'],
        'order_by': 'LogId'
    },
    'log.UpdateProgramCalls': {
        'columns': ['LogId', 'LogDate', 'ProcCalled', 'sap_event_id', 'archive_packet_id', 'source', 'username'],
        'order_by': 'LogId'
    }
}

# Optional tables that may not exist
OPTIONAL_TABLES = {
    'cds.ShopNestData': {
        'columns': ['ProgramName', 'DatePrinted', 'PrintedBy'],
        'order_by': 'ProgramName'
    }
}

def get_connection_string(server, database, username=None, password=None, trusted=True):
    """Build SQL Server connection string"""
    if trusted:
        return f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};Trusted_Connection=yes;"
    else:
        return f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};"

def export_table(cursor, table_name, table_info, output_dir):
    """Export a single table to CSV"""
    print(f"Exporting {table_name}...")
    
    # Build SQL query
    columns_str = ', '.join(table_info['columns'])
    sql = f"SELECT {columns_str} FROM {table_name} ORDER BY {table_info['order_by']}"
    
    try:
        cursor.execute(sql)
        
        # Create filename (replace dots with underscores)
        filename = table_name.replace('.', '_').lower() + '.csv'
        filepath = output_dir / filename
        
        # Write to CSV
        with open(filepath, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile, quoting=csv.QUOTE_MINIMAL)
            
            # Write header (clean column names)
            headers = [col.split(' as ')[-1] if ' as ' in col else col for col in table_info['columns']]
            writer.writerow(headers)
            
            # Write data
            row_count = 0
            while True:
                rows = cursor.fetchmany(1000)  # Fetch in batches
                if not rows:
                    break
                
                for row in rows:
                    # Convert data types for CSV compatibility
                    csv_row = []
                    for value in row:
                        if value is None:
                            csv_row.append('')
                        elif isinstance(value, datetime):
                            csv_row.append(value.isoformat())
                        else:
                            csv_row.append(str(value))
                    writer.writerow(csv_row)
                    row_count += 1
        
        print(f"  Exported {row_count} rows to {filename}")
        return row_count
        
    except Exception as e:
        print(f"  Error exporting {table_name}: {e}")
        return 0

def check_table_exists(cursor, table_name):
    """Check if a table exists"""
    schema, table = table_name.split('.')
    sql = """
    SELECT COUNT(*) 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
    """
    cursor.execute(sql, schema, table)
    return cursor.fetchone()[0] > 0

def create_manifest(export_stats, output_dir, server, database):
    """Create export manifest file"""
    manifest = {
        'export_info': {
            'export_date': datetime.now().isoformat(),
            'source_server': server,
            'source_database': database,
            'total_tables': len(export_stats),
            'total_rows': sum(export_stats.values())
        },
        'tables': export_stats
    }
    
    manifest_path = output_dir / 'export_manifest.json'
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)
    
    # Also create text version
    text_manifest_path = output_dir / 'export_manifest.txt'
    with open(text_manifest_path, 'w', encoding='utf-8') as f:
        f.write("SapInter Data Export Manifest\n")
        f.write("=" * 30 + "\n")
        f.write(f"Export Date: {manifest['export_info']['export_date']}\n")
        f.write(f"Source Server: {manifest['export_info']['source_server']}\n")
        f.write(f"Source Database: {manifest['export_info']['source_database']}\n")
        f.write(f"Total Tables: {manifest['export_info']['total_tables']}\n")
        f.write(f"Total Rows: {manifest['export_info']['total_rows']}\n\n")
        
        f.write("Table Export Details:\n")
        f.write("-" * 20 + "\n")
        for table, count in export_stats.items():
            f.write(f"{table}: {count} rows\n")

def main():
    parser = argparse.ArgumentParser(description='Export SapInter SQL Server data to CSV files')
    parser.add_argument('--server', required=True, help='SQL Server instance name')
    parser.add_argument('--database', default='SNInterDev', help='Database name (default: SNInterDev)')
    parser.add_argument('--output-dir', default='./export_data', help='Output directory (default: ./export_data)')
    parser.add_argument('--username', help='Username (if not using trusted connection)')
    parser.add_argument('--password', help='Password (if not using trusted connection)')
    parser.add_argument('--trusted', action='store_true', default=True, help='Use trusted connection (default: True)')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    print(f"Starting SapInter data export...")
    print(f"Server: {args.server}")
    print(f"Database: {args.database}")
    print(f"Output directory: {output_dir}")
    print("-" * 50)
    
    try:
        # Connect to SQL Server
        conn_str = get_connection_string(args.server, args.database, args.username, args.password, args.trusted)
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        export_stats = {}
        
        # Export main tables
        for table_name, table_info in TABLES_TO_EXPORT.items():
            if check_table_exists(cursor, table_name):
                row_count = export_table(cursor, table_name, table_info, output_dir)
                export_stats[table_name] = row_count
            else:
                print(f"Table {table_name} not found, skipping...")
        
        # Export optional tables
        for table_name, table_info in OPTIONAL_TABLES.items():
            if check_table_exists(cursor, table_name):
                row_count = export_table(cursor, table_name, table_info, output_dir)
                export_stats[table_name] = row_count
            else:
                print(f"Optional table {table_name} not found, skipping...")
        
        # Create manifest
        create_manifest(export_stats, output_dir, args.server, args.database)
        
        print("-" * 50)
        print(f"Export completed successfully!")
        print(f"Exported {len(export_stats)} tables with {sum(export_stats.values())} total rows")
        print(f"Files saved to: {output_dir}")
        print(f"Check export_manifest.json for details")
        
    except Exception as e:
        print(f"Error during export: {e}")
        sys.exit(1)
    
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == '__main__':
    main()