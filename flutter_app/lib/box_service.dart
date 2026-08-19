import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Handles the box registry: creating boxes, validating customer
/// credentials, activity logging, and delivery confirmation.
class BoxService {
  BoxService._();
  static final BoxService instance = BoxService._();

  final _db = FirebaseDatabase.instance;

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode(int length, Random rand) {
    return List.generate(length, (_) => _chars[rand.nextInt(_chars.length)])
        .join();
  }

  Future<Map<String, String>> createBox(
    String ownerUid, {
    required String boxName,
    required String description,
    required String contents,
  }) async {
    final rand = Random.secure();
    late String boxId;
    late DatabaseReference ref;

    while (true) {
      boxId = _randomCode(6, rand);
      ref = _db.ref('boxes/$boxId');
      final exists = (await ref.child('meta').get()).exists;
      if (!exists) break;
    }

    final boxPassword = _randomCode(8, rand);

    await ref.set({
      'meta': {
        'ownerUid': ownerUid,
        'boxPassword': boxPassword,
        'boxName': boxName,
        'description': description,
        'contents': contents,
        'createdAt': ServerValue.timestamp,
      },
      'sensors': {
        'temperature': 0,
        'humidity': 0,
        'doorStatus': 'Closed',
        'accelerationX': 0,
        'accelerationY': 0,
        'accelerationZ': 0,
      },
      'control': {'door': false, 'fan': false, 'fanAuto': false, 'buzzer': false},
      'device': {'status': 'offline', 'lastSeen': 0},
      'location': {'latitude': 0, 'longitude': 0},
    });

    // ownedBoxes stores a small map so the sender's list can show the
    // name + delivery status without an extra read per box.
    await _db.ref('users/$ownerUid/ownedBoxes/$boxId').set({
      'name': boxName,
      'delivered': false,
    });

    await logEvent(boxId, ownerUid, 'box_created');
    await _attachSenderInfo(boxId, ownerUid);

    return {'boxId': boxId, 'boxPassword': boxPassword};
  }

  /// Copies the sender's own profile details onto the box itself, so
  /// the customer can see (and call) who it's coming from — without
  /// needing read access to another user's account. Mirrors
  /// attachCustomerToBox below, in the other direction.
  Future<void> _attachSenderInfo(String boxId, String ownerUid) async {
    final profileSnap = await _db.ref('users/$ownerUid').get();
    if (!profileSnap.exists) return;
    final profile = Map<String, dynamic>.from(profileSnap.value as Map);

    await _db.ref('boxes/$boxId/sender').set({
      'uid': ownerUid,
      'username': profile['username']?.toString() ?? '',
      'firstName': profile['firstName']?.toString() ?? '',
      'lastName': profile['lastName']?.toString() ?? '',
      'phone': profile['phone']?.toString() ?? '',
      'company': profile['company']?.toString() ?? '',
    });
  }

  Future<bool> validateBoxCredentials(String boxId, String password) async {
    final snap = await _db.ref('boxes/$boxId/meta/boxPassword').get();
    if (!snap.exists) return false; // already claimed, or wrong ID
    return snap.value.toString() == password;
  }

  /// Permanently erases the box password once a customer has
  /// successfully claimed the box — not just hidden in the UI. This
  /// means the credentials can never be reused to "hijack" a box that
  /// already has its customer, and there's nothing sensitive left
  /// sitting in the database to leak.
  Future<void> lockBoxCredentials(String boxId) {
    return _db.ref('boxes/$boxId/meta/boxPassword').remove();
  }

  Future<void> logEvent(String boxId, String uid, String type) {
    return _db.ref('boxes/$boxId/activity').push().set({
      'type': type,
      'byUid': uid,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Records that a customer connected to a box under their own
  /// account, so it shows up in their "My Boxes" list — mirrors
  /// ownedBoxes on the sender side. A customer can connect to (and
  /// therefore accumulate) many boxes over time.
  Future<void> logCustomerConnection(String uid, String boxId) async {
    final metaSnap = await _db.ref('boxes/$boxId/meta').get();
    final boxName = metaSnap.exists
        ? (Map<String, dynamic>.from(metaSnap.value as Map)['boxName']?.toString() ?? boxId)
        : boxId;

    await _db.ref('users/$uid/connectedBoxes/$boxId').set({
      'name': boxName,
      'delivered': false,
    });
  }

  /// Copies the connecting customer's own profile details onto the box
  /// itself, so the sender can see who it's going to (name + phone)
  /// right on the Monitor screen — without needing read access to
  /// another user's account.
  Future<void> attachCustomerToBox(String boxId, String uid) async {
    final profileSnap = await _db.ref('users/$uid').get();
    if (!profileSnap.exists) return;
    final profile = Map<String, dynamic>.from(profileSnap.value as Map);

    await _db.ref('boxes/$boxId/customer').set({
      'uid': uid,
      'username': profile['username']?.toString() ?? '',
      'firstName': profile['firstName']?.toString() ?? '',
      'lastName': profile['lastName']?.toString() ?? '',
      'phone': profile['phone']?.toString() ?? '',
    });
  }

  /// Marks the box delivered on the sender's side (their portfolio +
  /// a popup notification), AND on the confirming customer's side,
  /// so both "My Boxes" lists reflect DELIVERED correctly. Also sets
  /// a plain delivered flag on the box itself, which is the single
  /// shared source of truth the History screen (and anything else)
  /// can read regardless of which role is looking.
  Future<void> confirmDelivery(String boxId, String customerUid) async {
    final metaSnap = await _db.ref('boxes/$boxId/meta').get();
    if (!metaSnap.exists) return;

    final meta = Map<String, dynamic>.from(metaSnap.value as Map);
    final ownerUid = meta['ownerUid']?.toString();
    final boxName = meta['boxName']?.toString() ?? boxId;

    await _db.ref('boxes/$boxId/delivered').set(true);
    await _db.ref('users/$customerUid/connectedBoxes/$boxId/delivered').set(true);

    if (ownerUid == null) return;

    await _db.ref('users/$ownerUid/ownedBoxes/$boxId/delivered').set(true);

    await _db.ref('users/$ownerUid/deliveryNotifications').push().set({
      'boxId': boxId,
      'boxName': boxName,
      'timestamp': ServerValue.timestamp,
    });
  }
}
