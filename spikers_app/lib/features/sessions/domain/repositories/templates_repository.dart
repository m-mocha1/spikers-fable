import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';

abstract class TemplatesRepository {
  /// The coach's saved templates, newest first.
  Stream<List<SessionTemplate>> watch(String coachUid);

  Future<void> save(String coachUid, SessionTemplate template);

  Future<void> delete(String coachUid, String templateId);
}
