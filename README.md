# Smart Inventory & Billing App

**Smart Inventory** is a high-performance, **offline-first** retail management tool built with **Flutter** and **SQLite**. It is designed for small to medium businesses that require a fast, reliable, and secure way to manage stock and process sales without relying on an active internet connection.

---

## Features

* **Local Inventory Management:** High-speed stock tracking using a local `sqflite` database for zero-latency performance.
* **Smart Billing System:** * Dynamic "New Sale" module with interactive item counters.
    * Real-time total price calculation and cart management.
* **Data Integrity & Guardrails:**
    * **Stock Validation:** Prevents sales that exceed available inventory.
    * **SQL Constraints:** Database-level `CHECK` constraints to ensure stock never goes negative.
* **Professional UI/UX:**
    * Modern **Material 3** design with custom theming.
    * **Adaptive Icons** for a native look and feel on Android.
    * Interactive SnackBars with floating behavior to keep the UI accessible.
* **Secure Access:** Integrated with **Firebase Auth** and **Google Sign-In** for authorized user access.

---

## Technical Stack

* **Frontend:** [Flutter](https://flutter.dev) (Dart)
* **Database:** [sqflite](https://pub.dev/packages/sqflite) (SQLite)
* **Authentication:** Firebase Auth & Google Sign-In
* **Design:** Material 3 with adaptive icon support.

---

##  Installation & Setup

### Prerequisites
* Flutter SDK installed.
* A Firebase project (for Authentication features).

### Steps
1.  **Clone the repo:**
    ```bash
    git clone https://github.com/Mega-Gangar/Smart-Inventory.git
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Configure Android Signing:**
    * Add your **SHA-1** fingerprint to your Firebase Console.
    * Place your `google-services.json` in `android/app/`.
4.  **Generate Icon Assets:**
    ```bash
    flutter pub run flutter_launcher_icons
    ```
5.  **Run the app:**
    ```bash
    flutter run
    ```

---

## Database Schema

The app uses a relational SQLite structure:
* **Products Table:** Stores `id`, `name`, `price`, `cost`, and `stock`.
* **Sales Table:** Stores transaction history, including timestamps and total amounts.
* **Integrity:** Uses `stock >= 0` constraints to maintain accurate inventory levels.
---

## Screenshots
- **Login/Registration**

<img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_1.jpg" width=300 alt="login page"/>  <img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_2.jpg" width=300 alt="registration page"/>

- **Inventory Screen**

<img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_3.jpg" width=300 alt="inventory page1"/>  <img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_4.jpg" width=300 alt="inventory page2"/>

- **Billing Page**

<img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_5.jpg" width=300 alt="billing page"/>

- **Sales/Profit Screen**

<img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_6.jpg" width=300 alt="sales page"/>  <img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_7.jpg" width=300 alt="profit page"/>

- **Print Layout**

<img src="https://github.com/Mega-Gangar/Smart-Inventory/blob/main/screenshots/photo_8.jpg" width=300 alt="print layout"/>
