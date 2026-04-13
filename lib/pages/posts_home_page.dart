import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_2_flutter/models/post.dart';
import 'package:taller_2_flutter/services/posts_service.dart';
import 'package:taller_2_flutter/widgets/post_widget.dart';

class PostHomePage extends StatefulWidget {
  const PostHomePage({super.key});

  @override
  State<PostHomePage> createState() => _PostHomePageState();
}

class _PostHomePageState extends State<PostHomePage> {
  static const String _likedPostIdsKey = 'likedPostIds';
  static const String _createdPostsKey = 'createdPosts';

  final Set<int> _likedPostIds = {};
  final Map<int, int> _likeDeltasByPostId = {};
  final Map<int, int> _dislikeDeltasByPostId = {};
  final Map<int, Post> _updatedPostsById = {};
  final Set<int> _deletedPostIds = {};
  final List<Post> _createdPosts = <Post>[];

  bool _isCreatingPost = false;
  bool _isMutatingPost = false;

  late final PostsService _postsService;
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();

    _postsService = const PostsService(
      baseUrl: 'https://dummyjson.com',
      useFallbackLocal: true,
    );

    _postsFuture = _postsService.getPosts();
    _loadLikedPosts();
    _loadCreatedPosts();
  }

  Future<void> _loadLikedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_likedPostIdsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _likedPostIds.clear();
      _likedPostIds.addAll(ids.map(int.parse));
    });
  }

  Future<void> _loadCreatedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_createdPostsKey);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return;

    final loadedPosts = decoded
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();

    setState(() {
      _createdPosts
        ..clear()
        ..addAll(loadedPosts);
    });
  }

  Future<void> _saveLikedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _likedPostIdsKey,
      _likedPostIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _saveCreatedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _createdPosts.map((post) => post.toJson()).toList(),
    );
    await prefs.setString(_createdPostsKey, encoded);
  }

  void _updateLikedPosts(int postId, bool isLiked) {
    setState(() {
      if (isLiked) {
        _likedPostIds.add(postId);
      } else {
        _likedPostIds.remove(postId);
      }
    });
    _saveLikedPosts();
  }

  void _incrementLikeCount(int postId) {
    setState(() {
      _likeDeltasByPostId[postId] = (_likeDeltasByPostId[postId] ?? 0) + 1;
    });
  }

  void _incrementDislikeCount(int postId) {
    setState(() {
      _dislikeDeltasByPostId[postId] =
          (_dislikeDeltasByPostId[postId] ?? 0) + 1;
    });
  }

  int _likesCountFor(Post post) {
    return post.reactions.likes + (_likeDeltasByPostId[post.id] ?? 0);
  }

  int _dislikesCountFor(Post post) {
    return post.reactions.dislikes + (_dislikeDeltasByPostId[post.id] ?? 0);
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _postsFuture = _postsService.getPosts();
    });
    await _postsFuture;
    await _loadLikedPosts();
  }

  List<Post> _mergeVisiblePosts(List<Post> fetchedPosts) {
    final merged = <Post>[..._createdPosts, ...fetchedPosts]
        .map((post) => _updatedPostsById[post.id] ?? post)
        .where((post) => !_deletedPostIds.contains(post.id))
        .toList();
    return merged;
  }

  Future<Map<String, dynamic>?> _openPostFormDialog({
    required String dialogTitle,
    required String submitLabel,
    String initialTitle = '',
    String initialBody = '',
    List<String> initialTags = const <String>[],
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final bodyController = TextEditingController(text: initialBody);
    final tagsController = TextEditingController(text: initialTags.join(', '));

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body'),
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (Separados por coma)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();
                final tags = tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();

                if (title.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Title is required.')),
                  );
                  return;
                }

                Navigator.of(
                  context,
                ).pop({'title': title, 'body': body, 'tags': tags});
              },
              child: Text(submitLabel),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
    tagsController.dispose();

    return result;
  }

  Future<void> _openCreatePostDialog() async {
    final created = await _openPostFormDialog(
      dialogTitle: 'Create post',
      submitLabel: 'Create',
    );

    if (created == null) return;

    setState(() => _isCreatingPost = true);
    try {
      final newPost = await _postsService.createPost(
        title: created['title'] as String,
        body: created['body'] as String,
        tags: (created['tags'] as List).cast<String>(),
      );

      if (!mounted) return;

      setState(() {
        _createdPosts.insert(0, newPost);
      });
      await _saveCreatedPosts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post creado con id ${newPost.id}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el post.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingPost = false);
      }
    }
  }

  Future<void> _openEditPostDialog(Post post) async {
    final updated = await _openPostFormDialog(
      dialogTitle: 'Update post #${post.id}',
      submitLabel: 'Update',
      initialTitle: post.title,
      initialBody: post.body,
      initialTags: post.tags,
    );

    if (updated == null) return;

    setState(() => _isMutatingPost = true);
    try {
      final title = updated['title'] as String;
      final body = updated['body'] as String;
      final tags = (updated['tags'] as List).cast<String>();

      final createdIndex = _createdPosts.indexWhere((p) => p.id == post.id);

      if (createdIndex != -1) {
        if (!mounted) return;
        setState(() {
          _createdPosts[createdIndex] = _createdPosts[createdIndex].copyWith(
            title: title,
            body: body,
            tags: tags,
          );
        });
        await _saveCreatedPosts();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post ${post.id} actualizado.')));
        return;
      }

      final updatedPost = await _postsService.updatePost(
        id: post.id,
        title: title,
        body: body,
        tags: tags,
      );

      if (!mounted) return;

      setState(() {
        final current = _updatedPostsById[post.id] ?? post;
        _updatedPostsById[post.id] = current.copyWith(
          title: updatedPost.title,
          body: updatedPost.body,
          tags: updatedPost.tags,
        );
      });
      await _saveCreatedPosts();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post ${post.id} actualizado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el post.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutatingPost = false);
      }
    }
  }

  Future<void> _deletePost(Post post) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete post'),
          content: Text('Seguro que deseas eliminar el post #${post.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() => _isMutatingPost = true);
    try {
      final createdIndex = _createdPosts.indexWhere((p) => p.id == post.id);
      if (createdIndex != -1) {
        if (!mounted) return;
        setState(() {
          _createdPosts.removeAt(createdIndex);
          _updatedPostsById.remove(post.id);
          _deletedPostIds.add(post.id);
        });
        await _saveCreatedPosts();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post ${post.id} eliminado.')));
        return;
      }

      await _postsService.deletePost(id: post.id);

      if (!mounted) return;

      setState(() {
        _createdPosts.removeWhere((p) => p.id == post.id);
        _updatedPostsById.remove(post.id);
        _deletedPostIds.add(post.id);
      });
      await _saveCreatedPosts();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post ${post.id} eliminado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el post.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutatingPost = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Feed')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isCreatingPost || _isMutatingPost)
            ? null
            : _openCreatePostDialog,
        icon: _isCreatingPost || _isMutatingPost
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(
          _isCreatingPost
              ? 'Creating...'
              : _isMutatingPost
              ? 'Working...'
              : 'Create post',
        ),
      ),
      body: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Ocurrio un error al cargar los posts.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _postsFuture = _postsService.getPosts();
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final fetchedPosts = snapshot.data ?? [];
          final posts = _mergeVisiblePosts(fetchedPosts);

          if (posts.isEmpty) {
            return const Center(child: Text('No hay posts disponibles.'));
          }

          return RefreshIndicator(
            onRefresh: _refreshPosts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final isLiked = _likedPostIds.contains(post.id);

                return PostWidget(
                  post: post,
                  isLiked: isLiked,
                  likesCount: _likesCountFor(post),
                  dislikesCount: _dislikesCountFor(post),
                  onLikePressed: () {
                    _incrementLikeCount(post.id);
                    _updateLikedPosts(post.id, true);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 900),
                        content: Text('Post ${post.id} marcado como liked'),
                      ),
                    );
                  },
                  onDislikePressed: () {
                    _incrementDislikeCount(post.id);
                    _updateLikedPosts(post.id, false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(milliseconds: 900),
                        content: Text('Post ${post.id} like removido'),
                      ),
                    );
                  },
                  onEditPressed: _isMutatingPost
                      ? null
                      : () => _openEditPostDialog(post),
                  onDeletePressed: _isMutatingPost
                      ? null
                      : () => _deletePost(post),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
