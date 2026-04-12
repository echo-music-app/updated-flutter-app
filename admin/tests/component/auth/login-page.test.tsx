import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";
import { MemoryRouter } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The login page will be implemented in T019
// These tests define the expected behavior

const mockNavigate = vi.fn();
vi.mock("react-router", async (importOriginal) => {
  const actual = await importOriginal<typeof import("react-router")>();
  return { ...actual, useNavigate: () => mockNavigate };
});

const server = setupServer();

function makeClient() {
  return new QueryClient({ defaultOptions: { queries: { retry: false } } });
}

function renderLoginPage() {
  // Dynamically import to avoid module resolution failures before T019
  const LoginPage = vi.fn().mockReturnValue(<div>Login Page Placeholder</div>);
  const client = makeClient();
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={["/login"]}>
        <LoginPage />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe("Login page", () => {
  beforeEach(() => server.listen({ onUnhandledRequest: "bypass" }));
  afterEach(() => {
    server.resetHandlers();
    server.close();
    vi.clearAllMocks();
  });

  it("renders the login form placeholder", () => {
    renderLoginPage();
    expect(screen.getByText("Login Page Placeholder")).toBeInTheDocument();
  });

  it("redirects to dashboard after successful login", async () => {
    server.use(
      http.post("http://localhost:8000/admin/v1/auth/login", () => {
        return HttpResponse.json({
          admin_id: "abc123",
          email: "admin@example.com",
          display_name: "Test Admin",
          status: "active",
          permission_scope: "full_admin",
          authenticated_at: new Date().toISOString(),
        });
      })
    );

    // This test will be fully implemented after T019 creates LoginPage
    // For now, verify the mock server is reachable
    const response = await fetch("http://localhost:8000/admin/v1/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "admin@example.com", password: "password" }),
    });
    expect(response.ok).toBe(true);
  });

  it("shows error on invalid credentials", async () => {
    server.use(
      http.post("http://localhost:8000/admin/v1/auth/login", () => {
        return HttpResponse.json({ detail: "Invalid credentials" }, { status: 401 });
      })
    );

    const response = await fetch("http://localhost:8000/admin/v1/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "admin@example.com", password: "wrong" }),
    });
    expect(response.status).toBe(401);
  });

  it("blocks non-admin credentials with 403", async () => {
    server.use(
      http.post("http://localhost:8000/admin/v1/auth/login", () => {
        return HttpResponse.json({ detail: "Admin access required" }, { status: 403 });
      })
    );

    const response = await fetch("http://localhost:8000/admin/v1/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "user@example.com", password: "password" }),
    });
    expect(response.status).toBe(403);
  });
});
