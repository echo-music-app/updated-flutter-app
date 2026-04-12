class PostAttachmentSummary {
  const PostAttachmentSummary({required this.id, required this.type});

  final String id;
  final String type;
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
