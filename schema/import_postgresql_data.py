#!/usr/bin/env python3
"""
PostgreSQL Data Import Script
Imports data from CSV files exported from SQL Server into PostgreSQL
"""

import psycopg2
import csv
import json
import os
from datetime import datetime
from pathlib import Path
import argparse
import sys
from psycopg2.extras import execute_batch

# Table mappings from SQL Server to PostgreSQL
TABLE_MAPPINGS = {
    'oys_program': {
        'target_table': 'oys.program',
        'columns': ['auto_id', 'db_entry_datetime', 'program_guid', 'program_name', 'layout_number', 
                   'machine_name', 'cutting_time', 'task_name', 'nest_type', 'ws_name'],
        'skip_auto_id': True,  # Skip auto_id since it's SERIAL
        'dependencies': []
    },
    'oys_parent_plate': {
        'target_table': 'oys.parent_plate',
        'columns': ['auto_id', 'db_entry_datetime', 'program_guid', 'plate_name', 'material', 
                   'thickness', 'area'],
        'skip_auto_id': True,
        'dependencies': ['oys_program']
    },
    'oys_parent_part': {
        'target_table': 'oys.parent_part',
        'columns': ['auto_id', 'db_entry_datetime', 'program_guid', 'parent_part_guid', 'sn_part_name', 
                   'qty_program', 'true_area', 'nested_area'],
        'skip_auto_id': True,
        'dependencies': ['oys_parent_plate']
    },
    'oys_child_plate': {
        'target_table': 'oys.child_plate',
        'columns': ['auto_id', 'db_entry_datetime', 'program_guid', 'child_plate_guid', 'plate_name', 
                   'plate_number', 'material_master', 'material', 'thickness', 'child_nest_task_name', 
                   'child_nest_program_name', 'child_nest_repeat_id', 'area'],
        'skip_auto_id': True,
        'dependencies': ['oys_program']
    },
    'oys_child_part': {
        'target_table': 'oys.child_part',
        'columns': ['auto_id', 'db_entry_datetime', 'child_plate_guid', 'child_part_guid', 'parent_part_guid', 
                   'sn_part_name', 'sap_part_name', 'qty_program', 'job', 'shipment', 'true_area', 'nested_area'],
        'skip_auto_id': True,
        'dependencies': ['oys_child_plate']
    },
    'oys_remnant': {
        'target_table': 'oys.remnant',
        'columns': ['auto_id', 'db_entry_datetime', 'child_plate_guid', 'remnant_guid', 'remnant_name', 
                   'area', 'is_rectangular', 'rect_width', 'rect_length'],
        'skip_auto_id': True,
        'dependencies': ['oys_child_plate']
    },
    'oys_status': {
        'target_table': 'oys.status',
        'columns': ['auto_id', 'db_entry_datetime', 'program_guid', 'status_guid', 'sigmanest_status', 
                   'sap_status', 'source', 'user_name'],
        'skip_auto_id': True,
        'dependencies': ['oys_program']
    },
    'sap_interface_config': {
        'target_table': 'sap.interface_config',
        'columns': ['lock', 'simtrans_district', 'remnant_dxf_path', 'heat_swap_keyword', 'log_procedure_calls'],
        'skip_auto_id': False,
        'dependencies': []
    },
    'sap_interface_version': {
        'target_table': 'sap.interface_version',
        'columns': ['lock', 'major', 'minor', 'patch'],
        'skip_auto_id': False,
        'dependencies': []
    },
    'sap_matl_compat_map': {
        'target_table': 'sap.matl_compat_map',
        'columns': ['id', 'parent_matl', 'child_matl', 'use_intermediate_compat', 'is_bidirectional'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_demand_queue': {
        'target_table': 'sap.demand_queue',
        'columns': ['id', 'sap_event_id', 'sap_part_name', 'work_order', 'part_name', 'qty', 'matl', 
                   'on_hold', 'state', 'dwg', 'codegen', 'job', 'shipment', 'op1', 'op2', 'op3', 
                   'mark', 'raw_material_master', 'due_date'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_renamed_demand_allocation': {
        'target_table': 'sap.renamed_demand_allocation',
        'columns': ['id', 'original_part_name', 'new_part_name', 'work_order_name', 'qty'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_part_operations': {
        'target_table': 'sap.part_operations',
        'columns': ['id', 'part_name', 'operation2', 'operation3', 'operation4', 'auto_process_instruction'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_inventory_queue': {
        'target_table': 'sap.inventory_queue',
        'columns': ['id', 'sap_event_id', 'sheet_name', 'sheet_type', 'qty', 'matl', 'thk', 'width', 
                   'length', 'material_master', 'notes1', 'notes2', 'notes3', 'notes4'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_feedback_queue': {
        'target_table': 'sap.feedback_queue',
        'columns': ['feedback_id', 'data_set', 'archive_packet_id', 'status', 'program_name', 'repeat_id', 
                   'machine_name', 'cutting_time', 'sheet_index', 'sheet_name', 'material_master', 'part_name', 
                   'part_qty', 'job', 'shipment', 'true_area', 'nested_area', 'remnant_name', 'length', 
                   'width', 'area', 'is_rectangular'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'sap_move_code_queue': {
        'target_table': 'sap.move_code_queue',
        'columns': ['id', 'machine_name', 'program_name'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'log_sap_demand_calls': {
        'target_table': 'log.sap_demand_calls',
        'columns': ['log_id', 'log_date', 'proc_called', 'sap_event_id', 'sap_part_name', 'work_order', 
                   'part_name', 'qty', 'matl', 'process', 'state', 'dwg', 'codegen', 'job', 'shipment', 
                   'op1', 'op2', 'op3', 'mark', 'raw_mm', 'due_date', 'alloc_id'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'log_sap_inventory_calls': {
        'target_table': 'log.sap_inventory_calls',
        'columns': ['log_id', 'log_date', 'proc_called', 'sap_event_id', 'sheet_name', 'sheet_type', 
                   'qty', 'matl', 'thk', 'wid', 'len', 'mm', 'notes1', 'notes2', 'notes3', 'notes4'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'log_feedback_calls': {
        'target_table': 'log.feedback_calls',
        'columns': ['log_id', 'log_date', 'proc_called', 'feedback_id', 'archive_packet_id'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'log_update_program_calls': {
        'target_table': 'log.update_program_calls',
        'columns': ['log_id', 'log_date', 'proc_called', 'sap_event_id', 'archive_packet_id', 'source', 'username'],
        'skip_auto_id': True,
        'dependencies': []
    },
    'cds_shop_nest_data': {
        'target_table': 'cds.shop_nest_data',
        'columns': ['program_name', 'date_printed', 'printed_by'],
        'skip_auto_id': False,
        'dependencies': []
    }
}

def get_connection_string(host, database, username, password, port=5432):
    """Build PostgreSQL connection string"""
    return f"host={host} port={port} dbname={database} user={username} password={password}"

def convert_value(value, target_column):
    """Convert value from CSV to PostgreSQL format"""
    if value == '' or value is None:
        return None
    
    # Handle boolean conversions
    if 'is_' in target_column or target_column in ['on_hold', 'log_procedure_calls', 'use_intermediate_compat', 'is_bidirectional']:
        if value in ['1', 'True', 'true', 't', 'T']:
            return True
        elif value in ['0', 'False', 'false', 'f', 'F']:
            return False
        else:
            return None
    
    # Handle datetime conversions
    if 'date' in target_column or 'datetime' in target_column:
        if value:
            try:
                # Try parsing ISO format first
                return datetime.fromisoformat(value.replace('Z', '+00:00'))
            except ValueError:
                try:
                    # Try parsing common SQL Server format
                    return datetime.strptime(value, '%Y-%m-%d %H:%M:%S')
                except ValueError:
                    try:
                        # Try parsing date only
                        return datetime.strptime(value, '%Y-%m-%d').date()
                    except ValueError:
                        print(f"Warning: Could not parse datetime value: {value}")
                        return None
        return None
    
    # Handle numeric conversions
    if target_column in ['auto_id', 'id', 'log_id', 'feedback_id', 'layout_number', 'plate_number', 
                        'qty_program', 'qty', 'repeat_id', 'cutting_time', 'sheet_index', 'part_qty', 
                        'length', 'width', 'archive_packet_id', 'alloc_id', 'lock', 'major', 'minor', 
                        'patch', 'simtrans_district', 'child_nest_repeat_id']:
        try:
            return int(float(value)) if value else None
        except ValueError:
            return None
    
    # Handle float conversions
    if target_column in ['cutting_time', 'thickness', 'area', 'true_area', 'nested_area', 
                        'rect_width', 'rect_length', 'thk', 'wid', 'len']:
        try:
            return float(value) if value else None
        except ValueError:
            return None
    
    # Handle UUID conversions
    if 'guid' in target_column:
        return value if value else None
    
    # Default to string
    return value if value else None

def clear_existing_data(cursor, clear_mode):
    """Clear existing data based on mode"""
    if clear_mode == 'none':
        return
    
    print(f"Clearing existing data (mode: {clear_mode})...")
    
    if clear_mode == 'all':
        # Clear all data from all tables in dependency order
        tables_to_clear = [
            'log.sap_demand_calls', 'log.sap_inventory_calls', 'log.feedback_calls', 'log.update_program_calls',
            'sap.demand_queue', 'sap.inventory_queue', 'sap.feedback_queue', 'sap.move_code_queue',
            'sap.renamed_demand_allocation', 'sap.part_operations',
            'cds.shop_nest_data',
            'oys.remnant', 'oys.child_part', 'oys.child_plate', 'oys.parent_part', 'oys.status',
            'oys.parent_plate', 'oys.program'
        ]
    elif clear_mode == 'config':
        # Only clear configuration tables
        tables_to_clear = ['sap.interface_config', 'sap.interface_version', 'sap.matl_compat_map']
    elif clear_mode == 'data':
        # Clear data tables but keep config
        tables_to_clear = [
            'log.sap_demand_calls', 'log.sap_inventory_calls', 'log.feedback_calls', 'log.update_program_calls',
            'sap.demand_queue', 'sap.inventory_queue', 'sap.feedback_queue', 'sap.move_code_queue',
            'sap.renamed_demand_allocation', 'sap.part_operations',
            'cds.shop_nest_data',
            'oys.remnant', 'oys.child_part', 'oys.child_plate', 'oys.parent_part', 'oys.status',
            'oys.parent_plate', 'oys.program'
        ]
    
    for table in tables_to_clear:
        try:
            cursor.execute(f"DELETE FROM {table}")
            print(f"  Cleared {table}")
        except Exception as e:
            print(f"  Warning: Could not clear {table}: {e}")

def import_table(cursor, csv_file, table_mapping, batch_size=1000):
    """Import a single table from CSV"""
    table_name = table_mapping['target_table']
    columns = table_mapping['columns']
    skip_auto_id = table_mapping['skip_auto_id']
    
    print(f"Importing {table_name}...")
    
    if not csv_file.exists():
        print(f"  CSV file not found: {csv_file}")
        return 0
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            # Prepare columns for insert (skip auto_id if specified)
            insert_columns = columns[1:] if skip_auto_id else columns
            column_placeholders = ', '.join(['%s'] * len(insert_columns))
            column_names = ', '.join(insert_columns)
            
            insert_sql = f"INSERT INTO {table_name} ({column_names}) VALUES ({column_placeholders})"
            
            batch_data = []
            row_count = 0
            
            for row in reader:
                # Convert row data
                row_data = []
                for col in insert_columns:
                    # Get original column name from CSV (might have different casing)
                    csv_col = None
                    for csv_key in row.keys():
                        if csv_key.lower() == col.lower():
                            csv_col = csv_key
                            break
                    
                    if csv_col:
                        converted_value = convert_value(row[csv_col], col)
                        row_data.append(converted_value)
                    else:
                        row_data.append(None)
                
                batch_data.append(tuple(row_data))
                row_count += 1
                
                # Execute batch when it reaches batch_size
                if len(batch_data) >= batch_size:
                    execute_batch(cursor, insert_sql, batch_data)
                    batch_data = []
            
            # Execute remaining batch
            if batch_data:
                execute_batch(cursor, insert_sql, batch_data)
            
            print(f"  Imported {row_count} rows")
            return row_count
            
    except Exception as e:
        print(f"  Error importing {table_name}: {e}")
        raise

def get_import_order():
    """Get tables in dependency order for import"""
    ordered_tables = []
    processed = set()
    
    def add_dependencies(table_key):
        if table_key in processed:
            return
        
        table_mapping = TABLE_MAPPINGS[table_key]
        
        # Add dependencies first
        for dep in table_mapping['dependencies']:
            if dep in TABLE_MAPPINGS:
                add_dependencies(dep)
        
        ordered_tables.append(table_key)
        processed.add(table_key)
    
    # Process all tables
    for table_key in TABLE_MAPPINGS.keys():
        add_dependencies(table_key)
    
    return ordered_tables

def reset_sequences(cursor):
    """Reset PostgreSQL sequences to max values"""
    print("Resetting sequences...")
    
    sequences = [
        ('oys.program', 'auto_id'),
        ('oys.parent_plate', 'auto_id'),
        ('oys.parent_part', 'auto_id'),
        ('oys.child_plate', 'auto_id'),
        ('oys.child_part', 'auto_id'),
        ('oys.remnant', 'auto_id'),
        ('oys.status', 'auto_id'),
        ('sap.matl_compat_map', 'id'),
        ('sap.demand_queue', 'id'),
        ('sap.renamed_demand_allocation', 'id'),
        ('sap.part_operations', 'id'),
        ('sap.inventory_queue', 'id'),
        ('sap.feedback_queue', 'feedback_id'),
        ('sap.move_code_queue', 'id'),
        ('log.sap_demand_calls', 'log_id'),
        ('log.sap_inventory_calls', 'log_id'),
        ('log.feedback_calls', 'log_id'),
        ('log.update_program_calls', 'log_id'),
        ('cds.shop_nest_data', 'id')
    ]
    
    for table, id_column in sequences:
        try:
            # Get current max value
            cursor.execute(f"SELECT COALESCE(MAX({id_column}), 0) FROM {table}")
            max_val = cursor.fetchone()[0]
            
            if max_val > 0:
                # Reset sequence
                sequence_name = f"{table.replace('.', '_')}_{id_column}_seq"
                cursor.execute(f"SELECT setval('{sequence_name}', {max_val})")
                print(f"  Reset {sequence_name} to {max_val}")
                
        except Exception as e:
            print(f"  Warning: Could not reset sequence for {table}.{id_column}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Import CSV data into PostgreSQL')
    parser.add_argument('--host', required=True, help='PostgreSQL host')
    parser.add_argument('--port', default=5432, type=int, help='PostgreSQL port (default: 5432)')
    parser.add_argument('--database', required=True, help='PostgreSQL database name')
    parser.add_argument('--username', required=True, help='PostgreSQL username')
    parser.add_argument('--password', required=True, help='PostgreSQL password')
    parser.add_argument('--input-dir', default='./export_data', help='Input directory with CSV files (default: ./export_data)')
    parser.add_argument('--clear', choices=['none', 'all', 'config', 'data'], default='none', 
                       help='Clear existing data: none (default), all, config, data')
    parser.add_argument('--batch-size', default=1000, type=int, help='Batch size for inserts (default: 1000)')
    
    args = parser.parse_args()
    
    input_dir = Path(args.input_dir)
    if not input_dir.exists():
        print(f"Error: Input directory does not exist: {input_dir}")
        sys.exit(1)
    
    print(f"Starting PostgreSQL data import...")
    print(f"Host: {args.host}:{args.port}")
    print(f"Database: {args.database}")
    print(f"Input directory: {input_dir}")
    print(f"Clear mode: {args.clear}")
    print("-" * 50)
    
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=args.host,
            port=args.port,
            database=args.database,
            user=args.username,
            password=args.password
        )
        conn.autocommit = False
        cursor = conn.cursor()
        
        # Clear existing data if requested
        clear_existing_data(cursor, args.clear)
        conn.commit()
        
        # Import tables in dependency order
        ordered_tables = get_import_order()
        import_stats = {}
        
        for table_key in ordered_tables:
            csv_file = input_dir / f"{table_key}.csv"
            
            if csv_file.exists():
                row_count = import_table(cursor, csv_file, TABLE_MAPPINGS[table_key], args.batch_size)
                import_stats[table_key] = row_count
                conn.commit()
            else:
                print(f"CSV file not found for {table_key}, skipping...")
        
        # Reset sequences
        reset_sequences(cursor)
        conn.commit()
        
        print("-" * 50)
        print(f"Import completed successfully!")
        print(f"Imported {len(import_stats)} tables with {sum(import_stats.values())} total rows")
        
        # Save import stats
        stats_file = input_dir / 'import_stats.json'
        with open(stats_file, 'w') as f:
            json.dump({
                'import_date': datetime.now().isoformat(),
                'target_host': args.host,
                'target_database': args.database,
                'tables': import_stats,
                'total_tables': len(import_stats),
                'total_rows': sum(import_stats.values())
            }, f, indent=2)
        
        print(f"Import statistics saved to: {stats_file}")
        
    except Exception as e:
        print(f"Error during import: {e}")
        if 'conn' in locals():
            conn.rollback()
        sys.exit(1)
    
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == '__main__':
    main()