// lib/main.dart
import 'package:flutter/material.dart';

import 'app/tome_app.dart';
import 'features/run/run_bloc.dart';

void main() {
  runApp(TomeApp(runBloc: RunBloc()));
}
