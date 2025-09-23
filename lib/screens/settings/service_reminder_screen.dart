import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mahlete_semay_project/models/service_reminder_model.dart';
import 'package:mahlete_semay_project/providers/service_reminder_provider.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ServiceReminderScreen extends StatelessWidget {
  const ServiceReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Consumer<ServiceReminderProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                stretch: true,
                backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('Service Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary.withOpacity(0.2), theme.colorScheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Icon(Icons.notifications_active_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.1)),
                  ),
                ),
              ),
              provider.reminders.isEmpty
                  ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(context))
                  : SliverPadding(
                padding: EdgeInsets.fromLTRB(context.w(16), context.w(16), context.w(16), context.w(100)),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final reminder = provider.reminders[index];
                      return _ReminderCard(reminder: reminder)
                          .animate()
                          .fadeIn(delay: (100 * index).ms)
                          .slideY(begin: 0.2, curve: Curves.easeOutCubic);
                    },
                    childCount: provider.reminders.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditReminderDialog(context),
        label: const Text('New Reminder'),
        icon: const Icon(Icons.add_alert_outlined),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
              child: Icon(Icons.notifications_off_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reminders Set',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set a reminder for your next service to receive daily notifications 5 days prior.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ServiceReminder reminder;
  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final difference = reminder.serviceDateTime.difference(now);
    final daysLeft = difference.inDays;
    final isPast = difference.isNegative;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          color: theme.cardColor.withOpacity(0.4),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: isPast ? Colors.grey : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(theme, Icons.calendar_today, DateFormat('EEEE, MMMM d, yyyy').format(reminder.serviceDateTime)),
                    const SizedBox(height: 8),
                    _buildInfoRow(theme, Icons.access_time_filled_rounded, DateFormat('h:mm a').format(reminder.serviceDateTime)),
                    if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        reminder.notes!,
                        style: TextStyle(color: theme.textTheme.bodySmall?.color, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$daysLeft Days Left',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showAddEditReminderDialog(context, reminder: reminder),
                        tooltip: 'Edit Reminder',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        onPressed: () {
                          Provider.of<ServiceReminderProvider>(context, listen: false).cancelReminder(reminder.id);
                          CustomSnackbar.show(context, 'Reminder for "${reminder.title}" cancelled.');
                        },
                        tooltip: 'Cancel Reminder',
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

void _showAddEditReminderDialog(BuildContext context, {ServiceReminder? reminder}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddEditReminderDialog(reminder: reminder),
  );
}

class _AddEditReminderDialog extends StatefulWidget {
  final ServiceReminder? reminder;
  const _AddEditReminderDialog({this.reminder});

  @override
  State<_AddEditReminderDialog> createState() => _AddEditReminderDialogState();
}

class _AddEditReminderDialogState extends State<_AddEditReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDateTime;

  bool get isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.reminder!.title;
      _notesController.text = widget.reminder!.notes ?? '';
      _selectedDateTime = widget.reminder!.serviceDateTime;
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;

    if (!context.mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<ServiceReminderProvider>(context, listen: false);

      if (provider.hasConflict(_selectedDateTime!, excludeReminderId: isEditing ? widget.reminder!.id : null)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Schedule'),
            content: const Text('You already have a service scheduled for this hour. Are you sure you want to add another one?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add Anyway')),
            ],
          ),
        );
        if (confirm != true) return;
      }

      if (isEditing) {
        final updatedReminder = ServiceReminder(
          id: widget.reminder!.id,
          title: _titleController.text.trim(),
          serviceDateTime: _selectedDateTime!,
          notes: _notesController.text.trim(),
        );
        await provider.updateReminder(updatedReminder);
        if (mounted) CustomSnackbar.show(context, 'Reminder updated!');
      } else {
        final newReminder = ServiceReminder.create(
          title: _titleController.text.trim(),
          serviceDateTime: _selectedDateTime!,
          notes: _notesController.text.trim(),
        );
        await provider.addReminder(newReminder);
        if (mounted) CustomSnackbar.show(context, 'Reminder set successfully!');
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEditing ? 'Edit Reminder' : 'Set New Reminder', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Service Title (e.g., Sunday Worship)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)),
                  validator: (value) => value!.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date & Time',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_month),
                      errorText: _selectedDateTime == null ? 'Please select a date and time' : null,
                    ),
                    child: Text(
                      _selectedDateTime == null ? 'Tap to select' : DateFormat.yMMMd().add_jm().format(_selectedDateTime!),
                      style: TextStyle(fontSize: 16, color: _selectedDateTime == null ? theme.hintColor : null),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note_alt_outlined)),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selectedDateTime == null ? null : _submit,
                      child: Text(isEditing ? 'Save Changes' : 'Set Reminder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}