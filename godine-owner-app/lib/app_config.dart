/// GoDine — Centralized app config for URL construction and cross-platform linking.
///
/// Update [webBaseUrl] to match the domain where the web app is deployed.
class AppConfig {
  /// Base URL where the GoDine web app is hosted.
  /// Change this to your production URL (e.g. https://godine.in).
  static const String webBaseUrl = 'https://godine.in';

  /// Construct the customer menu URL for a specific restaurant + table.
  static String menuUrl(String slug, {int? table}) {
    final tableParam = table != null ? '&table=$table' : '';
    return '$webBaseUrl/menu.html?r=$slug$tableParam';
  }

  /// Construct the customer order tracking URL.
  static String customerUrl(String slug) {
    return '$webBaseUrl/customer.html?r=$slug';
  }

  /// Construct the owner dashboard URL.
  static String dashboardUrl() {
    return '$webBaseUrl/dashboard.html';
  }

  /// App download link (set to Play Store / App Store URL when published).
  static const String appDownloadUrl = '#';

  /// Razorpay Live Key ID
  static const String razorpayKeyId = 'rzp_live_SgWyCv725a4fC3';
}
