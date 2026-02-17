# SubSplit

**SubSplit** is a premium Flutter application designed to make managing shared subscriptions effortless. Whether it's Netflix, Spotify, or a custom service, SubSplit helps you track costs, split bills among friends, and monitor payment statuses—all in a beautiful, glassmorphic interface.

## ✨ Features

- **Manage Subscriptions:** Add and organize all your shared subscriptions in one place.
- **Fair Cost Splitting:** automatically calculates the per-person share based on the total cost and number of members.
- **Payment Tracking:**
    - Track who has paid and who hasn't for the current billing period.
    - "Close Period" feature to archive payments and start a fresh month.
    - Prevents closing a period if there are unpaid members.
- **Currency Support:** Seamlessly toggle between **USD ($)** and **NIO (C$)** for each subscription.
- **Premium UI:**
    - Dark-themed, glassmorphic design language.
    - Smooth animations and micro-interactions.
    - Custom animated toast notifications.
- **Offline First:** Built with **Drift** for robust local data persistence.

## 🛠️ Tech Stack

- **Framework:** Flutter
- **State Management:** Riverpod
- **Database:** Drift (SQLite)
- **Architecture:** Clean Architecture (Domain, Data, Presentation layers)
- **Functional Programming:** Dartz (Either<Failure, Success>)
- **Code Generation:** Freezed, JSON Serializable

## 🚀 Getting Started

1.  **Prerequisites:**
    - Flutter SDK installed
    - Dart SDK installed

2.  **Installation:**

    ```bash
    # Clone the repository
    git clone https://github.com/yourusername/subsplit.git

    # Navigate to the project directory
    cd subsplit

    # Install dependencies
    flutter pub get

    # Run code generation
    dart run build_runner build --delete-conflicting-outputs
    ```

3.  **Run the App:**

    ```bash
    flutter run
    ```
