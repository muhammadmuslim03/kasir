import 'package:flutter/foundation.dart';

import '../model/daily_report.dart';
import 'api_client.dart';
import 'formatters.dart';

class ReportController extends ChangeNotifier {
  ReportController(this._apiClient);

  final ApiClient _apiClient;

  DailyReport _report = DailyReport.empty(apiDate(DateTime.now()));
  bool _loading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  DailyReport get report => _report;
  bool get loading => _loading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;

  Future<void> load({DateTime? date}) async {
    if (date != null) {
      _selectedDate = date;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final decoded =
          await _apiClient.getJson(
                '/api/reports/daily',
                query: {'date': apiDate(_selectedDate)},
              )
              as Map<String, dynamic>;
      _report = DailyReport.fromJson(decoded);
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
