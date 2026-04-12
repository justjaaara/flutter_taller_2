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
  final List<Post> _createdPosts = <Post>[];

  bool _isCreatingPost = false;

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

  Future<void> _openCreatePostDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final tagsController = TextEditingController();

    final created = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create post'),
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
              onPressed: () async {
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
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
    tagsController.dispose();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Feed')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingPost ? null : _openCreatePostDialog,
        icon: _isCreatingPost
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isCreatingPost ? 'Creating...' : 'Create post'),
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
          final posts = <Post>[..._createdPosts, ...fetchedPosts];

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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
