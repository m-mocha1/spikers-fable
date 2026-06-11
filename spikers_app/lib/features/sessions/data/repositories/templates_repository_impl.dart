import '../../../../models/session_template_model.dart';
import '../../domain/repositories/templates_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class TemplatesRepositoryImpl implements TemplatesRepository {
  final SessionsRemoteDataSource _remote;

  TemplatesRepositoryImpl(this._remote);

  @override
  Stream<List<SessionTemplate>> watch(String coachUid) =>
      _remote.watchTemplates(coachUid);

  @override
  Future<void> save(String coachUid, SessionTemplate template) =>
      _remote.saveTemplate(coachUid, template);

  @override
  Future<void> delete(String coachUid, String templateId) =>
      _remote.deleteTemplate(coachUid, templateId);
}
