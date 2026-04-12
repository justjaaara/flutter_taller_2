import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taller_2_flutter/data/posts_data.dart';
import 'package:taller_2_flutter/models/post.dart';

class PostsService {
  final String baseUrl;
  final bool useFallbackLocal;

  const PostsService({required this.baseUrl, this.useFallbackLocal = true});

  Map<String, dynamic> _normalizePostJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);

    normalized['id'] = normalized['id'] ?? 0;
    normalized['title'] = normalized['title'] ?? '';
    normalized['body'] = normalized['body'] ?? '';
    normalized['tags'] = normalized['tags'] ?? const <String>[];
    normalized['views'] = normalized['views'] ?? 0;
    normalized['userId'] = normalized['userId'] ?? 0;

    final reactions = normalized['reactions'];
    if (reactions is! Map<String, dynamic>) {
      normalized['reactions'] = {'likes': 0, 'dislikes': 0};
    } else {
      normalized['reactions'] = {
        'likes': reactions['likes'] ?? 0,
        'dislikes': reactions['dislikes'] ?? 0,
      };
    }

    return normalized;
  }

  Future<List<Post>> getPosts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/posts'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to load posts');
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (decoded is Map<String, dynamic> && decoded['posts'] is List) {
        final list = decoded['posts'] as List;
        return list
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Response does not have the expected format');
    } catch (e) {
      if (!useFallbackLocal) rethrow;
      await Future.delayed(const Duration(seconds: 1));
      return posts;
    }
  }

  Future<Post> createPost({
    required String title,
    String body = '',
    List<String> tags = const <String>[],
  }) async {
    final payload = <String, dynamic>{
      'userId': 1,
      'title': title,
      'body': body,
      'tags': tags,
    };

    final response = await http
        .post(
          Uri.parse('$baseUrl/posts/add'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create post');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Create response does not have the expected format');
    }

    return Post.fromJson(_normalizePostJson(decoded));
  }
}
