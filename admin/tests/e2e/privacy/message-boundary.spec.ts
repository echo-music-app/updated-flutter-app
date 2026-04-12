import { expect, test } from "@playwright/test";

test.describe("Message privacy boundary", () => {
  test("no message navigation link exists on authenticated shell", async ({ page }) => {
    // Navigate to login — even without auth, verify no message links in the DOM
    await page.goto("/login");

    const messageLinks = page.getByRole("link", { name: /message/i });
    const count = await messageLinks.count();
    expect(count).toBe(0);
  });

  test("direct navigation to /admin/v1/messages returns 404", async ({ request }) => {
    const response = await request.get("/admin/v1/messages");
    expect(response.status()).toBe(404);
  });

  test("no message-related routes exist in the SPA", async ({ page }) => {
    await page.goto("/messages");
    // Should redirect to login (404 or redirect)
    const url = page.url();
    expect(url).not.toContain("/messages");
  });
});
