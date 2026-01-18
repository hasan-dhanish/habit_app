import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui'; // Added import
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:home_widget/home_widget.dart'; // Added for Widget
import '../widgets/animated_metallic_container.dart'; // Added for AnimatedMetallicContainer
import '../models/habit.dart';
import '../models/goal.dart';
import '../models/goal.dart';
import '../models/journal_entry.dart';
import '../models/journal_entry.dart';
import 'package:image_picker/image_picker.dart'; // Added
import 'package:path_provider/path_provider.dart'; // Added
import 'dart:io'; // Added
import '../services/offline_ai_service.dart'; // Added


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // =========================================================
  // 1️⃣ STATE VARIABLES
  // =========================================================
  int _tabIndex = 0; // 0: Habits, 1: Goals

  // Habits State
  final TextEditingController _habitController = TextEditingController();
  final List<Habit> habits = [];
  int streak = 0;
  DateTime? lastCompletedDate;

  // Journal State
  final List<JournalEntry> journalEntries = [];




  bool _isEagleViewExpanded = false; // Start collapsed
  int _consistencyView = 0; // 0: Day, 1: Week, 2: Year

  // Carousel State
  late PageController _pageController;
  int _currentPage = 1000; // Start in middle for 'infinite' feel, or just 1.

  // Goals State
  final TextEditingController _goalController = TextEditingController();
  final List<Goal> goals = [];
  DateTime? _newGoalDeadline;

  // Date Handling
  DateTime _selectedDate = DateTime.now();
  // _dateController, _initialPage removed as we moved to text picker

  // AI Coach State
  String _aiMessage = "Tap for today's insight";
  bool _isAiLoading = false;
  final List<String> _mockInsights = [
      "Small progress is still progress. Keep going!",
      "Hydration check! Have you had water recently?",
      "Consistency beats intensity. Just do 5 minutes.",
      "You're doing great! Take a deep breath.",
      "The best time to plant a tree was 20 years ago. The second best time is now.",
      "Focus on the step in front of you, not the whole staircase.",
      "Rest is productive too. Don't burn out.",
  ];

  void _generateInsight() {
      setState(() {
          _isAiLoading = true;
      });
      
      // Simulate "Thinking" time for better UX
      Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
              final insight = OfflineAIService.getInsight(
                  habits: habits,
                  goals: goals,
                  journalEntries: journalEntries,
                  streak: streak,
              );
              
              setState(() {
                  _aiMessage = insight;
                  _isAiLoading = false;
              });
          }
      });
  }

  // =========================================================
  // 2️⃣ LIFECYCLE
  // =========================================================
  @override
  void initState() {
    super.initState();
    // viewportFraction < 1.0 allows seeing neighbors
    _pageController = PageController(initialPage: 1, viewportFraction: 0.75);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _habitController.dispose();
    _goalController.dispose();
    super.dispose();
  }


  // Helper to ensure comparison with today's date only (ignoring time)
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // =========================================================
  // 3️⃣ PERSISTENCE (Merged)
  // =========================================================
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save Habits
    prefs.setString(
      'habits',
      jsonEncode(habits.map((e) => e.toJson()).toList()),
    );

    prefs.setString(
      'lastCompletedDate',
      lastCompletedDate?.toIso8601String() ?? '',
    );
    prefs.setInt('streak', streak);

    // Save Goals
    prefs.setString(
      'goals',
      jsonEncode(
        goals
            .map(
              (g) => {
                'name': g.name,
                'deadline': g.deadline.toIso8601String(),
                'isCompleted': g.isCompleted,
              },
            )
            .toList(),
      ),
    );

    // Save Journals
    prefs.setString(
      'journal',
      jsonEncode(journalEntries.map((e) => e.toJson()).toList()),
    );



    // Sync to Widget
    _updateWidgetData();

  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Habits
    final habitString = prefs.getString('habits');
    if (habitString != null) {
      final decoded = jsonDecode(habitString) as List;
      habits.clear();
      habits.addAll(decoded.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList());
    }

    // --- LOGIN STREAK LOGIC ---
    final lastLoginParams = prefs.getString('lastLoginDate'); // "YYYY-MM-DD"
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    // Default streak is 1 if new user, or load existing
    int currentStreak = prefs.getInt('streak') ?? 1;

    if (lastLoginParams == null) {
      // First time ever
      currentStreak = 1;
    } else {
      if (lastLoginParams == todayStr) {
         // Already logged in today, keep streak
      } else {
         final lastLogin = DateTime.parse(lastLoginParams);
         final now = DateTime.now();
         final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
         
         // Helper to ignore time
         bool isSameDay(DateTime a, DateTime b) => 
             a.year == b.year && a.month == b.month && a.day == b.day;

         if (isSameDay(lastLogin, yesterday)) {
             // Consistently logged in!
             currentStreak++;
         } else {
             // Missed a day (or more)
             currentStreak = 1;
         }
      }
    }

    // Save strictly as "streak" to reuse existing UI
    streak = currentStreak;
    await prefs.setString('lastLoginDate', todayStr);
    await prefs.setInt('streak', streak);
    
    setState(() {});

    // The following lines were for habit completion streak, which is now handled by _updateStreakIfCompleted
    // and the 'streak' variable is repurposed for login streak.
    // If habit completion streak needs to be displayed, a new state variable would be needed.
    // streak = prefs.getInt('streak') ?? 0;
    final date = prefs.getString('lastCompletedDate');
    if (date != null) {
      lastCompletedDate = DateTime.parse(date);
    }

    // Load Goals
    final goalsString = prefs.getString('goals');
    if (goalsString != null) {
      final decoded = jsonDecode(goalsString) as List;
      goals.clear();
      goals.addAll(
        decoded.map(
          (e) => Goal(
            name: e['name'],
            deadline: DateTime.parse(e['deadline']),
            isCompleted: e['isCompleted'],
          ),
        ),
      );
    }

    // Load Journal
    final journalString = prefs.getString('journal');
    if (journalString != null) {
      final decoded = jsonDecode(journalString) as List;
      journalEntries.clear();
      journalEntries.addAll(decoded.map((e) => JournalEntry.fromJson(e)));
    }




    // Note: The previous "Clear" was theoretical. To really clear it for the user,
    // I should have run code. Since I can't easily run a "one-off" script on their device without building,
    // I am relying on the fact that they might have just run the previous version.
    // Actually, to trigger the clear safely, I'll add a check.
    // IF journalEntries is empty (which it is on init), and we load nothing, it's empty.

    setState(() {});
  }

  Future<void> _updateWidgetData() async {
    // Save Streak
    await HomeWidget.saveWidgetData<String>('streak', '$streak');

    // Save History (Last 7 days)
    final now = DateTime.now();
    List<String> historyBits = [];

    // Pre-calculate daily counts
    final Map<DateTime, int> activityMap = {};
    for (final habit in habits) {
      for (final date in habit.completedDates) {
        final d = DateTime(date.year, date.month, date.day);
        activityMap[d] = (activityMap[d] ?? 0) + 1;
      }
    }

    // Generate last 7 days logic (Oldest to Newest for the loop, but check logic)
    // Layout: Dot1(Left) -> Dot7(Right).
    // Dot7 is Today. Dot1 is 6 days ago.
    // So list should be [Day-6, Day-5, ..., Today]

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final normalizedDate = DateTime(d.year, d.month, d.day);
      final count = activityMap[normalizedDate] ?? 0;
      historyBits.add(count > 0 ? "1" : "0");
    }

    await HomeWidget.saveWidgetData<String>('history_7', historyBits.join(','));
    await HomeWidget.updateWidget(
      name: 'EagleWidgetProvider',
      androidName: 'EagleWidgetProvider',
    );
  }

  // =========================================================
  // =========================================================
  // 4️⃣ HABIT CONTROLLERS
  // =========================================================
  double _completionPercent() {
    if (habits.isEmpty) return 0.0;
    int completed = habits.where((h) => h.isCompletedOn(_selectedDate)).length;
    return completed / habits.length;
  }
  void _updateStreakIfCompleted() {
     // Streak is now "Login Streak", handled in _loadData().
     // This function is kept to avoid compilation errors if called elsewhere,
     // but it no longer alters the streak based on habits.
  }

  void _showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Habit'),
        content: TextField(
          controller: _habitController,
          decoration: const InputDecoration(hintText: 'Enter habit name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _habitController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _habitController.text.trim();
              if (text.isNotEmpty) {
                setState(() => habits.add(Habit(name: text)));
                _saveData();
              }
              _habitController.clear();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditHabitDialog(Habit habit) {
    _habitController.text = habit.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Habit'),
        content: TextField(controller: _habitController),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => habits.remove(habit));
              _saveData();
              _habitController.clear();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _habitController.text.trim();
              if (text.isNotEmpty) {
                setState(() => habit.name = text);
                _saveData();
              }
              _habitController.clear();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 5️⃣ GOAL CONTROLLERS
  // =========================================================
  void _addGoal() {
    if (_goalController.text.isEmpty || _newGoalDeadline == null) return;
    setState(() {
      goals.add(Goal(name: _goalController.text, deadline: _newGoalDeadline!));
      _sortGoals();
    });
    _saveData();
    _goalController.clear();
    _newGoalDeadline = null;
    Navigator.pop(context);
  }

  void _deleteGoal(Goal goal) {
    setState(() => goals.remove(goal));
    _saveData();
  }

  void _toggleGoal(Goal goal) {
    setState(() {
      goal.isCompleted = !goal.isCompleted;
      _sortGoals();
    });
    _saveData();
  }

  void _sortGoals() {
    goals.sort((a, b) {
      // Sort strictly by deadline, ignoring completion status for order
      return a.deadline.compareTo(b.deadline);
    });
  }

  void _showAddGoalDialog() {
    _newGoalDeadline = null; // Reset
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _goalController,
                decoration: const InputDecoration(labelText: 'Goal Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    _newGoalDeadline == null
                        ? 'No Date Chosen'
                        : '${_newGoalDeadline!.day}/${_newGoalDeadline!.month}/${_newGoalDeadline!.year}',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setDialogState(() => _newGoalDeadline = picked);
                    },
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: _addGoal, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 5.5 JOURNAL DIALOGS
  // =========================================================
  void _showAddJournalDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Entry ✍️'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'How was your day?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  journalEntries.add(
                    JournalEntry(
                      id: DateTime.now().toString(),
                      content: controller.text,
                      date: DateTime.now(),
                    ),
                  );
                  _saveData();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditJournalDialog(JournalEntry entry) {
    final controller = TextEditingController(text: entry.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry ✍️'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          // Delete Option
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              // Confirm delete
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete?'),
                  content: const Text(
                    'Are you sure you want to delete this entry?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          journalEntries.removeWhere((e) => e.id == entry.id);
                          _saveData();
                        });
                        Navigator.pop(c); // Close confirm
                        Navigator.pop(context); // Close edit
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  entry.content = controller.text;
                  _saveData();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(Goal goal) {
    _goalController.text = goal.name;
    // Keep reference to initial date if user doesn't change it
    DateTime editingDate = goal.deadline;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Goal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      hintText: 'e.g., Save \$5000',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Deadline: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: editingDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => editingDate = picked);
                          }
                        },
                        child: Text(
                          '${editingDate.day}/${editingDate.month}/${editingDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Goal',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Goal?'),
                        content: const Text(
                          'Are you sure you want to delete this goal?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              _deleteGoal(goal);
                              Navigator.pop(c); // Close confirm
                              Navigator.pop(context); // Close edit
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                TextButton(
                  onPressed: () {
                    _goalController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_goalController.text.isNotEmpty) {
                      setState(() {
                        goal.name = _goalController.text;
                        goal.deadline = editingDate;
                        _sortGoals();
                        _saveData();
                      });
                      _goalController.clear();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // 6️⃣ UI BUILDING BLOCKS
  // =========================================================
  Widget _buildToggleButtons() {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      // reduce vertical margin so it fits the sticky header height
      margin: const EdgeInsets.symmetric(vertical: 8),
      // Use IntrinsicHeight to make sure dividers/buttons align well if needed,
      // but here we just need a row.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildToggleButton('Habits', 0),
            const SizedBox(width: 12),
            _buildToggleButton('Goals', 1),
            const SizedBox(width: 12),
            _buildToggleButton('Journal', 2),
            const SizedBox(width: 12),
            _buildToggleButton('Progress', 3), 
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isSelected = _tabIndex == index;
    // Glassmorphic Button
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tabIndex = index);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // Semi-transparent background for glass effect
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitList() {
    return ReorderableListView(
      physics: const ClampingScrollPhysics(),
      header: const SizedBox.shrink(), // Removed EagleView header
      padding: const EdgeInsets.only(bottom: 120),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = habits.removeAt(oldIndex);
          habits.insert(newIndex, item);
        });
        _saveData();
      },
      children: [
        for (final habit in habits)
          Container(key: ValueKey(habit), child: _habitCard(habit)),
      ],
    );
  }





  Widget _graphOptionButton(String label, int index) {
    bool isSelected = _consistencyView == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _consistencyView = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGraphBars(Map<DateTime, int> activityMap) {
    int count = _consistencyView == 0 ? 7 : (_consistencyView == 1 ? 8 : 6);
    List<Widget> bars = [];
    final now = DateTime.now();

    for (int i = count - 1; i >= 0; i--) {
      String label = '';
      double percentage = 0.0;

      if (_consistencyView == 0) { // Day (Last 7 Days)
        final date = now.subtract(Duration(days: i));
        label = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][date.weekday-1];
        final d = DateTime(date.year, date.month, date.day);
        int done = activityMap[d] ?? 0;
        percentage = habits.isEmpty ? 0 : (done / habits.length);
        if (percentage > 1.0) percentage = 1.0;
      } else if (_consistencyView == 1) { // Week (Last 8 Weeks)
         // Simple simulation: Avg of 7 days
         double totalPerc = 0;
         for (int d=0; d<7; d++) {
            final date = now.subtract(Duration(days: (i * 7) + d));
             final normalized = DateTime(date.year, date.month, date.day);
             int done = activityMap[normalized] ?? 0;
             if (habits.isNotEmpty) totalPerc += (done / habits.length);
         }
         percentage = totalPerc / 7;
         if (percentage > 1.0) percentage = 1.0;
         label = 'W${i+1}';
      } else { // Year (Last 6 Months)
         final date = DateTime(now.year, now.month - i, 1);
         label = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month-1];
         // Simulation: just randomish based on previous month logic or valid logic
         // Let's implement valid logic: get all days in this month
         int daysInMonth = 0;
         double totalPerc = 0;
         for (int d=0; d<31; d++) {
             final checkDate = DateTime(date.year, date.month, d+1);
             if (checkDate.month != date.month) break; // Next month
             daysInMonth++;
             final normalized = DateTime(checkDate.year, checkDate.month, checkDate.day);
             int done = activityMap[normalized] ?? 0;
             if (habits.isNotEmpty) totalPerc += (done / habits.length);
         }
         percentage = daysInMonth > 0 ? (totalPerc / daysInMonth) : 0;
         if (percentage > 1.0) percentage = 1.0;
      }

      bars.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             AnimatedContainer(
               duration: const Duration(milliseconds: 500),
               width: 20,
               height: 100 * percentage,
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.primary.withOpacity(0.6 + (percentage * 0.4)),
                 borderRadius: BorderRadius.circular(5),
                 boxShadow: [
                   BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), blurRadius: 4, offset:const Offset(0,2))
                 ]
               ),
             ),
             const SizedBox(height: 8),
             Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        )
      );
    }
    return bars;
  }

  Widget _buildGoalList() {
    if (goals.isEmpty) {
      return const Center(child: Text('Set a goal and smash it! 🎯'));
    }
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        return _goalCard(goals[index]);
      },
    );
  }

  Widget _buildJournalTab() {
    if (journalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    // Sort by date desc
    final sortedEntries = List.of(journalEntries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            setState(() => journalEntries.removeWhere((e) => e.id == entry.id));
            _saveData();
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: AnimatedMetallicContainer(
            margin: const EdgeInsets.symmetric(vertical: 8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  entry.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.5),
                ),
              ),
              onTap: () => _showEditJournalDialog(entry),
            ),
          ),
        );
      },
    );
  }

  Widget _goalCard(Goal goal) {
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          goal.isCompleted = !goal.isCompleted;
          _sortGoals();
        });
        _saveData();
      },
      child: AnimatedScale(
        scale: goal.isCompleted ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Dismissible(
          key: ValueKey(goal),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteGoal(goal),
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 20),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
          child: AnimatedMetallicContainer(
            margin: const EdgeInsets.symmetric(vertical: 4),
            baseColor: Theme.of(context).cardColor, // Use card color base
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  goal.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  key: ValueKey(goal.isCompleted),
                  color: goal.isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                ),
              ),
              title: Text(
                goal.name,
                style: TextStyle(
                  decoration: goal.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: goal.isCompleted ? Colors.white54 : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                daysLeft < 0 ? 'Overdue!' : '$daysLeft days left',
                style: TextStyle(
                  color: daysLeft < 0 ? Colors.redAccent : Colors.white54,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Goal?'),
                      content: const Text(
                        'Are you sure you want to delete this goal?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            _deleteGoal(goal);
                            Navigator.pop(c);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              onLongPress: () => _showEditGoalDialog(goal),
            ),
          ),
        ),
      ),
    );
  }

  Widget _habitCard(Habit habit) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          bool isDone = habit.isCompletedOn(_selectedDate);
          if (!isDone) {
            habit.completedDates.add(
              DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
              ),
            );
          } else {
            habit.completedDates.removeWhere(
              (d) =>
                  d.year == _selectedDate.year &&
                  d.month == _selectedDate.month &&
                  d.day == _selectedDate.day,
            );
          }
          _updateStreakIfCompleted();
        });
        _saveData();

        if (habit.isCompletedOn(_selectedDate) && _completionPercent() == 1.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Perfect Day! All habits completed!',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.grey[900],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onLongPress: () => _showEditHabitDialog(habit),
      child: AnimatedScale(
        scale: habit.isCompletedOn(_selectedDate) ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedMetallicContainer(
          margin: const EdgeInsets.symmetric(vertical: 4),
          baseColor: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ), // Adjusted padding
            leading: Checkbox(
              value: habit.isCompletedOn(_selectedDate),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    habit.completedDates.add(
                      DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                      ),
                    );
                  } else {
                    habit.completedDates.removeWhere(
                      (d) =>
                          d.year == _selectedDate.year &&
                          d.month == _selectedDate.month &&
                          d.day == _selectedDate.day,
                    );
                  }
                });
                _saveData();
                // trigger confetti if goal reached
                if (value == true && _completionPercent() == 1.0) {
                  // _confettiController.play(); // Assuming _confettiController exists
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
              checkColor: Colors.black, // Dark check for contrast
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16,
                      decoration: habit.isCompletedOn(_selectedDate)
                          ? TextDecoration.lineThrough
                          : null,
                      color: habit.isCompletedOn(_selectedDate)
                          ? Colors.white54
                          : Colors.white,
                    ),
                  ),
                ),
                if (habit.streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${habit.streak}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // 6.5 BODY TRACKING
  // =========================================================


  // =========================================================

  // 7️⃣ MAIN BUILD
  // =========================================================
  String _getTimeBasedImage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'assets/images/sunrise.png';
    } else if (hour >= 12 && hour < 17) {
      return 'assets/images/noon.png';
    } else if (hour >= 17 && hour < 20) {
      return 'assets/images/sunset.png';
    } else {
      return 'assets/images/night.png';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override

  Widget _buildHomeTab() {
    // 1. Prepare Data for Heatmap & Graph
    const int weeksToShow = 53;
    final now = DateTime.now();
    final Map<DateTime, int> activityMap = {};
    for (final habit in habits) {
      for (final date in habit.completedDates) {
        final d = DateTime(date.year, date.month, date.day);
        activityMap[d] = (activityMap[d] ?? 0) + 1;
      }
    }
    final int totalHabits = habits.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        const SizedBox(height: 10),
        // 1. GREETING
         Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Dhanish',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 2. CAROUSEL & STATS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              const SizedBox(height: 4),
              SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 3, // 0: Photo, 1: Progress, 2: AI
                  onPageChanged: (int index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.3)).clamp(
                            0.0,
                            1.0,
                          );
                        } else {
                          value = index == 1 ? 1.0 : 0.7;
                        }
                        return Center(
                          child: SizedBox(
                            height:
                                Curves.easeOut.transform(value) * 300,
                            width:
                                Curves.easeOut.transform(value) * 300,
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedMetallicContainer(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(4, 4),
                          ),
                        ],
                        child: Center(
                          child: index == 1
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0.0,
                                    end: _completionPercent(),
                                  ),
                                  duration: const Duration(
                                    seconds: 1,
                                    milliseconds: 200,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 140,
                                          height: 140,
                                          child: CircularProgressIndicator(
                                            value: value,
                                            strokeWidth: 12,
                                            backgroundColor:
                                                Colors.white10,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                  Color
                                                >(
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${(value * 100).toInt()}%',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Text(
                                              'Done',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : index == 0
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                  child: Image.asset(
                                    _getTimeBasedImage(),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : _buildAICard(), // Index 2 is now AI
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${(_completionPercent() * 100).toInt()}% completed',
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: _completionPercent() == 1.0
                          ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$streak DAY STREAK',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // 3. EAGLE VIEW HEATMAP
        AnimatedMetallicContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yearly Overview 🦅',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: List.generate(weeksToShow, (weekIndex) {
                      return Column(
                        children: List.generate(7, (dayIndex) {
                          final daysAgo = (weeksToShow - 1 - weekIndex) * 7 + (6 - dayIndex);
                          final date = now.subtract(Duration(days: daysAgo));
                          final normalizedDate = DateTime(date.year, date.month, date.day);
                          final count = activityMap[normalizedDate] ?? 0;
                          double opacity = 0.1;
                          if (totalHabits > 0 && count > 0) {
                            opacity = 0.3 + (0.7 * (count / totalHabits));
                            if (opacity > 1.0) opacity = 1.0;
                          }
                          return Container(
                            width: 12, height: 12, margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: count > 0 ? Colors.green.withOpacity(opacity) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Tooltip(message: '${date.day}/${date.month}: $count', child: const SizedBox()),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // 4. CONSISTENCY LINE GRAPH
          AnimatedMetallicContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Consistency 📈',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                    ),
                    Row(
                      children: [
                        _graphOptionButton('Day', 0),
                        const SizedBox(width: 8),
                        _graphOptionButton('Week', 1),
                        const SizedBox(width: 8),
                        _graphOptionButton('Year', 2),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      data: _getGraphData(activityMap),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<double> _getGraphData(Map<DateTime, int> activityMap) {
    int count = _consistencyView == 0 ? 7 : (_consistencyView == 1 ? 8 : 6);
    List<double> data = [];
    final now = DateTime.now();

    for (int i = count - 1; i >= 0; i--) {
      double percentage = 0.0;
      if (_consistencyView == 0) { // Day
        final date = now.subtract(Duration(days: i));
        final d = DateTime(date.year, date.month, date.day);
        int done = activityMap[d] ?? 0;
        percentage = habits.isEmpty ? 0 : (done / habits.length);
      } else if (_consistencyView == 1) { // Week
         double totalPerc = 0;
         for (int d=0; d<7; d++) {
            final date = now.subtract(Duration(days: (i * 7) + d));
             final normalized = DateTime(date.year, date.month, date.day);
             int done = activityMap[normalized] ?? 0;
             if (habits.isNotEmpty) totalPerc += (done / habits.length);
         }
         percentage = totalPerc / 7;
      } else { // Year (Months)
         final date = DateTime(now.year, now.month - i, 1);
         int daysInMonth = 0;
         double totalPerc = 0;
         for (int d=0; d<31; d++) {
             final checkDate = DateTime(date.year, date.month, d+1);
             if (checkDate.month != date.month) break;
             daysInMonth++;
             final normalized = DateTime(checkDate.year, checkDate.month, checkDate.day);
             int done = activityMap[normalized] ?? 0;
             if (habits.isNotEmpty) totalPerc += (done / habits.length);
         }
         percentage = daysInMonth > 0 ? (totalPerc / daysInMonth) : 0;
      }
      if (percentage > 1.0) percentage = 1.0;
      data.add(percentage);
    }
    return data;
  }

  Widget _buildDateSelectorHeader() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    // Format: "Wed, 13 Jan"
    // Since we don't have intl package, manual helpers:
    final weekDay = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_selectedDate.weekday - 1];
    final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_selectedDate.month - 1];
    final dateString = '$weekDay, ${_selectedDate.day} $month';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The date is',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      // Customizing the DatePicker Theme to match app darker theme
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: Theme.of(context).colorScheme.primary,
                            onPrimary: Colors.white,
                            surface: Colors.grey[900]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                   decoration: BoxDecoration(
                     border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2))
                   ),
                   child: Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (!isToday) ...[
                 const SizedBox(width: 16),
                 IconButton(
                   icon: const Icon(Icons.undo, color: Colors.white70),
                   tooltip: 'Back to Today',
                   onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = DateTime.now());
                   },
                 )
              ]
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tabIndex == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                onPressed: () {
                  if (_tabIndex == 1) {
                    _showAddHabitDialog();
                  } else if (_tabIndex == 2) {
                    _showAddGoalDialog();
                  } else if (_tabIndex == 3) {
                    // Journal Tab

                    final now = DateTime.now();
                    final todayEntryIndex = journalEntries.indexWhere((e) {
                      return e.date.year == now.year &&
                          e.date.month == now.month &&
                          e.date.day == now.day;
                    });
                    if (todayEntryIndex != -1) {
                      _showEditJournalDialog(journalEntries[todayEntryIndex]);
                    } else {
                      _showAddJournalDialog();
                    }

                  }

                },
                backgroundColor: Colors.deepPurpleAccent,
                child: Icon(
                  _tabIndex == 3 ? Icons.edit : Icons.add,
                ),
              ),
            ),
      body: Stack(
        children: [
          SafeArea(
            child: Builder(
              builder: (context) {
                if (_tabIndex == 0) return _buildHomeTab();
                
                // For Habits(1), Goals(2), Journal(3) - Use Column for Sticky Header effect
                return Column(
                  children: [
                    _buildDateSelectorHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _tabIndex == 1
                            ? _buildHabitList()
                          : _tabIndex == 2
                              ? _buildGoalList()
                              : _tabIndex == 3
                                  ? _buildJournalTab()
                                  : Container(), // Placeholder or removed logic

                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // FLOATING NAV BAR
          _buildFloatingNavBar(),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedMetallicContainer(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            baseColor: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _buildNavBarItem('Home', 0),
                  const SizedBox(width: 8),
                  _buildNavBarItem('Habits', 1),
                  const SizedBox(width: 8),
                  _buildNavBarItem('Goals', 2),
                  const SizedBox(width: 8),
                  _buildNavBarItem('Journal', 3),
                  const SizedBox(width: 8),

                ],

              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildAICard() {
    return GestureDetector(
      onTap: () {
         if (!_isAiLoading) {
             HapticFeedback.mediumImpact();
             _generateInsight();
         }
      },
      child: AnimatedMetallicContainer(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "AI Coach",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Body / Animation
              if (_isAiLoading)
                const SizedBox(
                   height: 30, width: 30,
                   child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              else
                Text(
                  _aiMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const Spacer(),

              // Footer
              Text(
                _isAiLoading ? "Thinking..." : "Tap for new insight",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    
    // Smooth Curve
    for (int i = 0; i < data.length; i++) {
        double x = i * stepX;
        double y = size.height - (data[i] * size.height);
        if (i == 0) {
            path.moveTo(x, y);
        } else {
            double prevX = (i - 1) * stepX;
            double prevY = size.height - (data[i - 1] * size.height);
            double cp1x = prevX + (stepX / 2);
            double cp1y = prevY;
            double cp2x = x - (stepX / 2);
            double cp2y = y;
            path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
        }
    }

    // Shadow
    final shadowPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(shadowPath, shadowPaint);
    canvas.drawPath(path, paint);
    
    // Draw dots
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (int i = 0; i < data.length; i++) {
        double x = i * stepX;
        double y = size.height - (data[i] * size.height);
        canvas.drawCircle(Offset(x,y), 4, dotPaint);
        canvas.drawCircle(Offset(x,y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
