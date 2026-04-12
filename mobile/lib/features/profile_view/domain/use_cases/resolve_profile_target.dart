import 'package:mobile/features/profile_view/domain/entities/profile.dart';

class ResolveProfileTargetUseCase {
  const ResolveProfileTargetUseCase();

  /// Resolves the route target given an optional [userId] and [currentUserId].
  ///
  /// - `/profile` (no userId): own mode.
  /// - `/profile/:userId` where userId == currentUserId: own mode, isSelfResolved=true.
  /// - `/profile/:userId` where userId != currentUserId: other mode.
  ProfileRouteTarget resolve({String? userId, required String? currentUserId}) {
    if (userId == null || userId.isEmpty) {
      return const ProfileRouteTarget(mode: ProfileMode.own);
    }
    if (currentUserId != null && userId == currentUserId) {
      return const ProfileRouteTarget(
        mode: ProfileMode.own,
        isSelfResolved: true,
      );
    }
    return ProfileRouteTarget(mode: ProfileMode.other, targetUserId: userId);
  }
}
