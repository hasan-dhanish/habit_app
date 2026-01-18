class JournalEntry {
  String id;
  String content;
  DateTime date;

  JournalEntry({
    required this.id,
    required this.content,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'date': date.toIso8601String(),
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      content: json['content'],
      date: DateTime.parse(json['date']),
    );
  }
}
