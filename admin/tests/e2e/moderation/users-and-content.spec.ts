import { expect, test } from "@playwright/test";

test.describe("User and content moderation", () => {
  test("users list page requires authentication", async ({ page }) => {
    await page.goto("/users");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });

  test("content list page requires authentication", async ({ page }) => {
    await page.goto("/content");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });

  test("user detail page requires authentication", async ({ page }) => {
    await page.goto("/users/some-user-id");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });

  test("content detail page requires authentication", async ({ page }) => {
    await page.goto("/content/some-content-id");
    await expect(page).toHaveURL(/\/login/, { timeout: 5000 });
  });
});
