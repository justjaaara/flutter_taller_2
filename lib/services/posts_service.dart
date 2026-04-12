import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taller_2_flutter/data/posts_data.dart';
import 'package:taller_2_flutter/models/post.dart';

class PostsService {
  final String baseUrl;
  final bool useFallbackLocal;

  const PostsService({required this.baseUrl, this.useFallbackLocal = true});

  Future<List<Post>> getPosts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/posts'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to load posts');
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Response does not have the expected format');
      }

      return decoded
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!useFallbackLocal) rethrow;
      await Future.delayed(const Duration(seconds: 1));
      return posts;
    }
  }
}
