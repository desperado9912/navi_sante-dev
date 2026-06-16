import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controller/facility_bloc_cubit.dart';
import '../controller/recently_viewed_cubit.dart';

class Hospitals extends StatefulWidget {
  const Hospitals({super.key});

  @override
  State<Hospitals> createState() => _HospitalsState();
}

class _HospitalsState extends State<Hospitals> {
  @override
  void initState() {
    super.initState();
    context.read<FacilityBloc>().add(LoadFacilities());
    context.read<RecentlyViewedCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Search for Hospitals or use filters to get results.'),
      ),
    );
  }
}
