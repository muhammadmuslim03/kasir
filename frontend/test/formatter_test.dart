import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/controller/formatters.dart';

void main() {
  test('formats Indonesian currency and API date', () {
    expect(formatCurrency(16000), 'Rp 16.000');
    expect(apiDate(DateTime(2026, 6, 13)), '2026-06-13');
  });
}
