import { adminFetch } from "@/core/api/http-client";

export interface ManagedContentItem {
  id: string;
  owner_user_id: string;
  status: "visible" | "removed" | "flagged";
  content_type: string;
  preview_text: string | null;
  created_at: string;
}

export interface ContentActionRequest {
  action_type: "remove" | "restore" | "delete_permanently";
  reason: string;
  confirmed?: boolean;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  page_size: number;
}

export const contentApi = {
  listContent: (params?: {
    page?: number;
    page_size?: number;
  }): Promise<PaginatedResponse<ManagedContentItem>> => {
    const searchParams = new URLSearchParams();
    if (params?.page) searchParams.set("page", String(params.page));
    if (params?.page_size) searchParams.set("page_size", String(params.page_size));
    const qs = searchParams.toString();
    return adminFetch<PaginatedResponse<ManagedContentItem>>(
      `/admin/v1/content${qs ? `?${qs}` : ""}`
    );
  },

  getContent: (contentId: string): Promise<ManagedContentItem> =>
    adminFetch<ManagedContentItem>(`/admin/v1/content/${contentId}`),

  applyAction: (
    contentId: string,
    data: ContentActionRequest
  ): Promise<{ outcome: string; message: string }> =>
    adminFetch(`/admin/v1/content/${contentId}/actions`, {
      method: "POST",
      body: JSON.stringify(data),
    }),

  deleteContent: (contentId: string): Promise<{ outcome: string; message: string }> =>
    adminFetch(`/admin/v1/content/${contentId}`, { method: "DELETE" }),
};
