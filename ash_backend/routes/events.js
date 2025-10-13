const express = require('express');
const Event = require('../models/Event');
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

// Get all events for a user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { startDate, endDate, status, limit = 50 } = req.query;
    const userId = req.user.userId;

    let query = { userId };

    // Add date range filter
    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) query.startTime.$gte = new Date(startDate);
      if (endDate) query.startTime.$lte = new Date(endDate);
    }

    // Add status filter
    if (status) {
      query.status = status;
    }

    const events = await Event.find(query)
      .sort({ startTime: 1 })
      .limit(parseInt(limit));

    res.json({
      success: true,
      events: events.map(event => ({
        id: event._id,
        googleEventId: event.googleEventId,
        title: event.title,
        description: event.description,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        location: event.location,
        attendees: event.attendees,
        status: event.status,
        reminderSent: event.reminderSent,
        reminderTime: event.reminderTime?.toISOString(),
        isRecurring: event.isRecurring,
        recurrencePattern: event.recurrencePattern,
        metadata: event.metadata,
        createdAt: event.createdAt.toISOString(),
        updatedAt: event.updatedAt.toISOString()
      })),
      count: events.length
    });

  } catch (error) {
    console.error('Error getting events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get events'
    });
  }
});

// Get upcoming events
router.get('/upcoming', authenticateToken, async (req, res) => {
  try {
    const { limit = 10 } = req.query;
    const userId = req.user.userId;

    const events = await Event.findUpcoming(userId, parseInt(limit));

    res.json({
      success: true,
      events: events.map(event => ({
        id: event._id,
        googleEventId: event.googleEventId,
        title: event.title,
        description: event.description,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        location: event.location,
        attendees: event.attendees,
        status: event.status,
        reminderSent: event.reminderSent,
        reminderTime: event.reminderTime?.toISOString(),
        isToday: event.isToday(),
        isFuture: event.isFuture(),
        duration: event.getDuration()
      })),
      count: events.length
    });

  } catch (error) {
    console.error('Error getting upcoming events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get upcoming events'
    });
  }
});

// Get a specific event
router.get('/:eventId', authenticateToken, async (req, res) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.userId;

    const event = await Event.findOne({ _id: eventId, userId });

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    res.json({
      success: true,
      event: {
        id: event._id,
        googleEventId: event.googleEventId,
        title: event.title,
        description: event.description,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        location: event.location,
        attendees: event.attendees,
        status: event.status,
        reminderSent: event.reminderSent,
        reminderTime: event.reminderTime?.toISOString(),
        isRecurring: event.isRecurring,
        recurrencePattern: event.recurrencePattern,
        metadata: event.metadata,
        createdAt: event.createdAt.toISOString(),
        updatedAt: event.updatedAt.toISOString()
      }
    });

  } catch (error) {
    console.error('Error getting event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get event'
    });
  }
});

// Update an event
router.put('/:eventId', authenticateToken, async (req, res) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.userId;
    const updateData = req.body;

    const event = await Event.findOne({ _id: eventId, userId });

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    // Update in Google Calendar if it exists
    if (event.googleEventId) {
      try {
        await googleService.updateEvent(userId, event.googleEventId, updateData);
      } catch (googleError) {
        console.error('Error updating Google Calendar event:', googleError);
        // Continue with local update even if Google update fails
      }
    }

    // Update local event
    Object.assign(event, updateData);
    event.status = 'rescheduled';
    await event.save();

    // Log the update
    await Log.logInteraction({
      userId,
      interactionType: 'event_updated',
      details: {
        eventId: event._id,
        googleEventId: event.googleEventId,
        changes: updateData
      }
    });

    res.json({
      success: true,
      message: 'Event updated successfully',
      event: {
        id: event._id,
        title: event.title,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        status: event.status
      }
    });

  } catch (error) {
    console.error('Error updating event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update event'
    });
  }
});

