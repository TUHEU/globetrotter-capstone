import 'package:share_plus/share_plus.dart';

/// Thin wrapper around share_plus so every screen shares text the same way
/// (and so this is the one place to touch if the share format ever changes).
class ShareService {
  ShareService._();

  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
