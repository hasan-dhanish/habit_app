class Habit {
  String name;
  List<DateTime> completedDates;
  DateTime creationDate;

  Habit({
    required this.name,
    List<DateTime>? completedDates,
    DateTime? creationDate,
  }) : completedDates = completedDates ?? [],
       creationDate = creationDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'completedDates': completedDates.map((e) => e.toIso8601String()).toList(),
      'creationDate': creationDate.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      name: json['name'],
      completedDates: (json['completedDates'] as List)
          .map((e) => DateTime.parse(e))
          .toList(),
      creationDate: json['creationDate'] != null 
          ? DateTime.parse(json['creationDate']) 
          : DateTime(2020), // Default for legacy data
    );
  }

  /// Returns true if the habit is completed today.
  bool get isDone {
    final today = DateTime.now();
    return isCompletedOn(today);
  }

  /// Sets completion status for today.
  set isDone(bool value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (value) {
      if (!completedDates.contains(today)) {
        completedDates.add(today);
      }
    } else {
      completedDates.removeWhere((date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day);
    }
  }

  bool isCompletedOn(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return completedDates.any((d) =>
        d.year == target.year &&
        d.month == target.month &&
        d.day == target.day);
  }

  int get streak {
    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.map((e) => DateTime(e.year, e.month, e.day)).toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    if (sortedDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    // If the latest completion is not today or yesterday, streak is broken (0).
    // Unless we want to show the "previous" streak? Usually streak is 0 if broken.
    if (sortedDates.first != todayDate && sortedDates.first != yesterdayDate) {
      return 0;
    }

    int currentStreak = 0;
    DateTime checkDate = sortedDates.first == todayDate ? todayDate : yesterdayDate;

    for (final date in sortedDates) {
      if (date == checkDate) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break; // Gap found
      }
    }
    return currentStreak;
  }
}
