# ASH - AI Scheduling Helper

ASH is a comprehensive full-stack AI assistant with a sleek, modern UI that helps you schedule meetings, manage your calendar, and stay organized through natural language interactions and enhanced voice commands.

## 🚀 Features

### Core Functionality
- **AI-Powered Scheduling**: Advanced natural language processing with OpenAI GPT-4
- **Enhanced Voice Commands**: Real-time speech-to-text with OpenAI Whisper and TTS
- **Streaming Responses**: Low-latency real-time communication
- **Calendar Integration**: Seamless Google Calendar and Gmail API integration
- **Smart Reminders**: Automated meeting reminders and notifications
- **Cross-Platform**: Flutter app for mobile and web with responsive design

### Sleek UI & UX
- **Modern Material 3 Design**: Clean, minimalist interface with smooth animations
- **Voice-First Interface**: Tap-to-speak with glowing animations and real-time feedback
- **Gradient Aesthetics**: Beautiful blue-to-teal gradients and subtle shadows
- **Responsive Design**: Optimized for mobile, tablet, and desktop
- **Dark/Light Mode**: Automatic theme switching with user preferences

### ASH Personality
- Polite, professional, and slightly futuristic tone
- Intelligent intent recognition and natural language understanding
- Proactive scheduling suggestions and conflict resolution
- Context-aware conversations with chat history

## 🏗️ Architecture

### Backend (Node.js)
- **Express.js** server with RESTful API
- **OpenAI GPT-4** for natural language processing
- **Google Calendar & Gmail APIs** for calendar management
- **MongoDB** with Mongoose for data persistence
- **WebSocket** support for real-time voice interactions
- **JWT** authentication with Google OAuth2

### Frontend (Flutter)
- **Cross-platform** mobile and web app
- **Riverpod** state management
- **Material Design 3** UI components
- **Voice integration** with speech-to-text and text-to-speech
- **Google Sign-In** authentication

## 📁 Project Structure

```
ash/
├── ash_backend/                 # Node.js backend
│   ├── config/                  # Configuration files
│   │   ├── database.js         # MongoDB connection
│   │   ├── google.js           # Google APIs integration
│   │   └── openai.js           # ASH AI agent
│   ├── models/                  # Mongoose schemas
│   │   ├── User.js             # User model
│   │   ├── Event.js            # Event model
│   │   └── Log.js              # Interaction logs
│   ├── routes/                  # API routes
│   │   ├── auth.js             # Authentication
│   │   ├── schedule.js         # Scheduling endpoints
│   │   ├── events.js           # Event management
│   │   ├── voice.js            # Voice interactions
│   │   └── speak.js            # Text-to-speech
│   ├── services/                # Business logic
│   │   └── reminderService.js  # Automated reminders
│   ├── package.json
│   └── server.js               # Main server file
├── ash_app/                     # Flutter frontend
│   ├── lib/
│   │   ├── core/               # Core functionality
│   │   │   ├── config/         # App configuration
│   │   │   ├── models/         # Data models
│   │   │   ├── providers/      # State management
│   │   │   ├── routing/        # Navigation
│   │   │   ├── services/       # API services
│   │   │   └── theme/          # UI theming
│   │   ├── screens/            # App screens
│   │   │   ├── auth/           # Authentication
│   │   │   ├── home/           # Home dashboard
│   │   │   ├── chat/           # Chat interface
│   │   │   ├── calendar/       # Calendar view
│   │   │   └── settings/       # User settings
│   │   ├── widgets/            # Reusable components
│   │   └── main.dart           # App entry point
│   └── pubspec.yaml
└── README.md
```

## 🛠️ Quick Setup

### Prerequisites
- Node.js 18+ and npm
- Flutter SDK 3.10+
- MongoDB Atlas account
- Google Cloud Console project
- OpenAI API key

### 🚀 Quick Start

1. **Clone and setup backend**
   ```bash
   git clone <repository-url>
   cd ash/ash_backend
   npm install
   cp env.example .env
   # Edit .env with your API keys (see SETUP_GUIDE.md)
   npm run dev
   ```

2. **Setup Flutter app**
   ```bash
   cd ash_app
   flutter pub get
   # Update app_config.dart with your credentials
   flutter run
   ```

### 📖 Detailed Setup

For complete setup instructions including API configuration, see [SETUP_GUIDE.md](SETUP_GUIDE.md) which covers:
- MongoDB Atlas configuration
- OpenAI API setup
- Google Cloud OAuth2 setup
- Environment variables
- Testing and troubleshooting

## 🔧 Google Cloud Setup

### 1. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - Google Calendar API
   - Gmail API
   - Google+ API

