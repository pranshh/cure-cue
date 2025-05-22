import 'package:flutter/material.dart';
import '../theme_constants.dart';

class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  
  const CustomTimePicker({
    Key? key,
    required this.initialTime,
  }) : super(key: key);

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late int selectedHour;
  late int selectedMinute;
  late bool isPM;

  @override
  void initState() {
    super.initState();
    selectedHour = widget.initialTime.hourOfPeriod;
    selectedMinute = widget.initialTime.minute;
    isPM = widget.initialTime.period == DayPeriod.pm;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set Reminder Time',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: BoxDecoration(
                color: ThemeConstants.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheelPicker(
                    label: 'Hour',
                    items: List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')),
                    selectedIndex: selectedHour - 1,
                    onChanged: (index) => setState(() => selectedHour = index + 1),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildWheelPicker(
                    label: 'Minute',
                    items: List.generate(12, (i) => (i * 5).toString().padLeft(2, '0')),
                    selectedIndex: selectedMinute ~/ 5,
                    onChanged: (index) => setState(() => selectedMinute = index * 5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodButton('AM', !isPM),
                const SizedBox(width: 20),
                _buildPeriodButton('PM', isPM),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    final hour = isPM ? 
                      (selectedHour == 12 ? 12 : selectedHour + 12) : 
                      (selectedHour == 12 ? 0 : selectedHour);
                    Navigator.pop(
                      context,
                      TimeOfDay(hour: hour, minute: selectedMinute),
                    );
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelPicker({
    required String label,
    required List<String> items,
    required int selectedIndex,
    required Function(int) onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListWheelScrollView.useDelegate(
              controller: FixedExtentScrollController(initialItem: selectedIndex),
              itemExtent: 40,
              perspective: 0.005,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, index) {
                  return Center(
                    child: Text(
                      items[index],
                      style: TextStyle(
                        fontSize: selectedIndex == index ? 24 : 20,
                        fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                        color: selectedIndex == index 
                          ? ThemeConstants.primaryColor 
                          : Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String text, bool isSelected) {
    return Material(
      color: isSelected ? ThemeConstants.primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: isSelected ? 0 : 2,
      child: InkWell(
        onTap: () => setState(() => isPM = text == 'PM'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : ThemeConstants.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
