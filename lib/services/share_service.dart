import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Share text content using native system share with fallback
  Future<void> shareText({
    required String text,
    String? subject,
    Rect? sharePositionOrigin,
    BuildContext? context,
  }) async {
    try {
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    } on MissingPluginException catch (e) {
      debugPrint('Share plugin not available: $e');
      // Fallback to clipboard
      await _copyToClipboard(text);
      if (context != null) {
        _showSuccessSnackBar(context, 'Content copied to clipboard');
      }
    } catch (e) {
      debugPrint('Error sharing text: $e');
      // Fallback to clipboard
      await _copyToClipboard(text);
      if (context != null) {
        _showSuccessSnackBar(context, 'Content copied to clipboard');
      }
    }
  }

  /// Share content with all available data
  Future<void> shareContent({
    required Map<String, dynamic> content,
    Rect? sharePositionOrigin,
    BuildContext? context,
  }) async {
    try {
      final title = content['title'] ?? 'Unknown Title';
      final extract = content['extract'] ?? '';
      final url = content['url'] ?? '';
      final author = content['author'] ?? '';
      final publishedDate = content['published_date'] ?? '';
      final tags = content['tags'] ?? [];
      
      // Create comprehensive formatted share text
      String shareText = '📖 $title\n\n';
      
      if (author.isNotEmpty) {
        shareText += '✍️ By: $author\n';
      }
      
      if (publishedDate.isNotEmpty) {
        shareText += '📅 Published: $publishedDate\n\n';
      }
      
      if (extract.isNotEmpty) {
        final limitedExtract = extract.length > 300 
            ? '${extract.substring(0, 300)}...' 
            : extract;
        shareText += '$limitedExtract\n\n';
      }
      
      if (tags.isNotEmpty && tags is List) {
        final tagString = tags.take(5).join(', ');
        shareText += '🏷️ Tags: $tagString\n\n';
      }
      
      if (url.isNotEmpty) {
        shareText += '🔗 Read more: $url\n\n';
      }
      
      shareText += '📱 Shared via Finity App';

      await this.shareText(
        text: shareText,
        subject: '📖 $title - Shared from Finity',
        sharePositionOrigin: sharePositionOrigin,
        context: context,
      );
    } catch (e) {
      debugPrint('Error sharing content: $e');
      if (context != null) {
        _showErrorSnackBar(context, 'Unable to share content');
      }
    }
  }

  /// Share content with image URL - shows image directly in WhatsApp and other apps
  Future<void> shareContentWithImage({
    required Map<String, dynamic> content,
    Rect? sharePositionOrigin,
    BuildContext? context,
  }) async {
    try {
      final title = content['title'] ?? 'Unknown Title';
      final extract = content['extract'] ?? '';
      final url = content['url'] ?? '';
      final imageUrl = content['image'];
      final author = content['author'] ?? '';
      final publishedDate = content['published_date'] ?? '';
      final tags = content['tags'] ?? [];
      final category = content['category'] ?? '';
      
      // Create comprehensive formatted share text
      String shareText = '📖 $title\n\n';
      
      if (author.isNotEmpty) {
        shareText += '✍️ Author: $author\n';
      }
      
      if (category.isNotEmpty) {
        shareText += '📂 Category: $category\n';
      }
      
      if (publishedDate.isNotEmpty) {
        shareText += '📅 Published: $publishedDate\n\n';
      }
      
      if (extract.isNotEmpty) {
        final limitedExtract = extract.length > 250 
            ? '${extract.substring(0, 250)}...' 
            : extract;
        shareText += '$limitedExtract\n\n';
      }
      
      if (tags.isNotEmpty && tags is List) {
        final tagString = tags.take(3).join(', ');
        shareText += '🏷️ Tags: $tagString\n\n';
      }
      
      if (url.isNotEmpty) {
        shareText += '🔗 Read full article: $url\n\n';
      }
      
      shareText += '📱 Discover more with Finity App';

      // Try to share with image URL directly for better WhatsApp integration
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          // Share with image URL - WhatsApp and other apps will show image preview
          await Share.shareXFiles(
            [],
            text: '$shareText\n\n🖼️ $imageUrl',
            subject: '📖 $title - Shared from Finity',
            sharePositionOrigin: sharePositionOrigin,
          );
        } catch (imageShareError) {
          debugPrint('Error sharing with image URL: $imageShareError');
          // Fallback to text with image URL embedded
          shareText += '\n\n🖼️ Featured Image: $imageUrl';
          await this.shareText(
            text: shareText,
            subject: '📖 $title - Shared from Finity',
            sharePositionOrigin: sharePositionOrigin,
            context: context,
          );
        }
      } else {
        // No image, share as text
        await this.shareText(
          text: shareText,
          subject: '📖 $title - Shared from Finity',
          sharePositionOrigin: sharePositionOrigin,
          context: context,
        );
      }
    } catch (e) {
      debugPrint('Error sharing content with image: $e');
      if (context != null) {
        _showErrorSnackBar(context, 'Unable to share content');
      }
    }
  }

  /// Share image URL directly (for image-focused sharing)
  Future<void> shareImageWithContent({
    required String imageUrl,
    required Map<String, dynamic> content,
    Rect? sharePositionOrigin,
    BuildContext? context,
  }) async {
    try {
      final title = content['title'] ?? 'Check this out!';
      final url = content['url'] ?? '';
      
      String shareText = '📖 $title\n\n';
      if (url.isNotEmpty) {
        shareText += '🔗 $url\n\n';
      }
      shareText += '📱 Via Finity App';
      
      // Share image URL with minimal text for better visual impact
      await Share.shareXFiles(
        [],
        text: '$shareText\n\n$imageUrl',
        subject: title,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error sharing image with content: $e');
      // Fallback to regular content sharing
      await shareContent(
        content: content,
        sharePositionOrigin: sharePositionOrigin,
        context: context,
      );
    }
  }

  /// Copy text to clipboard
  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
    }
  }

  /// Show success snack bar
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Show error snack bar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
