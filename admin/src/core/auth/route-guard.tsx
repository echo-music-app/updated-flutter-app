import { useQuery } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { Navigate } from "react-router";
import { adminFetch, UnauthorizedError } from "@/core/api/http-client";
import { queryKeys } from "@/core/api/query-keys";
import type { AdminSession } from "@/features/auth/domain/entities/admin-session";

interface RouteGuardProps {
  children: ReactNode;
}

export function RouteGuard({ children }: RouteGuardProps) {
  const {
    data: session,
    isLoading,
    error,
  } = useQuery({
    queryKey: queryKeys.admin.session(),
    queryFn: () => adminFetch<AdminSession>("/admin/v1/auth/session"),
    retry: false,
  });

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="admin-panel text-center">
          <span className="text-sm text-muted-foreground">Preparing admin workspace...</span>
        </div>
      </div>
    );
  }

  if (error instanceof UnauthorizedError || !session) {
    return <Navigate to="/login" replace />;
  }

  if (session.status === "disabled") {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}
