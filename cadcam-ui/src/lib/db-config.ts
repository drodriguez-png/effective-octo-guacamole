import { config } from 'mssql';
import 'dotenv/config';

export interface DatabaseConfig extends config {
  server: string;
  database: string;
  user: string;
  password: string;
  port?: number;
  options?: {
    encrypt?: boolean;
    trustServerCertificate?: boolean;
    enableArithAbort?: boolean;
  };
}

export const createDatabaseConfig = (): DatabaseConfig => {
  const dbConfig: DatabaseConfig = {
    server: process.env.DB_SERVER || 'localhost',
    database: process.env.DB_DATABASE || 'SNInterDev',
    user: process.env.DB_USER || '',
    password: process.env.DB_PASSWORD || '',
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 1433,
    options: {
      encrypt: process.env.DB_ENCRYPT === 'true' || false,
      trustServerCertificate: process.env.DB_TRUST_SERVER_CERTIFICATE === 'true' || true,
      appName: 'cadcam_interface'
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000,
    },
    requestTimeout: 30000,
    connectionTimeout: 30000,
  };

  validateDatabaseConfig(dbConfig);

  return dbConfig;
};

const validateDatabaseConfig = (config: DatabaseConfig): void => {
  if (!config.server) {
    throw new Error('Database server is required');
  }
  if (!config.database) {
    throw new Error('Database name is required');
  }
  
  const useWindowsAuth = process.env.DB_WINDOWS_AUTH === 'true';
  if (!useWindowsAuth) {
    if (!config.user) {
      throw new Error('Database user is required when not using Windows authentication');
    }
    if (!config.password) {
      throw new Error('Database password is required when not using Windows authentication');
    }
  }
};
