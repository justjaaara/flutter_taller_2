import 'package:flutter/material.dart';

import '../models/post.dart';

class PostWidget extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final int? likesCount;
  final int? dislikesCount;
  final VoidCallback? onTap;
  final VoidCallback? onLikePressed;
  final VoidCallback? onDislikePressed;

  const PostWidget({
    super.key,
    required this.post,
    this.isLiked = false,
    this.likesCount,
    this.dislikesCount,
    this.onTap,
    this.onLikePressed,
    this.onDislikePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.surface,
                    child: Text(
                      '#${post.id}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: post.tags
                      .map(
                        (tag) => Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.secondary
                              .withAlpha(28),
                          label: Text('#$tag'),
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  _ReactionButton(
                    icon: Icons.thumb_up_alt_rounded,
                    value: likesCount ?? post.reactions.likes,
                    color: Colors.green.shade700,
                    active: isLiked,
                    onPressed: onLikePressed,
                  ),
                  const SizedBox(width: 14),
                  _ReactionButton(
                    icon: Icons.thumb_down_alt_rounded,
                    value: dislikesCount ?? post.reactions.dislikes,
                    color: Colors.red.shade700,
                    active: false,
                    onPressed: onDislikePressed,
                  ),
                  const SizedBox(width: 14),
                  _Metric(
                    icon: Icons.visibility_rounded,
                    value: post.views,
                    color: Colors.blueGrey.shade700,
                  ),
                  const Spacer(),
                  Text(
                    'User ${post.userId}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final bool active;
  final VoidCallback? onPressed;

  const _ReactionButton({
    required this.icon,
    required this.value,
    required this.color,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            foregroundColor: active ? color : color.withAlpha(160),
            backgroundColor: active ? color.withAlpha(34) : Colors.transparent,
          ),
          icon: Icon(icon, size: 18),
        ),
        Text('$value', style: textStyle),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _Metric({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text('$value', style: textStyle),
      ],
    );
  }
}
