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
    <div className="flex h-screen bg-background">
      <aside className="w-64 border-r bg-card flex flex-col">
        <div className="p-6 border-b">
          <h1 className="text-lg font-semibold">Echo Admin</h1>
        </div>
        <nav className="flex-1 p-4 space-y-1">
          {NAV_ITEMS.map((item) => {
            const isActive = location.pathname === item.href;
            return (
              <Link
                key={item.href}
                to={item.href}
                className={`block px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>
      <main className="flex-1 overflow-auto">
        <div className="p-6">{children}</div>
      </main>
    </div>
  );
}
