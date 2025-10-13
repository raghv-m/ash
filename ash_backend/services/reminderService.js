const cron = require('node-cron');
const Event = require('../models/Event');
const User = require('../models/User');
const Log = require('../models/Log');
const speakRoutes = require('../routes/speak');
const googleService = require('../config/google');

class ReminderService {
  constructor() {
    this.jobs = new Map();
    this.isRunning = false;
  }

  start() {
    if (this.isRunning) {
      console.log('Reminder service is already running');
      return;
    }

    console.log('🔔 Starting reminder service...');
    
    // Run every minute to check for reminders
    this.reminderJob = cron.schedule('* * * * *', async () => {
      await this.checkAndSendReminders();
    }, {
      scheduled: false
    });

    this.reminderJob.start();
    this.isRunning = true;
    
    console.log('✅ Reminder service started successfully');
  }

  stop() {
    if (!this.isRunning) {
      console.log('Reminder service is not running');
      return;
    }

    console.log('🛑 Stopping reminder service...');
    
    if (this.reminderJob) {
      this.reminderJob.stop();
      this.reminderJob.destroy();
    }

    // Stop all individual reminder jobs
    this.jobs.forEach((job, eventId) => {
      job.stop();
      job.destroy();
    });
    this.jobs.clear();

    this.isRunning = false;
    console.log('✅ Reminder service stopped successfully');
  }

  async checkAndSendReminders() {
    try {
      const eventsNeedingReminders = await Event.findNeedingReminders();
      
      if (eventsNeedingReminders.length === 0) {
        return;
      }

      console.log(`🔔 Found ${eventsNeedingReminders.length} events needing reminders`);

      for (const event of eventsNeedingReminders) {
        await this.sendReminder(event);
      }
    } catch (error) {
      console.error('Error checking reminders:', error);
    }
  }

  async sendReminder(event) {
    try {
      const user = await User.findOne({ userId: event.userId });
      if (!user || !user.isActive) {
        console.log(`User ${event.userId} not found or inactive, skipping reminder`);
        return;
      }

      // Mark reminder as sent
      await event.markReminderSent();

      // Generate reminder message
      const reminderMessage = this.generateReminderMessage(event);
      
      // Log the reminder
      await Log.logInteraction({
        userId: event.userId,
        interactionType: 'reminder_sent',
        details: {
          eventId: event._id,
          title: event.title,
          startTime: event.startTime.toISOString(),
          message: reminderMessage
        },
        metadata: {
          platform: 'system'
        }
      });

      // Send reminder via email (if Google tokens are valid)
      if (user.hasValidGoogleTokens()) {
        try {
          await this.sendEmailReminder(user, event, reminderMessage);
        } catch (emailError) {
          console.error('Error sending email reminder:', emailError);
        }
      }

      // TODO: Send push notification if user has mobile app
      // TODO: Send SMS if user has phone number and SMS enabled

      console.log(`✅ Reminder sent for event: ${event.title} (${event._id})`);

    } catch (error) {
      console.error(`Error sending reminder for event ${event._id}:`, error);
      
      // Log the error
      await Log.logInteraction({
        userId: event.userId,
        interactionType: 'error',
        details: {
          eventId: event._id,
          error: error.message,
          context: 'reminder_sending'
        },
        metadata: {
          platform: 'system'
        }
      });
    }
  }

  generateReminderMessage(event) {
    const now = new Date();
    const timeUntilEvent = event.startTime - now;
    const minutesUntil = Math.round(timeUntilEvent / (1000 * 60));
    
    let timeText;
    if (minutesUntil <= 0) {
      timeText = 'now';
    } else if (minutesUntil < 60) {
      timeText = `in ${minutesUntil} minute${minutesUntil !== 1 ? 's' : ''}`;
    } else {
      const hours = Math.floor(minutesUntil / 60);
      const minutes = minutesUntil % 60;
      timeText = `in ${hours} hour${hours !== 1 ? 's' : ''}`;
      if (minutes > 0) {
        timeText += ` and ${minutes} minute${minutes !== 1 ? 's' : ''}`;
      }
    }

    const startTime = event.startTime.toLocaleString();
    const location = event.location ? ` at ${event.location}` : '';
    const attendees = event.attendees.length > 0 
      ? ` with ${event.attendees.map(a => a.name || a.email).join(', ')}`
      : '';

    return `🔔 Reminder: "${event.title}" starts ${timeText} (${startTime})${location}${attendees}. ${event.description ? `\n\nDescription: ${event.description}` : ''}`;
  }

  async sendEmailReminder(user, event, message) {
    try {
      // Create a simple email reminder
      const emailData = {
        title: `Reminder: ${event.title}`,
        description: message,
        startTime: event.startTime,
        endTime: event.endTime,
        location: event.location,
        attendees: event.attendees
      };

      // Send to user's email
      await googleService.sendInvite(user.userId, emailData, [{
        email: user.email,
        name: user.name
      }]);

    } catch (error) {
      console.error('Error sending email reminder:', error);
      throw error;
    }
  }

  // Schedule a specific reminder for an event
  scheduleReminder(event) {
    try {
      if (!event.reminderTime || event.reminderSent) {
        return;
      }

      const reminderTime = new Date(event.reminderTime);
      const now = new Date();

      // If reminder time is in the past, don't schedule
      if (reminderTime <= now) {
        return;
      }

      // Cancel existing job if any
      if (this.jobs.has(event._id.toString())) {
        this.jobs.get(event._id.toString()).stop();
        this.jobs.get(event._id.toString()).destroy();
      }

      // Create cron expression for the reminder time
      const cronExpression = this.createCronExpression(reminderTime);
      
      const job = cron.schedule(cronExpression, async () => {
        await this.sendReminder(event);
        this.jobs.delete(event._id.toString());
      }, {
        scheduled: true,
        timezone: 'UTC'
      });

      this.jobs.set(event._id.toString(), job);
      
      console.log(`📅 Scheduled reminder for event ${event._id} at ${reminderTime.toISOString()}`);

    } catch (error) {
      console.error(`Error scheduling reminder for event ${event._id}:`, error);
    }
  }

  // Cancel a scheduled reminder
  cancelReminder(eventId) {
    const job = this.jobs.get(eventId.toString());
    if (job) {
      job.stop();
      job.destroy();
      this.jobs.delete(eventId.toString());
      console.log(`❌ Cancelled reminder for event ${eventId}`);
    }
  }

  // Create cron expression from date
  createCronExpression(date) {
    const minute = date.getMinutes();
    const hour = date.getHours();
    const day = date.getDate();
    const month = date.getMonth() + 1; // Cron months are 1-based
    const year = date.getFullYear();

    // For simplicity, we'll use a daily check and let the main cron job handle the actual sending
    // This is more reliable than trying to schedule exact times
    return '* * * * *'; // Every minute - the main job will check if it's time
  }

  // Get status of reminder service
  getStatus() {
    return {
      isRunning: this.isRunning,
      activeReminders: this.jobs.size,
      nextCheck: new Date(Date.now() + 60000).toISOString() // Next minute
    };
  }
}

module.exports = new ReminderService();


