export type UserModerationStatus = "active" | "restricted" | "suspended";

export interface ManagedUser {
  id: string;
  username: string;
  email: string;
  status: UserModerationStatus;
  createdAt: string;
  flagCount: number;
}

export function fromApiSummary(raw: {
  id: string;
  username: string;
  email: string;
  status: string;
  created_at: string;
  flag_count?: number;
}): ManagedUser {
  return {
    id: raw.id,
    username: raw.username,
    email: raw.email,
    status: raw.status as UserModerationStatus,
    createdAt: raw.created_at,
    flagCount: raw.flag_count ?? 0,
  };
}
