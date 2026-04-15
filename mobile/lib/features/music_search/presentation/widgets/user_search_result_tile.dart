import 'package:flutter/material.dart';
import 'package:mobile/features/music_search/domain/entities/music_search_result.dart';

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
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(user.username.isEmpty ? '?' : user.username[0].toUpperCase())
            : null,
      ),
      title: Text(user.username),
      subtitle: Text('@${user.username.toLowerCase()}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
