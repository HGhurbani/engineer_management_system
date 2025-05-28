# Engineer Management System

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge">
</p>

A comprehensive, multi-platform Engineer Management System built with Flutter and Firebase. This application provides a seamless, role-based experience for administrators, engineers, and clients to manage engineering projects from inception to completion.

The system is designed with a clean, modern UI and is structured to be scalable and maintainable. It supports three distinct user roles, each with a tailored interface and feature set.

---

## ✨ Key Features

The application is divided into three main portals based on user roles: Admin, Engineer, and Client.

### 👨‍💼 Admin Panel
The admin has full control over the entire system with a powerful and intuitive dashboard.

* **📊 Analytics Dashboard**: Get a quick overview of system statistics, including the total number of engineers, clients, and active projects.
* **👤 User Management**: Full CRUD (Create, Read, Update, Delete) functionality for managing engineers, clients, and general employees.
* **🏗️ Project Management**: Create new projects, assign them to engineers and clients, and delete projects along with all their associated data.
* **📋 Phase & Sub-Phase Control**: Dive deep into project details to add, edit, and delete main phases and sub-phases, giving granular control over the project timeline.
* **🕒 Attendance Tracking**: Monitor engineer attendance in real-time. View daily summaries of working hours, overtime, and payments calculated based on system settings.
* **📍 Location & Signature Verification**: View detailed attendance records, including the exact geolocation of check-ins/outs on Google Maps and the engineer's digital signature for verification.
* **⚙️ System Settings**: Configure application-wide settings such as default working hours and engineer hourly rates to streamline payroll calculations.
* **🔔 Notifications**: Receive real-time notifications for important events, like when an engineer completes a project phase.

### 👷 Engineer Portal
The engineer's portal is designed for on-the-go project management and reporting.

* **📱 Mobile-First Dashboard**: A dedicated dashboard to view all assigned projects.
* **✅ Phase Updates**: Update the status of project phases, add detailed notes, and mark phases as complete.
* **📸 Image & 360° Photo Upload**: Capture and upload images and 360° photos directly from the field to document progress for each phase.
* **⏰ Smart Attendance**: A simple, signature-based check-in and check-out system that captures geolocation for accurate time and location tracking.
* **📤 Report Sharing**: Generate and share detailed phase reports with stakeholders via text, WhatsApp, or email.
* **🔔 Real-time Alerts**: Receive notifications for new project assignments or updates.

### 🏢 Client Portal
The client portal offers a transparent window into project progress.

* **🔐 Secure Access**: Clients can log in to view the status and progress of their specific projects.
* **🔍 Progress Tracking**: Track the project timeline by viewing all completed main phases and sub-phases.
* **📄 Review & Verify**: Review detailed notes and view all images uploaded by the engineer for each completed stage, ensuring full transparency.
* **🔔 Project Updates**: Receive notifications when new phases of their project are completed.

---

## 🚀 Tech Stack & Architecture

This project is built with a modern, scalable tech stack.

* **Framework**: [Flutter](https://flutter.dev/)
* **Backend**: [Firebase](https://firebase.google.com/)
    * **Authentication**: For secure, role-based user login and registration.
    * **Firestore Database**: As the primary NoSQL database for storing all application data.
    * **Cloud Storage**: Used as a dependency for file management.
* **State Management**: [Provider](https://pub.dev/packages/provider)
* **Geolocation**: [Geolocator](https://pub.dev/packages/geolocator) for tracking engineer locations.
* **Mapping**: [Google Maps Flutter](https://pub.dev/packages/Maps_flutter) for displaying attendance locations.
* **Image Handling**:
    * [Image Picker](https://pub.dev/packages/image_picker) for accessing the device camera and gallery.
    * A custom PHP backend for handling image uploads.
* **Digital Signatures**: [Signature](https://pub.dev/packages/signature) for capturing signatures during attendance checks.
* **Localization & Formatting**: [Intl](https://pub.dev/packages/intl) for date and time formatting, with support for Arabic locale.
* **UI**: Material 3 with the 'Tajawal' font for a clean, modern interface with Arabic language support.

---

## 🛠️ Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites
* Flutter SDK: Make sure you have the Flutter SDK installed. For instructions, see the [official Flutter documentation](https://flutter.dev/docs/get-started/install).
* A Firebase project.

### Installation

1.  **Clone the repository:**
    ```sh
    git clone [https://github.com/hghurbani/engineer_management_system.git](https://github.com/hghurbani/engineer_management_system.git)
    cd engineer_management_system
    ```

2.  **Set up Firebase:**
    * Create a new project on the [Firebase Console](https://console.firebase.google.com/).
    * Add an Android and/or iOS app to your Firebase project.
    * Download the `google-services.json` file for Android and place it in the `android/app/` directory.
    * For iOS, download the `GoogleService-Info.plist` file and add it to your project in Xcode.

3.  **Set up the Image Upload Server:**
    * The application is configured to upload images to a PHP server. You must either set up your own server at the URL specified in `lib/pages/admin/admin_project_details_page.dart` or modify the image upload logic to use a different service (like Firebase Storage).
    * The current endpoint is: `https://creditphoneqatar.com/eng-app/upload_image.php`.

4.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

5.  **Run the application:**
    ```sh
    flutter run
    ```

---

## 📂 Project Structure

The project code is organized into a clean and maintainable structure, primarily within the `lib` directory.

lib/
├── main.dart                 # App entry point, theme, and routes
└── pages/
├── admin/                # Contains all pages for the Admin role
│   ├── admin_attendance_page.dart
│   ├── admin_clients_page.dart
│   ├── admin_dashboard.dart
│   ├── admin_employees_page.dart
│   ├── admin_engineers_page.dart
│   ├── admin_project_details_page.dart
│   ├── admin_projects_page.dart
│   └── admin_settings_page.dart
├── auth/                 # Authentication pages
│   └── login_page.dart
├── client/               # Pages for the Client role
│   └── client_home.dart
├── engineer/             # Pages for the Engineer role
│   ├── engineer_home.dart
│   └── project_details_page.dart
└── notifications_page.dart   # Common notifications page


---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
