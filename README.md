# Fitness App (iOS)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue.svg?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![SwiftData](https://img.shields.io/badge/Storage-SwiftData-purple.svg?style=flat-square)](https://developer.apple.com/xcode/swiftdata/)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20Modular-green.svg?style=flat-square)]()
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](LICENSE)

A modern, offline-first iOS fitness and strength tracking app built natively with **SwiftUI** and **SwiftData**. Designed with clean domain architecture, progressive overload tracking, studio equipment isolation, and smart gym companion utilities.

---

## ✨ Features

### 🏋️‍♂️ Smart Workout Tracking & Plans
- **Routine Builder**: Create structured workout routines (e.g. *Push*, *Pull*, *Legs*) with target sets, rep ranges, and rest periods.
- **Auto-Prefill from History**: Starting an exercise automatically pre-fills weights and reps based on your last completed session for seamless progressive overload.
- **Active Workout HUD**: Live set logger, set reordering, inline decimal weight input, and completion summary modal (duration, total volume, completed sets).
- **Free Workouts**: Jump straight into a workout without a pre-set routine.

### ⏱️ Rest Timer & Haptics
- **Background Rest Countdown**: Observable countdown between sets with live lock-screen local notifications (`UserNotifications`).
- **Quick Adjustments**: On-the-fly $+30\,\text{s}$ and $-15\,\text{s}$ interval adjustments right from the active workout screen.

### 🏢 Studio & Gym Management
- **Studio-Bound Machines**: Weight stacks differ across gym brands and models; the app binds custom machines to specific gyms to ensure accurate history comparisons.
- **Locker Tracker**: Never forget your locker number—set your locker with instant verification and automatic 12-hour expiration.
- **MapKit Transit Finder**: Instant search for nearby public transit stops (bus, U-Bahn, S-Bahn) and estimated walking distances from your studio.

### 📄 Membership & Contract Deadlines
- **Statutory German Contract Engine**: Calculates exact cancellation deadlines according to statutory rolling renewal rules.
- **Automated Deadline Reminders**: Local calendar notifications alert you before your cancellation deadline so contracts don't roll over unintentionally.

### 📊 Exercise Catalog & Analytics
- **Visual Category Grid**: Shortcuts-style category tiles with SF Symbols and tactile spring animations.
- **Equipment Filtering**: Group exercises by barbell, dumbbell, machine, cable, or bodyweight.
- **Progression Analytics**: 1RM calculation using the Epley formula ($1\text{RM} = w \cdot (1 + r/30)$) and historical workout performance logs.

---

## 🛠️ Architecture & Tech Stack

```
Fitness App/
├── Models/                 # SwiftData Schema & Domain Models
│   ├── Gym.swift           # Studio entity with location, contract & locker
│   ├── Exercise.swift      # Exercise catalog & equipment associations
│   ├── WorkoutPlan.swift   # Routine templates & target set entries
│   ├── WorkoutSession.swift# Live/completed sessions, exercises & sets
│   ├── OpeningHours.swift  # Timezone-safe Monday-based opening status
│   └── MembershipContract.swift # Rolling renewals & notice calculations
├── Services/               # Core Business Logic & Infrastructure
│   ├── WorkoutStats.swift  # 1RM Epley calculations, volume, history lookup
│   ├── WorkoutFactory.swift# Session creation & history-based prefilling
│   ├── RestTimer.swift     # Observable countdown & notification triggers
│   ├── StudioMaps.swift    # MapKit public transport search
│   └── ContractReminder.swift # UNCalendarNotificationTrigger scheduler
├── Views/                  # Declarative SwiftUI UI Layer
│   ├── ActiveWorkout/      # Live workout tracker & rest timer HUD
│   ├── Training/           # Routine list and plan editor
│   ├── Exercises/          # Category grid, picker & detail analytics
│   ├── Studio/             # "Mein Studio" dashboard, transit & contracts
│   ├── History/            # Monthly grouped workout logs
│   ├── Gyms/               # Studio switcher & equipment manager
│   └── Components/         # Reusable decimal/integer number fields
├── Data/                   # Seed & Fixture Data
│   ├── SeedData.swift      # Default German exercise catalog & initial gym
│   └── PreviewData.swift   # In-memory ModelContainer for SwiftUI Previews
└── Tools/
    └── make_icon.swift     # CoreGraphics app icon generation script
```

- **UI**: SwiftUI (iOS 17 navigation APIs, modern `TabView`, custom button styles).
- **Persistence**: SwiftData (`ModelContainer`, `@Model`, `@Query`, `#Predicate`, cascaded relationships).
- **Concurrency & Observation**: Swift 6 concurrency, `@Observable`, async/await.
- **Testing**: Swift Testing framework (`@Test`, `#expect`).
- **Localization**: German (`de`) primary locale with German workout terminology and comma-separated decimal formatting (`82,5 kg`).

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma (14.0+) or later
- Xcode 15.4 or Xcode 16.0+
- iOS 17.0+ deployment target

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/iMepst/fitness-app-ios.git
   cd fitness-app-ios
   ```
2. Open the Xcode project:
   ```bash
   open "Fitness App.xcodeproj"
   ```
3. Select an iOS Simulator (e.g. iPhone 16) or physical device and press **Cmd + R** to run.

---

## 🧪 Running Tests

The test suite covers pure domain logic (1RM calculations, prefilling logic, session completion, contract calculations, and locker expiration):

```bash
xcodebuild test -project "Fitness App.xcodeproj" -scheme "Fitness App" -destination "platform=iOS Simulator,name=iPhone 16"
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