### 2. Configure OAuth2
1. Go to "Credentials" in the Google Cloud Console
2. Create OAuth2 Client ID
3. Add authorized redirect URIs:
   - `http://localhost:3000/auth/google/callback` (development)
   - `https://yourdomain.com/auth/google/callback` (production)

### 3. Get API Credentials
- Copy Client ID and Client Secret to your `.env` file
- Update Flutter app configuration with Client ID

## 🚀 Deployment

### Backend Deployment (Vercel)

1. **Install Vercel CLI**
   ```bash
   npm install -g vercel
   ```

2. **Deploy**
   ```bash
   cd ash_backend
   vercel
   ```

3. **Environment Variables**
   Set environment variables in Vercel dashboard:
   - `OPENAI_API_KEY`
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `MONGO_URI`
   - `JWT_SECRET`

### Frontend Deployment (Firebase Hosting)

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Build for web**
   ```bash
   cd ash_app
   flutter build web
   ```

3. **Deploy**
   ```bash
   firebase init hosting
   firebase deploy
   ```

### Database (MongoDB Atlas)

1. Create MongoDB Atlas account
2. Create a new cluster
3. Get connection string
4. Update `MONGO_URI` in environment variables

## 📱 Usage

### Getting Started
1. **Sign in** with your Google account
2. **Grant permissions** for Calendar and Gmail access
3. **Start chatting** with ASH using text or voice

### Voice Commands (Enhanced)
- **Tap the microphone** icon to start voice input
- **Speak naturally**: "Schedule a meeting with John tomorrow at 2 PM"
- **Real-time feedback**: See transcription and get voice responses
- **Context awareness**: ASH remembers your conversation

### Text Commands
- **Natural language**: "Book a meeting with Emma next week, avoid mornings"
- **Calendar queries**: "What's on my calendar today?"
- **Meeting management**: "Reschedule my 3 PM meeting to 4 PM"
- **Smart suggestions**: ASH will suggest optimal times

### UI Features
- **Sleek chat interface** with gradient message bubbles
- **Voice button** with glowing animation when listening
- **Typing indicators** for real-time feedback
- **Error handling** with user-friendly messages
- **Dark/Light mode** toggle in settings

## 🔌 API Endpoints

### Authentication
- `GET /auth/google` - Google OAuth2 login
- `GET /auth/google/callback` - OAuth2 callback
- `GET /auth/profile` - Get user profile
- `POST /auth/logout` - Sign out

### Scheduling
- `POST /schedule` - Process scheduling requests
- `GET /schedule/suggestions` - Get time suggestions
- `POST /schedule/check-availability` - Check availability

### Events
- `GET /events` - Get user events
- `GET /events/upcoming` - Get upcoming events
- `POST /events/:id/reschedule` - Reschedule event
- `DELETE /events/:id` - Cancel event

### Voice (Enhanced)
- `POST /voice/process` - Process voice input with streaming
- `GET /voice/status` - Get voice settings
- `GET /voice/history` - Get chat history
- `POST /voice/session` - Create new chat session
- `WebSocket /voice/ws` - Real-time voice chat

### Speech
- `POST /speak/tts` - Text-to-speech with OpenAI
- `GET /speak/voices` - Available voices
- `POST /speak/test` - Test TTS
- `POST /speak/batch` - Batch TTS processing

## 🧪 Testing

### Backend Tests
```bash
cd ash_backend
npm test
```

### Frontend Tests
```bash
cd ash_app
flutter test
```

## 🔒 Security

- JWT token authentication
- Google OAuth2 integration
- Rate limiting on API endpoints
- Input validation and sanitization
- CORS configuration
- Environment variable protection

## 📊 Monitoring

- Request logging with timestamps
- Error tracking and reporting
- User interaction analytics
- Performance monitoring
- Health check endpoints

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Contact the development team

## 🗺️ Roadmap

### Phase 1 (Current)
- ✅ Basic scheduling functionality
- ✅ Google Calendar integration
- ✅ Voice commands
- ✅ Mobile and web apps

### Phase 2 (Future)
- 🔄 Smart recommendation engine with user preference learning
- 🔄 WhatsApp/Slack integration for notifications
- 🔄 Recurring meeting management
- 🔄 Multilingual support (English, Hindi, Punjabi)
- 🔄 Advanced AI features with custom models
- 🔄 Team collaboration tools
- 🔄 Voice cloning for personalized ASH responses
- 🔄 Advanced calendar analytics and insights

## 🙏 Acknowledgments

- OpenAI for GPT-4 API
- Google for Calendar and Gmail APIs
- Flutter team for the amazing framework
- The open-source community

---

**ASH - Your AI Scheduling Helper** 🤖📅

