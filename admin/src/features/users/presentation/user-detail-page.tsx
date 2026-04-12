import { useState } from "react";
import { useParams } from "react-router";
import {
  useUpdateUserStatus,
  useUserDetail,
} from "@/features/users/domain/use_cases/use-user-moderation";
import { AdminActionForm } from "@/shared/forms/admin-action-form";
import { EmptyState } from "@/shared/ui/empty-state";

// Message-related navigation is explicitly excluded from this page (US3)
export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const { data: user, isLoading } = useUserDetail(userId ?? "");
  const updateStatus = useUpdateUserStatus();
  const [feedback, setFeedback] = useState<string | null>(null);

  if (isLoading) {
    return <div className="text-muted-foreground">Loading user...</div>;
  }

  if (!user) {
    return <EmptyState title="User not found" />;
  }

  const handleStatusChange = (newStatus: string, { reason }: { reason: string }) => {
    updateStatus.mutate(
      { userId: user.id, status: newStatus, reason },
      {
        onSuccess: () => setFeedback(`Status updated to ${newStatus}`),
        onError: () => setFeedback("Failed to update status"),
      }
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">{user.username}</h2>
        <p className="text-muted-foreground">{user.email}</p>
        <p className="text-sm mt-1">
          Status: <span className="font-medium">{user.status}</span>
        </p>
      </div>

      {feedback && (
        <div role="alert" className="rounded-md bg-primary/10 px-3 py-2 text-sm">
          {feedback}
        </div>
      )}

      <div className="border rounded-lg p-4 space-y-4">
        <h3 className="font-medium">Change Status</h3>
        <div className="flex gap-2 flex-wrap">
          {["active", "restricted", "suspended"].map((status) => (
            <AdminActionForm
              key={status}
              title={`Set ${status}`}
              isDestructive={status === "suspended"}
              onSubmit={({ reason }) => handleStatusChange(status, { reason })}
              isLoading={updateStatus.isPending}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