// Cancel an event
router.delete('/:eventId', authenticateToken, async (req, res) => {
  try {
    const { eventId } = req.params;
    const userId = req.user.userId;

    const event = await Event.findOne({ _id: eventId, userId });

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    // Cancel in Google Calendar if it exists
    if (event.googleEventId) {
      try {
        await googleService.deleteEvent(userId, event.googleEventId);
      } catch (googleError) {
        console.error('Error cancelling Google Calendar event:', googleError);
        // Continue with local cancellation even if Google cancellation fails
      }
    }

    // Cancel local event
    await event.cancel();

    // Log the cancellation
    await Log.logInteraction({
      userId,
      interactionType: 'event_cancelled',
      details: {
        eventId: event._id,
        googleEventId: event.googleEventId,
        title: event.title
      }
    });

    res.json({
      success: true,
      message: `Event "${event.title}" cancelled successfully`,
      eventId: event._id
    });

  } catch (error) {
    console.error('Error cancelling event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to cancel event'
    });
  }
});

// Reschedule an event
router.post('/:eventId/reschedule', authenticateToken, async (req, res) => {
  try {
    const { eventId } = req.params;
    const { startTime, endTime } = req.body;
    const userId = req.user.userId;

    if (!startTime || !endTime) {
      return res.status(400).json({
        success: false,
        error: 'Start time and end time are required'
      });
    }

    const event = await Event.findOne({ _id: eventId, userId });

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    const newStartTime = new Date(startTime);
    const newEndTime = new Date(endTime);

    // Update in Google Calendar if it exists
    if (event.googleEventId) {
      try {
        await googleService.updateEvent(userId, event.googleEventId, {
          startTime: newStartTime,
          endTime: newEndTime
        });
      } catch (googleError) {
        console.error('Error rescheduling Google Calendar event:', googleError);
        // Continue with local reschedule even if Google update fails
      }
    }

    // Reschedule local event
    await event.reschedule(newStartTime, newEndTime);

    // Log the reschedule
    await Log.logInteraction({
      userId,
      interactionType: 'reschedule_request',
      details: {
        eventId: event._id,
        googleEventId: event.googleEventId,
        oldStartTime: event.startTime.toISOString(),
        newStartTime: newStartTime.toISOString(),
        newEndTime: newEndTime.toISOString()
      }
    });

    res.json({
      success: true,
      message: `Event "${event.title}" rescheduled successfully`,
      event: {
        id: event._id,
        title: event.title,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        status: event.status
      }
    });

  } catch (error) {
    console.error('Error rescheduling event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reschedule event'
    });
  }
});

// Set reminder for an event
router.post('/:eventId/reminder', authenticateToken, async (req, res) => {
  try {
    const { eventId } = req.params;
    const { minutesBefore = 30 } = req.body;
    const userId = req.user.userId;

    const event = await Event.findOne({ _id: eventId, userId });

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    event.reminderTime = new Date(event.startTime.getTime() - minutesBefore * 60 * 1000);
    await event.save();

    res.json({
      success: true,
      message: `Reminder set for ${minutesBefore} minutes before the event`,
      reminderTime: event.reminderTime.toISOString()
    });

  } catch (error) {
    console.error('Error setting reminder:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to set reminder'
    });
  }
});

// Get events for a specific date
router.get('/date/:date', authenticateToken, async (req, res) => {
  try {
    const { date } = req.params;
    const userId = req.user.userId;

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
    const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));

    const events = await Event.findByUserAndDateRange(userId, startOfDay, endOfDay);

    res.json({
      success: true,
      date: targetDate.toISOString(),
      events: events.map(event => ({
        id: event._id,
        title: event.title,
        description: event.description,
        startTime: event.startTime.toISOString(),
        endTime: event.endTime.toISOString(),
        location: event.location,
        attendees: event.attendees,
        status: event.status,
        duration: event.getDuration()
      })),
      count: events.length
    });

  } catch (error) {
    console.error('Error getting events for date:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get events for date'
    });
  }
});

module.exports = router;


