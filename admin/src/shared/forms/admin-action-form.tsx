import type { ReactNode } from "react";

interface AdminActionFormProps {
  title: string;
  description?: string;
  onSubmit: (data: { reason: string; confirmed?: boolean }) => void;
  isDestructive?: boolean;
  isLoading?: boolean;
  children?: ReactNode;
}

export function AdminActionForm({
  title,
  description,
  onSubmit,
  isDestructive = false,
  isLoading = false,
  children,
}: AdminActionFormProps) {
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const reason = (formData.get("reason") as string)?.trim() ?? "";
    const confirmed = formData.get("confirmed") === "on";
    onSubmit({ reason, confirmed });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <h3 className="text-lg font-medium">{title}</h3>
        {description && <p className="text-sm text-muted-foreground mt-1">{description}</p>}
      </div>
      <div>
        <label htmlFor="reason" className="block text-sm font-medium mb-1">
          Reason <span className="text-destructive">*</span>
        </label>
        <textarea
          id="reason"
          name="reason"
          required
          rows={3}
          className="w-full rounded-md border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
          placeholder="Enter reason for this action..."
        />
      </div>
      {isDestructive && (
        <div className="flex items-center gap-2">
          <input type="checkbox" id="confirmed" name="confirmed" required className="h-4 w-4" />
          <label htmlFor="confirmed" className="text-sm font-medium text-destructive">
            I confirm this destructive action
          </label>
        </div>
      )}
      {children}
      <button
        type="submit"
        disabled={isLoading}
        className={`px-4 py-2 rounded-md text-sm font-medium ${
          isDestructive
            ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
            : "bg-primary text-primary-foreground hover:bg-primary/90"
        } disabled:opacity-50`}
      >
        {isLoading ? "Submitting..." : "Submit"}
      </button>
    </form>
  );
}
