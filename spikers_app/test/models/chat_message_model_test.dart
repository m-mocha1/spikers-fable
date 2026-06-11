import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/models/chat_message_model.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('messages').doc('m1');
    await ref.set(data);
    return ref.get();
  }

  group('ChatMessage', () {
    test('round-trips through toMap/fromDoc', () async {
      final msg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        text: 'See you on court',
        createdAt: DateTime(2026, 1, 1),
      );
      final snap = await writeAndRead(msg.toMap());
      final parsed = ChatMessage.fromDoc(snap);
      expect(parsed.id, 'm1');
      expect(parsed.senderId, 'u1');
      expect(parsed.text, 'See you on court');
      // toMap writes FieldValue.serverTimestamp(), so the read-back value is
      // the (fake) server time, not the local createdAt.
      expect(parsed.createdAt, isA<DateTime>());
    });

    test('missing fields default safely', () async {
      final snap = await writeAndRead({});
      final parsed = ChatMessage.fromDoc(snap);
      expect(parsed.senderId, '');
      expect(parsed.text, '');
      expect(parsed.createdAt, isA<DateTime>());
    });
  });
}
