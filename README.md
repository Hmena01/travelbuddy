# NativeFlow

A cross-platform application built with Flutter with Firebase integration.

## Project Structure

- `lib/` - Contains the main Flutter application code
- `Backend/` - Backend server implementation
- `Flutter UI/` - Flutter UI components and screens
- `linux/` - Linux platform-specific code

## Features

- Real-time chat interface with Gemini AI
- Web-based audio/video streaming
- Firebase Authentication
- Cloud Firestore for chat history
- Firebase Storage for media files
- Cross-platform support (Web, Android, iOS, Desktop)

## Getting Started

### Prerequisites

1. Flutter SDK (3.6.1 or higher)
2. Firebase CLI
3. A Firebase project

### Setup

1. Clone this repository
2. Navigate to the Flutter UI directory:
   ```bash
   cd "Flutter UI"
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

### Firebase Configuration

1. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase for your project:
   ```bash
   flutterfire configure
   ```

3. This will generate the `firebase_options.dart` file with your Firebase configuration.

4. Enable the following Firebase services in your Firebase Console:
   - Authentication (Anonymous and Email/Password)
   - Cloud Firestore
   - Firebase Storage
   - Firebase Analytics (optional)
   - Firebase Crashlytics (optional)

### Running the Application

1. For web:
   ```bash
   flutter run -d chrome
   ```

2. For mobile:
   ```bash
   flutter run
   ```

## Firebase Features

### Authentication
- Anonymous sign-in for quick access
- Email/password authentication
- User session management

### Data Storage
- Chat messages stored in Firestore
- User profiles and preferences
- Media files in Firebase Storage

### Real-time Features
- Live chat synchronization
- User presence tracking
- Message delivery status

## Dependencies

See `pubspec.yaml` for a complete list of dependencies.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 