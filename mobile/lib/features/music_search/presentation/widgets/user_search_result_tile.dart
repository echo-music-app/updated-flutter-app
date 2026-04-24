import 'package:flutter/material.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';
import 'package:mobile/ui/core/widgets/app_avatar.dart';

class UserSearchResultTile extends StatelessWidget {
  const UserSearchResultTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  final UserSearchResult user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AppAvatar(
        radius: 20,
        imageProvider: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        fallbackText: user.username.isEmpty
            ? '?'
            : user.username[0].toUpperCase(),
      ),
      title: Text(user.username),
      subtitle: Text('@${user.username.toLowerCase()}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
