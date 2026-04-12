export const queryKeys = {
  admin: {
    session: () => ["admin", "session"] as const,
    users: {
      list: (filters?: Record<string, unknown>) => ["admin", "users", "list", filters] as const,
      detail: (userId: string) => ["admin", "users", userId] as const,
    },
    content: {
      list: (filters?: Record<string, unknown>) => ["admin", "content", "list", filters] as const,
      detail: (contentId: string) => ["admin", "content", contentId] as const,
    },
    friendRelationships: {
      list: (filters?: Record<string, unknown>) =>
        ["admin", "friend-relationships", "list", filters] as const,
      detail: (relationshipId: string) =>
        ["admin", "friend-relationships", relationshipId] as const,
    },
  },
} as const;
