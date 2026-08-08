import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../import/domain/parsed_schedule.dart';
import '../../../import/presentation/screens/review_screen.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../domain/chat_message.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_usage_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Uint8List? _pendingImage;

  static const _suggestions = [
    'Am I free tomorrow afternoon?',
    'When is my next exam?',
    'How many classes do I have this week?',
    'What should I study today?',
    "Can I skip tomorrow's lecture?",
  ];

  @override
  void initState() {
    super.initState();
    // When reopening the chat, land on the latest message, not the top.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  /// If the AI just deleted something, offer a one-tap Undo.
  void _maybeShowUndo() {
    final undo = ref.read(chatControllerProvider.notifier).takePendingUndo();
    if (undo == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(undo.label),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await undo.restore();
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('Restored ✅'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
            }
          },
        ),
      ));
  }

  /// If a free user just hit the monthly AI limit, open the paywall.
  void _maybeShowPaywall() {
    final needs = ref.read(chatControllerProvider.notifier).takeNeedsPaywall();
    if (!needs || !mounted) return;
    // Defer so we don't push a route during a build/listener callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPaywall(context);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _relativeTime(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateUtilsX.prettyDate(d);
  }

  void _openHistory() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final sessionsAsync = ref.watch(chatSessionsProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(
                        children: [
                          Text('Chat history',
                              style: theme.textTheme.titleLarge),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(chatControllerProvider.notifier).reset();
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New chat'),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: sessionsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text("Couldn't load your history.",
                              style: theme.textTheme.bodyMedium),
                        ),
                        data: (sessions) {
                          if (sessions.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                              child: Column(
                                children: [
                                  Icon(Icons.forum_outlined,
                                      size: 40, color: theme.hintColor),
                                  const SizedBox(height: 12),
                                  Text('No saved chats yet',
                                      style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Your conversations with the assistant '
                                      'will appear here automatically.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final s = sessions[i];
                              return Material(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    child: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: AppColors.primary, size: 20),
                                  ),
                                  title: Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    s.preview.isEmpty
                                        ? _relativeTime(s.updatedAt)
                                        : '${_relativeTime(s.updatedAt)} · ${s.preview}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.danger, size: 20),
                                    onPressed: () => ref
                                        .read(chatRepositoryProvider)
                                        ?.delete(s.id),
                                  ),
                                  onTap: () {
                                    ref
                                        .read(chatControllerProvider.notifier)
                                        .loadSession(s);
                                    Navigator.pop(ctx);
                                    _scrollToBottom();
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _attachImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pendingImage = bytes);
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _input.text;
    final image = _pendingImage;
    if (text.trim().isEmpty && image == null) return;
    _input.clear();
    setState(() => _pendingImage = null);
    await ref.read(chatControllerProvider.notifier).send(text, image: image);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (_, __) {
      _scrollToBottom();
      _maybeShowUndo();
      _maybeShowPaywall();
    });
    final theme = Theme.of(context);
    final showSuggestions = state.messages.length <= 1 && !state.sending;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(theme),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: state.messages.length + (state.sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= state.messages.length) {
                    return const _TypingBubble();
                  }
                  return _bubble(context, state.messages[i])
                      .animate()
                      .fadeIn(duration: 260.ms)
                      .slideY(begin: 0.12, curve: Curves.easeOut);
                },
              ),
            ),
            if (showSuggestions) _suggestionChips(theme),
            if (_pendingImage != null) _imagePreview(theme),
            _inputBar(theme, state.sending),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Study Assistant', style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Powered by AI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Builder(builder: (_) {
                      final remaining = ref.watch(chatRemainingProvider);
                      if (remaining == null) {
                        return Text(' · Pro',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.primary));
                      }
                      return Text(' · $remaining left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: remaining == 0
                                  ? AppColors.danger
                                  : theme.hintColor));
                    }),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(chatControllerProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChips(ThemeData theme) {
    Widget chip(String label, VoidCallback onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: icon != null
                ? Icon(icon, size: 16, color: AppColors.primary)
                : null,
            label: Text(label),
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            side: BorderSide.none,
            labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600),
            onPressed: onTap,
          ),
        ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Opens the gallery so the assistant can read a timetable photo.
          chip('Import schedule from image', _attachImage,
              icon: Icons.photo_library_rounded),
          for (final s in _suggestions) chip(s, () => _send(s)),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    final theme = Theme.of(context);
    final isUser = m.isUser;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(13),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary])
            : null,
        color: isUser ? null : theme.cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 5),
          bottomRight: Radius.circular(isUser ? 5 : 20),
        ),
        boxShadow: theme.brightness == Brightness.light
            ? AppColors.softShadow(opacity: 0.05, blur: 12)
            : null,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (m.image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(m.image!, height: 140, fit: BoxFit.cover),
              ),
            ),
          if (m.text.isNotEmpty)
            Text(
              m.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser ? Colors.white : null,
                height: 1.35,
              ),
            ),
          if (m.schedule != null) _scheduleCard(context, m.schedule!),
        ],
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 16, color: Colors.white),
        ),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _scheduleCard(BuildContext context, ParsedSchedule schedule) {
    final theme = Theme.of(context);
    final count = schedule.subjects.length;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Proposed schedule · $count subject${count == 1 ? '' : 's'}',
                  style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReviewScreen(schedule: schedule),
              )),
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Review & add to calendar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(_pendingImage!,
                height: 44, width: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Image attached')),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() => _pendingImage = null),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ThemeData theme, bool sending) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 6, right: 4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(26),
                boxShadow: theme.brightness == Brightness.light
                    ? AppColors.softShadow(opacity: 0.05, blur: 12)
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    color: AppColors.primary,
                    onPressed: sending ? null : _attachImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything…',
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : () => _send(),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 16, color: Colors.white),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 400.ms, delay: (i * 150).ms)
                  .then()
                  .fadeOut(duration: 400.ms);
            }),
          ),
        ),
      ],
    );
  }
}
