const express = require('express');
const WebSocket = require('ws');
const ashAgent = require('../config/openai');
const Log = require('../models/Log');
const Chat = require('../models/Chat');
const { v4: uuidv4 } = require('uuid');

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

// WebSocket server for real-time voice interaction
let wss;

const initializeWebSocket = (server) => {
  wss = new WebSocket.Server({ 
    server,
    path: '/voice/ws'
  });

  wss.on('connection', (ws, req) => {
    console.log('Voice WebSocket connection established');
    
    ws.on('message', async (message) => {
      try {
        const data = JSON.parse(message);
        
        if (data.type === 'audio') {
          // Handle audio data
          await handleAudioMessage(ws, data);
        } else if (data.type === 'text') {
          // Handle text message (fallback)
          await handleTextMessage(ws, data);
        }
      } catch (error) {
        console.error('Error processing WebSocket message:', error);
        ws.send(JSON.stringify({
          type: 'error',
          message: 'Failed to process message'
        }));
      }
    });

    ws.on('close', () => {
      console.log('Voice WebSocket connection closed');
    });

    ws.on('error', (error) => {
      console.error('Voice WebSocket error:', error);
    });
  });
};

// Handle audio messages from client
const handleAudioMessage = async (ws, data) => {
  try {
    const { audioData, userId, sessionId } = data;
    
    // Log the voice input
    await Log.logInteraction({
      userId,
      interactionType: 'voice_input',
      details: {
        sessionId,
        audioDataLength: audioData.length,
        processingTime: 0
      },
      metadata: {
        platform: 'websocket'
      }
    });

    // TODO: Implement OpenAI Realtime API integration
    // For now, we'll simulate the response
    const mockTranscription = "Schedule a meeting with John tomorrow at 2 PM";
    
    // Process the transcribed text with ASH agent
    const response = await ashAgent.processRequest(userId, mockTranscription, true);
    
    // Send response back to client
    ws.send(JSON.stringify({
      type: 'transcription',
      text: mockTranscription,
      confidence: 0.95
    }));

    ws.send(JSON.stringify({
      type: 'response',
      text: response.reply,
      success: response.success
    }));

  } catch (error) {
    console.error('Error handling audio message:', error);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to process audio'
    }));
  }
};

// Handle text messages (fallback for non-voice input)
const handleTextMessage = async (ws, data) => {
  try {
    const { text, userId, sessionId } = data;
    
    // Process the text with ASH agent
    const response = await ashAgent.processRequest(userId, text, false);
    
    // Send response back to client
    ws.send(JSON.stringify({
      type: 'response',
      text: response.reply,
      success: response.success
    }));

  } catch (error) {
    console.error('Error handling text message:', error);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to process text'
    }));
  }
};

