const { google } = require('googleapis');
const User = require('../models/User');

class GoogleAPIService {
  constructor() {
    this.oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
    
    this.calendar = google.calendar({ version: 'v3' });
    this.gmail = google.gmail({ version: 'v1' });
  }

  // Generate OAuth2 authorization URL
  getAuthUrl(userId) {
    const scopes = [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile'
    ];

    return this.oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: scopes,
      state: userId,
      prompt: 'consent'
    });
  }

  // Exchange authorization code for tokens
  async getTokens(code) {
    try {
      const { tokens } = await this.oauth2Client.getToken(code);
      this.oauth2Client.setCredentials(tokens);
      return tokens;
    } catch (error) {
      console.error('Error getting tokens:', error);
      throw new Error('Failed to exchange authorization code for tokens');
    }
  }

  // Set credentials for a user
  async setUserCredentials(userId) {
    try {
      const user = await User.findOne({ userId });
      if (!user || !user.hasValidGoogleTokens()) {
        throw new Error('User not found or invalid tokens');
      }

      this.oauth2Client.setCredentials({
        access_token: user.googleTokens.accessToken,
        refresh_token: user.googleTokens.refreshToken
      });

      return this.oauth2Client;
    } catch (error) {
      console.error('Error setting user credentials:', error);
      throw new Error('Failed to set user credentials');
    }
  }

  // Refresh tokens if needed
  async refreshTokensIfNeeded(userId) {
    try {
      const user = await User.findOne({ userId });
      if (!user) {
        throw new Error('User not found');
      }

      if (user.hasValidGoogleTokens()) {
        return user.googleTokens.accessToken;
      }

      // Refresh the token
      this.oauth2Client.setCredentials({
        refresh_token: user.googleTokens.refreshToken
      });

      const { credentials } = await this.oauth2Client.refreshAccessToken();
      
      // Update user with new tokens
      await user.updateGoogleTokens(credentials);
      
      return credentials.access_token;
    } catch (error) {
      console.error('Error refreshing tokens:', error);
      throw new Error('Failed to refresh tokens');
    }
  }

  // Calendar API methods
  async getFreeSlots(userId, startTime, endTime, duration = 60) {
    try {
      await this.setUserCredentials(userId);
      
      const response = await this.calendar.freebusy.query({
        auth: this.oauth2Client,
        requestBody: {
          timeMin: startTime.toISOString(),
          timeMax: endTime.toISOString(),
          items: [{ id: 'primary' }]
        }
      });

      const busyTimes = response.data.calendars.primary.busy || [];
      const freeSlots = this.calculateFreeSlots(startTime, endTime, busyTimes, duration);
      
      return freeSlots;
    } catch (error) {
      console.error('Error getting free slots:', error);
      throw new Error('Failed to get free time slots');
    }
  }

  async createEvent(userId, eventData) {
    try {
      await this.setUserCredentials(userId);
      
      const event = {
        summary: eventData.title,
        description: eventData.description || '',
        start: {
          dateTime: eventData.startTime.toISOString(),
          timeZone: eventData.timeZone || 'UTC'
        },
        end: {
          dateTime: eventData.endTime.toISOString(),
          timeZone: eventData.timeZone || 'UTC'
        },
        attendees: eventData.attendees || [],
        location: eventData.location || '',
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'email', minutes: 30 },
            { method: 'popup', minutes: 10 }
          ]
        }
      };

      const response = await this.calendar.events.insert({
        auth: this.oauth2Client,
        calendarId: 'primary',
        resource: event,
        sendUpdates: 'all'
      });

      return response.data;
    } catch (error) {
      console.error('Error creating event:', error);
      throw new Error('Failed to create calendar event');
    }
  }

  async updateEvent(userId, eventId, eventData) {
    try {
      await this.setUserCredentials(userId);
      
      const event = {
        summary: eventData.title,
        description: eventData.description || '',
        start: {
          dateTime: eventData.startTime.toISOString(),
          timeZone: eventData.timeZone || 'UTC'
        },
        end: {
          dateTime: eventData.endTime.toISOString(),
          timeZone: eventData.timeZone || 'UTC'
        },
        attendees: eventData.attendees || [],
        location: eventData.location || ''
      };

      const response = await this.calendar.events.update({
        auth: this.oauth2Client,
        calendarId: 'primary',
        eventId: eventId,
        resource: event,
        sendUpdates: 'all'
      });

      return response.data;
    } catch (error) {
      console.error('Error updating event:', error);
      throw new Error('Failed to update calendar event');
    }
  }

  async deleteEvent(userId, eventId) {
    try {
      await this.setUserCredentials(userId);
      
      await this.calendar.events.delete({
        auth: this.oauth2Client,
        calendarId: 'primary',
        eventId: eventId,
        sendUpdates: 'all'
      });

      return true;
    } catch (error) {
      console.error('Error deleting event:', error);
      throw new Error('Failed to delete calendar event');
    }
  }

  async getEvents(userId, startTime, endTime) {
    try {
      await this.setUserCredentials(userId);
      
      const response = await this.calendar.events.list({
        auth: this.oauth2Client,
        calendarId: 'primary',
        timeMin: startTime.toISOString(),
        timeMax: endTime.toISOString(),
        singleEvents: true,
        orderBy: 'startTime'
      });

      return response.data.items || [];
    } catch (error) {
      console.error('Error getting events:', error);
      throw new Error('Failed to get calendar events');
    }
  }

  // Gmail API methods
  async sendInvite(userId, eventData, attendees) {
    try {
      await this.setUserCredentials(userId);
      
      const user = await User.findOne({ userId });
      const fromEmail = user.email;
      
      const subject = `Meeting Invitation: ${eventData.title}`;
      const htmlBody = this.generateInviteEmail(eventData, attendees);
      
      const message = {
        to: attendees.map(attendee => attendee.email).join(', '),
        from: fromEmail,
        subject: subject,
        html: htmlBody
      };

      const response = await this.gmail.users.messages.send({
        auth: this.oauth2Client,
        userId: 'me',
        resource: {
          raw: Buffer.from(
            `To: ${message.to}\r\n` +
            `From: ${message.from}\r\n` +
            `Subject: ${message.subject}\r\n` +
            `Content-Type: text/html; charset=utf-8\r\n\r\n` +
            message.html
          ).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
        }
      });

      return response.data;
    } catch (error) {
      console.error('Error sending invite:', error);
      throw new Error('Failed to send meeting invitation');
    }
  }

  // Helper methods
  calculateFreeSlots(startTime, endTime, busyTimes, duration) {
    const freeSlots = [];
    let currentTime = new Date(startTime);
    
    // Sort busy times by start time
    const sortedBusyTimes = busyTimes.sort((a, b) => 
      new Date(a.start) - new Date(b.start)
    );

    for (const busyTime of sortedBusyTimes) {
      const busyStart = new Date(busyTime.start);
      const busyEnd = new Date(busyTime.end);
      
      // If there's a gap before this busy time
      if (currentTime < busyStart) {
        const gapDuration = busyStart - currentTime;
        if (gapDuration >= duration * 60 * 1000) {
          freeSlots.push({
            start: new Date(currentTime),
            end: new Date(busyStart)
          });
        }
      }
      
      currentTime = new Date(Math.max(currentTime, busyEnd));
    }
    
    // Check for free time after the last busy period
    if (currentTime < endTime) {
      const remainingDuration = endTime - currentTime;
      if (remainingDuration >= duration * 60 * 1000) {
        freeSlots.push({
          start: new Date(currentTime),
          end: new Date(endTime)
        });
      }
    }
    
    return freeSlots;
  }

  generateInviteEmail(eventData, attendees) {
    const startTime = new Date(eventData.startTime).toLocaleString();
    const endTime = new Date(eventData.endTime).toLocaleString();
    
    return `
      <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2>Meeting Invitation</h2>
          <p><strong>Title:</strong> ${eventData.title}</p>
          <p><strong>Date & Time:</strong> ${startTime} - ${endTime}</p>
          <p><strong>Location:</strong> ${eventData.location || 'TBD'}</p>
          <p><strong>Description:</strong> ${eventData.description || 'No description provided'}</p>
          <p><strong>Attendees:</strong> ${attendees.map(a => a.email).join(', ')}</p>
          <hr>
          <p><em>This invitation was sent by ASH - AI Scheduling Helper</em></p>
        </body>
      </html>
    `;
  }
}

module.exports = new GoogleAPIService();

