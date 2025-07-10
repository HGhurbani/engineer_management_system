# Engineer Management System

A comprehensive system for managing projects, engineers, clients, and employees, designed to streamline administrative and field operations in contracting and engineering companies. The system allows tracking project progress, managing attendance, recording meeting minutes, and monitoring engineer performance, in addition to providing custom dashboards for each role (Admin, Engineer, Client).

## Key Features

* **User and Role Management**:
    * Multi-role login system (Admin, Engineer, Client).
    * Manage engineers, clients, and employees from the Admin dashboard.
    * Add, edit, and delete user data.
    * Change user passwords.
* **Project Management**:
    * Create and track projects, assigning engineers and clients to them.
    * Track main and sub-project phases with the ability to add notes and photos.
    * Record and update the status of final commissioning tests.
    * View customized project dashboards for Admins, Engineers, and Clients.
* **Attendance System**:
    * Record engineer and employee check-in and check-out using geolocation and digital signature.
    * View daily attendance reports for the Admin with details on overtime hours and due payments.
    * Set default working hours and hourly rates from the Admin dashboard.
* **Daily Schedules and Tasks**:
    * Manage daily scheduled tasks for engineers.
    * View engineer's daily tasks and update their status (pending, in-progress, completed).
* **Meeting Logs Management**:
    * Record meeting minutes with clients and employees.
    * Attach photos and details to each meeting log.
    * Export meeting logs to PDF files.
* **Material Requests**:
    * System for engineers to request materials for projects.
    * Track the status of material requests (pending, approved, rejected, ordered, received).
* **Notifications System**:
    * Instant notifications for project updates, material requests, and attendance statuses.
    * Browse notifications, mark as read, and delete them.
* **Performance Evaluation**:
    * Evaluation system for engineers based on criteria such as working hours, completed tasks, and activity rate.
    * Set different weights for evaluation criteria by the Admin.
    * Enable automatic monthly and yearly evaluations.
* **Attachments and Important Notes Management**:
    * Add important notes and attachments to projects.
* **Holiday Settings**:
    * Define weekly and official holidays (including programmed Saudi official holidays).
* **PDF Support**:
    * Generate and export detailed PDF reports for projects, attendance records, and meeting minutes.
    * Images in generated reports are fetched and resized up to 1024px to handle large photos without running out of memory.

## Technologies Used

* **Flutter**: A UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
* **Firebase**:
    * **Firestore**: A cloud-hosted NoSQL database for data storage and organization.
    * **Authentication**: For managing user authentication.
    * **Storage**: For storing images and attachments.
    * **Cloud Functions (Recommended)**: (Not available in this repo but recommended for secure backend logic and managing Firebase Auth users programmatically).
* **`geolocator`**: For obtaining geolocation data.
* **`signature`**: For capturing digital signatures.
* **`image_picker` / `file_picker`**: For picking images and files.
* **`http`**: For making HTTP requests (e.g., uploading images to an external PHP server).
* **`url_launcher`**: For launching URLs.
* **`share_plus`**: For sharing files and data.
* **`Maps_flutter`**: For displaying maps (in the map view page).
* **`pdf` / `printing`**: For creating and exporting PDF documents.
* **`intl`**: For date and time formatting.
* **`fl_chart`**: For displaying charts (in the evaluation page).
* **`table_calendar`**: For displaying calendars (in the daily schedule page).

## Project Structure

The project is organized into several main directories:

* `android/`: Android project configuration files.
* `ios/`: iOS project configuration files.
* `lib/`:
    * `main.dart`: The main entry point of the application, Firebase initialization, and route definitions.
    * `firebase_options.dart`: Platform-specific Firebase configurations.
    * `models/`: Data model definitions (e.g., `EvaluationSettings`, `Holiday`, `EngineerEvaluation`).
    * `pages/`: Contains user interface pages, organized by roles (admin/, engineer/, client/) and common pages (common/).
        * `admin/`: Admin dashboard pages.
        * `engineer/`: Engineer dashboard pages.
        * `client/`: Client dashboard pages.
        * `auth/`: Authentication pages (login).
        * `common/`: Common pages (e.g., change password, notifications).
    * `theme/`: Defines design constants and colors (`AppConstants`).
    * `utils/`: Helper functions (e.g., PDF styling, Saudi holidays).
