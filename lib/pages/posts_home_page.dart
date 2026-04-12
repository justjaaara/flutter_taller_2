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
  final Set<int> _likedPostIds = {};
  final Map<int, int> _likeDeltasByPostId = {};
  final Map<int, int> _dislikeDeltasByPostId = {};

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
  }

  Future<void> _loadLikedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('likedPostIds') ?? [];
    setState(() {
      _likedPostIds.clear();
      _likedPostIds.addAll(ids.map(int.parse));
    });
  }

  Future<void> _saveLikedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'likedPostIds',
      _likedPostIds.map((id) => id.toString()).toList(),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Feed')),
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

          final posts = snapshot.data ?? [];

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
