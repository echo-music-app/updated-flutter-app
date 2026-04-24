import { useState } from "react";
import { Link } from "react-router";
import { routes } from "@/core/routing/route-definitions";
import { useUserList } from "@/features/users/domain/use_cases/use-user-moderation";
import { DataTable } from "@/shared/table/data-table";
import { EmptyState } from "@/shared/ui/empty-state";

export function UsersListPage() {
  const [page, setPage] = useState(1);
  const { data, isLoading } = useUserList(page);

  const columns = [
    { key: "username", header: "Username" },
    { key: "email", header: "Email" },
    { key: "status", header: "Status" },
    { key: "created_at", header: "Created" },
    {
      key: "actions",
      header: "",
      render: (row: { id: string }) => (
        <Link to={routes.users.detail(row.id)} className="text-sm text-primary hover:underline">
          View
        </Link>
      ),
    },
  ];

  if (!isLoading && data?.items.length === 0) {
    return <EmptyState title="No users found" description="No users match the current filters." />;
  }

  return (
    <div className="admin-page">
      <div>
        <h2 className="admin-page-title">Users</h2>
        <p className="admin-page-subtitle mt-1">Monitor account health and moderation status</p>
      </div>
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        keyExtractor={(row) => row.id}
        emptyMessage="No users found."
      />
      <div className="admin-panel flex items-center gap-2">
        <button
          type="button"
          onClick={() => setPage((p) => Math.max(1, p - 1))}
          disabled={page <= 1}
          className="rounded-lg border bg-card px-3 py-1.5 text-sm font-medium transition hover:bg-accent disabled:opacity-50"
        >
          Previous
        </button>
        <button
          type="button"
          onClick={() => setPage((p) => p + 1)}
          disabled={!data?.items.length || data.items.length < 20}
          className="rounded-lg border bg-card px-3 py-1.5 text-sm font-medium transition hover:bg-accent disabled:opacity-50"
        >
          Next
        </button>
      </div>
    </div>
  );
}
