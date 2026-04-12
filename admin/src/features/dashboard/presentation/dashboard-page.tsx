export function DashboardPage() {
  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Dashboard</h2>
      <p className="text-muted-foreground">
        Welcome to the Echo Admin workspace. Use the navigation to manage users, content, and friend
        relationships.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {[
          { label: "Users", href: "/users" },
          { label: "Content", href: "/content" },
          { label: "Friend Relationships", href: "/friend-relationships" },
        ].map((item) => (
          <a
            key={item.href}
            href={item.href}
            className="rounded-lg border bg-card p-6 hover:bg-accent transition-colors"
          >
            <h3 className="font-medium">{item.label}</h3>
            <p className="text-sm text-muted-foreground mt-1">Manage {item.label.toLowerCase()}</p>
          </a>
        ))}
      </div>
    </div>
  );
}
