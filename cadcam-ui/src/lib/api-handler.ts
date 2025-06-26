import { ApiResponse } from "./types";

export type ApiHandler<T> = () => Promise<T>;

export async function handleApiRequest<T>(
  handler: ApiHandler<T>,
  successMessage?: string
): Promise<Response> {
  try {
    const data = await handler();
    
    const response: ApiResponse<T> = {
      data,
      success: true,
      message: successMessage
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache'
      }
    });

  } catch (error) {
    console.error('API request error:', error);
    
    const errorResponse: ApiResponse<T> = {
      data: null as T,
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