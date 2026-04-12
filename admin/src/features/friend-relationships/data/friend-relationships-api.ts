import { adminFetch } from "@/core/api/http-client";

export interface FriendRelationshipRecord {
  id: string;
  user_a_id: string;
  user_b_id: string;
  status: "pending" | "active" | "blocked" | "removed";
  created_at: string;
  updated_at: string;
}

export interface RelationshipActionRequest {
  action_type: "remove" | "restore" | "delete_permanently";
  reason: string;
  confirmed?: boolean;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  page_size: number;
}

export const friendRelationshipsApi = {
  listRelationships: (params?: {
    page?: number;
    page_size?: number;
  }): Promise<PaginatedResponse<FriendRelationshipRecord>> => {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.set("page", String(params.page));
    if (params?.page_size) searchParams.set("page_size", String(params.page_size));
    const qs = searchParams.toString();
    return adminFetch<PaginatedResponse<FriendRelationshipRecord>>(
      `/admin/v1/friend-relationships${qs ? `?${qs}` : ""}`
    );
  },

  getRelationship: (id: string): Promise<FriendRelationshipRecord> =>
    adminFetch<FriendRelationshipRecord>(`/admin/v1/friend-relationships/${id}`),

  applyAction: (
    id: string,
    data: RelationshipActionRequest
  ): Promise<{ outcome: string; message: string }> =>
    adminFetch(`/admin/v1/friend-relationships/${id}/actions`, {
      method: "POST",
      body: JSON.stringify(data),
    }),

  deleteRelationship: (id: string): Promise<{ outcome: string; message: string }> =>
    adminFetch(`/admin/v1/friend-relationships/${id}`, { method: "DELETE" }),
};
