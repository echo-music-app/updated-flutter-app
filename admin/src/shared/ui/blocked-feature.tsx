interface BlockedFeatureProps {
  featureName: string;
  reason?: string;
}

export function BlockedFeature({
  featureName,
  reason = "This feature is not available in the admin workspace.",
}: BlockedFeatureProps) {
  return (
    <div
      role="alert"
      data-testid="blocked-feature"
      className="admin-panel flex flex-col items-center justify-center py-12 text-center"
    >
      <div className="mb-4 rounded-full border border-destructive/30 bg-destructive/10 p-4">
        <span className="text-xl font-bold text-destructive">!</span>
      </div>
      <h3 className="text-lg font-semibold text-destructive">{featureName} is not available</h3>
      <p className="mt-2 max-w-sm text-sm text-muted-foreground">{reason}</p>
    </div>
  );
}
