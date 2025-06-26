import sql, { IResult, IRecordSet } from 'mssql';
import { createDatabaseConfig, DatabaseConfig } from './db-config';

const config = createDatabaseConfig();

export class DatabaseService {
  async query<T = any>(queryText: string, parameters?: Record<string, any>): Promise<IResult<T>> {
    try {
      await sql.connect(config);
      const request = new sql.Request();
      
      if (parameters) {
        Object.entries(parameters).forEach(([key, value]) => {
          request.input(key, value);
        });
      }

      // TODO: pagination
      const result = await request.query<T>(queryText);
      return result;
    } catch (error) {
      console.error('Query execution failed:', error);
      throw new Error(`Query failed: ${error}`);
    }
  }

  async execute(procedureName: string, parameters?: Record<string, any>): Promise<IResult<any>> {
    try {
      await sql.connect(config);
      const request = new sql.Request();
      
      if (parameters) {
        Object.entries(parameters).forEach(([key, value]) => {
          request.input(key, value);
        });
      }

      const result = await request.execute(procedureName);
      return result;
    } catch (error) {
      console.error('Stored procedure execution failed:', error);
      throw new Error(`Stored procedure execution failed: ${error}`);
    }
  }

  getConnectionStatus(): boolean {
    return this.isConnected;
  }
}

export const closeDatabaseConnection = async (): Promise<void> => {
  sql.close();
};
