export interface Program {
  ArchivePacketId: number;
  ProgramName: string;
  MachineName: string;
  TaskName: string;
  WSName: string;
  NestType: string;
  SigmanestStatus: string;
  SAPStatus: string;
  UserName: string;

  changeStatus: async () => {
    // if SigmanestStatus === 'Created': 'Released'
    // if SigmanestStatus === 'Released': 'Created' if SAPStatus == null
    // TODO: call db.execute('sap.ChangeProgramStatus')
  }
}

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
  error?: string;
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
