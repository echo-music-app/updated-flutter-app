import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router";
import { describe, expect, it } from "vitest";

// The AppShell nav must NOT include any message links
// This test verifies the navigation structure before implementation
describe("Message privacy boundary in navigation", () => {
  it("navigation does not include message links", async () => {
    const { AppShell } = await import("@/shared/layout/app-shell");

    render(
      <MemoryRouter>
        <AppShell>
          <div>Content</div>
        </AppShell>
      </MemoryRouter>
    );

    // Messages should not appear anywhere in the navigation
    expect(screen.queryByText(/message/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /message/i })).not.toBeInTheDocument();
  });

  it("navigation includes only allowed sections", async () => {
    const { AppShell } = await import("@/shared/layout/app-shell");

    render(
      <MemoryRouter>
        <AppShell>
          <div>Content</div>
        </AppShell>
      </MemoryRouter>
    );

    // These sections must be present
    expect(screen.getByRole("link", { name: /users/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /content/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /friend relationship/i })).toBeInTheDocument();
  });
});
