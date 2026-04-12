import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "@/core/api/query-keys";
import { usersApi } from "@/features/users/data/users-api";

export function useUserList(page = 1, pageSize = 20, query?: string) {
  return useQuery({
    queryKey: queryKeys.admin.users.list({ page, pageSize, query }),
    queryFn: () => usersApi.listUsers({ page, page_size: pageSize, query }),
  });
}

export function useUserDetail(userId: string) {
  return useQuery({
    queryKey: queryKeys.admin.users.detail(userId),
    queryFn: () => usersApi.getUser(userId),
    enabled: !!userId,
  });
}

export function useUpdateUserStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ userId, status, reason }: { userId: string; status: string; reason: string }) =>
      usersApi.updateUserStatus(userId, { status, reason }),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.admin.users.list() });
      queryClient.invalidateQueries({
        queryKey: queryKeys.admin.users.detail(variables.userId),
      });
    },
  });
}
