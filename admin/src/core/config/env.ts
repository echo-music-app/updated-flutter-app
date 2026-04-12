import { z } from "zod";

const envSchema = z.object({
  VITE_API_BASE_URL: z.url().default("http://localhost:8000"),
  VITE_APP_NAME: z.string().default("Echo Admin"),
});

function parseEnv() {
  const result = envSchema.safeParse(import.meta.env);
  if (!result.success) {
    throw new Error(`Invalid environment configuration: ${result.error.message}`);
  }
  return result.data;
}

export const env = parseEnv();
