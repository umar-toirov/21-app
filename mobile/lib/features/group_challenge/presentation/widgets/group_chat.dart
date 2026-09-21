import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';

/// Group chat. New messages arrive by polling every few seconds while the tab
/// is open; sending is optimistic and can be retried if it fails.
class GroupChatTab extends ConsumerStatefulWidget {
  const GroupChatTab({super.key, required this.groupId, required this.isLeader});

  final String groupId;
  final bool isLeader;

  @override
  ConsumerState<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends ConsumerState<GroupChatTab> with WidgetsBindingObserver {
  static const _pollEvery = Duration(seconds: 4);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessageModel> _messages = [];
  Timer? _poll;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollEvery, (_) => _refresh());
  }

  ApiRepository get _api => ref.read(apiRepositoryProvider);

  Future<void> _load() async {
    try {
      final page = await _api.getGroupMessages(widget.groupId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  /// Fetch the latest page and merge it in (new messages, and deletions).
  Future<void> _refresh() async {
    if (_loading) return;
    try {
      final page = await _api.getGroupMessages(widget.groupId);
      if (!mounted) return;
      final byId = {for (final m in page.messages) m.id: m};
      var changed = false;
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final fresh = byId.remove(_messages[i].id);
          if (fresh != null && fresh.isDeleted != _messages[i].isDeleted) {
            _messages[i] = fresh;
            changed = true;
          }
        }
        if (byId.isNotEmpty) {
          _messages.addAll(byId.values.where((m) => !_isMyPendingTwin(m)));
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          changed = true;
        }
        if (_error != null) {
          _error = null;
          changed = true;
        }
      });
      if (changed) _stickToBottomIfNear();
    } catch (_) {
      // Polling failures are silent; the next tick retries.
    }
  }

  bool _isMyPendingTwin(ChatMessageModel m) =>
      m.isYou && _messages.any((p) => p.pending && p.body == m.body);

  Future<void> _loadEarlier() async {
    if (_loadingMore || _messages.isEmpty) return;
    final firstServer = _messages.firstWhere((m) => !m.pending, orElse: () => _messages.first);
    setState(() => _loadingMore = true);
    try {
      final page = await _api.getGroupMessages(widget.groupId, before: firstServer.id);
      if (!mounted) return;
      setState(() {
        final known = _messages.map((m) => m.id).toSet();
        _messages.insertAll(0, page.messages.where((m) => !known.contains(m.id)));
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(apiErrorMessage(e));
    }
  }

  void _stickToBottomIfNear() {
    if (!_scroll.hasClients) return;
    // The list is reversed, so "bottom" is offset 0.
    if (_scroll.offset < 160) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
      ));
  }

  Future<void> _send([ChatMessageModel? retry]) async {
    final text = (retry?.body ?? _input.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();

    final temp = ChatMessageModel(
      id: retry?.id ?? 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      userId: '',
      fullName: 'You',
      isLeader: widget.isLeader,
      isYou: true,
      body: text,
      isDeleted: false,
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() {
      if (retry != null) _messages.removeWhere((m) => m.id == retry.id);
      _messages.add(temp);
    });
    if (retry == null) _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });

    try {
      final sent = await _api.postGroupMessage(widget.groupId, text);
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == temp.id);
        if (!_messages.any((m) => m.id == sent.id)) _messages.add(sent);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == temp.id);
        if (i >= 0) _messages[i] = temp.copyWith(pending: false, failed: true);
      });
      _toast(apiErrorMessage(e));
    }
  }

  Future<void> _showActions(ChatMessageModel m) async {
    if (m.pending || m.isDeleted) return;
    if (m.failed) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Try again'),
                onTap: () => Navigator.pop(ctx, 'retry'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Discard', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'discard'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'retry') _send(m);
      if (choice == 'discard') setState(() => _messages.removeWhere((x) => x.id == m.id));
      return;
    }
    if (!(m.isYou || widget.isLeader)) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          title: Text(
            m.isYou ? 'Delete message' : 'Delete message (admin)',
            style: const TextStyle(color: AppColors.danger),
          ),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteGroupMessage(widget.groupId, m.id);
      _refresh();
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _body()),
        _Composer(controller: _input, onSend: _send),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.orange));
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                apiErrorMessage(_error!),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: AppColors.orange, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Say hi and keep each other going.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Build oldest to newest with day separators, then show reversed.
    final items = <Widget>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;
      final next = i < _messages.length - 1 ? _messages[i + 1] : null;
      if (prev == null || !_sameDay(prev.createdAt, m.createdAt)) {
        items.add(_DaySeparator(date: m.createdAt));
      }
      final startsGroup = prev == null ||
          !_sameDay(prev.createdAt, m.createdAt) ||
          prev.userId != m.userId ||
          m.createdAt.difference(prev.createdAt).inMinutes >= 5;
      final endsGroup = next == null ||
          !_sameDay(next.createdAt, m.createdAt) ||
          next.userId != m.userId ||
          next.createdAt.difference(m.createdAt).inMinutes >= 5;
      items.add(_Bubble(
        message: m,
        showName: startsGroup && !m.isYou,
        showTime: endsGroup,
        onLongPress: () => _showActions(m),
        onTap: m.failed ? () => _showActions(m) : null,
      ));
    }
    final ordered = items.reversed.toList();

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      itemCount: ordered.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == ordered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(onPressed: _loadEarlier, child: const Text('Load earlier messages')),
            ),
          );
        }
        return ordered[i];
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(date.year == now.year ? 'EEE, MMM d' : 'MMM d, y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showName,
    required this.showTime,
    required this.onLongPress,
    this.onTap,
  });

  final ChatMessageModel message;
  final bool showName;
  final bool showTime;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.isYou;
    final maxWidth = MediaQuery.of(context).size.width * 0.74;
    final bg = m.isDeleted
        ? Colors.transparent
        : (mine ? AppColors.orange : AppColors.surface);
    final fg = mine ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: EdgeInsets.only(top: showName ? 8 : 0, bottom: showTime ? 6 : 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.fullName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (m.isLeader) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Opacity(
              opacity: m.pending ? 0.6 : 1,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                  border: m.isDeleted || mine
                      ? (m.isDeleted ? Border.all(color: AppColors.border) : null)
                      : Border.all(color: AppColors.border),
                ),
                child: Text(
                  m.isDeleted ? 'This message was deleted' : m.body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontStyle: m.isDeleted ? FontStyle.italic : FontStyle.normal,
                    color: m.isDeleted ? AppColors.muted : fg,
                  ),
                ),
              ),
            ),
          ),
          if (m.failed)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: Text(
                "Couldn't send. Tap to retry.",
                style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            )
          else if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
              child: Text(
                m.pending ? 'Sending…' : DateFormat('HH:mm').format(m.createdAt),
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message the group…',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.orange, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final enabled = value.text.trim().isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? AppColors.orange : AppColors.borderStrong,
                  ),
                  child: IconButton(
                    tooltip: 'Send',
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
