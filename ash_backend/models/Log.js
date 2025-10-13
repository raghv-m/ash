const mongoose = require('mongoose');

const logSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  interactionType: {
    type: String,
    required: true,
    enum: [
      'voice_input',
      'text_input',
      'schedule_request',
      'reschedule_request',
      'cancel_request',
      'confirmation',
      'reminder_sent',
      'event_created',
      'event_updated',
      'event_cancelled',
      'google_api_call',
      'error',
      'authentication',
      'voice_response'
    ],
    index: true
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  },
  details: {
    input: {
      type: String,
      default: ''
    },
    output: {
      type: String,
      default: ''
    },
    intent: {
      type: String,
      default: ''
    },
    entities: {
      type: mongoose.Schema.Types.Mixed,
      default: {}
    },
    confidence: {
      type: Number,
      default: 0
    },
    processingTime: {
      type: Number,
      default: 0
    },
    error: {
      type: String,
      default: ''
    },
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Event',
      default: null
    },
    googleEventId: {
      type: String,
      default: ''
    },
    apiEndpoint: {
      type: String,
      default: ''
    },
    httpStatus: {
      type: Number,
      default: null
    },
    voiceData: {
      duration: {
        type: Number,
        default: 0
      },
      language: {
        type: String,
        default: 'en-US'
      },
      transcription: {
        type: String,
        default: ''
      }
    }
  },
  metadata: {
    userAgent: {
      type: String,
      default: ''
    },
    ipAddress: {
      type: String,
      default: ''
    },
    sessionId: {
      type: String,
      default: ''
    },
    deviceType: {
      type: String,
      enum: ['mobile', 'web', 'desktop', 'unknown'],
      default: 'unknown'
    },
    platform: {
      type: String,
      enum: ['flutter', 'web', 'api', 'unknown'],
      default: 'unknown'
    }
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Compound indexes for better query performance
logSchema.index({ userId: 1, timestamp: -1 });
logSchema.index({ userId: 1, interactionType: 1, timestamp: -1 });
logSchema.index({ timestamp: -1 });
logSchema.index({ 'details.eventId': 1 });

// Static method to log user interaction
logSchema.statics.logInteraction = function(data) {
  const log = new this({
    userId: data.userId,
    interactionType: data.interactionType,
    details: data.details || {},
    metadata: data.metadata || {}
  });
  
  return log.save();
};

// Static method to find logs by user and type
logSchema.statics.findByUserAndType = function(userId, interactionType, limit = 50) {
  return this.find({
    userId,
    interactionType
  }).sort({ timestamp: -1 }).limit(limit);
};

// Static method to find recent logs for a user
logSchema.statics.findRecentByUser = function(userId, hours = 24, limit = 100) {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000);
  return this.find({
    userId,
    timestamp: { $gte: since }
  }).sort({ timestamp: -1 }).limit(limit);
};

// Static method to get interaction statistics
logSchema.statics.getInteractionStats = function(userId, days = 7) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  
  return this.aggregate([
    {
      $match: {
        userId,
        timestamp: { $gte: since }
      }
    },
    {
      $group: {
        _id: '$interactionType',
        count: { $sum: 1 },
        avgProcessingTime: { $avg: '$details.processingTime' }
      }
    },
    {
      $sort: { count: -1 }
    }
  ]);
};

// Static method to find error logs
logSchema.statics.findErrors = function(userId, limit = 20) {
  return this.find({
    userId,
    interactionType: 'error'
  }).sort({ timestamp: -1 }).limit(limit);
};

// Method to add processing time
logSchema.methods.addProcessingTime = function(startTime) {
  this.details.processingTime = Date.now() - startTime;
  return this.save();
};

// Method to mark as error
logSchema.methods.markAsError = function(errorMessage) {
  this.interactionType = 'error';
  this.details.error = errorMessage;
  return this.save();
};

module.exports = mongoose.model('Log', logSchema);


