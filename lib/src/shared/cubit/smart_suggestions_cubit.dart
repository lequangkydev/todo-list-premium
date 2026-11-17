import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// Whether passive suggestions (list, priority, usual time, duplicates) are
/// shown while typing (Settings → Smart suggestions)
@lazySingleton
class SmartSuggestionsCubit extends HydratedCubit<bool> {
  SmartSuggestionsCubit() : super(true);

  void update(bool enabled) => emit(enabled);

  @override
  bool fromJson(Map<String, dynamic> json) => json['enabled'] as bool? ?? true;

  @override
  Map<String, dynamic> toJson(bool state) => {'enabled': state};
}
