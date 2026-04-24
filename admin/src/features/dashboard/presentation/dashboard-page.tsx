import { Link } from "react-router";
import { routes } from "@/core/routing/route-definitions";

export function DashboardPage() {
  return (
    <div className="admin-page">
      <div>
        <h2 className="admin-page-title">Dashboard</h2>
        <p className="admin-page-subtitle mt-1">Live moderation overview and quick navigation</p>
      </div>
      <div className="admin-panel">
        <p className="text-sm text-muted-foreground">
          Welcome to the Echo Admin workspace. Use the navigation to manage users, content, and
          friend relationships.
        </p>
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {[
          {
            label: "Users",
            href: routes.users.list,
            meta: "Profile moderation and status controls",
          },
          {
            label: "Content",
            href: routes.content.list,
            meta: "Review and enforce content actions",
          },
          {
            label: "Friend Relationships",
            href: routes.friendRelationships.list,
            meta: "Resolve edge-case relationship states",
          },
        ].map((item) => (
          <Link
            key={item.href}
            to={item.href}
            className="admin-panel group transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md"
          >
            <p className="admin-chip mb-3 border-primary/30 bg-primary/10 text-primary">
              Workspace
            </p>
            <h3 className="text-base font-semibold">{item.label}</h3>
            <p className="mt-1 text-sm text-muted-foreground">{item.meta}</p>
            <p className="mt-4 text-xs font-semibold text-primary/80 group-hover:text-primary">
              Open section →
            </p>
          </Link>
        ))}
      </div>
    </div>
  );
}
