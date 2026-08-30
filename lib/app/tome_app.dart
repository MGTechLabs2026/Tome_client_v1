// lib/app/tome_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/run/run_bloc.dart';
import '../routing/app_router.dart';
import 'theme.dart';

class TomeApp extends StatelessWidget {
  const TomeApp({super.key, required this.runBloc});

  final RunBloc runBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: runBloc,
      child: MaterialApp.router(
        title: 'Tome: Martial Arts',
        theme: tomeTheme(),
        routerConfig: appRouter(runBloc),
      ),
    );
  }
}
