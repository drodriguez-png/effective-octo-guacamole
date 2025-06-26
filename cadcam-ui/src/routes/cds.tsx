import { Title } from "@solidjs/meta";
import { createResource } from "solid-js";
import { Program, ApiResponse } from "~/lib/types";
import { DataTable, TableColumn } from "~/components/DataTable";
import "~/styles/PageLayout.css";

async function fetchPrograms(): Promise<Program[]> {
  const response = await fetch('/api/programs');
  const data: ApiResponse<Program[]> = await response.json();
  
  if (!data.success) {
    throw new Error(data.error || 'Failed to fetch programs');
  }
  
  return data.data;
}

const programColumns: TableColumn<Program>[] = [
  { key: 'ArchivePacketId', header: 'Archive ID' },
  { key: 'ProgramName', header: 'Program Name', className: 'program-name' },
  { key: 'MachineName', header: 'Machine' },
  { key: 'TaskName', header: 'Task' },
  { key: 'WSName', header: 'Workstation' },
  { key: 'NestType', header: 'Nest Type' },
  { key: 'SigmanestStatus', header: 'Sigmanest Status', className: 'status sigmanest-status' },
  { key: 'SAPStatus', header: 'SAP Status', className: 'status sap-status' },
  { key: 'UserName', header: 'User' },
];

export default function CDS() {
  const [programs] = createResource(fetchPrograms);

  return (
    <main class="page-main">
      <Title>Code Delivery System</Title>
      <div class="page-icon">📦</div>
      <h1 class="page-title">Code Delivery System</h1>
      <p class="page-description">
        Active programs in the SAP-Sigmanest interface system
      </p>

      <DataTable 
        data={programs}
        columns={programColumns}
        loadingMessage="Loading programs..."
        errorMessage="Failed to load programs"
        noDataMessage="No programs found"
      />
    </main>
  );
}
