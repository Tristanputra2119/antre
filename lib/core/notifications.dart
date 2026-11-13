import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final callNotifierProvider = Provider<CallNotifier>((ref) => CallNotifier());

/// Local (on-device) notification for "your number was called".
/// shortcut: only fires while the app process is alive (foreground/background);
/// switch to FCM + a Supabase trigger if it must reach a killed app.
class CallNotifier {
  CallNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool?>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ticket_called',
      'Nomor dipanggil',
      channelDescription: 'Pemberitahuan saat giliran Anda tiba',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  Future<bool?> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  /// Android 13+ asks the user once; later calls return the saved answer.
  Future<void> requestPermission() async {
    await _init();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> show({required String title, required String body}) async {
    await _init();
    await _plugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }
}
