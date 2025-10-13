# ASH Setup Guide - Complete API Configuration

This comprehensive guide will walk you through setting up all the required APIs and services for ASH (AI Scheduling Helper).

## 📋 Prerequisites

Before starting, ensure you have:
- Node.js 18+ installed
- Flutter SDK 3.10+ installed
- A code editor (VS Code recommended)
- Git installed

## 🗄️ Step 1: MongoDB Atlas Setup

### 1.1 Create MongoDB Atlas Account

1. Go to [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Click "Try Free" to create a new account
3. Sign up with your email or Google account
4. Verify your email address

### 1.2 Create a New Cluster

1. **Choose Cloud Provider & Region**
   - Select your preferred cloud provider (AWS, Google Cloud, or Azure)
   - Choose a region close to your users for better performance
   - For free tier, select the closest available region

2. **Select Cluster Tier**
   - Choose "M0 Sandbox" (Free tier) for development
   - For production, consider M2 or higher

3. **Configure Cluster**
   - Cluster Name: `ash-cluster` (or your preferred name)
   - Click "Create Cluster"

### 1.3 Configure Database Access

1. **Create Database User**
   - Go to "Database Access" in the left sidebar
   - Click "Add New Database User"
   - Choose "Password" authentication
   - Username: `ash-user` (or your preferred username)
   - Password: Generate a secure password (save this!)
   - Database User Privileges: "Read and write to any database"
   - Click "Add User"

2. **Network Access**
   - Go to "Network Access" in the left sidebar
   - Click "Add IP Address"
   - For development: Click "Allow Access from Anywhere" (0.0.0.0/0)
   - For production: Add specific IP addresses
   - Click "Confirm"

### 1.4 Get Connection String

1. **Connect to Cluster**
   - Go to "Clusters" in the left sidebar
   - Click "Connect" on your cluster
   - Choose "Connect your application"
   - Driver: Node.js
   - Version: 4.1 or later

2. **Copy Connection String**
   ```
   mongodb+srv://ash-user:<password>@ash-cluster.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```
   - Replace `<password>` with your actual password
   - Replace `ash-cluster.xxxxx` with your actual cluster name

3. **Update Backend Configuration**
   ```bash
   cd ash_backend
   cp env.example .env
   ```
   
   Edit `.env` file:
   ```env
   MONGO_URI=mongodb+srv://ash-user:your_password@ash-cluster.xxxxx.mongodb.net/ash_scheduler?retryWrites=true&w=majority
   ```

## 🔑 Step 2: OpenAI API Setup

### 2.1 Create OpenAI Account

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Click "Sign Up" to create an account
3. Verify your email address
4. Complete phone verification

### 2.2 Add Payment Method

1. **Billing Setup**
   - Go to "Billing" in the left sidebar
   - Click "Add payment method"
   - Add a credit card (required for API access)
   - Set usage limits to control costs

2. **Usage Limits**
   - Set a monthly limit (e.g., $10-20 for development)
   - Monitor usage regularly

### 2.3 Create API Key

1. **Generate API Key**
   - Go to "API Keys" in the left sidebar
   - Click "Create new secret key"
   - Name: `ASH-Backend-Key`
   - Copy the key immediately (you won't see it again!)

2. **Update Backend Configuration**
   ```env
   OPENAI_API_KEY=sk-your-actual-api-key-here
   ```

### 2.4 Test API Access

```bash
cd ash_backend
npm install
node -e "
const OpenAI = require('openai');
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
openai.models.list().then(console.log).catch(console.error);
"
```

## 🔐 Step 3: Google Cloud Setup

### 3.1 Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Project Name: `ASH-Scheduling-Helper`
4. Organization: (leave default if you have one)
5. Location: (leave default)
6. Click "Create"

### 3.2 Enable Required APIs

1. **Google Calendar API**
   - Go to "APIs & Services" → "Library"
   - Search for "Google Calendar API"
   - Click on it and press "Enable"

2. **Gmail API**
   - Search for "Gmail API"
   - Click on it and press "Enable"

3. **Google+ API** (for user info)
   - Search for "Google+ API"
   - Click on it and press "Enable"

### 3.3 Configure OAuth Consent Screen

1. **OAuth Consent Screen**
   - Go to "APIs & Services" → "OAuth consent screen"
   - Choose "External" (unless you have Google Workspace)
   - Click "Create"

2. **App Information**
   - App Name: `ASH - AI Scheduling Helper`
   - User Support Email: Your email
   - Developer Contact Information: Your email
   - Click "Save and Continue"

3. **Scopes**
   - Click "Add or Remove Scopes"
   - Add these scopes:
     - `../auth/userinfo.email`
     - `../auth/userinfo.profile`
     - `../auth/calendar`
     - `../auth/gmail.send`
   - Click "Update" → "Save and Continue"

4. **Test Users** (for development)
   - Add your email address
   - Add any test user emails
   - Click "Save and Continue"

### 3.4 Create OAuth2 Credentials

1. **Create Credentials**
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth 2.0 Client IDs"

2. **Application Type**
   - Application Type: "Web application"
   - Name: `ASH Web Client`

3. **Authorized Redirect URIs**
   - Add these URIs:
     ```
     http://localhost:3000/auth/google/callback
     https://your-backend-domain.vercel.app/auth/google/callback
     ```

4. **Get Credentials**
   - Click "Create"
   - Copy the Client ID and Client Secret

### 3.5 Update Backend Configuration

```env
GOOGLE_CLIENT_ID=your-client-id.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/auth/google/callback
```

### 3.6 Update Flutter Configuration

Edit `ash_app/lib/core/config/app_config.dart`:
```dart
static const String googleClientId = 'your-client-id.googleusercontent.com';
```

## 🚀 Step 4: Backend Setup

### 4.1 Install Dependencies

```bash
cd ash_backend
npm install
```

### 4.2 Environment Configuration

Create `.env` file with all your credentials:
```env
# Server Configuration
PORT=3000
NODE_ENV=development

# OpenAI Configuration
OPENAI_API_KEY=sk-your-openai-api-key

# Google OAuth2 Configuration
GOOGLE_CLIENT_ID=your-google-client-id.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/auth/google/callback

# MongoDB Configuration
MONGO_URI=mongodb+srv://ash-user:your-password@ash-cluster.xxxxx.mongodb.net/ash_scheduler?retryWrites=true&w=majority

# JWT Configuration
JWT_SECRET=your-super-secure-jwt-secret-key-here
JWT_EXPIRES_IN=7d

# Frontend URL (for CORS)
FRONTEND_URL=http://localhost:3001

# Voice Configuration
VOICE_ENABLED=true
TTS_PROVIDER=openai
```

### 4.3 Test Backend

```bash
npm run dev
```

Visit `http://localhost:3000/health` - you should see:
```json
{
  "status": "OK",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "service": "ASH Backend",
  "version": "1.0.0"
}
```

## 📱 Step 5: Flutter Setup

### 5.1 Install Dependencies

```bash
cd ash_app
flutter pub get
```

### 5.2 Update Configuration

Edit `lib/core/config/app_config.dart`:
```dart
class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000'; // Change for production
  static const String googleClientId = 'your-google-client-id.googleusercontent.com';
  
  // WebSocket Configuration
  static const String wsUrl = 'ws://localhost:3000/voice/ws';
}
```

### 5.3 Test Flutter App

```bash
# For mobile
flutter run

# For web
flutter run -d chrome
```

## 🔧 Step 6: Testing the Integration

### 6.1 Test Google Sign-In

1. Run the Flutter app
2. Click "Continue with Google"
3. Complete OAuth flow
4. Verify you're signed in

### 6.2 Test Voice Features

1. In the chat interface, tap the microphone icon
2. Say: "Schedule a meeting with John tomorrow at 2 PM"
3. Verify transcription and response

### 6.3 Test Calendar Integration

1. Ask ASH: "What's on my calendar today?"
2. Try: "Schedule a meeting with Sarah next Friday at 3 PM"
3. Check your Google Calendar for the new event

## 🚨 Troubleshooting

### Common Issues

1. **MongoDB Connection Failed**
   - Check your connection string
   - Verify network access settings
   - Ensure your IP is whitelisted

2. **Google OAuth Error**
   - Verify redirect URIs match exactly
   - Check OAuth consent screen configuration
   - Ensure APIs are enabled

3. **OpenAI API Error**
   - Verify API key is correct
   - Check billing and usage limits
   - Ensure you have sufficient credits

4. **Voice Not Working**
   - Check microphone permissions
   - Verify speech-to-text is initialized
   - Test with simple phrases first

### Debug Commands

```bash
# Test MongoDB connection
node -e "
const mongoose = require('mongoose');
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB error:', err));
"

# Test OpenAI API
node -e "
const OpenAI = require('openai');
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
openai.chat.completions.create({
  model: 'gpt-4',
  messages: [{ role: 'user', content: 'Hello' }]
}).then(res => console.log(res.choices[0].message.content));
"

# Test Google APIs
node -e "
const { google } = require('googleapis');
const oauth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI
);
console.log('Google OAuth2 client created successfully');
"
```

## 🔒 Security Best Practices

### 1. Environment Variables
- Never commit `.env` files to version control
- Use different credentials for development and production
- Rotate API keys regularly

### 2. Database Security
- Use strong passwords for database users
- Limit network access to necessary IPs only
- Enable MongoDB Atlas security features

### 3. API Security
- Set usage limits on OpenAI API
- Monitor API usage regularly
- Use HTTPS in production

### 4. OAuth Security
- Keep client secrets secure
- Use proper redirect URIs
- Implement proper token refresh logic

## 📊 Monitoring & Maintenance

### 1. API Usage Monitoring
- Set up alerts for high usage
- Monitor costs regularly
- Implement rate limiting

### 2. Database Monitoring
- Monitor connection counts
- Set up backup schedules
- Monitor query performance

### 3. Error Tracking
- Implement proper logging
- Set up error alerts
- Monitor user feedback

## 🆘 Support Resources

- **MongoDB Atlas**: [Documentation](https://docs.atlas.mongodb.com/)
- **OpenAI API**: [Documentation](https://platform.openai.com/docs)
- **Google Cloud**: [Documentation](https://cloud.google.com/docs)
- **Flutter**: [Documentation](https://flutter.dev/docs)

## 📞 Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review the error logs in your console
3. Verify all API keys and configurations
4. Test each service individually
5. Check the official documentation for each service

---

**Happy Coding! 🚀**

Your ASH AI Scheduling Helper should now be fully configured and ready to use!

