import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ThemeModeCubit extends HydratedCubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.system);

  void update(ThemeMode mode) => emit(mode);

  @override
  ThemeMode fromJson(Map<String, dynamic> json) => ThemeMode.values.firstWhere(
    (m) => m.name == json['mode'],
    orElse: () => ThemeMode.system,
  );

  @override
  Map<String, dynamic> toJson(ThemeMode state) => {'mode': state.name};
}
