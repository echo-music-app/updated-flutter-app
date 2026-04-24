import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Link } from "react-router";
import { queryKeys } from "@/core/api/query-keys";
import { routes } from "@/core/routing/route-definitions";
import { friendRelationshipsApi } from "@/features/friend-relationships/data/friend-relationships-api";
import { DataTable } from "@/shared/table/data-table";
import { EmptyState } from "@/shared/ui/empty-state";

export function RelationshipListPage() {
  const [page] = useState(1);
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.admin.friendRelationships.list({ page }),
    queryFn: () => friendRelationshipsApi.listRelationships({ page }),
  });

  const columns = [
    { key: "user_a_id", header: "User A" },
    { key: "user_b_id", header: "User B" },
    { key: "status", header: "Status" },
    { key: "created_at", header: "Created" },
    {
      key: "actions",
      header: "",
      render: (row: { id: string }) => (
        <Link
          to={routes.friendRelationships.detail(row.id)}
          className="text-sm text-primary hover:underline"
        >
          Review
        </Link>
      ),
    },
  ];

  if (!isLoading && data?.items.length === 0) {
    return <EmptyState title="No relationships found" />;
  }

  return (
    <div className="admin-page">
      <div>
        <h2 className="admin-page-title">Friend Relationships</h2>
        <p className="admin-page-subtitle mt-1">
          Audit relationship states and resolve moderation requests
        </p>
      </div>
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        keyExtractor={(row) => row.id}
        emptyMessage="No relationships found."
      />
    </div>
  );
}
