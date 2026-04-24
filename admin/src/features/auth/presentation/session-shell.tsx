import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useNavigate } from "react-router";
import { useTheme } from "@/app/providers/theme-provider";
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
  const { theme, setTheme } = useTheme();

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
      <div className="admin-panel mb-5 flex flex-wrap items-center justify-between gap-3 p-4">
        <div>
          <p className="text-xs uppercase tracking-wide text-muted-foreground">Signed in as</p>
          <p className="text-sm font-semibold">{session?.display_name ?? "Admin"}</p>
        </div>
        <div className="flex items-center gap-2">
          <select
            aria-label="Theme mode"
            value={theme}
            onChange={(e) => setTheme(e.target.value as "light" | "dark" | "system")}
            className="rounded-lg border bg-card px-2.5 py-2 text-xs text-foreground"
          >
            <option value="system">System</option>
            <option value="light">Light</option>
            <option value="dark">Dark</option>
          </select>
          <button
            type="button"
            onClick={() => logoutMutation.mutate()}
            disabled={logoutMutation.isPending}
            className="rounded-lg border border-destructive/20 bg-destructive/10 px-3 py-2 text-xs font-semibold text-destructive transition hover:bg-destructive/15 disabled:opacity-50"
          >
            {logoutMutation.isPending ? "Signing out..." : "Sign out"}
          </button>
        </div>
      </div>
      {children}
    </AppShell>
  );
}
