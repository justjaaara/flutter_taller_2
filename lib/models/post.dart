class Post {
  final int id;
  final String title;
  final String body;
  final List<String> tags;
  final Reactions reactions;
  final int views;
  final int userId;

  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.reactions,
    required this.views,
    required this.userId,
  });
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      tags: List<String>.from(json['tags']),
      reactions: Reactions(
        likes: json['reactions']['likes'] as int,
        dislikes: json['reactions']['dislikes'] as int,
      ),
      views: json['views'] as int,
      userId: json['userId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'tags': tags,
      'reactions': {'likes': reactions.likes, 'dislikes': reactions.dislikes},
      'views': views,
      'userId': userId,
    };
  }
}

class Reactions {
  final int likes;
  final int dislikes;

  const Reactions({required this.likes, required this.dislikes});
}
