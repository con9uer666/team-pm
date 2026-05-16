import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Form field that pops a date-then-time picker on tap, exposing a single
/// `DateTime?` via [onChanged]. Used by task / meeting / objective create
/// sheets so the picker UX stays uniform.
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.includeTime = true,
    this.helperText,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool includeTime;
  final String? helperText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 5);
    final last = lastDate ?? DateTime(now.year + 5);
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null) return;
    if (!includeTime) {
      onChanged(DateTime(date.year, date.month, date.day));
      return;
    }
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String get _formatted {
    if (value == null) return '';
    return DateFormat(includeTime ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd').format(value!);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          _formatted.isEmpty ? '请选择' : _formatted,
          style: TextStyle(
            color: _formatted.isEmpty ? const Color(0xFF94A3B8) : null,
          ),
        ),
      ),
    );
  }
}
