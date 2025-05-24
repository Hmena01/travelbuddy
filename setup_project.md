# NativeFlow Translation App Setup Guide

## Project Overview
NativeFlow is a real-time translation app built with Flutter (client) and Python (backend) using Google's Gemini AI for translation and audio processing.

## Architecture
- **Frontend**: Flutter app with SoLoud for audio playback and record for audio recording
- **Backend**: Python WebSocket server using Gemini API for real-time translation
- **Database**: Firebase Firestore for storing translation history (optional)
- **Audio**: Real-time audio streaming between client and server

## Quick Start

### 1. Backend Setup

```bash
# Navigate to backend directory
cd Backend

# Install Python dependencies
pip install -r requirements.txt

# Create environment file
cp environment_setup.md .env
# Edit .env file with your API keys (see environment_setup.md for details)
```

**Required Environment Variables:**
- `GOOGLE_API_KEY`: Get from [Google AI Studio](https://aistudio.google.com)
- `FIREBASE_SERVICE_ACCOUNT_FILE`: Firebase service account JSON file (optional)

### 2. Frontend Setup

```bash
# Navigate to client directory
cd client

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run -d chrome --web-port 8080
```

### 3. Run the Backend Server

```bash
# In a separate terminal
cd Backend/Server
python server.py
```

The server will start on `ws://localhost:9083`

## Firebase Configuration (Optional)

Firebase is used for storing translation history and user sessions. The app will work without Firebase, but you won't have persistent data.

### Setup Firebase:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project
3. Enable Firestore Database
4. Go to Project Settings > Service Accounts
5. Generate private key and save as `Backend/serviceAccountKey.json`
6. Run `flutterfire configure` in the client directory for Flutter configuration

## Features

### Core Translation Features
- Real-time voice translation using Gemini AI
- Multi-language support with native accents
- Audio streaming with automatic silence detection
- Text transcription of translated audio
- Pronunciation assistance (slow repetition)

### Technical Features
- WebSocket communication for real-time data
- PCM audio processing and WAV conversion
- SoLoud audio engine for cross-platform playback
- Firebase integration for data persistence
- Modern Flutter UI with animations

## Usage

1. **Start the backend server** (`python Backend/Server/server.py`)
2. **Launch the Flutter app** (`flutter run -d chrome`)
3. **Press the microphone button** to start recording
4. **Speak in any language** - the AI will detect and translate
5. **Listen to the translation** with native pronunciation
6. **Recording auto-stops** after 5 seconds of silence

## Supported Platforms
- Web (Chrome, Firefox, Safari)
- Android (with additional setup)
- iOS (with additional setup)
- macOS
- Windows
- Linux

## Troubleshooting

### Common Issues:

1. **WebSocket Connection Failed**
   - Ensure backend server is running on port 9083
   - Check firewall settings
   - For mobile: use correct IP address (10.0.2.2 for Android emulator)

2. **Audio Not Playing**
   - Ensure SoLoud is initialized
   - Check browser audio permissions
   - Verify audio data is received from server

3. **Microphone Permission Denied**
   - Enable microphone permissions in browser/app settings
   - Check device microphone access

4. **Firebase Errors**
   - Verify service account key file exists
   - Check Firebase project configuration
   - Ensure Firestore is enabled

5. **Compilation Errors**
   - Run `flutter clean && flutter pub get`
   - Check Flutter SDK version (requires 3.6.1+)
   - Verify all dependencies are compatible

## Development

### Adding New Languages
The system supports any language that Gemini AI can process. No additional configuration needed.

### Customizing Audio Processing
- Modify sample rates in `home_page.dart` for recording
- Adjust WAV header generation in `_generateWavHeader`
- Update server audio processing in `server.py`

### Extending Firebase Integration
- Add new collections in `save_translation_to_firebase`
- Implement user authentication in `FirebaseService`
- Create analytics and usage tracking

## API Keys and Security
- Never commit API keys to version control
- Use environment variables for all sensitive data
- Implement proper authentication for production use
- Consider rate limiting for API usage

## Performance Optimization
- Audio chunks are sent every 200ms for real-time processing
- Firebase writes are batched to minimize costs
- SoLoud provides efficient cross-platform audio playback
- WebSocket connections are managed efficiently

## Contributing
1. Fork the repository
2. Create a feature branch
3. Follow the existing code style
4. Test on multiple platforms
5. Submit a pull request

## License
MIT License - see LICENSE file for details 