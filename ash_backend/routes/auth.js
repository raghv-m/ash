const express = require('express');
const jwt = require('jsonwebtoken');
const { google } = require('googleapis');
const User = require('../models/User');
const Log = require('../models/Log');
const googleService = require('../config/google');

const router = express.Router();

// Middleware to verify JWT token
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findOne({ userId: decoded.userId });
    
    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'Invalid or inactive user' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  });
};

// Google OAuth2 login
router.get('/google', (req, res) => {
  try {
    const authUrl = googleService.getAuthUrl();
    res.json({ authUrl });
  } catch (error) {
    console.error('Error generating auth URL:', error);
    res.status(500).json({ error: 'Failed to generate authentication URL' });
  }
});

// Google OAuth2 callback
router.get('/google/callback', async (req, res) => {
  try {
    const { code, state: userId } = req.query;

    if (!code) {
      return res.status(400).json({ error: 'Authorization code not provided' });
    }

    // Exchange code for tokens
    const tokens = await googleService.getTokens(code);
    
    // Get user info from Google
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
    
    oauth2Client.setCredentials(tokens);
    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const userInfo = await oauth2.userinfo.get();

    const { id, email, name, picture } = userInfo.data;

    // Find or create user
    let user = await User.findOne({ userId: id });
    
    if (user) {
      // Update existing user
      user.email = email;
      user.name = name;
      user.picture = picture;
      user.lastLogin = new Date();
      await user.updateGoogleTokens(tokens);
    } else {
      // Create new user
      user = new User({
        userId: id,
        email,
        name,
        picture,
        googleTokens: {
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token,
          expiryDate: new Date(Date.now() + tokens.expires_in * 1000)
        },
        timeZone: 'UTC' // Default timezone, can be updated later
      });
      await user.save();
    }

    // Generate JWT token
    const token = generateToken(user.userId);

    // Log the authentication
    await Log.logInteraction({
      userId: user.userId,
      interactionType: 'authentication',
      details: {
        method: 'google_oauth',
        success: true
      },
      metadata: {
        platform: 'web'
      }
    });

    // Redirect to frontend with token
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3001';
    res.redirect(`${frontendUrl}/auth/callback?token=${token}&userId=${user.userId}`);

  } catch (error) {
    console.error('Error in OAuth callback:', error);
    
    // Log the error
    if (req.query.state) {
      await Log.logInteraction({
        userId: req.query.state,
        interactionType: 'authentication',
        details: {
          method: 'google_oauth',
          success: false,
          error: error.message
        },
        metadata: {
          platform: 'web'
        }
      });
    }

    res.status(500).json({ error: 'Authentication failed' });
  }
});

// Get current user profile
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    res.json({
      userId: user.userId,
      email: user.email,
      name: user.name,
      picture: user.picture,
      timeZone: user.timeZone,
      preferences: user.preferences,
      hasValidGoogleTokens: user.hasValidGoogleTokens(),
      lastLogin: user.lastLogin,
      createdAt: user.createdAt
    });
  } catch (error) {
    console.error('Error getting user profile:', error);
    res.status(500).json({ error: 'Failed to get user profile' });
  }
});

// Update user preferences
router.put('/preferences', authenticateToken, async (req, res) => {
  try {
    const { timeZone, preferences } = req.body;
    const user = req.user;

    if (timeZone) {
      user.timeZone = timeZone;
    }

    if (preferences) {
      user.preferences = { ...user.preferences, ...preferences };
    }

    await user.save();

    res.json({
      message: 'Preferences updated successfully',
      preferences: user.preferences,
      timeZone: user.timeZone
    });
  } catch (error) {
    console.error('Error updating preferences:', error);
    res.status(500).json({ error: 'Failed to update preferences' });
  }
});

// Refresh Google tokens
router.post('/refresh-tokens', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    if (!user.googleTokens.refreshToken) {
      return res.status(400).json({ error: 'No refresh token available' });
    }

    const newAccessToken = await googleService.refreshTokensIfNeeded(user.userId);
    
    res.json({
      message: 'Tokens refreshed successfully',
      hasValidTokens: user.hasValidGoogleTokens()
    });
  } catch (error) {
    console.error('Error refreshing tokens:', error);
    res.status(500).json({ error: 'Failed to refresh tokens' });
  }
});

// Logout (invalidate token on client side)
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    // Log the logout
    await Log.logInteraction({
      userId: req.user.userId,
      interactionType: 'authentication',
      details: {
        method: 'logout',
        success: true
      },
      metadata: {
        platform: 'api'
      }
    });

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    console.error('Error during logout:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// Verify token endpoint
router.get('/verify', authenticateToken, (req, res) => {
  res.json({
    valid: true,
    user: {
      userId: req.user.userId,
      email: req.user.email,
      name: req.user.name
    }
  });
});

module.exports = router;


