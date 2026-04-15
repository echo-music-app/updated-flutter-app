import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DemoPostStore {
  DemoPostStore._();

  static const _storageKey = 'demo_posts_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final List<HomeFeedPost> _posts = <HomeFeedPost>[];
  static bool _loaded = false;

  static Future<List<HomeFeedPost>> all() async {
    await _ensureLoaded();
    return List<HomeFeedPost>.unmodifiable(_posts);
  }

  static Future<List<ProfilePostSummary>> profilePosts() async {
    await _ensureLoaded();
    return _posts
        .map(
          (post) => ProfilePostSummary(
            id: post.id,
            userId: post.userId,
            privacy: _toProfilePrivacy(post.privacy),
            attachments: const <PostAttachmentSummary>[],
            createdAt: post.createdAt,
            updatedAt: post.createdAt,
          ),
        )
        .toList(growable: false);
  }

  static Future<void> add({
    required String text,
    String? spotifyUrl,
    required PostPrivacy privacy,
  }) async {
    await _ensureLoaded();
    final trimmedText = text.trim();
    final trimmedSpotify = spotifyUrl?.trim();
    final now = DateTime.now();
    _posts.insert(
      0,
      HomeFeedPost(
        id: 'demo-${now.microsecondsSinceEpoch}',
        userId: 'demo-user',
        userName: 'Demo User',
        userHandle: '@demouser',
        text: trimmedText.isEmpty ? null : trimmedText,
        spotifyUrl: (trimmedSpotify == null || trimmedSpotify.isEmpty)
            ? null
            : trimmedSpotify,
        privacy: privacy,
        createdAt: now,
      ),
    );
    await _persist();
  }

  static String _toProfilePrivacy(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return 'Public';
      case PostPrivacy.friendsOnly:
        return 'Friends';
      case PostPrivacy.onlyMe:
        return 'OnlyMe';
    }
  }

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return;

    final parsed = jsonDecode(raw) as List<dynamic>;
    _posts
      ..clear()
      ..addAll(
        parsed
            .map((item) => item as Map<String, dynamic>)
            .map(_fromJson)
            .toList(),
      );
  }

  static Future<void> _persist() async {
    final encoded = jsonEncode(_posts.map(_toJson).toList());
    await _storage.write(key: _storageKey, value: encoded);
  }

  static Map<String, dynamic> _toJson(HomeFeedPost post) {
    return {
      'id': post.id,
      'userId': post.userId,
      'userName': post.userName,
      'userHandle': post.userHandle,
      'userAvatarUrl': post.userAvatarUrl,
      'text': post.text,
      'spotifyUrl': post.spotifyUrl,
      'privacy': post.privacy.name,
      'createdAt': post.createdAt.toIso8601String(),
    };
  }

  static HomeFeedPost _fromJson(Map<String, dynamic> json) {
    final privacyName = (json['privacy'] as String?) ?? PostPrivacy.public.name;
    final privacy = PostPrivacy.values.firstWhere(
      (p) => p.name == privacyName,
      orElse: () => PostPrivacy.public,
    );

    return HomeFeedPost(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userHandle: json['userHandle'] as String,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      text: json['text'] as String?,
      spotifyUrl: json['spotifyUrl'] as String?,
      privacy: privacy,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
