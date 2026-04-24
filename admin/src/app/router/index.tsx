import { lazy, Suspense } from "react";
import { createBrowserRouter, Navigate, RouterProvider } from "react-router";
import { RouteGuard } from "@/core/auth/route-guard";
import { routes } from "@/core/routing/route-definitions";
import { SessionShell } from "@/features/auth/presentation/session-shell";

// Auth
const LoginPage = lazy(() =>
  import("@/features/auth/presentation/login-page").then((m) => ({ default: m.LoginPage }))
);

// Dashboard
const DashboardPage = lazy(() =>
  import("@/features/dashboard/presentation/dashboard-page").then((m) => ({
    default: m.DashboardPage,
  }))
);

// Users
const UsersListPage = lazy(() =>
  import("@/features/users/presentation/users-list-page").then((m) => ({
    default: m.UsersListPage,
  }))
);
const UserDetailPage = lazy(() =>
  import("@/features/users/presentation/user-detail-page").then((m) => ({
    default: m.UserDetailPage,
  }))
);

// Content
const ContentListPage = lazy(() =>
  import("@/features/content/presentation/content-list-page").then((m) => ({
    default: m.ContentListPage,
  }))
);
const ContentDetailPage = lazy(() =>
  import("@/features/content/presentation/content-detail-page").then((m) => ({
    default: m.ContentDetailPage,
  }))
);

// Friend Relationships
const RelationshipListPage = lazy(() =>
  import("@/features/friend-relationships/presentation/relationship-list-page").then((m) => ({
    default: m.RelationshipListPage,
  }))
);
const RelationshipDetailPage = lazy(() =>
  import("@/features/friend-relationships/presentation/relationship-detail-page").then((m) => ({
    default: m.RelationshipDetailPage,
  }))
);

function LoadingFallback() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="admin-panel text-center">
        <span className="text-sm text-muted-foreground">Loading module...</span>
      </div>
    </div>
  );
}

function Guarded({ children }: { children: React.ReactNode }) {
  return (
    <RouteGuard>
      <SessionShell>
        <Suspense fallback={<LoadingFallback />}>{children}</Suspense>
      </SessionShell>
    </RouteGuard>
  );
}

const router = createBrowserRouter([
  {
    path: routes.login,
    element: (
      <Suspense fallback={<LoadingFallback />}>
        <LoginPage />
      </Suspense>
    ),
  },
  {
    path: routes.dashboard,
    element: (
      <Guarded>
        <DashboardPage />
      </Guarded>
    ),
  },
  {
    path: routes.users.list,
    element: (
      <Guarded>
        <UsersListPage />
      </Guarded>
    ),
  },
  {
    path: "/users/:userId",
    element: (
      <Guarded>
        <UserDetailPage />
      </Guarded>
    ),
  },
  {
    path: routes.content.list,
    element: (
      <Guarded>
        <ContentListPage />
      </Guarded>
    ),
  },
  {
    path: "/content/:contentId",
    element: (
      <Guarded>
        <ContentDetailPage />
      </Guarded>
    ),
  },
  {
    path: routes.friendRelationships.list,
    element: (
      <Guarded>
        <RelationshipListPage />
      </Guarded>
    ),
  },
  {
    path: "/friend-relationships/:relationshipId",
    element: (
      <Guarded>
        <RelationshipDetailPage />
      </Guarded>
    ),
  },
  // Explicit message route blocks (US3 — message management excluded)
  {
    path: "/messages",
    element: <Navigate to={routes.dashboard} replace />,
  },
  {
    path: "/messages/*",
    element: <Navigate to={routes.dashboard} replace />,
  },
  // 404 catch-all
  {
    path: "*",
    element: (
      <Guarded>
        <div className="flex flex-col items-center justify-center h-screen">
          <h2 className="text-2xl font-bold">404 Not Found</h2>
          <p className="text-muted-foreground mt-2">This page does not exist.</p>
        </div>
      </Guarded>
    ),
  },
]);

export function Router() {
  return <RouterProvider router={router} />;
}
