import 'package:injectable/injectable.dart';

import '../../data/local/database/app_database.dart';

@module
abstract class DatabaseModule {
  @singleton
  AppDatabase get database => AppDatabase();
}
