declare global {
  namespace NodeJS {
    interface ProcessEnv {
      ADMIN_TEST_EMAIL: string;
      ADMIN_TEST_PASSWORD: string;
    }
  }
}
