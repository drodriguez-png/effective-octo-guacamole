import sql, { IResult, IRecordSet } from 'mssql';
import { createDatabaseConfig, DatabaseConfig } from './db-config';

const config = createDatabaseConfig();

export class DatabaseService {
  /**
   * Executes a SQL query with optional parameters
   * @param queryText - The SQL query to execute
   * @param parameters - Optional parameters to bind to the query
   * @returns Promise resolving to query results
   * @throws Error if query execution fails
   */
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

  /**
   * Executes a stored procedure with optional parameters
   * @param procedureName - Name of the stored procedure to execute
   * @param parameters - Optional parameters to pass to the stored procedure
   * @returns Promise resolving to procedure execution results
   * @throws Error if stored procedure execution fails
   */
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

  /**
   * Gets the current database connection status
   * @returns boolean indicating if database is connected
   */
  getConnectionStatus(): boolean {
    return this.isConnected;
  }
}

/**
 * Closes the database connection pool
 * @returns Promise that resolves when connection is closed
 */
export const closeDatabaseConnection = async (): Promise<void> => {
  sql.close();
};
