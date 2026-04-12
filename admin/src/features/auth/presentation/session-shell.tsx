import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useNavigate } from "react-router";
import { queryKeys } from "@/core/api/query-keys";
import { routes } from "@/core/routing/route-definitions";
import { adminAuthApi } from "@/features/auth/data/admin-auth-api";
import { AppShell } from "@/shared/layout/app-shell";

interface SessionShellProps {
  children: ReactNode;
}

export function SessionShell({ children }: SessionShellProps) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: session } = useQuery({
    queryKey: queryKeys.admin.session(),
    queryFn: adminAuthApi.getSession,
    retry: false,
  });

  const logoutMutation = useMutation({
    mutationFn: adminAuthApi.logout,
    onSuccess: () => {
      queryClient.clear();
      navigate(routes.login, { replace: true });
    },
  });

  return (
    <AppShell>
      <div className="flex items-center justify-between mb-6 pb-4 border-b">
        <span className="text-sm text-muted-foreground">{session?.display_name ?? "Admin"}</span>
        <button
          type="button"
          onClick={() => logoutMutation.mutate()}
          disabled={logoutMutation.isPending}
          className="text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          Sign out
        </button>
      </div>
      {children}
    </AppShell>
  );
}
