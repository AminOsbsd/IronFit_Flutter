import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/widgets/common_widgets.dart';

void main() {
  test('EUR prices use euro symbol and two decimals', () {
    expect(money(60), '60,00\u00a0€');
    expect(money(1099.9), '1\u202f099,90\u00a0€');
  });
  test('TND history keeps original amount and currency', () {
    expect(money(60, currency: 'TND'), '60,000\u00a0TND');
  });
}
