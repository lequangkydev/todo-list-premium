import '../../../flavors.dart';

class AppConstants {
  AppConstants._();

  // TODO(all): App Store id once the app is created in App Store Connect
  static const String appIOSId = '123456';

  /// Weekly premium subscription. Must match the product created in App Store
  /// Connect and Play Console.
  // TODO(all): confirm the real product id before enabling IAP
  static const String premiumWeeklyProductId =
      'com.vtn.todolist.premium.weekly';

  static const String packageName = 'com.vtn.todolist';
  static const urlPolicy = 'url';
  static const urlTerms = 'url';
  static String appName = F.appFlavor == Flavor.dev
      ? 'Todo List Dev'
      : 'Todo List';

  // 2 cái này không thay đổi
  static const String appIOSUrl = 'https://apps.apple.com/us/app/id$appIOSId';
  static const String appAndroidUrl =
      'https://play.google.com/store/apps/details?id=$packageName';
}
