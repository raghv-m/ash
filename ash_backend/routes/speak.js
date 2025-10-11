const express = require('express');
const OpenAI = require('openai');
const Log = require('../models/Log');

const router = express.Router();

// Middleware to verify JWT token
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

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Text-to-Speech endpoint
router.post('/tts', authenticateToken, async (req, res) => {
  try {
    const { text, voice = 'alloy', format = 'mp3' } = req.body;
    const userId = req.user.userId;

    if (!text || text.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Text is required for speech synthesis'
      });
    }

    // Validate voice parameter
    const validVoices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
    if (!validVoices.includes(voice)) {
      return res.status(400).json({
        success: false,
        error: `Invalid voice. Must be one of: ${validVoices.join(', ')}`
      });
    }

    // Validate format parameter
    const validFormats = ['mp3', 'opus', 'aac', 'flac'];
    if (!validFormats.includes(format)) {
      return res.status(400).json({
        success: false,
        error: `Invalid format. Must be one of: ${validFormats.join(', ')}`
      });
    }

    // Log the TTS request
    await Log.logInteraction({
      userId,
      interactionType: 'voice_response',
      details: {
        input: text,
        voice,
        format,
        textLength: text.length,
        processingTime: 0
      },
      metadata: {
        platform: 'api'
      }
    });

    // Generate speech using OpenAI TTS
    const response = await openai.audio.speech.create({
      model: 'tts-1',
      voice: voice,
      input: text,
      response_format: format,
      speed: 1.0
    });

    // Convert the response to base64 for JSON transmission
    const audioBuffer = Buffer.from(await response.arrayBuffer());
    const audioBase64 = audioBuffer.toString('base64');

    // Log successful TTS generation
    await Log.logInteraction({
      userId,
      interactionType: 'voice_response',
      details: {
        input: text,
        voice,
        format,
        textLength: text.length,
        audioSize: audioBuffer.length,
        processingTime: Date.now() - Date.now() // This would be calculated properly in real implementation
      },
      metadata: {
        platform: 'api'
      }
    });

    res.json({
      success: true,
      audio: audioBase64,
      format: format,
      voice: voice,
      textLength: text.length,
      audioSize: audioBuffer.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error generating speech:', error);
    
    // Log the error
    await Log.logInteraction({
      userId: req.user?.userId,
      interactionType: 'error',
      details: {
        error: error.message,
        input: req.body.text
      },
      metadata: {
        platform: 'api'
      }
    });

    res.status(500).json({
      success: false,
      error: 'Failed to generate speech',
      message: error.message
    });
  }
});

// Get available voices
router.get('/voices', authenticateToken, async (req, res) => {
  try {
    const voices = [
      {
        id: 'alloy',
        name: 'Alloy',
        description: 'A balanced, neutral voice',
        gender: 'neutral',
        language: 'en-US'
      },
      {
        id: 'echo',
        name: 'Echo',
        description: 'A clear, confident voice',
        gender: 'male',
        language: 'en-US'
      },
      {
        id: 'fable',
        name: 'Fable',
        description: 'A warm, storytelling voice',
        gender: 'male',
        language: 'en-US'
      },
      {
        id: 'onyx',
        name: 'Onyx',
        description: 'A deep, authoritative voice',
        gender: 'male',
        language: 'en-US'
      },
      {
        id: 'nova',
        name: 'Nova',
        description: 'A bright, energetic voice',
        gender: 'female',
        language: 'en-US'
      },
      {
        id: 'shimmer',
        name: 'Shimmer',
        description: 'A soft, gentle voice',
        gender: 'female',
        language: 'en-US'
      }
    ];

    res.json({
      success: true,
      voices: voices,
      defaultVoice: 'alloy',
      supportedFormats: ['mp3', 'opus', 'aac', 'flac']
    });
  } catch (error) {
    console.error('Error getting voices:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get available voices'
    });
  }
});

