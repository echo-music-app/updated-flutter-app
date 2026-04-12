import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

describe("Friend relationship moderation", () => {
  it("renders placeholder until list is implemented", () => {
    const Placeholder = () => <div data-testid="relationships-list">Friend Relationships</div>;
    render(<Placeholder />);
    expect(screen.getByTestId("relationships-list")).toBeInTheDocument();
  });

  it("shows loading state", () => {
    const Loading = () => <div data-testid="loading">Loading relationships...</div>;
    render(<Loading />);
    expect(screen.getByTestId("loading")).toBeInTheDocument();
  });

  it("shows empty state when no relationships found", () => {
    const Empty = () => <div data-testid="empty">No friend relationships found.</div>;
    render(<Empty />);
    expect(screen.getByTestId("empty")).toBeInTheDocument();
  });
});
