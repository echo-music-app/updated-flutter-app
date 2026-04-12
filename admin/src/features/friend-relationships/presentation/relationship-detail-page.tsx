import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useParams } from "react-router";
import { queryKeys } from "@/core/api/query-keys";
import { friendRelationshipsApi } from "@/features/friend-relationships/data/friend-relationships-api";
import { AdminActionForm } from "@/shared/forms/admin-action-form";
import { EmptyState } from "@/shared/ui/empty-state";

export function RelationshipDetailPage() {
  const { relationshipId } = useParams<{ relationshipId: string }>();
  const queryClient = useQueryClient();
  const [feedback, setFeedback] = useState<string | null>(null);

  const { data: relationship, isLoading } = useQuery({
    queryKey: queryKeys.admin.friendRelationships.detail(relationshipId ?? ""),
    queryFn: () => friendRelationshipsApi.getRelationship(relationshipId ?? ""),
    enabled: !!relationshipId,
  });

  const applyAction = useMutation({
    mutationFn: ({
      actionType,
      reason,
      confirmed,
    }: {
      actionType: "remove" | "restore" | "delete_permanently";
      reason: string;
      confirmed: boolean;
    }) => {
      if (!relationshipId) {
        return Promise.reject(new Error("Relationship ID is missing"));
      }

      return friendRelationshipsApi.applyAction(relationshipId, {
        action_type: actionType,
        reason,
        confirmed,
      });
    },
    onSuccess: (data) => {
      setFeedback(data.message);
      queryClient.invalidateQueries({
        queryKey: queryKeys.admin.friendRelationships.list(),
      });
    },
    onError: () => setFeedback("Action failed. Please try again."),
  });

  if (isLoading) return <div className="text-muted-foreground">Loading...</div>;
  if (!relationship) return <EmptyState title="Relationship not found" />;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">Friend Relationship</h2>
        <p className="text-sm text-muted-foreground">ID: {relationship.id}</p>
        <p className="text-sm mt-1">
          Status: <span className="font-medium">{relationship.status}</span>
        </p>
        <p className="text-sm">User A: {relationship.user_a_id}</p>
        <p className="text-sm">User B: {relationship.user_b_id}</p>
      </div>

      {feedback && (
        <div role="alert" className="rounded-md bg-primary/10 px-3 py-2 text-sm">
          {feedback}
        </div>
      )}

      <div className="space-y-4">
        <AdminActionForm
          title="Remove Relationship"
          onSubmit={({ reason }) =>
            applyAction.mutate({ actionType: "remove", reason, confirmed: false })
          }
          isLoading={applyAction.isPending}
        />
        <AdminActionForm
          title="Permanently Delete"
          isDestructive
          onSubmit={({ reason, confirmed }) =>
            applyAction.mutate({
              actionType: "delete_permanently",
              reason,
              confirmed: confirmed ?? false,
            })
          }
          isLoading={applyAction.isPending}
        />
      </div>
    </div>
  );
}
