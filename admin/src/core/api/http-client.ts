import { env } from "@/core/config/env";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly detail: string
  ) {
    super(`API error ${status}: ${detail}`);
    this.name = "ApiError";
  }
}

export class UnauthorizedError extends ApiError {
  constructor(detail = "Unauthorized") {
    super(401, detail);
    this.name = "UnauthorizedError";
  }
}

export class ForbiddenError extends ApiError {
  constructor(detail = "Forbidden") {
    super(403, detail);
    this.name = "ForbiddenError";
  }
}

async function parseErrorDetail(response: Response): Promise<string> {
  try {
    const body = await response.json();
    return typeof body?.detail === "string" ? body.detail : response.statusText;
  } catch {
    return response.statusText;
  }
}

export async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const url = `${env.VITE_API_BASE_URL}${path}`;

  const response = await fetch(url, {
    ...init,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });

  if (!response.ok) {
    const detail = await parseErrorDetail(response);
    if (response.status === 401) {
      throw new UnauthorizedError(detail);
    }
    if (response.status === 403) {
      throw new ForbiddenError(detail);
    }
    throw new ApiError(response.status, detail);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return response.json() as Promise<T>;
}
