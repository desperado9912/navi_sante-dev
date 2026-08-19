import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/hospitals/data/facility_local.dart';
import 'core/utils/navigation_settings.dart';
import 'features/home/controller/map_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen while Loading/Initializing apis
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  //Hive initialization
  await Hive.initFlutter();
  await Hive.openBox('mapCache');
  await FacilityLocal.init();
  await NavigationSettings.init();

  //Init map cache manager (not supported on web — no temp directory)
  if (!kIsWeb) {
    await MapCacheManager.instance.initialize();
  }

  //orientation lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  //supabase initilize
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  //google OAuth initilization
  final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
  final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();

  // TODO: Delete debug print note.
  debugPrint('[main] GOOGLE_WEB_CLIENT_ID: "$webClientId"');
  debugPrint('[main] GOOGLE_IOS_CLIENT_ID: "$iosClientId"');

  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? webClientId                          // Web plugin requires clientId
        : (Platform.isIOS ? iosClientId : null), // iOS uses iosClientId
    serverClientId: kIsWeb ? null : webClientId, // Not supported on web
  );

  runApp(const NaviSanteApp());
}
