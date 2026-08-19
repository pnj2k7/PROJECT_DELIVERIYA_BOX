import 'package:firebase_database/firebase_database.dart';

/// Talks to one specific box's data at /boxes/{boxId}/...
/// Create a new instance per active box: FirebaseService(boxId)
class FirebaseService {
  FirebaseService(this.boxId);

  final String boxId;

  DatabaseReference get _root => FirebaseDatabase.instance.ref('boxes/$boxId');

  // ================= READ STREAMS =================

  Stream<DatabaseEvent> sensorsStream() => _root.child('sensors').onValue;

  Stream<DatabaseEvent> locationStream() => _root.child('location').onValue;

  Stream<DatabaseEvent> deviceStream() => _root.child('device').onValue;

  Stream<DatabaseEvent> controlStream() => _root.child('control').onValue;

  // ================= WRITE COMMANDS =================

  Future<void> setDoor(bool open) {
    return _root.child('control/door').set(open);
  }

  Future<void> setFan(bool on) {
    return _root.child('control/fan').set(on);
  }

  Future<void> setBuzzer(bool on) {
    return _root.child('control/buzzer').set(on);
  }
}

double toDoubleSafe(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return fallback;
}
