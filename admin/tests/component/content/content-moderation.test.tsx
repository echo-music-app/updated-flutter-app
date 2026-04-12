import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

describe("Content moderation", () => {
  it("renders placeholder until content list is implemented", () => {
    const Placeholder = () => <div data-testid="content-list">Content List</div>;
    render(<Placeholder />);
    expect(screen.getByTestId("content-list")).toBeInTheDocument();
  });

  it("content list shows loading state", () => {
    const Loading = () => <div data-testid="loading">Loading content...</div>;
    render(<Loading />);
    expect(screen.getByTestId("loading")).toBeInTheDocument();
  });
});
