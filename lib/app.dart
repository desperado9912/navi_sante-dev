import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/viewmodel/auth_cubit.dart';
import 'core/utils/language_cubit/language_cubit.dart';
import 'features/auth/screens/login.dart';
import 'features/home/viewmodel/map_cubit.dart';
import 'features/hospitals/viewmodels/facility_bloc.dart';
import 'features/hospitals/data/facility_local.dart';
import 'features/hospitals/data/facility_remote.dart';
import 'features/hospitals/data/facility_repository.dart';
import 'features/pharmacy/viewmodels/pharmacy_bloc.dart';
import 'features/pharmacy/data/medication_local.dart';
import 'features/pharmacy/data/medication_remote.dart';
import 'features/pharmacy/data/medication_repository.dart';
import 'core/utils/navigation_menu.dart';
import 'screens/onboarding.dart';

class NaviSanteApp extends StatelessWidget {
  const NaviSanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => FacilityRepository(
            local: FacilityLocal(),
            remote: FacilityRemote(Supabase.instance.client),
          ),
        ),
        RepositoryProvider(
          create: (_) => MedicationRepository(
            local: MedicationLocal(),
            remote: MedicationRemote(Supabase.instance.client),
          ),
        ),
      ],
      
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthCubit()),
          BlocProvider(create: (_) => LanguageCubit()),
          BlocProvider(create: (_) => MapCubit()),
          BlocProvider(
            create: (context) =>
                FacilityBloc(repository: context.read<FacilityRepository>())
                  ..add(LoadFacilities())
                  ..add(LoadRecentlyViewed()),
          ),
          BlocProvider(
            create: (context) =>
                PharmacyBloc(repository: context.read<MedicationRepository>()),
          ),
        ],

        child: BlocBuilder<LanguageCubit, LanguageState>(
          builder: (context, langState) {
            return GetMaterialApp(
              title: 'NaviSanté',
              debugShowCheckedModeBanner: false,
              locale: langState.locale,
              translations: AppTranslations(),
              fallbackLocale: const Locale('en', 'US'),
              theme: ThemeData(
                colorSchemeSeed: const Color(0xFF2A7D8F),
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                textTheme: GoogleFonts.plusJakartaSansTextTheme(),
                cupertinoOverrideTheme: const CupertinoThemeData(
                  primaryColor: CupertinoColors.activeBlue,
                ),
              ),
              routes: {
                '/login': (_) => const LoginScreen(),
                '/home': (_) => const NavigationMenu(),
              },
              home: const StartupWrapper(),
            );
          },
        ),
      ),
    );
  }
}
