import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  debugPrint('[main] GOOGLE_WEB_CLIENT_ID: "$webClientId"');
  debugPrint('[main] GOOGLE_IOS_CLIENT_ID: "$iosClientId"');

  await GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? iosClientId : null,
    serverClientId: webClientId,
  );

  runApp(const NaviSanteApp());
}
