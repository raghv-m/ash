# ASH Deployment Guide

This guide provides detailed instructions for deploying ASH (AI Scheduling Helper) to production environments.

## 📋 Prerequisites

Before deploying, ensure you have:
- Node.js 18+ installed
- Flutter SDK 3.10+ installed
- MongoDB Atlas account
- Google Cloud Console project
- OpenAI API account
- Vercel account (for backend)
- Firebase account (for frontend)

## 🏗️ Backend Deployment (Vercel)

### 1. Prepare Backend for Production

1. **Update environment variables**
   ```bash
   cd ash_backend
   cp env.example .env.production
   ```

2. **Update production configuration**
   ```env
   NODE_ENV=production
   PORT=3000
   OPENAI_API_KEY=your_production_openai_key
   GOOGLE_CLIENT_ID=your_production_google_client_id
   GOOGLE_CLIENT_SECRET=your_production_google_client_secret
   GOOGLE_REDIRECT_URI=https://your-backend-domain.vercel.app/auth/google/callback
   MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/ash_scheduler
   JWT_SECRET=your_secure_jwt_secret
   FRONTEND_URL=https://your-frontend-domain.web.app
   ```

### 2. Deploy to Vercel

1. **Install Vercel CLI**
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel**
   ```bash
   vercel login
   ```

3. **Initialize project**
   ```bash
   cd ash_backend
   vercel
   ```

4. **Configure environment variables**
   ```bash
   vercel env add OPENAI_API_KEY
   vercel env add GOOGLE_CLIENT_ID
   vercel env add GOOGLE_CLIENT_SECRET
   vercel env add MONGO_URI
   vercel env add JWT_SECRET
   vercel env add FRONTEND_URL
   ```

5. **Deploy**
   ```bash
   vercel --prod
   ```

### 3. Configure Custom Domain (Optional)

1. Go to Vercel dashboard
2. Select your project
3. Go to Settings > Domains
4. Add your custom domain
5. Configure DNS records

## 🎨 Frontend Deployment (Firebase Hosting)

### 1. Prepare Frontend for Production

1. **Update configuration**
   ```dart
   // lib/core/config/app_config.dart
   static const String baseUrl = 'https://your-backend-domain.vercel.app';
   static const String googleClientId = 'your_production_google_client_id';
   ```

2. **Build for web**
   ```bash
   cd ash_app
   flutter build web --release
   ```

### 2. Deploy to Firebase

1. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize Firebase project**
   ```bash
   cd ash_app
   firebase init hosting
   ```

4. **Configure firebase.json**
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ]
     }
   }
   ```

5. **Deploy**
   ```bash
   firebase deploy
   ```

### 3. Configure Custom Domain

1. Go to Firebase Console
2. Select your project
3. Go to Hosting
4. Add custom domain
5. Configure DNS records

## 🗄️ Database Setup (MongoDB Atlas)

### 1. Create MongoDB Atlas Cluster

1. Go to [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Create a new cluster
3. Choose your preferred cloud provider and region
4. Select cluster tier (M0 for free tier)

### 2. Configure Database Access

1. Go to Database Access
2. Add new database user
3. Set username and password
4. Grant read/write permissions

### 3. Configure Network Access

1. Go to Network Access
2. Add IP address (0.0.0.0/0 for all IPs in production)
3. Or add specific IP addresses

### 4. Get Connection String

1. Go to Clusters
2. Click "Connect"
3. Choose "Connect your application"
4. Copy connection string
5. Replace `<password>` with your database user password

## 🔐 Google Cloud Configuration

### 1. Update OAuth2 Settings

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to APIs & Services > Credentials
4. Edit your OAuth2 Client ID
5. Add authorized redirect URIs:
   - `https://your-backend-domain.vercel.app/auth/google/callback`
6. Add authorized JavaScript origins:
   - `https://your-frontend-domain.web.app`

### 2. Configure API Quotas

1. Go to APIs & Services > Quotas
2. Set appropriate quotas for:
   - Google Calendar API
   - Gmail API
