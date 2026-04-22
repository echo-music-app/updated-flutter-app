class PostAttachmentSummary {
  const PostAttachmentSummary({
    required this.id,
    required this.type,
    this.content,
    this.url,
  });

  final String id;
  final String type;
  final String? content;
  final String? url;
}

class ProfilePostComment {
  const ProfilePostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
}

class ProfilePostSummary {
  const ProfilePostSummary({
    required this.id,
    required this.userId,
    required this.privacy,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  final String id;
  final String userId;
  final String privacy;
  final List<PostAttachmentSummary> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ProfilePostsPage {
  const ProfilePostsPage({
    required this.items,
    required this.pageSize,
    required this.count,
    this.nextCursor,
  });

  final List<ProfilePostSummary> items;
  final int pageSize;
  final int count;
  final String? nextCursor;
}
