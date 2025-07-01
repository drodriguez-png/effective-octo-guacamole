import { APIEvent } from "@solidjs/start/server";
import { DatabaseService } from "~/lib/database";
import { handleApiRequest } from "~/lib/api-handler";

interface PartOperationsRequest {
  partName: string;
  operation1: string;
  operation2: string;
  operation3: string;
}

export async function POST(event: APIEvent): Promise<Response> {
  return handleApiRequest(async () => {
    const body = await event.request.json() as PartOperationsRequest;
    const { partName, operation1, operation2, operation3 } = body;

    if (!partName) {
      throw new Error("Part name is required");
    }

    const db = new DatabaseService();
    
    const result = await db.execute("sap.SetPartOperations", {
      'part_name': partName,
      'op1': operation1,
      'op2': operation2,
      'op3': operation3
    });

    return { 
      success: true,
      message: "Part operations submitted successfully",
      partName,
      operations: [operation1, operation2, operation3].filter(Boolean)
    };
  }, "Part operations submitted successfully");
}
