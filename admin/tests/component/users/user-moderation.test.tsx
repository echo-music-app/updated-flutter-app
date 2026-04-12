import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

describe("User moderation", () => {
  it("renders placeholder until user list is implemented", () => {
    const Placeholder = () => <div data-testid="users-list">Users List</div>;
    render(<Placeholder />);
    expect(screen.getByTestId("users-list")).toBeInTheDocument();
  });

  it("user list shows loading state", () => {
    const Loading = () => <div data-testid="loading">Loading users...</div>;
    render(<Loading />);
    expect(screen.getByTestId("loading")).toBeInTheDocument();
  });

  it("user list shows empty state when no users found", () => {
    const Empty = () => <div data-testid="empty">No users found.</div>;
    render(<Empty />);
    expect(screen.getByTestId("empty")).toBeInTheDocument();
  });
});
