import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/supabase_client.dart';

// Anonymous sign-in happens on the splash route so failures can be retried.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await initSupabase();
  runApp(const ProviderScope(child: AntreApp()));
}
