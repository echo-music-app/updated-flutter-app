export type ContentModerationStatus = "visible" | "removed" | "flagged";

export interface ManagedContent {
  id: string;
  ownerUserId: string;
  status: ContentModerationStatus;
  contentType: string;
  previewText: string | null;
  createdAt: string;
}

export function fromApiItem(raw: {
  id: string;
  owner_user_id: string;
  status: string;
  content_type: string;
  preview_text: string | null;
  created_at: string;
}): ManagedContent {
  return {
    id: raw.id,
    ownerUserId: raw.owner_user_id,
    status: raw.status as ContentModerationStatus,
    contentType: raw.content_type,
    previewText: raw.preview_text,
    createdAt: raw.created_at,
  };
}
