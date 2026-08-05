import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_app/app_config.dart';

void main() {
  test('uses the local API by default', () {
    expect(kApiBaseUrl, 'http://127.0.0.1:8000');
  });
}
