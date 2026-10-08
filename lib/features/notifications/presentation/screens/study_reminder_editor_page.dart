import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../../domain/entities/weekday.dart';
import '../providers/study_reminders_providers.dart';
import '../providers/study_reminders_state.dart';
import '../widgets/study_reminder_format.dart';

/// Creates a new [StudyReminder] (`reminderId == null`) or edits an
/// existing one — the same screen either way, since the only difference is
/// which [StudyReminderDraft] the form starts from and which
/// [StudyRemindersNotifier] method Save calls. Validation is
/// [validateStudyReminderDraft] (a pure domain function this screen maps
/// onto localized field errors), never reimplemented here.
class StudyReminderEditorPage extends ConsumerStatefulWidget {
  const StudyReminderEditorPage({super.key, this.reminderId});

  final String? reminderId;

  bool get isEditing => reminderId != null;

  @override
  ConsumerState<StudyReminderEditorPage> createState() =>
      _StudyReminderEditorPageState();
}

class _StudyReminderEditorPageState
    extends ConsumerState<StudyReminderEditorPage> {
  final _titleController = TextEditingController();
  int _hour = 8;
  int _minute = 0;
  ReminderRepeat _repeat = ReminderRepeat.everyDay;
  Set<Weekday> _customDays = {};
  bool _enabled = true;

  bool _initializedFromExisting = false;
  bool _isSaving = false;
  List<StudyReminderValidationError> _errors = [];
  String? _saveErrorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _initializeFrom(StudyReminder reminder) {
    if (_initializedFromExisting) return;
    _initializedFromExisting = true;
    _titleController.text = reminder.title;
    _hour = reminder.hour;
    _minute = reminder.minute;
    _repeat = reminder.repeat;
    _customDays = Set.of(reminder.customDays);
    _enabled = reminder.enabled;
  }

  StudyReminderDraft _buildDraft() => StudyReminderDraft(
    title: _titleController.text,
    enabled: _enabled,
    hour: _hour,
    minute: _minute,
    repeat: _repeat,
    customDays: _repeat == ReminderRepeat.custom ? _customDays : const {},
  );

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    final draft = _buildDraft();
    final errors = validateStudyReminderDraft(draft);
    setState(() {
      _errors = errors;
      _saveErrorMessage = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _isSaving = true);
    final notifier = ref.read(studyRemindersNotifierProvider.notifier);
    final failure = widget.isEditing
        ? await notifier.update(widget.reminderId!, draft)
        : await notifier.create(draft);

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saveErrorMessage = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!widget.isEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studyReminderEditorNewTitle)),
        body: _buildForm(context, l10n),
      );
    }

    final remindersState = ref.watch(studyRemindersNotifierProvider);
    final reminder = ref.watch(studyReminderByIdProvider(widget.reminderId!));

    if (remindersState is StudyRemindersLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studyReminderEditorEditTitle)),
        body: const MadeenPageLoading(),
      );
    }
    if (reminder == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studyReminderEditorEditTitle)),
        body: MadeenPageMessage(
          message: l10n.notificationDetailsNotFoundMessage,
        ),
      );
    }
    _initializeFrom(reminder);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyReminderEditorEditTitle)),
      body: _buildForm(context, l10n),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final titleError =
        _errors.contains(StudyReminderValidationError.titleRequired)
        ? l10n.studyReminderEditorTitleRequiredError
        : null;
    final daysError =
        _errors.contains(StudyReminderValidationError.daysRequired)
        ? l10n.studyReminderEditorDaysRequiredError
        : null;

    final t = MadeenTokens.of(context);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                MadeenSpace.pageMargin,
                MadeenSpace.lg,
                MadeenSpace.pageMargin,
                MadeenSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l10n.studyReminderEditorTitleLabel,
                      errorText: titleError,
                    ),
                  ),
                  const SizedBox(height: MadeenSpace.md),
                  MadeenCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MadeenSpace.md,
                    ),
                    child: MadeenDividedList(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.schedule_outlined,
                            color: t.inkSecondary,
                          ),
                          title: Text(
                            l10n.studyReminderEditorTimeLabel,
                            style: MadeenType.bodyMd.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            formatReminderTime(context, _hour, _minute),
                            style: MadeenType.metricMd.copyWith(
                              color: t.accentText,
                            ),
                          ),
                          onTap: _pickTime,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: t.inkSecondary,
                          ),
                          title: Text(
                            l10n.studyReminderEditorEnabledLabel,
                            style: MadeenType.bodyMd.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MadeenSpace.lg),
                  MadeenSectionHeader(
                    title: l10n.studyReminderEditorRepeatLabel,
                  ),
                  const SizedBox(height: MadeenSpace.xs),
                  Wrap(
                    spacing: MadeenSpace.xs,
                    runSpacing: MadeenSpace.xs,
                    children: [
                      for (final repeat in ReminderRepeat.values)
                        ChoiceChip(
                          label: Text(reminderRepeatLabel(l10n, repeat)),
                          selected: _repeat == repeat,
                          onSelected: (_) => setState(() => _repeat = repeat),
                        ),
                    ],
                  ),
                  if (_repeat == ReminderRepeat.custom) ...[
                    const SizedBox(height: MadeenSpace.lg),
                    MadeenSectionHeader(
                      title: l10n.studyReminderEditorDaysLabel,
                      color: daysError != null ? t.error : null,
                    ),
                    const SizedBox(height: MadeenSpace.xs),
                    Wrap(
                      spacing: MadeenSpace.xs,
                      runSpacing: MadeenSpace.xs,
                      children: [
                        for (final day in Weekday.values)
                          FilterChip(
                            label: Text(weekdayShortLabel(l10n, day)),
                            selected: _customDays.contains(day),
                            onSelected: (selected) => setState(() {
                              _customDays = Set.of(_customDays);
                              if (selected) {
                                _customDays.add(day);
                              } else {
                                _customDays.remove(day);
                              }
                            }),
                          ),
                      ],
                    ),
                    if (daysError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: MadeenSpace.xxs),
                        child: Text(
                          daysError,
                          style: MadeenType.bodySm.copyWith(color: t.error),
                        ),
                      ),
                  ],
                  if (_saveErrorMessage != null) ...[
                    const SizedBox(height: MadeenSpace.md),
                    Text(
                      _saveErrorMessage!,
                      style: MadeenType.bodySm.copyWith(color: t.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          MadeenBottomActionBar(
            child: SizedBox(
              width: double.infinity,
              height: MadeenSize.buttonHeight,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.studyReminderEditorSaveButton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
