import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// In-app mindset-coach chat — a general-purpose conversation (no access to
/// the user's habits/mood/journal/spending data, by design; see the
/// [CoachMessage] doc comment), backed by the `coach-chat` Netlify Function
/// so no API key ever ships inside the app. One of the home bottom-nav
/// tabs, same as Products — not gated by the Settings module toggle since
/// it isn't a personal-tracking module.
class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (store.coachDailyLimitReached) {
      setState(() => _error = "You've reached today's chat limit — back tomorrow for more.");
      return;
    }
    _inputCtrl.clear();
    setState(() {
      _sending = true;
      _error = null;
    });
    _scrollToBottom();
    final error = await store.sendCoachMessage(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear this conversation?', style: display(16, Surfaces.heading(dark))),
        content: const Text('This only clears the chat on this device — it can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await store.clearCoachChat();
      if (mounted) setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final messages = store.coachMessages;
    final remaining = (kCoachDailyMessageLimit - store.coachMessagesSentToday).clamp(0, kCoachDailyMessageLimit);

    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                icon: Icons.spa_outlined,
                title: 'Coach',
                subtitle: 'A grounded mindset chat — general only, no app data shared.',
                showBackButton: false,
                actions: [
                  if (messages.isNotEmpty)
                    IconButton(
                      onPressed: _confirmClear,
                      icon: Icon(Icons.delete_outline, color: Surfaces.muted(dark)),
                      tooltip: 'Clear conversation',
                    ),
                ],
              ),
              Expanded(
                child: messages.isEmpty
                    ? _EmptyState(dark: dark, onSuggestionTap: (text) {
                        _inputCtrl.text = text;
                        _send();
                      })
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, i) =>
                            _MessageBubble(message: messages[i], dark: dark),
                      ),
              ),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Surfaces.accent(dark)),
                      ),
                      const SizedBox(width: 8),
                      Text('Coach is thinking…', style: body(12, Surfaces.muted(dark))),
                    ],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(_error!,
                      style: body(12, Colors.redAccent, weight: FontWeight.w600)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  '$remaining of $kCoachDailyMessageLimit messages left today',
                  style: body(10.5, Surfaces.muted(dark)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_sending,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: "What's on your mind?",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : () {
                        HapticFeedback.selectionClick();
                        _send();
                      },
                      icon: Icon(Icons.send_rounded, color: Surfaces.accent(dark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool dark;
  final ValueChanged<String> onSuggestionTap;
  const _EmptyState({required this.dark, required this.onSuggestionTap});

  static const _suggestions = [
    "I'm having a rough day — where do I even start?",
    'How do I stay consistent when motivation runs out?',
    'Help me reframe a setback I had today.',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, size: 40, color: Surfaces.accent(dark)),
            const SizedBox(height: 14),
            Text('Talk it through',
                style: display(18, Surfaces.heading(dark)), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'A grounded space to think out loud — this chat doesn\'t see your habits, mood, or journal, just what you tell it here.',
              textAlign: TextAlign.center,
              style: body(12.5, Surfaces.muted(dark)).copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            for (final s in _suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSuggestionTap(s),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Surfaces.accent(dark).withValues(alpha: 0.08),
                      border: Border.all(color: Surfaces.accent(dark).withValues(alpha: 0.25)),
                    ),
                    child: Text(s,
                        textAlign: TextAlign.center,
                        style: body(12.5, Surfaces.accent(dark), weight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final CoachMessage message;
  final bool dark;
  const _MessageBubble({required this.message, required this.dark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          color: isUser
              ? Surfaces.accent(dark)
              : Surfaces.accent(dark).withValues(alpha: 0.10),
        ),
        child: Text(
          message.content,
          style: body(13.5, isUser ? Colors.white : Surfaces.bodyText(dark))
              .copyWith(height: 1.4),
        ),
      ),
    );
  }
}
