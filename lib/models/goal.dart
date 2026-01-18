class Goal {
  String name;
  DateTime deadline;
  bool isCompleted;

  Goal({
    required this.name,
    required this.deadline,
    this.isCompleted = false,
  });
}
