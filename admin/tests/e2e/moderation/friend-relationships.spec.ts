import { expect, test } from "@playwright/test";

test.describe("Friend relationship moderation", () => {
  test("friend relationships page requires authentication", async ({ page }) => {
    await page.goto("/friend-relationships");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });

  test("relationship detail page requires authentication", async ({ page }) => {
    await page.goto("/friend-relationships/some-id");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });
});
