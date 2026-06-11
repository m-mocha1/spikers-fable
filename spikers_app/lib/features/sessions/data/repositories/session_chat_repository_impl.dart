import 'package:spikers_app/features/sessions/domain/entities/chat_message_model.dart';
import '../../domain/repositories/session_chat_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class SessionChatRepositoryImpl implements SessionChatRepository {
  final SessionsRemoteDataSource _remote;

  SessionChatRepositoryImpl(this._remote);

  @override
  Stream<List<ChatMessage>> watchLatest(String sessionId, {int limit = 30}) =>
      _remote.watchLatestMessages(sessionId, limit: limit);

  @override
  Future<List<ChatMessage>> fetchOlder(String sessionId,
          {required DateTime before, int limit = 30}) =>
      _remote.fetchOlderMessages(sessionId, before: before, limit: limit);

  @override
  Future<void> send(String sessionId,
          {required String senderId, required String text}) =>
      _remote.sendMessage(sessionId, senderId: senderId, text: text);
}
