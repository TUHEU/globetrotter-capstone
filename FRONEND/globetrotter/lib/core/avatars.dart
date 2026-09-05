import 'package:flutter/material.dart';

/// The fixed set of pickable avatars. Emoji-based on purpose: no image
/// assets to bundle/host, renders identically everywhere (chat bubbles,
/// profile, friends list) with zero network fetch.
class AvatarOption {
  final String key;
  final String emoji;
  final String labelFr;
  final String labelEn;
  const AvatarOption(this.key, this.emoji, this.labelFr, this.labelEn);
}

const List<AvatarOption> kAvatarOptions = [
  AvatarOption('boy', '👦', 'Garçon', 'Boy'),
  AvatarOption('girl', '👧', 'Fille', 'Girl'),
  AvatarOption('lion', '🦁', 'Lion', 'Lion'),
  AvatarOption('car', '🚗', 'Voiture', 'Car'),
  AvatarOption('bike', '🚲', 'Vélo', 'Bike'),
  AvatarOption('controller', '🎮', 'Manette', 'Game controller'),
];

String? emojiForAvatar(String? key) {
  if (key == null) return null;
  for (final a in kAvatarOptions) {
    if (a.key == key) return a.emoji;
  }
  return null;
}

/// Drop-in replacement for a plain initials CircleAvatar: shows the picked
/// emoji avatar if the user has one, otherwise falls back to the first
/// letter of their name on a colored background — used consistently across
/// chat bubbles, the profile sheet, friends list, and inbox.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final Color color;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    required this.avatar,
    required this.color,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = emojiForAvatar(avatar);
    return CircleAvatar(
      radius: radius,
      backgroundColor: emoji != null ? color.withValues(alpha: 0.15) : color,
      child: emoji != null
          ? Text(emoji, style: TextStyle(fontSize: radius * 1.05))
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Colors.white, fontSize: radius * 0.73, fontWeight: FontWeight.w700),
            ),
    );
  }
}
