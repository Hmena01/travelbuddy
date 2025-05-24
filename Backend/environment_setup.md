# Backend Environment Setup

Create a `.env` file in the Backend directory with the following variables:

```bash
# Google API Configuration
GOOGLE_API_KEY=your_google_api_key_here

# Firebase Configuration
# Option 1: Use service account key file
FIREBASE_SERVICE_ACCOUNT_FILE=serviceAccountKey.json

# Option 2: Use service account key as JSON string (for cloud deployment)
# FIREBASE_SERVICE_ACCOUNT_KEY={"type": "service_account", "project_id": "your-project-id", ...}

# Server Configuration
PORT=9083
HOST=0.0.0.0
```

## Setup Instructions

1. **Get Google API Key:**
   - Go to Google AI Studio (aistudio.google.com)
   - Create an API key for Gemini API
   - Add it to your `.env` file

2. **Firebase Setup:**
   - Go to Firebase Console (console.firebase.google.com)
   - Create a new project or use existing one
   - Enable Firestore Database
   - Go to Project Settings > Service Accounts
   - Generate a new private key (downloads JSON file)
   - Save as `serviceAccountKey.json` in Backend directory

3. **Install Dependencies:**
   ```bash
   cd Backend
   pip install -r requirements.txt
   ```

4. **Run Server:**
   ```bash
   cd Backend/Server
   python server.py
   ``` 