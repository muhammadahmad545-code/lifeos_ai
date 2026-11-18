import 'package:basalt/basalt.dart';
import 'package:flutter/material.dart';

/// Icon-only button with a label that TalkBack (and the UI tests) can find.
class IconAction extends StatelessWidget {
  const IconAction({super.key, required this.icon, required this.label, required this.onPressed, this.color, this.size});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, color: color, size: size),
      ),
    );
  }
}

/// Round check used for tasks, habits and checklist items.
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.done, required this.onTap, required this.label, this.color});

  final bool done;
  final VoidCallback? onTap;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    final c = color ?? p.accent;
    return Semantics(
      container: true,
      button: true,
      checked: done,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c : Colors.transparent,
                border: Border.all(color: done ? c : p.textFaint, width: 1.8),
              ),
              child: done ? Icon(Icons.check_rounded, size: 16, color: p.onAccent) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A pushed screen in the same style as the tab pages: back arrow, large title, padded list.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.headerActions = const [],
    required this.children,
    this.floating,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> headerActions;
  final List<Widget> children;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: actions),
      floatingActionButton: floating,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, 96),
        children: [
          BHeader(title: title, subtitle: subtitle, actions: headerActions),
          ...children,
        ],
      ),
    );
  }
}

/// Form screen: app bar with a title and a primary action, scrollable fields.
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.saveLabel = 'Save',
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final String saveLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: TextButton(onPressed: onSave, child: Text(saveLabel)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxxl),
          children: children,
        ),
      ),
    );
  }
}

/// Small label above a form control.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.lg, Gap.xs, Gap.sm),
      child: Text(text.toUpperCase(), style: BasaltType.overline.copyWith(color: p.textFaint)),
    );
  }
}

/// Horizontal wrap of chips.
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: children);
}

/// A tappable field-like row that opens a picker (date, time, ...).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.icon, required this.label, required this.onTap, this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.basalt;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: p.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: p.textMuted),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(label, style: BasaltType.body.copyWith(color: p.text)),
                ),
              ),
              if (onClear != null) IconAction(icon: Icons.close_rounded, label: 'Clear $label', onPressed: onClear, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row in a card.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.icon});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return BListRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 20),
    lastDate: DateTime(now.year + 20),
  );
}

Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay? initial) =>
    showTimePicker(context: context, initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0));

/// Bottom sheet with a title, content and keyboard-aware padding.
Future<T?> showFormSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final p = ctx.basalt;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl - 4, 0, Gap.xl - 4, Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: BasaltType.title.copyWith(color: p.text)),
              const SizedBox(height: Gap.lg),
              builder(ctx),
            ],
          ),
        ),
      );
    },
  );
}

/// Primary floating "New ..." button.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: label,
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(label),
      );
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
