import 'dart:io';

class Credentials {
  Credentials(String filename) : this._lines = new File(filename).readAsLinesSync() {
    if (_lines.length < _requiredCount)
      throw new Exception('credentials file incomplete or otherwise corrupted');
  }
  final List<String> _lines;

  String get remyHost => _lines[0];
  int get remyPort => int.parse(_lines[1], radix: 10);
  String get remyUsername => _lines[2];
  String get remyPassword => _lines[3];
  String get databaseHost => _lines[4];
  int get databasePort => int.parse(_lines[5], radix: 10);
  int get databasePassword => int.parse(_lines[6], radix: 16);
  String get certificatePath => _lines[7];

  int get _requiredCount => 8;
}
