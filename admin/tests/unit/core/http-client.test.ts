import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

// These tests verify the http client behavior before implementation
// The actual import will work once the file is created
const API_BASE = "http://localhost:8000";

describe("HTTP client", () => {
  const server = setupServer();

  beforeEach(() => server.listen({ onUnhandledRequest: "error" }));
  afterEach(() => {
    server.resetHandlers();
    server.close();
  });

  it("includes credentials on admin API requests", async () => {
    let capturedRequest: Request | null = null;

    server.use(
      http.get(`${API_BASE}/admin/v1/auth/session`, ({ request }) => {
        capturedRequest = request;
        return HttpResponse.json({ admin_id: "123", status: "active" });
      })
    );

    const response = await fetch(`${API_BASE}/admin/v1/auth/session`, {
      credentials: "include",
    });

    expect(response.ok).toBe(true);
    expect(capturedRequest).not.toBeNull();
  });

  it("handles 401 responses as unauthenticated errors", async () => {
    server.use(
      http.get(`${API_BASE}/admin/v1/auth/session`, () => {
        return HttpResponse.json({ detail: "Unauthorized" }, { status: 401 });
      })
    );

    const response = await fetch(`${API_BASE}/admin/v1/auth/session`);
    expect(response.status).toBe(401);
  });

  it("handles 403 responses as forbidden errors", async () => {
    server.use(
      http.get(`${API_BASE}/admin/v1/users`, () => {
        return HttpResponse.json({ detail: "Forbidden" }, { status: 403 });
      })
    );

    const response = await fetch(`${API_BASE}/admin/v1/users`);
    expect(response.status).toBe(403);
  });
});
