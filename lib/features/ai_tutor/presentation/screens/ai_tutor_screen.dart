import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../providers/tutor_providers.dart';
import '../widgets/tutor_message_bubble.dart';
import '../widgets/tutor_suggested_prompts.dart';
import '../widgets/tutor_typing_indicator.dart';

/// AI Tutor — a mock-backed conversational study helper. Reached from
/// Home's AI Tutor card (blocked there, and again by the router's own
/// redirect, while an Exam Simulation attempt is in progress — see
/// `core/router/app_router.dart` and this feature's own
/// AI_TUTOR_API_REQUIREMENTS.md "Exam integrity" note).
class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String content) async {
    if (content.trim().isEmpty) return;
    _textController.clear();
    await ref
        .read(tutorConversationNotifierProvider.notifier)
        .sendMessage(content);
    _scrollToBottom();
  }

  Future<void> _confirmNewConversation(
    AppLocalizations l10n,
    bool hasMessages,
  ) async {
    if (!hasMessages) {
      ref
          .read(tutorConversationNotifierProvider.notifier)
          .startNewConversation();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiTutorNewConversation),
        content: Text(l10n.aiTutorNewConversationConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.notificationsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.aiTutorNewConversation),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref
          .read(tutorConversationNotifierProvider.notifier)
          .startNewConversation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tutorConversationNotifierProvider);
    final messages = state.conversation.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiTutorTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: l10n.aiTutorNewConversation,
            onPressed: () => _confirmNewConversation(l10n, messages.isNotEmpty),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SampleDataBanner(
              isSampleData: !AppConfig.isAiTutorApiAvailable,
              message: l10n.aiTutorSampleDataNotice,
            ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(onPromptSelected: _send)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MadeenSpace.pageMargin,
                        vertical: MadeenSpace.md,
                      ),
                      itemCount: messages.length + (state.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return const TutorTypingIndicator();
                        }
                        return TutorMessageBubble(message: messages[index]);
                      },
                    ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MadeenSpace.pageMargin,
                  0,
                  MadeenSpace.pageMargin,
                  MadeenSpace.xs,
                ),
                child: Text(
                  state.error!.message,
                  style: MadeenType.bodySm.copyWith(
                    color: MadeenTokens.of(context).error,
                  ),
                ),
              ),
            _Composer(controller: _textController, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MadeenSpace.pageMargin,
        vertical: MadeenSpace.xl,
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 32, color: t.accentText),
          const SizedBox(height: MadeenSpace.md),
          Text(
            l10n.aiTutorWelcomeTitle,
            style: Theme.of(context).textTheme.headlineMedium!
                .copyWith(color: t.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MadeenSpace.xs),
          Text(
            l10n.aiTutorWelcomeSubtitle,
            style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MadeenSpace.lg),
          TutorSuggestedPrompts(onSelected: onPromptSelected),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return MadeenBottomActionBar(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              decoration: InputDecoration(
                hintText: l10n.aiTutorInputHint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MadeenSpace.md,
                  vertical: MadeenSpace.sm - 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: MadeenSpace.xs),
          Semantics(
            button: true,
            label: l10n.aiTutorSendButton,
            excludeSemantics: true,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: t.primaryAction,
                foregroundColor: t.onPrimaryAction,
                minimumSize: const Size.square(MadeenSize.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MadeenRadius.base),
                ),
              ),
              icon: const Icon(Icons.send),
              tooltip: l10n.aiTutorSendButton,
              onPressed: () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}
