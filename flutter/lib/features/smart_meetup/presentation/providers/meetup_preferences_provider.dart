import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/repositories/smart_meetup_repository.dart';

class MeetupPreferencesProvider extends ChangeNotifier {
  MeetupPreferencesProvider(this._repository, this._account);

  final SmartMeetupRepository _repository;
  final String? _account;
  List<MeetupCategoryOption>? categories;
  bool loading = false;
  Failure? failure;
  bool _closed = false;

  Future<void> loadCategories() async {
    final account = _account;
    if (_closed || loading || categories != null || account == null) return;
    loading = true;
    failure = null;
    notifyListeners();
    final result = await _repository.filterOptions(account);
    if (_closed) return;
    loading = false;
    result.fold((error) => failure = error, (options) => categories = options);
    notifyListeners();
  }

  void close() {
    _closed = true;
    categories = null;
    failure = null;
    loading = false;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
