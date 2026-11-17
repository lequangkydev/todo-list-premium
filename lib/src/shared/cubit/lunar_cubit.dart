import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

import '../enum/language.dart';

/// Whether lunar dates and festivals are shown (Settings → Lunar calendar).
/// null = automatic: on in Vietnamese, off otherwise.
@lazySingleton
class LunarCubit extends HydratedCubit<bool?> {
  LunarCubit() : super(null);

  void update(bool show) => emit(show);

  bool showFor(Language language) => state ?? language == Language.vietnamese;

  @override
  bool? fromJson(Map<String, dynamic> json) => json['show'] as bool?;

  @override
  Map<String, dynamic> toJson(bool? state) => {'show': state};
}
