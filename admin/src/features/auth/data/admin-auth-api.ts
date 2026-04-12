import { adminFetch } from "@/core/api/http-client";
import type { AdminSession } from "@/features/auth/domain/entities/admin-session";

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse extends AdminSession {
  access_token: string;
}

export const adminAuthApi = {
  login: (data: LoginRequest): Promise<LoginResponse> =>
    adminFetch<LoginResponse>("/admin/v1/auth/login", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  getSession: (): Promise<AdminSession> => adminFetch<AdminSession>("/admin/v1/auth/session"),

  logout: (): Promise<void> => adminFetch<void>("/admin/v1/auth/logout", { method: "POST" }),
};