* `assets/`: Contains fonts (`fonts/`) and images (`images/`).
* `pubspec.yaml`: Project and dependency definitions.
* `web/`: Web application configuration files (including Google Maps API and Firebase JS SDK setup).
* `.gitignore`: Specifies files and folders to be ignored by Git.
* `CMakeLists.txt`: Build configuration files for Linux and Windows platforms.

## Getting Started

To set up and run the project locally, follow these steps:

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.6.0 or newer).
* [Firebase CLI](https://firebase.google.com/docs/cli).
* An active Firebase account with a project created.

### Setup

1.  **Clone the Repository**:
    ```bash
    git clone [Your Repo URL]
    cd engineer_management_system
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    * Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
    * Enable Firestore Database, Authentication (Email/Password), and Cloud Storage services.
    * **For Android**:
        * Add an Android app to your Firebase project.
        * Download the `google-services.json` file and place it in `android/app/`.
        * Ensure location permissions are added in `android/app/src/main/AndroidManifest.xml`:
            ```xml
            <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
            <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
            ```
    * **For iOS**:
        * Add an iOS app to your Firebase project.
        * Follow Firebase instructions to add `GoogleService-Info.plist` to your Xcode project.
    * **For Web**:
        * Add a Web app to your Firebase project.
        * Create a `web/firebase-config.js` file containing your project's `firebaseConfig` object and ensure `web/index.html` includes this script. The keys should match the values in `lib/firebase_options.dart`.
    * **For All Platforms**: Run the following command to generate the `firebase_options.dart` file:
        ```bash
        flutterfire configure
        ```
        You may need to manually adjust `lib/firebase_options.dart` to perfectly match some `appId` and `apiKey` values for Android/iOS after auto-configuration. The current file indicates that `apiKey` and `appId` have been manually modified for Android.

4.  **Image Upload Server Setup (Optional)**:
    * The project uses an external PHP server for image uploads. You need to set up a simple PHP server that receives `POST` requests for files and returns the URL of the uploaded image.
    * The server URL is defined in `lib/theme/app_constants.dart` as `AppConstants.uploadUrl`.
    * If you do not use a PHP server, you will need to modify the image upload logic in `project_details_page.dart`, `meeting_logs_page.dart`, and `admin_meeting_logs_page.dart` to directly upload images to Firebase Storage.

5.  **Add Fonts**:
    * Ensure that the `assets/fonts/` folder exists in your project root, and that the font files (e.g., `Tajawal-Regular.ttf`) are inside it.
    * Make sure the fonts are defined in `pubspec.yaml` under the `flutter/fonts` section.

### Running the Application

1.  **Run the App**:
    ```bash
    flutter run
    ```
    Or to run the web application:
    ```bash
    flutter run -d chrome --web-renderer html
    ```
    (Using `--web-renderer html` by default ensures better compatibility for Google Maps and some other web features).

### Test Login Credentials (Can be changed after first registration)

You can use the following test login credentials or create new users through the UI:

* **For Admin**:
    * Email: `z@z.com`
    * Password: `12345678`
* **For Engineer**:
    * Email: `eng@eng.com`
    * Password: `12345678`
* **For Client**:
    * Email: `cus@cus.com`
    * Password: `12345678`

    *Note: If these accounts do not exist, the application will create them automatically upon first login attempt using these credentials, assigning them the appropriate role.*

## Screenshots

* [Add screenshots here to showcase the main UI interfaces (Dashboard, Projects, Attendance, etc.)]

## Contributing

We welcome contributions! If you'd like to improve this project, please follow these steps:

1.  Fork the repository.
2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).
3.  Make your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

This project is licensed under the MIT License. (Or any other license you choose).

---

[**Google Maps API Key**: `AIzaSyALwjTWZOafa0RhBLcOgrgHHuzQWk5_fwQ`]
[**Firebase Web Config**: `AIzaSyDX_fhBTQmwm-KP8Qu2gfwFQylGuaEm4VA`]
[**Firebase Android App ID**: `1:526461382833:android:5a049565fbb06e9330f290`]
[**Firebase Android API Key**: `AIzaSyDRvznjDBdA83VNWzmbC2VbU-0UGuYyRCk`]
[**Project ID**: `eng-system`]
[**Storage Bucket**: `eng-system.firebasestorage.app`]
