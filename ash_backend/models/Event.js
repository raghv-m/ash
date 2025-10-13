const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  googleEventId: {
    type: String,
    default: null,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    default: '',
    trim: true
  },
  startTime: {
    type: Date,
    required: true,
    index: true
  },
  endTime: {
    type: Date,
    required: true,
    index: true
  },
  location: {
    type: String,
    default: '',
    trim: true
  },
  attendees: [{
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true
    },
    name: {
      type: String,
      default: '',
      trim: true
    },
    responseStatus: {
      type: String,
      enum: ['needsAction', 'declined', 'tentative', 'accepted'],
      default: 'needsAction'
    }
  }],
  status: {
    type: String,
    enum: ['scheduled', 'confirmed', 'cancelled', 'rescheduled', 'completed'],
    default: 'scheduled',
    index: true
  },
  reminderSent: {
    type: Boolean,
    default: false
  },
  reminderTime: {
    type: Date,
    default: null
  },
  isRecurring: {
    type: Boolean,
    default: false
  },
  recurrencePattern: {
    frequency: {
      type: String,
      enum: ['daily', 'weekly', 'monthly', 'yearly'],
      default: null
    },
    interval: {
      type: Number,
      default: 1
    },
    endDate: {
      type: Date,
      default: null
    },
    daysOfWeek: [{
      type: String,
      enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    }]
  },
  metadata: {
    createdBy: {
      type: String,
      enum: ['user', 'ash', 'google'],
      default: 'ash'
    },
    voiceConfirmed: {
      type: Boolean,
      default: false
    },
    originalRequest: {
      type: String,
      default: ''
    },
    aiReasoning: {
      type: String,
      default: ''
    }
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

// Compound indexes for better query performance
eventSchema.index({ userId: 1, startTime: 1 });
eventSchema.index({ userId: 1, status: 1 });
eventSchema.index({ startTime: 1, endTime: 1 });
eventSchema.index({ reminderTime: 1, reminderSent: 1 });

// Middleware to update the updatedAt field
eventSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  
  // Auto-calculate reminder time if not set
  if (!this.reminderTime && this.startTime) {
    const reminderMinutes = 30; // Default reminder time
    this.reminderTime = new Date(this.startTime.getTime() - reminderMinutes * 60 * 1000);
  }
  
  next();
});

// Method to check if event is in the future
eventSchema.methods.isFuture = function() {
  return this.startTime > new Date();
};

// Method to check if event is today
eventSchema.methods.isToday = function() {
  const today = new Date();
  const eventDate = new Date(this.startTime);
  return eventDate.toDateString() === today.toDateString();
};

// Method to get event duration in minutes
eventSchema.methods.getDuration = function() {
  return Math.round((this.endTime - this.startTime) / (1000 * 60));
};

// Method to check if reminder should be sent
eventSchema.methods.shouldSendReminder = function() {
  const now = new Date();
  return !this.reminderSent && 
         this.reminderTime && 
         this.reminderTime <= now && 
         this.isFuture();
};

// Method to mark reminder as sent
eventSchema.methods.markReminderSent = function() {
  this.reminderSent = true;
  return this.save();
};

// Method to cancel event
eventSchema.methods.cancel = function() {
  this.status = 'cancelled';
  return this.save();
};

// Method to reschedule event
eventSchema.methods.reschedule = function(newStartTime, newEndTime) {
  this.startTime = newStartTime;
  this.endTime = newEndTime;
  this.status = 'rescheduled';
  this.reminderSent = false;
  this.reminderTime = new Date(newStartTime.getTime() - 30 * 60 * 1000);
  return this.save();
};

// Static method to find events by user and date range
eventSchema.statics.findByUserAndDateRange = function(userId, startDate, endDate) {
  return this.find({
    userId,
    startTime: { $gte: startDate, $lte: endDate },
    status: { $ne: 'cancelled' }
  }).sort({ startTime: 1 });
};

// Static method to find upcoming events
eventSchema.statics.findUpcoming = function(userId, limit = 10) {
  return this.find({
    userId,
    startTime: { $gte: new Date() },
    status: { $ne: 'cancelled' }
  }).sort({ startTime: 1 }).limit(limit);
};

// Static method to find events needing reminders
eventSchema.statics.findNeedingReminders = function() {
  const now = new Date();
  return this.find({
    reminderTime: { $lte: now },
    reminderSent: false,
    status: { $ne: 'cancelled' },
    startTime: { $gte: now }
  });
};

module.exports = mongoose.model('Event', eventSchema);


