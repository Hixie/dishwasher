import 'dart:io';

class Credentials {
  Credentials(String filename) : this._lines = new File(filename).readAsLinesSync() {
    if (_lines.length < _requiredCount)
      throw new Exception('credentials file incomplete or otherwise corrupted');
  }
  final List<String> _lines;

  String get remyUsername => _lines[0];
  String get remyPassword => _lines[1];
  String get databaseHost => _lines[2];
  int get databasePort => int.parse(_lines[3], radix: 10);
  String get certificatePath => _lines[4];
  String get buttonProcess => _lines[5];
  String get leakSensorProcess => _lines[6];

  int get _requiredCount => 6;
}
