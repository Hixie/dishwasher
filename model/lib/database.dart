import 'dart:io';
import 'dart:typed_data';

typedef LogCallback = void Function(String message);

class DatabaseWritingClient {
  DatabaseWritingClient(this.host, this.port, this.securityContext, this.password, { this.onLog });

  final InternetAddress host;
  final int port;
  final SecurityContext securityContext;
  final int password;
  final LogCallback onLog;

  bool listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length)
      return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index])
        return false;
    }
    return true;
  }

  Uint8List _lastDatabaseUpdate;

  void send(Uint8List nextDatabaseUpdate) {
    if (_lastDatabaseUpdate == null || !listEquals(_lastDatabaseUpdate, nextDatabaseUpdate)) {
      _lastDatabaseUpdate = nextDatabaseUpdate;
      _send(nextDatabaseUpdate);
    }
  }

  bool _failed = false;

  Future<void> _send(Uint8List record) async {
    try {
      Socket socket = await SecureSocket.connect(host, port, context: securityContext)
        ..setOption(SocketOption.tcpNoDelay, true)
        ..add((ByteData(8)..setUint64(0, password)).buffer.asUint8List())
        ..add((ByteData(8)..setUint64(0, 0x02)).buffer.asUint8List()) // table ID
        ..add(record);
      await socket.flush();
      await socket.close();
      if (_failed) {
        log('recovered.');
        _failed = false;
      }
    } catch (error) {
      log('database send failed: $error');
      _failed = true;
    }
  }

  void log(String message) {
    if (onLog != null)
      onLog(message);
  }
}

String pretty(Uint8List data) {
  StringBuffer buffer = StringBuffer();
  for (int index = 0; index < data.length; index += 1) {
    buffer.write(' ');
    if (index > 0 && index % 8 == 0)
      buffer.write(' ');
    buffer.write(data[index].toRadixString(16).padLeft(2, "0"));
  }
  return buffer.toString();
}
