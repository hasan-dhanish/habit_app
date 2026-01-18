# 🦅 Habit App

A minimalist, privacy-focused habit tracker built with Flutter. Designed to help you build consistency through streaks, journaling, and local AI insights.

## ✨ Features

### 📅 Habit Tracking
- **Daily Habits**: Create and track daily habits with a simple checkbox interface.
- **Streaks**: Visualize your consistency with flame streaks 🔥.
- **Heatmap**: See your yearly progress at a glance (GitHub-style contributions graph).

### 🎯 Goals
- **Deadline Tracking**: Set long-term goals with specific deadlines.
- **Countdowns**: The app automatically calculates days remaining and warns you if "Crunch Time" is approaching. 🚨

### ✍️ Daily Journal
- **Mood Tracking**: Log your thoughts and feelings.
- **Sentiment Analysis**: The offline AI coach analyzes your entries to provide tailored encouragement (e.g., suggesting rest if you mention burnout).

### 🤖 Offline AI Coach
- **Zero Privacy Risk**: Runs 100% locally on your device. No data is sent to the cloud.
- **Smart Insights**: Analyzes your streaks, missed habits, and deadlines to give you a specific "Tip of the Day" every time you check in.
- **Context Aware**: Knows if it's morning ("Eat the frog!") or late night ("Time to sleep?").

### 🎨 Design
- **Dark Mode**: Sleek, battery-saving dark interface.
- **OLED Friendly**: Deep blacks `(0xFF000000)` and vibrant accent colors.
- **Red Theme**: Default "Nothing" styling for minimal distraction.

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: `setState` (kept simple for MVP)
- **Local Storage**: `SharedPreferences` (Data persistence)
- **Architecture**: Widget-based component architecture

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed
- Android Studio / VS Code

### Installation
1. Clone the repository
   ```bash
   git clone https://github.com/hasan-dhanish/habit_app.git
   ```
2. Install dependencies
   ```bash
   flutter pub get
   ```
3. Run the app
   ```bash
   flutter run
   ```

## 📱 Build an APK
To generate a release APK for Android:
```bash
flutter build apk --release
```
The file will be found at `build/app/outputs/flutter-apk/app-release.apk`.

## 🔒 Privacy
Your data never leaves your phone. All habits, journals, and goals are stored locally using `SharedPreferences`.

---
*Built with ❤️ by Hasan*
