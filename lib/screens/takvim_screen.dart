// lib/screens/takvim_screen.dart - Siyah Tema Uyumlu
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_colors.dart';

class TakvimScreen extends StatefulWidget {
  const TakvimScreen({Key? key}) : super(key: key);

  @override
  State<TakvimScreen> createState() => _TakvimScreenState();
}

class _TakvimScreenState extends State<TakvimScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: kText,
            ),
            children: const [
              TextSpan(text: 'Tak'),
              TextSpan(text: 'vim', style: TextStyle(color: kPrimary)),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAŞLIK
            Text(
              'Tarihi Seç',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kText,
              ),
            ),
            const SizedBox(height: 16),

            // TAKVIM
            Container(
              decoration: BoxDecoration(
                color: kBgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDate = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kText,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: kPrimary,
                      size: 24,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: kPrimary,
                      size: 24,
                    ),
                    headerMargin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: kText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    weekendStyle: TextStyle(
                      color: kText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: TextStyle(
                      color: kText,
                      fontWeight: FontWeight.w500,
                    ),
                    todayTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    todayDecoration: BoxDecoration(
                      color: kSuccess.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    weekendTextStyle: TextStyle(
                      color: kText,
                      fontWeight: FontWeight.w500,
                    ),
                    outsideTextStyle: TextStyle(
                      color: isDark ? kTextSub.withOpacity(0.4) : kTextSub.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                    cellMargin: const EdgeInsets.all(6),
                    cellPadding: const EdgeInsets.all(8),
                  ),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  rowDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SEÇİLİ TARİH GÖSTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBgCard2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: kPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seçilen Tarih:',
                          style: TextStyle(
                            fontSize: 12,
                            color: kTextSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // BUTON
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context, _selectedDate);
                },
                child: const Text('Seç'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