3. Monitor usage in production

## 🔧 Environment Variables Summary

### Backend (Vercel)
```env
NODE_ENV=production
OPENAI_API_KEY=sk-...
GOOGLE_CLIENT_ID=your-client-id.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=https://your-backend.vercel.app/auth/google/callback
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/ash_scheduler
JWT_SECRET=your-secure-random-string
FRONTEND_URL=https://your-frontend.web.app
```

### Frontend (Firebase)
```dart
static const String baseUrl = 'https://your-backend.vercel.app';
static const String googleClientId = 'your-client-id.googleusercontent.com';
```

## 📊 Monitoring & Analytics

### 1. Backend Monitoring

1. **Vercel Analytics**
   - Built-in performance monitoring
   - Error tracking
   - Function execution metrics

2. **Custom Logging**
   - Request/response logging
   - Error tracking
   - User interaction logs

### 2. Frontend Monitoring

1. **Firebase Analytics**
   - User engagement metrics
   - App performance
   - Crash reporting

2. **Custom Analytics**
   - User interaction tracking
   - Feature usage statistics

## 🔒 Security Checklist

### Backend Security
- [ ] Environment variables properly configured
- [ ] JWT secrets are secure and random
- [ ] CORS configured for production domains
- [ ] Rate limiting enabled
- [ ] Input validation implemented
- [ ] Error messages don't expose sensitive data

### Frontend Security
- [ ] HTTPS enabled
- [ ] Content Security Policy configured
- [ ] API keys not exposed in client code
- [ ] Secure authentication flow

### Database Security
- [ ] Database user has minimal required permissions
- [ ] Network access restricted to necessary IPs
- [ ] Regular backups configured
- [ ] Encryption at rest enabled

## 🚀 CI/CD Pipeline

### 1. GitHub Actions (Optional)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy ASH

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
          working-directory: ./ash_backend

  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
      - name: Install dependencies
        run: cd ash_app && flutter pub get
      - name: Build web
        run: cd ash_app && flutter build web
      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: your-firebase-project-id
```

## 📱 Mobile App Deployment

### 1. Android (Google Play Store)

1. **Build APK/AAB**
   ```bash
   cd ash_app
   flutter build appbundle --release
   ```

2. **Upload to Google Play Console**
   - Create developer account
   - Upload AAB file
   - Configure store listing
   - Submit for review

### 2. iOS (App Store)

1. **Build iOS app**
   ```bash
   cd ash_app
   flutter build ios --release
   ```

2. **Upload to App Store Connect**
   - Create developer account
   - Upload IPA file
   - Configure app information
   - Submit for review

## 🔄 Updates & Maintenance

### 1. Backend Updates

1. **Update code**
   ```bash
   cd ash_backend
   git pull origin main
   ```

2. **Redeploy**
   ```bash
   vercel --prod
   ```

### 2. Frontend Updates

1. **Update code**
   ```bash
   cd ash_app
   git pull origin main
   flutter pub get
   ```

2. **Rebuild and deploy**
   ```bash
   flutter build web --release
   firebase deploy
   ```

## 🆘 Troubleshooting

### Common Issues

1. **CORS Errors**
   - Check FRONTEND_URL in backend environment
   - Verify domain configuration

2. **Authentication Issues**
   - Verify Google OAuth2 configuration
   - Check redirect URIs

3. **Database Connection**
   - Verify MongoDB connection string
   - Check network access settings

4. **API Rate Limits**
   - Monitor API usage
   - Implement proper error handling

### Support

For deployment issues:
- Check Vercel/Firebase logs
- Review environment variables
- Verify API configurations
- Contact support teams

## 📈 Performance Optimization

### Backend
- Enable Vercel Edge Functions
- Implement caching strategies
- Optimize database queries
- Use CDN for static assets

### Frontend
- Enable Firebase Hosting caching
- Optimize Flutter web build
- Implement lazy loading
- Use service workers

---

**Happy Deploying! 🚀**

