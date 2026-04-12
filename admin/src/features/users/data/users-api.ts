import { adminFetch } from "@/core/api/http-client";

export interface ManagedUserSummary {
  id: string;
  username: string;
  email: string;
  status: "active" | "restricted" | "suspended";
  created_at: string;
  flag_count?: number;
}

export interface ManagedUserDetail extends ManagedUserSummary {
  bio: string | null;
  preferred_genres: string[];
  moderation_history: AdminAction[];
  owned_content_ids: string[];
  friend_relationship_ids: string[];
}

export interface AdminAction {
  id: string;
  occurred_at: string;
  actor_admin_id: string;
  entity_type: string;
  entity_id: string | null;
  operation_name: string;
  outcome: "success" | "denied" | "failed";
  change_payload: Record<string, unknown>;
}

export interface UserStatusUpdateRequest {
  status: string;
  reason: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  page_size: number;
}

export const usersApi = {
  listUsers: (params?: {
    page?: number;
    page_size?: number;
    query?: string;
  }): Promise<PaginatedResponse<ManagedUserSummary>> => {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.set("page", String(params.page));
    if (params?.page_size) searchParams.set("page_size", String(params.page_size));
    if (params?.query) searchParams.set("query", params.query);
    const qs = searchParams.toString();
    return adminFetch<PaginatedResponse<ManagedUserSummary>>(
      `/admin/v1/users${qs ? `?${qs}` : ""}`
    );
  },

  getUser: (userId: string): Promise<ManagedUserSummary> =>
    adminFetch<ManagedUserSummary>(`/admin/v1/users/${userId}`),

  updateUserStatus: (
    userId: string,
    data: UserStatusUpdateRequest
  ): Promise<{ outcome: string; message: string; user: ManagedUserSummary }> =>
    adminFetch(`/admin/v1/users/${userId}/status`, {
      method: "PATCH",
      body: JSON.stringify(data),
    }),
};
