# NativeFlow

A real-time translation app built with **pure Flutter** and Python backend using Google's Gemini AI for translation and audio processing.

## 🚀 **Pure Flutter UI - No JavaScript!**

This app uses **100% Flutter/Dart** for the frontend with:
- **SoLoud** for cross-platform audio playback
- **record** package for audio recording  
- **Native Flutter widgets** for all UI components
- **WebSocket** communication with Python backend

## Project Structure

- `client/` - Pure Flutter application 
- `Backend/` - Python WebSocket server with Gemini AI integration
- `Backend/Server/server.py` - Main translation server
- `setup_project.md` - Comprehensive setup guide

## Features

- 🎯 **Real-time voice translation** using Gemini AI
- 🌍 **Multi-language support** with native accent pronunciation
- 🎵 **High-quality audio** with SoLoud cross-platform audio engine
- 📱 **Pure Flutter UI** - works on Web, Android, iOS, Desktop
- 🔥 **Firebase integration** for translation history (optional)
- ⚡ **WebSocket streaming** for real-time communication
- 🎨 **Beautiful animations** with flutter_animate

## Quick Start

### 1. Backend Setup
```bash
cd Backend
pip install -r requirements.txt
# Add your GOOGLE_API_KEY to .env file
cd Server
python server.py
```

### 2. Flutter App
```bash
cd client
flutter pub get
flutter run -d chrome --web-port 8080
```

**Note:** Run `flutter run` from the `client` directory, not the root!

## How It Works

1. **Press the microphone button** to start recording
2. **Speak in any language** - Gemini AI detects and translates  
3. **Listen to the translation** with native pronunciation
4. **Recording auto-stops** after 5 seconds of silence

## Technical Architecture

- **Frontend**: Flutter with SoLoud for audio, WebSocket for communication
- **Backend**: Python with Gemini API for translation, Firebase for data
- **Audio**: PCM recording → WebSocket → Gemini → Audio response → SoLoud playback
- **UI**: Pure Flutter widgets with Material Design 3

## Platform Support
- ✅ Web (Chrome, Firefox, Safari)
- ✅ Android  
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ✅ Linux

## Environment Setup

**Required:**
- `GOOGLE_API_KEY` (from [Google AI Studio](https://aistudio.google.com))

**Optional:**
- Firebase service account for translation history

See `Backend/environment_setup.md` for detailed setup instructions.

## No JavaScript Required!

Unlike other implementations, this uses **pure Flutter** for all UI and audio processing:
- ❌ No JavaScript audio worklets
- ❌ No HTML5 audio APIs
- ❌ No browser-specific audio code
- ✅ Flutter SoLoud for consistent audio across all platforms
- ✅ Native Dart WebSocket communication
- ✅ Material Design widgets for beautiful UI

## Development

The app is structured as a modern Flutter application:
- `lib/main.dart` - App initialization with Firebase
- `lib/home_page.dart` - Main translation interface  
- `lib/services/` - Firebase and other services
- `Backend/Server/server.py` - Translation server with Gemini AI

## Contributing

1. Fork the repository
2. Create your feature branch 
3. Test on multiple platforms
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