// Enhanced voice processing with streaming
router.post('/process', authenticateToken, async (req, res) => {
  try {
    const { audioData, text, sessionId, isStreaming = false } = req.body;
    const userId = req.user.userId;
    const currentSessionId = sessionId || uuidv4();

    if (!audioData && !text) {
      return res.status(400).json({
        success: false,
        error: 'Audio data or text is required'
      });
    }

    // Set up streaming response if requested
    if (isStreaming) {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Cache-Control'
      });
    }

    let inputText = text;
    let transcription = null;
    let audioUrl = null;

    // If audio data is provided, transcribe it using OpenAI Whisper
    if (audioData && !text) {
      try {
        const transcriptionResult = await ashAgent.transcribeAudio(audioData);
        inputText = transcriptionResult.text;
        transcription = transcriptionResult;
      } catch (transcriptionError) {
        console.error('Transcription error:', transcriptionError);
        inputText = "I couldn't understand that. Could you please repeat?";
      }
    }

    // Get or create chat session
    let chat = await Chat.findBySession(currentSessionId);
    if (!chat) {
      chat = await Chat.createSession(userId, currentSessionId);
    }

    // Add user message to chat
    await chat.addMessage('user', inputText, {
      isVoice: !!audioData,
      transcription: transcription?.text,
      confidence: transcription?.confidence,
      audioUrl: audioUrl
    });

    // Log the voice input
    await Log.logInteraction({
      userId,
      interactionType: audioData ? 'voice_input' : 'text_input',
      details: {
        input: inputText,
        sessionId: currentSessionId,
        audioDataLength: audioData ? audioData.length : 0,
        processingTime: 0,
        transcription: transcription
      },
      metadata: {
        platform: 'api'
      }
    });

    // Process the request with ASH agent (with streaming if requested)
    const response = await ashAgent.processRequest(userId, inputText, !!audioData, {
      sessionId: currentSessionId,
      streaming: isStreaming,
      streamCallback: isStreaming ? (chunk) => {
        res.write(`data: ${JSON.stringify({ type: 'chunk', content: chunk })}\n\n`);
      } : null
    });

    // Add assistant response to chat
    await chat.addMessage('assistant', response.reply, {
      isVoice: false,
      processingTime: response.processingTime
    });

    // Generate TTS audio for voice response
    let ttsAudio = null;
    if (audioData || req.user.preferences.voiceEnabled) {
      try {
        ttsAudio = await ashAgent.generateTTS(response.reply);
      } catch (ttsError) {
        console.error('TTS generation error:', ttsError);
      }
    }

    // Update conversation state
    await chat.updateState('idle');

    const finalResponse = {
      success: response.success,
      transcription: inputText,
      reply: response.reply,
      processingTime: response.processingTime,
      sessionId: currentSessionId,
      audioUrl: ttsAudio?.url,
      conversationState: chat.context.conversationState
    };

    if (isStreaming) {
      res.write(`data: ${JSON.stringify({ type: 'complete', data: finalResponse })}\n\n`);
      res.end();
    } else {
      res.json(finalResponse);
    }

  } catch (error) {
    console.error('Error processing voice input:', error);
    
    // Log the error
    await Log.logInteraction({
      userId: req.user?.userId,
      interactionType: 'error',
      details: {
        error: error.message,
        sessionId: req.body.sessionId
      },
      metadata: {
        platform: 'api'
      }
    });

    if (req.body.isStreaming) {
      res.write(`data: ${JSON.stringify({ type: 'error', error: error.message })}\n\n`);
      res.end();
    } else {
      res.status(500).json({
        success: false,
        error: 'Failed to process voice input'
      });
    }
  }
});

// Get voice session status
router.get('/status', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    res.json({
      success: true,
      voiceEnabled: user.preferences.voiceEnabled,
      ttsProvider: user.preferences.ttsProvider,
      websocketUrl: process.env.NODE_ENV === 'production' 
        ? `wss://${req.get('host')}/voice/ws`
        : `ws://localhost:${process.env.PORT || 3000}/voice/ws`
    });
  } catch (error) {
    console.error('Error getting voice status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get voice status'
    });
  }
});

// Update voice preferences
router.put('/preferences', authenticateToken, async (req, res) => {
  try {
    const { voiceEnabled, ttsProvider } = req.body;
    const user = req.user;

    if (voiceEnabled !== undefined) {
      user.preferences.voiceEnabled = voiceEnabled;
    }

    if (ttsProvider && ['openai', 'google'].includes(ttsProvider)) {
      user.preferences.ttsProvider = ttsProvider;
    }

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

// Get chat history
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const { sessionId, limit = 50 } = req.query;
    const userId = req.user.userId;

    let chats;
    if (sessionId) {
      const chat = await Chat.findBySession(sessionId);
      chats = chat ? [chat] : [];
    } else {
      chats = await Chat.findByUser(userId, parseInt(limit));
    }

    res.json({
      success: true,
      chats: chats.map(chat => ({
        sessionId: chat.sessionId,
        messages: chat.messages.map(msg => ({
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          metadata: msg.metadata
        })),
        type: chat.type,
        context: chat.context,
        summary: chat.summary,
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt
      }))
    });
  } catch (error) {
    console.error('Error getting chat history:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get chat history'
    });
  }
});

// Create new chat session
router.post('/session', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const sessionId = uuidv4();
    
    const chat = await Chat.createSession(userId, sessionId);
    
    res.json({
      success: true,
      sessionId: chat.sessionId,
      message: 'New chat session created'
    });
  } catch (error) {
    console.error('Error creating chat session:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create chat session'
    });
  }
});

// Test voice connection
router.post('/test', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Log the test
    await Log.logInteraction({
      userId,
      interactionType: 'voice_input',
      details: {
        input: 'Voice connection test',
        processingTime: 0
      },
      metadata: {
        platform: 'api'
      }
    });

    res.json({
      success: true,
      message: 'Voice connection test successful',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error testing voice connection:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to test voice connection'
    });
  }
});

module.exports = { router, initializeWebSocket };

