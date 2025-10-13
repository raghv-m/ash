const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  picture: {
    type: String,
    default: null
  },
  googleTokens: {
    accessToken: {
      type: String,
      default: null
    },
    refreshToken: {
      type: String,
      default: null
    },
    expiryDate: {
      type: Date,
      default: null
    }
  },
  timeZone: {
    type: String,
    default: 'UTC',
    required: true
  },
  preferences: {
    voiceEnabled: {
      type: Boolean,
      default: true
    },
    ttsProvider: {
      type: String,
      enum: ['openai', 'google'],
      default: 'openai'
    },
    reminderMinutes: {
      type: Number,
      default: 30
    },
    workingHours: {
      start: {
        type: String,
        default: '09:00'
      },
      end: {
        type: String,
        default: '17:00'
      }
    },
    workingDays: {
      type: [String],
      default: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    }
  },
  isActive: {
    type: Boolean,
    default: true
  },
  lastLogin: {
    type: Date,
    default: Date.now
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
userSchema.index({ email: 1 });
userSchema.index({ userId: 1 });
userSchema.index({ createdAt: -1 });

// Middleware to update the updatedAt field
userSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Method to check if Google tokens are valid
userSchema.methods.hasValidGoogleTokens = function() {
  if (!this.googleTokens.accessToken || !this.googleTokens.expiryDate) {
    return false;
  }
  return new Date() < this.googleTokens.expiryDate;
};

// Method to update Google tokens
userSchema.methods.updateGoogleTokens = function(tokens) {
  this.googleTokens = {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiryDate: new Date(Date.now() + tokens.expires_in * 1000)
  };
  return this.save();
};

// Method to get user's working hours in a specific timezone
userSchema.methods.getWorkingHours = function() {
  return {
    start: this.preferences.workingHours.start,
    end: this.preferences.workingHours.end,
    days: this.preferences.workingDays,
    timeZone: this.timeZone
  };
};

// Static method to find user by email
userSchema.statics.findByEmail = function(email) {
  return this.findOne({ email: email.toLowerCase() });
};

// Static method to find active users
userSchema.statics.findActiveUsers = function() {
  return this.find({ isActive: true });
};

module.exports = mongoose.model('User', userSchema);


