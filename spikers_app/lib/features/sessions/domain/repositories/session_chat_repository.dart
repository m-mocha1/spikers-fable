import 'package:spikers_app/features/sessions/domain/entities/chat_message_model.dart';

abstract class SessionChatRepository {
  /// Newest [limit] messages, newest first (live).
  Stream<List<ChatMessage>> watchLatest(String sessionId, {int limit});

  /// One older page, newest first, strictly before [before].
  Future<List<ChatMessage>> fetchOlder(String sessionId,
      {required DateTime before, int limit});

  Future<void> send(String sessionId,
      {required String senderId, required String text});
}
