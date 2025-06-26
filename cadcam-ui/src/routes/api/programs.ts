import { APIEvent } from "@solidjs/start/server";
import { DatabaseService } from "~/lib/database";
import { Program, ApiResponse } from "~/lib/types";

export async function GET(event: APIEvent): Promise<Response> {
  try {
    const db = new DatabaseService();
    
    const query = `
      SELECT 
        ArchivePacketId,
        ProgramName,
        MachineName,
        TaskName,
        WSName,
        NestType,
        SigmanestStatus,
        SAPStatus,
        UserName
      FROM sap.ActivePrograms 
    `;

    const result = await db.query<Program>(query);
    
    const response: ApiResponse<Program[]> = {
      data: result.recordset,
      success: true,
      message: `Retrieved ${result.recordset.length} programs`
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache'
      }
    });

  } catch (error) {
    console.error('Error fetching programs:', error);
    
    const errorResponse: ApiResponse<Program[]> = {
      data: [],
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };

    return new Response(JSON.stringify(errorResponse), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
}
