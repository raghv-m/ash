const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  role: {
    type: String,
    required: true,
    enum: ['user', 'assistant', 'system']
  },
  content: {
    type: String,
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now
  },
  metadata: {
    isVoice: {
      type: Boolean,
      default: false
    },
    audioUrl: {
      type: String,
      default: null
    },
    transcription: {
      type: String,
      default: null
    },
    confidence: {
      type: Number,
      default: null
    },
    processingTime: {
      type: Number,
      default: null
    }
  }
});

const chatSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  sessionId: {
    type: String,
    required: true,
    index: true
  },
  messages: [messageSchema],
  type: {
    type: String,
    enum: ['text', 'voice', 'mixed'],
    default: 'text'
  },
  context: {
    currentIntent: {
      type: String,
      default: null
    },
    pendingAction: {
      type: String,
      default: null
    },
    lastEventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Event',
      default: null
    },
    conversationState: {
      type: String,
      enum: ['idle', 'listening', 'processing', 'confirming', 'executing'],
      default: 'idle'
    }
  },
  summary: {
    type: String,
    default: null
  },
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Indexes for better performance
chatSchema.index({ userId: 1, createdAt: -1 });
chatSchema.index({ sessionId: 1 });
chatSchema.index({ 'context.conversationState': 1 });

// Middleware to update the updatedAt field
chatSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Method to add a message to the chat
chatSchema.methods.addMessage = function(role, content, metadata = {}) {
  this.messages.push({
    role,
    content,
    metadata: {
      isVoice: metadata.isVoice || false,
      audioUrl: metadata.audioUrl || null,
      transcription: metadata.transcription || null,
      confidence: metadata.confidence || null,
      processingTime: metadata.processingTime || null
    }
  });
  return this.save();
};

// Method to get the last N messages
chatSchema.methods.getLastMessages = function(count = 10) {
  return this.messages.slice(-count);
};

// Method to update conversation state
chatSchema.methods.updateState = function(newState, context = {}) {
  this.context.conversationState = newState;
  if (context.currentIntent) this.context.currentIntent = context.currentIntent;
  if (context.pendingAction) this.context.pendingAction = context.pendingAction;
  if (context.lastEventId) this.context.lastEventId = context.lastEventId;
  return this.save();
};

// Method to generate conversation summary
chatSchema.methods.generateSummary = function() {
  const messageCount = this.messages.length;
  const voiceMessages = this.messages.filter(msg => msg.metadata.isVoice).length;
  const lastMessage = this.messages[this.messages.length - 1];
  
  this.summary = `Chat with ${messageCount} messages (${voiceMessages} voice). Last: ${lastMessage?.content?.substring(0, 50)}...`;
  return this.save();
};

// Static method to find active chat for user
chatSchema.statics.findActiveChat = function(userId) {
  return this.findOne({
    userId,
    isActive: true
  }).sort({ updatedAt: -1 });
};

// Static method to find chats by user
chatSchema.statics.findByUser = function(userId, limit = 20) {
  return this.find({
    userId
  }).sort({ updatedAt: -1 }).limit(limit);
};

// Static method to find chats by session
chatSchema.statics.findBySession = function(sessionId) {
  return this.findOne({ sessionId });
};

// Static method to create new chat session
chatSchema.statics.createSession = function(userId, sessionId, initialMessage = null) {
  const chat = new this({
    userId,
    sessionId,
    type: 'text'
  });

  if (initialMessage) {
    chat.messages.push(initialMessage);
  }

  return chat.save();
};

// Static method to get conversation statistics
chatSchema.statics.getConversationStats = function(userId, days = 7) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  
  return this.aggregate([
    {
      $match: {
        userId,
        createdAt: { $gte: since }
      }
    },
    {
      $group: {
        _id: null,
        totalChats: { $sum: 1 },
        totalMessages: { $sum: { $size: '$messages' } },
        voiceMessages: {
          $sum: {
            $size: {
              $filter: {
                input: '$messages',
                cond: { $eq: ['$$this.metadata.isVoice', true] }
              }
            }
          }
        },
        avgMessagesPerChat: { $avg: { $size: '$messages' } }
      }
    }
  ]);
};

module.exports = mongoose.model('Chat', chatSchema);

