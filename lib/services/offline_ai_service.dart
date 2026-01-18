import '../models/habit.dart';
import '../models/goal.dart';
import '../models/journal_entry.dart';
import 'dart:math';

class OfflineAIService {
  static String getInsight({
    required List<Habit> habits,
    required List<Goal> goals,
    required List<JournalEntry> journalEntries,
    required int streak,
  }) {
    final now = DateTime.now();
    final random = Random();

    // 1. 🛑 CRITICAL ALERTS (Deadlines)
    for (final goal in goals) {
      if (!goal.isCompleted) {
        final daysLeft = goal.deadline.difference(now).inDays;
        if (daysLeft >= 0 && daysLeft <= 3) {
          return "🚨 Crunch time! Only $daysLeft days left for '${goal.name}'. You got this!";
        }
      }
    }

    // 2. ❤️ EMOTIONAL CHECK (Journal Sentiment)
    if (journalEntries.isNotEmpty) {
      // Look at the latest entry
      final lastEntry = journalEntries.last;
      // Only relevant if written today or yesterday
      if (now.difference(lastEntry.date).inHours < 36) {
        final content = lastEntry.content.toLowerCase();
        if (content.contains('tired') || content.contains('exhausted') || content.contains('burnout')) {
          return "🛌 You mentioned feeling tired. Remember, rest is part of the work.";
        }
        if (content.contains('sad') || content.contains('anxious') || content.contains('stress')) {
          return "💙 It's okay to have rough days. Be kind to yourself today.";
        }
        if (content.contains('happy') || content.contains('excited') || content.contains('great')) {
          return "✨ Love the energy! Channel that positivity into your hardest task.";
        }
      }
    }

    // 3. 🔥 STREAK HYPE
    if (streak >= 3 && streak < 7) {
      return "🔥 $streak day streak! You're building momentum. Don't stop now!";
    }
    if (streak >= 7) {
      return "🚀 Unstoppable! $streak days in a row. You are becoming a new machine.";
    }

    // 4. 🕵️‍♂️ HABIT DETECTIVE (Neglect)
    if (habits.isNotEmpty) {
      // Find a habit not done today
      final today = DateTime(now.year, now.month, now.day);
      final incomplete = habits.where((h) => !h.isCompletedOn(today)).toList();
      
      if (incomplete.isNotEmpty) {
        // Late in the day?
        if (now.hour >= 18) {
          final target = incomplete[random.nextInt(incomplete.length)];
          return "🌙 Evening check: Do you have 5 minutes for '${target.name}'?";
        }
      } else {
        // All done!
        if (now.hour < 12) {
           return "🏆 Morning champion! All habits crushed. Enjoy your day!";
        } else {
           return "✅ All clear. You conquered today. Time to relax?";
        }
      }

      // Check for 'Slacking' (Not done in 3 days)
      for (final h in habits) {
         bool doneRecently = false;
         // Check last 3 days
         for (int i=1; i<=3; i++) {
            if (h.isCompletedOn(now.subtract(Duration(days: i)))) {
                doneRecently = true;
                break;
            }
         }
         if (!doneRecently && habits.length > 2) {
             return "👀 We missed '${h.name}' lately. Small steps count – just do 2 mins of it?";
         }
      }
    }

    // 5. ⏰ TIME KEEPER (General Fallback)
    if (now.hour < 9) {
      return "🌅 Good morning! Eat that frog (hardest task) first.";
    }
    if (now.hour > 22) {
      return "😴 Sleep is best for recovery. Phone down, eyes closed soon?";
    }

    // 6. 🎲 RANDOM WISDOM (If nothing else matches)
    final quotes = [
      "Consistency > Intensity.",
      "A 1% improvement everyday means 37x better in a year.",
      "Don't break the chain!",
      "Focus on the process, not the outcome.",
      "You define your own success.",
    ];
    return quotes[random.nextInt(quotes.length)];
  }
}
