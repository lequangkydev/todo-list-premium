import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// Whether haptic feedback is on (Settings → Appearance)
@lazySingleton
class HapticsCubit extends HydratedCubit<bool> {
  HapticsCubit() : super(true);

  void update(bool enabled) => emit(enabled);

  @override
  bool fromJson(Map<String, dynamic> json) => json['enabled'] as bool? ?? true;

  @override
  Map<String, dynamic> toJson(bool state) => {'enabled': state};
}
