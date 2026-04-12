export type AdminStatus = "active" | "disabled";
export type AdminPermissionScope = "full_admin";

export interface AdminSession {
  admin_id: string;
  email: string;
  display_name: string;
  status: AdminStatus;
  permission_scope: AdminPermissionScope;
  authenticated_at: string;
}
