/// Override at run time when the API is not running on this device.
/// Example: --dart-define=API_BASE_URL=http://192.168.68.10:8000
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
