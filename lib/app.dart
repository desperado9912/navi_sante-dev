import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/cubit/language_cubit.dart';
import 'features/auth/services/auth_gate.dart';

class NaviSanteApp extends StatelessWidget {
  const NaviSanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => LanguageCubit()),
      ],
      child: MaterialApp(
        title: 'Navi Santé',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2A7D8F),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        ),
       
        //authgate decides routing to home
        home: const AuthGate(),
      ),
    );
  }
}
