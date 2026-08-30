import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/cubit/language_cubit.dart';
import 'features/auth/screens/login.dart';
import 'features/home/controller/map_cubit.dart';
import 'features/hospitals/controller/facility_bloc.dart';
import 'features/hospitals/data/facility_local.dart';
import 'features/hospitals/data/facility_remote.dart';
import 'features/hospitals/data/facility_repository.dart';
import 'features/pharmacy/controller/pharmacy_bloc.dart';
import 'features/pharmacy/data/medication_local.dart';
import 'features/pharmacy/data/medication_remote.dart';
import 'features/pharmacy/data/medication_repository.dart';
import 'core/utils/navigation_menu.dart';
import 'core/utils/onboarding_screen/onboarding_screen.dart';

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

        child: GetMaterialApp(
          title: 'NaviSanté',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF2A7D8F),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            textTheme: GoogleFonts.plusJakartaSansTextTheme(),
          ),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const NavigationMenu(),
          },
          home: const StartupWrapper(),
        ),
      ),
    );
  }
}
