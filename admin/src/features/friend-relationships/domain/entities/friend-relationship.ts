export type RelationshipStatus = "pending" | "active" | "blocked" | "removed";

export interface FriendRelationship {
  id: string;
  userAId: string;
  userBId: string;
  status: RelationshipStatus;
  createdAt: string;
  updatedAt: string;
}

export function fromApiRecord(raw: {
  id: string;
  user_a_id: string;
  user_b_id: string;
  status: string;
  created_at: string;
  updated_at: string;
}): FriendRelationship {
  return {
    id: raw.id,
    userAId: raw.user_a_id,
    userBId: raw.user_b_id,
    status: raw.status as RelationshipStatus,
    createdAt: raw.created_at,
    updatedAt: raw.updated_at,
  };
}
