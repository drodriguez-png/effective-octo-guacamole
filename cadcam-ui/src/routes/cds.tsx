import { Title } from "@solidjs/meta";
import { createSignal, createResource, For, Show } from "solid-js";
import { Program, ApiResponse } from "~/lib/types";
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
  const [programs] = createResource(fetchPrograms);

  return (
    <main class="page-main">
      <Title>Code Delivery System</Title>
      <div class="page-icon">📦</div>
      <h1 class="page-title">Code Delivery System</h1>
      <p class="page-description">
        Active programs in the SAP-Sigmanest interface system
      </p>

      <div class="programs-container">
        <Show
          when={!programs.loading}
          fallback={<div class="loading">Loading programs...</div>}
        >
          <Show
            when={!programs.error}
            fallback={<div class="error">Error: {programs.error?.message}</div>}
          >
            <Show
              when={programs() && programs()!.length > 0}
              fallback={<div class="no-data">No programs found</div>}
            >
              <div class="programs-table-container">
                <table class="programs-table">
                  <thead>
                    <tr>
                      <th>Archive ID</th>
                      <th>Program Name</th>
                      <th>Machine</th>
                      <th>Task</th>
                      <th>Workstation</th>
                      <th>Nest Type</th>
                      <th>Sigmanest Status</th>
                      <th>SAP Status</th>
                      <th>User</th>
                    </tr>
                  </thead>
                  <tbody>
                    <For each={programs()}>
                      {(program) => (
                        <tr>
                          <td>{program.ArchivePacketId}</td>
                          <td class="program-name">{program.ProgramName}</td>
                          <td>{program.MachineName}</td>
                          <td>{program.TaskName}</td>
                          <td>{program.WSName}</td>
                          <td>{program.NestType}</td>
                          <td class="status sigmanest-status">{program.SigmanestStatus}</td>
                          <td class="status sap-status">{program.SAPStatus}</td>
                          <td>{program.UserName}</td>
                        </tr>
                      )}
                    </For>
                  </tbody>
                </table>
              </div>
            </Show>
          </Show>
        </Show>
      </div>
    </main>
  );
}
