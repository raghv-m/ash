const express = require('express');
const ashAgent = require('../config/openai');
const Log = require('../models/Log');

const router = express.Router();

// Middleware to verify JWT token (imported from auth.js)
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const jwt = require('jsonwebtoken');
    const User = require('../models/User');
    
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

// Main scheduling endpoint - handles natural language requests
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { text, isVoice = false } = req.body;
    const userId = req.user.userId;

    if (!text || text.trim().length === 0) {
      return res.status(400).json({ 
        error: 'Text input is required',
        message: 'Please provide a scheduling request'
      });
    }

    // Log the scheduling request
    await Log.logInteraction({
      userId,
      interactionType: 'schedule_request',
      details: {
        input: text,
        isVoice
      },
      metadata: {
        platform: 'api',
        deviceType: 'unknown'
      }
    });

    // Process the request with ASH agent
    const response = await ashAgent.processRequest(userId, text, isVoice);

    res.json({
      success: response.success,
      reply: response.reply,
      processingTime: response.processingTime,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error in schedule endpoint:', error);
    
    // Log the error
    await Log.logInteraction({
      userId: req.user?.userId,
      interactionType: 'error',
      details: {
        input: req.body.text,
        error: error.message
      },
      metadata: {
        platform: 'api'
      }
    });

    res.status(500).json({
      success: false,
      error: 'Internal server error',
      message: 'Failed to process scheduling request'
    });
  }
});

// Get scheduling suggestions based on user preferences
router.get('/suggestions', authenticateToken, async (req, res) => {
  try {
    const { date, duration = 60, attendees } = req.query;
    const userId = req.user.userId;

    if (!date) {
      return res.status(400).json({ 
        error: 'Date parameter is required',
        message: 'Please provide a date for suggestions'
      });
    }

    const targetDate = new Date(date);
    const endDate = new Date(targetDate.getTime() + 24 * 60 * 60 * 1000); // Next 24 hours

    // Get free slots for the day
    const googleService = require('../config/google');
    const freeSlots = await googleService.getFreeSlots(userId, targetDate, endDate, parseInt(duration));

    // Filter slots based on working hours
    const user = req.user;
    const workingHours = user.getWorkingHours();
    
    const suggestions = freeSlots.filter(slot => {
      const slotHour = new Date(slot.start).getHours();
      const workingStart = parseInt(workingHours.start.split(':')[0]);
      const workingEnd = parseInt(workingHours.end.split(':')[0]);
      
      return slotHour >= workingStart && slotHour < workingEnd;
    }).slice(0, 5); // Return top 5 suggestions

    res.json({
      success: true,
      suggestions: suggestions.map(slot => ({
        start: slot.start.toISOString(),
        end: slot.end.toISOString(),
        duration: Math.round((slot.end - slot.start) / (1000 * 60)),
        formatted: {
          start: slot.start.toLocaleString(),
          end: slot.end.toLocaleString()
        }
      })),
      date: targetDate.toISOString()
    });

  } catch (error) {
    console.error('Error getting suggestions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get scheduling suggestions'
    });
  }
});

// Check availability for specific time slot
router.post('/check-availability', authenticateToken, async (req, res) => {
  try {
    const { startTime, endTime, attendees } = req.body;
    const userId = req.user.userId;

    if (!startTime || !endTime) {
      return res.status(400).json({ 
        error: 'Start time and end time are required'
      });
    }

    const start = new Date(startTime);
    const end = new Date(endTime);

    // Check if the time slot is available
    const googleService = require('../config/google');
    const freeSlots = await googleService.getFreeSlots(userId, start, end, 1);

    const isAvailable = freeSlots.some(slot => 
      new Date(slot.start) <= start && new Date(slot.end) >= end
    );

    res.json({
      success: true,
      available: isAvailable,
      startTime: start.toISOString(),
      endTime: end.toISOString(),
      message: isAvailable ? 'Time slot is available' : 'Time slot is not available'
    });

  } catch (error) {
    console.error('Error checking availability:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check availability'
    });
  }
});

// Parse natural language time expressions
router.post('/parse-time', authenticateToken, async (req, res) => {
  try {
    const { text, referenceDate } = req.body;
    const userId = req.user.userId;

    if (!text) {
      return res.status(400).json({ 
        error: 'Text input is required'
      });
    }

    // Use ASH agent to parse the time expression
    const parsePrompt = `Parse this time expression and return the exact date and time in ISO format: "${text}". 
    Reference date: ${referenceDate || new Date().toISOString()}. 
    Return only the parsed time in ISO format, no other text.`;

    const response = await ashAgent.processRequest(userId, parsePrompt, false);

    // Try to extract ISO date from the response
    const isoDateRegex = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?/;
    const match = response.reply.match(isoDateRegex);
    
    if (match) {
      const parsedDate = new Date(match[0]);
      res.json({
        success: true,
        originalText: text,
        parsedTime: parsedDate.toISOString(),
        formatted: parsedDate.toLocaleString()
      });
    } else {
      res.status(400).json({
        success: false,
        error: 'Could not parse time expression',
        originalText: text
      });
    }

  } catch (error) {
    console.error('Error parsing time:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to parse time expression'
    });
  }
});

// Get user's working hours and preferences
router.get('/preferences', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    res.json({
      success: true,
      preferences: {
        timeZone: user.timeZone,
        workingHours: user.preferences.workingHours,
        workingDays: user.preferences.workingDays,
        reminderMinutes: user.preferences.reminderMinutes,
        voiceEnabled: user.preferences.voiceEnabled,
        ttsProvider: user.preferences.ttsProvider
      }
    });
  } catch (error) {
    console.error('Error getting preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get user preferences'
    });
  }
});

// Update scheduling preferences
router.put('/preferences', authenticateToken, async (req, res) => {
  try {
    const { workingHours, workingDays, reminderMinutes, timeZone } = req.body;
    const user = req.user;

    if (workingHours) {
      user.preferences.workingHours = { ...user.preferences.workingHours, ...workingHours };
    }

    if (workingDays) {
      user.preferences.workingDays = workingDays;
    }

    if (reminderMinutes) {
      user.preferences.reminderMinutes = reminderMinutes;
    }

    if (timeZone) {
      user.timeZone = timeZone;
    }

    await user.save();

    res.json({
      success: true,
      message: 'Preferences updated successfully',
      preferences: {
        timeZone: user.timeZone,
        workingHours: user.preferences.workingHours,
        workingDays: user.preferences.workingDays,
        reminderMinutes: user.preferences.reminderMinutes
      }
    });
  } catch (error) {
    console.error('Error updating preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update preferences'
    });
  }
});

module.exports = router;


