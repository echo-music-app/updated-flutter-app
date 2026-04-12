export const routes = {
  login: "/login",
  dashboard: "/",
  users: {
    list: "/users",
    detail: (userId: string) => `/users/${userId}`,
  },
  content: {
    list: "/content",
    detail: (contentId: string) => `/content/${contentId}`,
  },
  friendRelationships: {
    list: "/friend-relationships",
    detail: (relationshipId: string) => `/friend-relationships/${relationshipId}`,
  },
} as const;
