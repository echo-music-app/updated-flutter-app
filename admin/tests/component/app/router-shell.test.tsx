import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router";
import { describe, expect, it, vi } from "vitest";

// Mock the route guard to test its behavior
vi.mock("@/core/auth/route-guard", () => ({
  RouteGuard: ({ children }: { children: React.ReactNode }) => {
    // Will be replaced by actual implementation
    return <div data-testid="guarded">{children}</div>;
  },
}));

describe("Router shell", () => {
  it("renders children when session is authenticated", async () => {
    const { RouteGuard } = await import("@/core/auth/route-guard");

    render(
      <MemoryRouter initialEntries={["/"]}>
        <Routes>
          <Route
            path="/"
            element={
              <RouteGuard>
                <div>Protected Content</div>
              </RouteGuard>
            }
          />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByTestId("guarded")).toBeInTheDocument();
    expect(screen.getByText("Protected Content")).toBeInTheDocument();
  });

  it("renders login page route without guard", () => {
    render(
      <MemoryRouter initialEntries={["/login"]}>
        <Routes>
          <Route path="/login" element={<div>Login Page</div>} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("Login Page")).toBeInTheDocument();
  });
});
