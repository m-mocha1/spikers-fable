import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controller/auth_controller.dart';
import '../../controller/session_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message_model.dart';

class SessionChatScreen extends StatefulWidget {
  const SessionChatScreen({super.key});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  static const _pageSize = 50;

  late final String _sessionId;
  late final String _sessionTitle;
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _auth = Get.find<AuthController>();
  final _sessionCtrl = Get.find<SessionController>();
  bool _sending = false;

  // Live window: newest _pageSize messages, kept fresh via Firestore snapshots.
  List<QueryDocumentSnapshot> _live = [];
  // Older history: fetched once via .get() in descending order, never re-streamed.
  final List<QueryDocumentSnapshot> _older = [];
  // uid -> { 'name': ..., 'photoUrl': ... } for resolving senders at render time.
  final Map<String, Map<String, String>> _senderInfo = {};
  StreamSubscription<QuerySnapshot>? _liveSub;
  bool _initialLoaded = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _streamError;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final id = (args is Map) ? args['id']?.toString() : null;
    if (id == null || id.isEmpty) {
      // Invalid navigation — bail out gracefully instead of crashing.
      _sessionId = '';
      _sessionTitle = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.back();
      });
      return;
    }
    _sessionId = id;
    _sessionTitle = (args as Map)['title']?.toString() ?? '';
    _markSeen();
    _scroll.addListener(_onScroll);
    _listen();
  }

  @override
  void dispose() {
    _markSeen();
    _liveSub?.cancel();
    _scroll.removeListener(_onScroll);
    _inputCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'chat_last_seen_$_sessionId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _listen() {
    _liveSub = FirebaseFirestore.instance
        .collection('sessions')
        .doc(_sessionId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _live = snap.docs;
        _initialLoaded = true;
        _streamError = null;
        // If the live window itself is short, the history is short too.
        if (snap.docs.length < _pageSize) _hasMore = false;
      });
      _refreshSenderInfo();
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _streamError = e.toString();
        _initialLoaded = true;
      });
    });
  }

  Future<void> _refreshSenderInfo() async {
    final needed = <String>{};
    for (final doc in _live) {
      final id = doc.get('senderId') as String? ?? '';
      if (id.isNotEmpty && !_senderInfo.containsKey(id)) needed.add(id);
    }
    for (final doc in _older) {
      final id = doc.get('senderId') as String? ?? '';
      if (id.isNotEmpty && !_senderInfo.containsKey(id)) needed.add(id);
    }
    if (needed.isEmpty) return;

    final uids = needed.toList();
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users_public')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          _senderInfo[doc.id] = {
            'name': (data['name'] ?? '') as String,
            'photoUrl': (data['photoUrl'] ?? '') as String,
          };
        }
      } catch (_) {
        // Leave missing senders unresolved; bubbles render with empty name.
      }
    }
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || !_scroll.hasClients) return;
    // reverse: true → maxScrollExtent is the visual top (oldest messages).
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final cursor = _older.isNotEmpty
        ? _older.last
        : (_live.isNotEmpty ? _live.last : null);
    if (cursor == null) return;

    setState(() => _loadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_sessionId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_pageSize)
          .get();
      if (!mounted) return;
      setState(() {
        _older.addAll(snap.docs);
        if (snap.docs.length < _pageSize) _hasMore = false;
        _loadingMore = false;
      });
      _refreshSenderInfo();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    await _sessionCtrl.sendMessage(_sessionId, text);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      // reverse: true → offset 0 is the bottom (newest message).
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final uid = _auth.currentUser.value!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_sessionTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.navyLight),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(l, uid)),
          _buildInput(l),
        ],
      ),
    );
  }

  Widget _buildMessages(AppLocalizations l, String uid) {
    if (_streamError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _streamError!,
            style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_initialLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_live.isEmpty && _older.isEmpty) {
      return Center(
        child: Text(l.chatEmpty,
            style: const TextStyle(color: AppColors.grey)),
      );
    }

    final total = _live.length + _older.length;
    final itemCount = total + (_loadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (i >= total) {
          // Spinner at the visual top while older messages load.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold),
              ),
            ),
          );
        }
        final doc = i < _live.length ? _live[i] : _older[i - _live.length];
        final msg = ChatMessage.fromDoc(doc);
        final isMe = msg.senderId == uid;
        final info = _senderInfo[msg.senderId];
        return _MessageBubble(
          message: msg,
          isMe: isMe,
          senderName: info?['name'] ?? '',
          senderPhotoUrl: info?['photoUrl'] ?? '',
        );
      },
    );
  }

  Widget _buildInput(AppLocalizations l) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 16),
      decoration: const BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: l.typeMessage,
                hintStyle: const TextStyle(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.navyBlue,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.gold, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  ),
                )
              : IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded,
                      color: AppColors.gold),
                ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String senderName;
  final String senderPhotoUrl;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.senderPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    const avatarSize = 32.0;
    const avatarGap = 8.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _ChatAvatar(
                photoUrl: senderPhotoUrl,
                name: senderName,
                size: avatarSize),
            const SizedBox(width: avatarGap),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.65,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: 4, bottom: 3),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.gold
                          : AppColors.navyLight,
                      borderRadius: BorderRadiusDirectional.only(
                        topStart: const Radius.circular(18),
                        topEnd: const Radius.circular(18),
                        bottomStart:
                            Radius.circular(isMe ? 18 : 4),
                        bottomEnd:
                            Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.navyBlue
                            : AppColors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final String photoUrl;
  final String name;
  final double size;
  const _ChatAvatar(
      {required this.photoUrl,
      required this.name,
      required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.gold,
      backgroundImage: photoUrl.isNotEmpty
          ? CachedNetworkImageProvider(photoUrl)
          : null,
      child: photoUrl.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
                color: AppColors.navyBlue,
              ),
            )
          : null,
    );
  }
}