// Get user's preferred voice settings
router.get('/preferences', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    res.json({
      success: true,
      preferences: {
        voiceEnabled: user.preferences.voiceEnabled,
        ttsProvider: user.preferences.ttsProvider,
        defaultVoice: 'alloy', // Could be stored in user preferences
        defaultFormat: 'mp3'
      }
    });
  } catch (error) {
    console.error('Error getting voice preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get voice preferences'
    });
  }
});

// Update voice preferences
router.put('/preferences', authenticateToken, async (req, res) => {
  try {
    const { voiceEnabled, ttsProvider, defaultVoice } = req.body;
    const user = req.user;

    if (voiceEnabled !== undefined) {
      user.preferences.voiceEnabled = voiceEnabled;
    }

    if (ttsProvider && ['openai', 'google'].includes(ttsProvider)) {
      user.preferences.ttsProvider = ttsProvider;
    }

    // TODO: Store defaultVoice in user preferences if needed
    // if (defaultVoice) {
    //   user.preferences.defaultVoice = defaultVoice;
    // }

    await user.save();

    res.json({
      success: true,
      message: 'Voice preferences updated successfully',
      preferences: {
        voiceEnabled: user.preferences.voiceEnabled,
        ttsProvider: user.preferences.ttsProvider
      }
    });
  } catch (error) {
    console.error('Error updating voice preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update voice preferences'
    });
  }
});

// Test TTS endpoint
router.post('/test', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const testText = "Hello! I'm ASH, your AI scheduling assistant. How can I help you today?";
    
    // Generate test speech
    const response = await openai.audio.speech.create({
      model: 'tts-1',
      voice: 'alloy',
      input: testText,
      response_format: 'mp3',
      speed: 1.0
    });

    const audioBuffer = Buffer.from(await response.arrayBuffer());
    const audioBase64 = audioBuffer.toString('base64');

    // Log the test
    await Log.logInteraction({
      userId,
      interactionType: 'voice_response',
      details: {
        input: testText,
        voice: 'alloy',
        format: 'mp3',
        textLength: testText.length,
        audioSize: audioBuffer.length,
        processingTime: 0
      },
      metadata: {
        platform: 'api'
      }
    });

    res.json({
      success: true,
      message: 'TTS test successful',
      audio: audioBase64,
      format: 'mp3',
      voice: 'alloy',
      text: testText,
      audioSize: audioBuffer.length
    });
  } catch (error) {
    console.error('Error testing TTS:', error);
    res.status(500).json({
      success: false,
      error: 'TTS test failed',
      message: error.message
    });
  }
});

// Batch TTS endpoint for multiple texts
router.post('/batch', authenticateToken, async (req, res) => {
  try {
    const { texts, voice = 'alloy', format = 'mp3' } = req.body;
    const userId = req.user.userId;

    if (!texts || !Array.isArray(texts) || texts.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Texts array is required'
      });
    }

    if (texts.length > 10) {
      return res.status(400).json({
        success: false,
        error: 'Maximum 10 texts allowed per batch request'
      });
    }

    const results = [];

    for (const text of texts) {
      try {
        const response = await openai.audio.speech.create({
          model: 'tts-1',
          voice: voice,
          input: text,
          response_format: format,
          speed: 1.0
        });

        const audioBuffer = Buffer.from(await response.arrayBuffer());
        const audioBase64 = audioBuffer.toString('base64');

        results.push({
          success: true,
          text: text,
          audio: audioBase64,
          audioSize: audioBuffer.length
        });
      } catch (error) {
        results.push({
          success: false,
          text: text,
          error: error.message
        });
      }
    }

    // Log the batch request
    await Log.logInteraction({
      userId,
      interactionType: 'voice_response',
      details: {
        input: `Batch TTS request for ${texts.length} texts`,
        voice,
        format,
        totalTexts: texts.length,
        successfulTexts: results.filter(r => r.success).length,
        processingTime: 0
      },
      metadata: {
        platform: 'api'
      }
    });

    res.json({
      success: true,
      results: results,
      totalTexts: texts.length,
      successfulTexts: results.filter(r => r.success).length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error in batch TTS:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process batch TTS request'
    });
  }
});

module.exports = router;

