interface Column<T> {
  key: keyof T | string;
  header: string;
  render?: (row: T) => React.ReactNode;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  isLoading?: boolean;
  emptyMessage?: string;
  keyExtractor: (row: T) => string;
}

export function DataTable<T>({
  columns,
  data,
  isLoading = false,
  emptyMessage = "No items found.",
  keyExtractor,
}: DataTableProps<T>) {
  if (isLoading) {
    return (
      <div className="admin-panel flex items-center justify-center py-12 text-sm text-muted-foreground">
        Loading...
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border bg-card/95 shadow-sm">
      <table className="w-full text-sm">
        <thead className="bg-muted/60">
          <tr>
            {columns.map((col) => (
              <th
                key={String(col.key)}
                className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-muted-foreground"
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-12 text-center text-muted-foreground">
                {emptyMessage}
              </td>
            </tr>
          ) : (
            data.map((row) => (
              <tr key={keyExtractor(row)} className="border-t transition-colors hover:bg-muted/30">
                {columns.map((col) => (
                  <td key={String(col.key)} className="px-4 py-3.5">
                    {col.render
                      ? col.render(row)
                      : String((row as Record<string, unknown>)[String(col.key)] ?? "")}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
