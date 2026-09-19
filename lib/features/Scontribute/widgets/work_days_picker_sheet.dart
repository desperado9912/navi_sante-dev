import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WorkDaysPickerSheet extends StatefulWidget {
  final String? initialValue;

  const WorkDaysPickerSheet({super.key, this.initialValue});

  static Future<String?> show(BuildContext context, {String? initialValue}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkDaysPickerSheet(initialValue: initialValue),
    );
  }

  @override
  State<WorkDaysPickerSheet> createState() => _WorkDaysPickerSheetState();
}

class _WorkDaysPickerSheetState extends State<WorkDaysPickerSheet> {
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late final Set<String> _selectedDays;
  bool _isOpen24Hours = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
    if (widget.initialValue != null) {
      if (widget.initialValue == 'Open 24/7') {
        _isOpen24Hours = true;
        _selectedDays.addAll(_weekdays);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _consolidateSelection() {
    if (_selectedDays.isEmpty) return 'Closed';
    final isAllDays = _selectedDays.length == 7;

    if (isAllDays && _isOpen24Hours) {
      return 'Open 24/7';
    }

    final hoursString = _isOpen24Hours
        ? '24h'
        : '(${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)})';

    // Check consecutive ranges
    final indices = _weekdays
        .asMap()
        .entries
        .where((e) => _selectedDays.contains(e.value))
        .map((e) => e.key)
        .toList();

    if (indices.length == 5 && indices.first == 0 && indices.last == 4) {
      // Mon-Fri
      return _isOpen24Hours ? 'Mon-Fri (24/7)' : 'Mon-Fri $hoursString';
    }
    if (indices.length == 6 && indices.first == 0 && indices.last == 5) {
      // Mon-Sat
      return _isOpen24Hours ? 'Mon-Sat (24/7)' : 'Mon-Sat $hoursString';
    }
    if (isAllDays) {
      return 'Mon-Sun $hoursString';
    }

    // Custom non-continuous or other ranges
    final dayLabel = _selectedDays.join(', ');
    return '$dayLabel $hoursString';
  }

  void _applyPreset(String preset) {
    setState(() {
      if (preset == 'Open 24/7') {
        _selectedDays.addAll(_weekdays);
        _isOpen24Hours = true;
      } else if (preset == 'Mon - Fri (08:00 - 18:00)') {
        _selectedDays.clear();
        _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        _isOpen24Hours = false;
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 18, minute: 0);
      } else if (preset == 'Mon - Sat (08:00 - 18:00)') {
        _selectedDays.clear();
        _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
        _isOpen24Hours = false;
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 18, minute: 0);
      } else if (preset == 'Mon - Sun (08:00 - 20:00)') {
        _selectedDays.clear();
        _selectedDays.addAll(_weekdays);
        _isOpen24Hours = false;
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 20, minute: 0);
      }
    });
  }

  /// Platform-adaptive compact time picker:
  /// iOS -> CupertinoTimePicker modal sheet
  /// Android -> Material compact TimePicker
  Future<void> _pickTimePlatformAdaptive(bool isStart) async {
    final current = isStart ? _startTime : _endTime;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIos) {
      DateTime tempDateTime = DateTime(
        2026,
        1,
        1,
        current.hour,
        current.minute,
      );

      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Text(
                      isStart ? 'Select Opening Time' : 'Select Closing Time',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          final pickedTime = TimeOfDay(
                            hour: tempDateTime.hour,
                            minute: tempDateTime.minute,
                          );
                          if (isStart) {
                            _startTime = pickedTime;
                          } else {
                            _endTime = pickedTime;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: tempDateTime,
                  onDateTimeChanged: (newDateTime) {
                    tempDateTime = newDateTime;
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: current,
        initialEntryMode: TimePickerEntryMode.dialOnly,
        helpText: isStart ? 'SELECT OPENING TIME' : 'SELECT CLOSING TIME',
        // Explicitly strips any inherited text decoration
        builder: (ctx, child) {
          final base = Theme.of(ctx);
          return Theme(
            data: base.copyWith(
              timePickerTheme: base.timePickerTheme.copyWith(
                backgroundColor: Colors.white,
                helpTextStyle: base.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1A1A1A),
                  decoration: TextDecoration.none,
                ),
                dayPeriodTextColor: const Color(0xFF1A1A1A),
                hourMinuteTextColor: const Color(0xFF1A1A1A),
                dialHandColor: const Color(0xFF2A7D8F),
                dialBackgroundColor: const Color(0xFFF2F4F7),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          if (isStart) {
            _startTime = picked;
          } else {
            _endTime = picked;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final consolidated = _consolidateSelection();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Work Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose operating days and daily opening hours.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
          const SizedBox(height: 16),

          // Quick Presets
          const Text(
            'Quick Presets',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Open 24/7'),
              _buildPresetChip('Mon - Fri (08:00 - 18:00)'),
              _buildPresetChip('Mon - Sat (08:00 - 18:00)'),
              _buildPresetChip('Mon - Sun (08:00 - 20:00)'),
            ],
          ),
          const SizedBox(height: 20),

          // Days selection
          const Text(
            'Operating Days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekdays.map((day) {
              final isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2A7D8F)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2A7D8F)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 24 hours toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Open 24 hours on active days',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              CupertinoSwitch(
                value: _isOpen24Hours,
                activeTrackColor: const Color(0xFF2A7D8F),
                onChanged: (val) => setState(() => _isOpen24Hours = val),
              ),
            ],
          ),

          if (!_isOpen24Hours) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTimePlatformAdaptive(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF5F6368)),
                              SizedBox(width: 4),
                              Text(
                                'Opens at',
                                style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimeOfDay(_startTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTimePlatformAdaptive(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF5F6368)),
                              SizedBox(width: 4),
                              Text(
                                'Closes at',
                                style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimeOfDay(_endTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Preview of formatted string
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD8F6FF).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A7D8F).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: Color(0xFF2A7D8F),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stored format',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                      ),
                      Text(
                        consolidated,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A7D8F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, consolidated),
              child: const Text(
                'Apply Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      backgroundColor: const Color(0xFFF2F4F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      onPressed: () => _applyPreset(label),
    );
  }
}
