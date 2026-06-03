import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/map_cubit.dart';
import '../widgets/home_map_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapCubit _mapCubit;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapCubit();
  }

  @override
  void dispose() {
    _mapCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _mapCubit,
      child: const HomeMapWidget(),
    );
  }
}
