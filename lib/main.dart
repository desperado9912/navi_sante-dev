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



//Alternate implementation for faster app load
// agent must not delete ever

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'app.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const NaviSanteAppBootloader());
// }

// class NaviSanteAppBootloader extends StatefulWidget {
//   const NaviSanteAppBootloader({super.key});

//   @override
//   State<NaviSanteAppBootloader> createState() => _NaviSanteAppBootloaderState();
// }

// class _NaviSanteAppBootloaderState extends State<NaviSanteAppBootloader> {
//   bool _initialized = false;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     try {
//       // 1. Orientation lock
//       await SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//         DeviceOrientation.portraitDown,
//       ]);

//       // 2. Load env configuration
//       await dotenv.load(fileName: ".env");

//       // 3. Supabase initialization
//       await Supabase.initialize(
//         url: dotenv.env['SUPABASE_URL'] ?? '',
//         anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
//         authOptions: const FlutterAuthClientOptions(
//           authFlowType: AuthFlowType.pkce,
//         ),
//       );

//       // 4. Google OAuth initialization
//       final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
//       final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
//       debugPrint('[main] GOOGLE_WEB_CLIENT_ID: "$webClientId"');
//       debugPrint('[main] GOOGLE_IOS_CLIENT_ID: "$iosClientId"');

//       await GoogleSignIn.instance.initialize(
//         clientId: Platform.isIOS ? iosClientId : null,
//         serverClientId: webClientId,
//       );

//       if (mounted) {
//         setState(() {
//           _initialized = true;
//         });
//       }
//     } catch (e, stackTrace) {
//       debugPrint('[Bootloader] Initialization failed: $e\n$stackTrace');
//       if (mounted) {
//         setState(() {
//           _error = e.toString();
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_error != null) {
//       return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: ThemeData(useMaterial3: true),
//         home: Scaffold(
//           body: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(28.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(
//                     Icons.error_outline_rounded,
//                     color: Color(0xFFC0392B),
//                     size: 48,
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Initialization Error',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF1A1A1A),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     _error!,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       color: Color(0xFF5F6368),
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 24),
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         _error = null;
//                         _initialized = false;
//                       });
//                       _load();
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF2A7D8F),
//                       foregroundColor: Colors.white,
//                       elevation: 0,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: const Text('Try Again'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       );
//     }

//     if (!_initialized) {
//       // Premium native-looking loading screen with app background matching brand color (Teal)
//       return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: ThemeData(useMaterial3: true),
//         home: const Scaffold(
//           backgroundColor: Color(0xFFF8F9F8), // Match theme background
//           body: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Elegant loading indicator driven by brand color (0xFF2A7D8F)
//                 SizedBox(
//                   width: 32,
//                   height: 32,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 3.5,
//                     valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A7D8F)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return const NaviSanteApp();
//   }
// }
