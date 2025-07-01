import { Title } from "@solidjs/meta";
import { createResource, createSignal, createMemo } from "solid-js";
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

export default function CDS() {
  const [programs, { refetch }] = createResource(fetchPrograms);
  const [hideReleased, setHideReleased] = createSignal(false);

const programColumns: TableColumn<Program>[] = [
  { key: 'ArchivePacketId', header: 'ID' },
  { key: 'ProgramName', header: 'Program Name', className: 'program-name' },
  { key: 'MachineName', header: 'Machine' },
  { key: 'TaskName', header: 'Task' },
  { key: 'WSName', header: 'Workspace' },
  { key: 'NestType', header: 'Nest Type' },
  {
    key: 'SigmanestStatus',
    header: 'Sigmanest Status',
    className: 'status sigmanest-status',
    render: (value, row) => (
      <button 
        class={`status-button ${value === 'Created' ? 'status-created' : ''} ${value === 'Released' ? 'status-disabled' : ''}`}
        onClick={() => value !== 'Released' && handleStatusChange(row.ArchivePacketId, value)}
        disabled={value === 'Released'}
      >
        {value}
      </button>
    )
  },
  { key: 'UserName', header: 'User' },
  {
    key: 'delete',
    header: 'Delete',
    render: (value, row) => (
      <button
        class="status-button delete-button"
        onClick={() => handleDelete(row.ArchivePacketId)}
      >
        Delete
      </button>
    )
  },
];

  const handleStatusChange = async (archivePacketId: number, currentStatus: string) => {
    try {
      const response = await fetch(`/api/program/${archivePacketId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        }
      });

      const result = await response.json();
      
      if (result.success) {
        // Refresh the programs list
        refetch();
      } else {
        alert(`Error: ${result.error || 'Failed to update program status'}`);
      }
    } catch (error) {
      console.error('Error updating program status:', error);
      alert('Error updating program status. Please try again.');
    }
  };

  const handleDelete = async (archivePacketId: number) => {
    if (!confirm('Are you sure you want to delete this program?')) {
      return;
    }

    try {
      const response = await fetch(`/api/program/${archivePacketId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
        }
      });

      const result = await response.json();
      
      if (result.success) {
        // Refresh the programs list
        refetch();
      } else {
        alert(`Error: ${result.error || 'Failed to delete program'}`);
      }
    } catch (error) {
      console.error('Error deleting program:', error);
      alert('Error deleting program. Please try again.');
    }
  };

  const filteredPrograms = createMemo(() => {
    const programsData = programs();
    if (!programsData) return programsData;
    
    if (hideReleased()) {
      return programsData.filter(program => program.SigmanestStatus !== 'Released');
    }
    
    return programsData;
  });

  return (
    <main class="page-main">
      <Title>Code Delivery System</Title>
      <div class="page-icon">📦</div>
      <h1 class="page-title">Code Delivery System</h1>
      <p class="page-description">
        Active programs in the SAP-Sigmanest interface system
      </p>

      <div class="filter-controls">
        <label class="toggle-label">
          <input
            type="checkbox"
            checked={hideReleased()}
            onChange={(e) => setHideReleased(e.currentTarget.checked)}
          />
          Hide Released Programs
        </label>
      </div>

      <DataTable 
        data={filteredPrograms}
        columns={programColumns}
        loadingMessage="Loading programs..."
        errorMessage="Failed to load programs"
        noDataMessage="No programs found"
      />
    </main>
  );
}
