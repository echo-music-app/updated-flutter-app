import { useState } from "react";
import { useParams } from "react-router";
import {
  useContentAction,
  useContentDetail,
} from "@/features/content/domain/use_cases/use-content-moderation";
import { AdminActionForm } from "@/shared/forms/admin-action-form";
import { EmptyState } from "@/shared/ui/empty-state";

// Message-related navigation is explicitly excluded from this page (US3)
export function ContentDetailPage() {
  const { contentId } = useParams<{ contentId: string }>();
  const { data: content, isLoading } = useContentDetail(contentId ?? "");
  const applyAction = useContentAction();
  const [feedback, setFeedback] = useState<string | null>(null);

  if (isLoading) {
    return <div className="text-muted-foreground">Loading content...</div>;
  }

  if (!content) {
    return <EmptyState title="Content not found" />;
  }

  const handleAction = (
    actionType: "remove" | "restore" | "delete_permanently",
    { reason, confirmed }: { reason: string; confirmed?: boolean }
  ) => {
    applyAction.mutate(
      { contentId: content.id, action_type: actionType, reason, confirmed },
      {
        onSuccess: () => setFeedback(`Action '${actionType}' applied`),
        onError: () => setFeedback("Failed to apply action"),
      }
    );
  };

  return (
    <div className="admin-page">
      <div className="admin-panel">
        <h2 className="admin-page-title">Content Review</h2>
        <p className="mt-1 text-sm text-muted-foreground">ID: {content.id}</p>
        <p className="mt-2 text-sm">
          Status: <span className="font-medium">{content.status}</span>
        </p>
        <p className="text-sm">Type: {content.content_type}</p>
      </div>

      {feedback && (
        <div role="alert" className="admin-panel border-primary/30 bg-primary/10 text-sm">
          {feedback}
        </div>
      )}

      <div className="admin-panel space-y-4">
        <AdminActionForm
          title="Remove Content"
          onSubmit={({ reason }) => handleAction("remove", { reason })}
          isLoading={applyAction.isPending}
        />
        <AdminActionForm
          title="Permanently Delete"
          isDestructive
          onSubmit={({ reason, confirmed }) =>
            handleAction("delete_permanently", { reason, confirmed })
          }
          isLoading={applyAction.isPending}
        />
      </div>
    </div>
  );
}
