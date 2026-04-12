import { useState } from "react";
import { Link } from "react-router";
import { routes } from "@/core/routing/route-definitions";
import { useContentList } from "@/features/content/domain/use_cases/use-content-moderation";
import { DataTable } from "@/shared/table/data-table";
import { EmptyState } from "@/shared/ui/empty-state";

export function ContentListPage() {
  const [page] = useState(1);
  const { data, isLoading } = useContentList(page);

  const columns = [
    { key: "content_type", header: "Type" },
    { key: "owner_user_id", header: "Owner" },
    { key: "status", header: "Status" },
    { key: "created_at", header: "Created" },
    {
      key: "actions",
      header: "",
      render: (row: { id: string }) => (
        <Link to={routes.content.detail(row.id)} className="text-sm text-primary hover:underline">
          Review
        </Link>
      ),
    },
  ];

  if (!isLoading && data?.items.length === 0) {
    return <EmptyState title="No content found" />;
  }

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">Content</h2>
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        keyExtractor={(row) => row.id}
        emptyMessage="No content found."
      />
    </div>
  );
}
