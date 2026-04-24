interface EmptyStateProps {
  title: string;
  description?: string;
  action?: React.ReactNode;
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="admin-panel flex flex-col items-center justify-center py-12 text-center">
      <div className="mb-3 rounded-full bg-accent px-3 py-1.5 text-xs font-semibold text-accent-foreground">
        Nothing to show
      </div>
      <p className="text-lg font-semibold">{title}</p>
      {description && <p className="mt-2 text-sm text-muted-foreground max-w-sm">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
