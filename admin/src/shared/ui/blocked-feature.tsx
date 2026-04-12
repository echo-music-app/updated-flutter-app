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
      className="flex flex-col items-center justify-center py-12 text-center"
    >
      <div className="rounded-full bg-destructive/10 p-4 mb-4">
        <span className="text-2xl">🚫</span>
      </div>
      <h3 className="text-lg font-medium text-destructive">{featureName} is not available</h3>
      <p className="mt-2 text-sm text-muted-foreground max-w-sm">{reason}</p>
    </div>
  );
}
