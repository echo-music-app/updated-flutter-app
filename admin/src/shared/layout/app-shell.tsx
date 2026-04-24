import type { ReactNode } from "react";
import { Link, useLocation } from "react-router";
import { routes } from "@/core/routing/route-definitions";

interface NavItem {
  label: string;
  href: string;
}

// Message management is explicitly excluded from navigation
const NAV_ITEMS: NavItem[] = [
  { label: "Dashboard", href: routes.dashboard },
  { label: "Users", href: routes.users.list },
  { label: "Content", href: routes.content.list },
  { label: "Friend Relationships", href: routes.friendRelationships.list },
];

interface AppShellProps {
  children: ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  const location = useLocation();

  return (
    <div className="flex min-h-screen bg-background px-4 py-4 md:px-6">
      <aside className="sticky top-4 hidden h-[calc(100vh-2rem)] w-72 flex-col overflow-hidden rounded-2xl border bg-card/90 shadow-md backdrop-blur-sm lg:flex">
        <div className="border-b px-6 py-5">
          <p className="admin-chip border-primary/30 bg-primary/10 text-primary">Admin Console</p>
          <h1 className="mt-3 text-lg font-semibold tracking-tight">Echo Control Room</h1>
          <p className="mt-1 text-xs text-muted-foreground">Moderation and oversight workspace</p>
        </div>
        <nav className="flex-1 space-y-1 p-4">
          {NAV_ITEMS.map((item) => {
            const isActive =
              location.pathname === item.href || location.pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.href}
                to={item.href}
                className={`block rounded-lg px-3 py-2.5 text-sm font-medium transition-all ${
                  isActive
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "text-muted-foreground hover:translate-x-0.5 hover:bg-accent hover:text-accent-foreground"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="border-t px-4 py-4 text-xs text-muted-foreground">
          US3 privacy boundary active: inbox features are intentionally excluded.
        </div>
      </aside>
      <main className="min-w-0 flex-1 overflow-auto lg:pl-6">
        <div className="mx-auto w-full max-w-7xl">{children}</div>
      </main>
    </div>
  );
}
