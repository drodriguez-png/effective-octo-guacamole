import { APIEvent } from "@solidjs/start/server";
import { DatabaseService } from "~/lib/database";
import { Program } from "~/lib/types";
import { handleApiRequest } from "~/lib/api-handler";

export async function GET(event: APIEvent): Promise<Response> {
  return handleApiRequest(async () => {
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
    return result.recordset;
  }, `Retrieved programs successfully`);
}
