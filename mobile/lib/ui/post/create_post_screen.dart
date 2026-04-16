import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';
import 'package:mobile/ui/core/widgets/app_top_nav_leading.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/ui/post/post_repository.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    required this.repository,
    this.onAuthExpired,
    super.key,
  });

  final PostRepository repository;
  final VoidCallback? onAuthExpired;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _postController = TextEditingController();
  final _spotifyController = TextEditingController();
  bool _isPublishing = false;
  PostPrivacy _selectedPrivacy = PostPrivacy.public;

  @override
  void dispose() {
    _postController.dispose();
    _spotifyController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPublishing = true);
    try {
      await widget.repository.createPost(
        text: _postController.text,
        spotifyUrl: _spotifyController.text,
        privacy: _selectedPrivacy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post published.')));
      context.go(Routes.home);
    } on PostAuthException {
      widget.onAuthExpired?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      context.go(Routes.login);
    } on PostCreateException catch (e) {
      if (!mounted) return;
      final message = e.message ?? 'Could not create post. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppTopNavLeading(),
        title: const Text('Create Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _postController,
                maxLines: 4,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Post text',
                  hintText: 'Share something...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please write something to post.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _spotifyController,
                decoration: const InputDecoration(
                  labelText: 'Spotify link (optional)',
                  hintText: 'https://open.spotify.com/track/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PostPrivacy>(
                initialValue: _selectedPrivacy,
                decoration: const InputDecoration(
                  labelText: 'Post privacy',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PostPrivacy.public,
                    child: Text('Public'),
                  ),
                  DropdownMenuItem(
                    value: PostPrivacy.onlyMe,
                    child: Text('Private'),
                  ),
                  DropdownMenuItem(
                    value: PostPrivacy.friendsOnly,
                    child: Text('Friends only'),
                  ),
                ],
                onChanged: _isPublishing
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedPrivacy = value);
                      },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isPublishing ? null : _publishPost,
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isPublishing ? 'Publishing...' : 'Publish Post'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}
