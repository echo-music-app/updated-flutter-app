import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "@/core/api/query-keys";
import { type ContentActionRequest, contentApi } from "@/features/content/data/content-api";

export function useContentList(page = 1, pageSize = 20) {
  return useQuery({
    queryKey: queryKeys.admin.content.list({ page, pageSize }),
    queryFn: () => contentApi.listContent({ page, page_size: pageSize }),
  });
}

export function useContentDetail(contentId: string) {
  return useQuery({
    queryKey: queryKeys.admin.content.detail(contentId),
    queryFn: () => contentApi.getContent(contentId),
    enabled: !!contentId,
  });
}

export function useContentAction() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ contentId, ...data }: { contentId: string } & ContentActionRequest) =>
      contentApi.applyAction(contentId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.admin.content.list() });
    },
  });
}
