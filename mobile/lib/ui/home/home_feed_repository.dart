import 'package:mobile/ui/home/home_view_model.dart';

class HomeFeedPage {
  const HomeFeedPage({
    required this.items,
    required this.pageSize,
    required this.count,
    this.nextCursor,
  });

  final List<HomeFeedPost> items;
  final int pageSize;
  final int count;
  final String? nextCursor;
}

abstract class HomeFeedRepository {
  Future<HomeFeedPage> getFollowingFeed({int pageSize = 20, String? cursor});
}

class HomeFeedAuthException implements Exception {
  const HomeFeedAuthException([this.message]);
  final String? message;
}

class HomeFeedLoadException implements Exception {
  const HomeFeedLoadException([this.message]);
  final String? message;
}
