const OpenAI = require('openai');
const googleService = require('./google');
const Event = require('../models/Event');
const User = require('../models/User');
const Log = require('../models/Log');

class ASHAgent {
  constructor() {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });
    
    this.systemPrompt = `You are ASH (AI Scheduling Helper), a polite, professional, and slightly futuristic AI assistant that manages calendars and schedules meetings.

Your personality:
- Polite and professional
- Slightly futuristic in tone
- Helpful and efficient
- Confident in your scheduling abilities
- Always confirm details before taking action

Your capabilities:
- Schedule meetings and events
- Reschedule existing meetings
- Cancel meetings
- Check availability
- Send meeting invitations
- Set reminders
- Parse natural language for dates and times
- Understand user intent from voice or text

Example greetings:
- "Hey there, I'm ASH. I manage your calendar so you don't have to. Want to check what's next on your schedule?"
- "Hello! I'm ASH, your AI scheduling assistant. How can I help you organize your time today?"

When scheduling:
1. Always confirm the details before creating the event
2. Check for conflicts
3. Suggest optimal times if requested
4. Send invitations to attendees
5. Set appropriate reminders

When users speak naturally about time, parse it correctly:
- "tomorrow at 3 PM" → specific date and time
- "next Friday morning" → Friday of next week, morning hours
- "in 2 hours" → current time + 2 hours
- "this afternoon" → today, afternoon hours

Always be helpful and ask clarifying questions when needed.`;

    this.tools = [
      {
        type: "function",
        function: {
          name: "getFreeSlots",
          description: "Get available time slots for scheduling",
          parameters: {
            type: "object",
            properties: {
              startDate: {
                type: "string",
                description: "Start date for checking availability (ISO string)"
              },
              endDate: {
                type: "string", 
                description: "End date for checking availability (ISO string)"
              },
              duration: {
                type: "number",
                description: "Duration in minutes (default: 60)"
              }
            },
            required: ["startDate", "endDate"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "createEvent",
          description: "Create a new calendar event",
          parameters: {
            type: "object",
            properties: {
              title: {
                type: "string",
                description: "Event title"
              },
              description: {
                type: "string",
                description: "Event description"
              },
              startTime: {
                type: "string",
                description: "Start time (ISO string)"
              },
              endTime: {
                type: "string",
                description: "End time (ISO string)"
              },
              attendees: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    email: { type: "string" },
                    name: { type: "string" }
                  }
                },
                description: "List of attendees"
              },
              location: {
                type: "string",
                description: "Event location"
              }
            },
            required: ["title", "startTime", "endTime"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "updateEvent",
          description: "Update an existing calendar event",
          parameters: {
            type: "object",
            properties: {
              eventId: {
                type: "string",
                description: "Event ID to update"
              },
              title: {
                type: "string",
                description: "Updated event title"
              },
              description: {
                type: "string",
                description: "Updated event description"
              },
              startTime: {
                type: "string",
                description: "Updated start time (ISO string)"
              },
              endTime: {
                type: "string",
                description: "Updated end time (ISO string)"
              },
              attendees: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    email: { type: "string" },
                    name: { type: "string" }
                  }
                },
                description: "Updated list of attendees"
              },
              location: {
                type: "string",
                description: "Updated event location"
              }
            },
            required: ["eventId"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "deleteEvent",
          description: "Delete a calendar event",
          parameters: {
            type: "object",
            properties: {
              eventId: {
                type: "string",
                description: "Event ID to delete"
              }
            },
            required: ["eventId"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "getUpcomingEvents",
          description: "Get upcoming events for the user",
          parameters: {
            type: "object",
            properties: {
              limit: {
                type: "number",
                description: "Number of events to retrieve (default: 10)"
              }
            }
          }
        }
      },
      {
        type: "function",
        function: {
          name: "sendInvite",
          description: "Send meeting invitation via email",
          parameters: {
            type: "object",
            properties: {
              eventId: {
                type: "string",
                description: "Event ID to send invite for"
              },
              attendees: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    email: { type: "string" },
                    name: { type: "string" }
                  }
                },
                description: "List of attendees to invite"
              }
            },
            required: ["eventId", "attendees"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "setReminder",
          description: "Set a reminder for an event",
          parameters: {
            type: "object",
            properties: {
              eventId: {
                type: "string",
                description: "Event ID to set reminder for"
              },
              minutesBefore: {
                type: "number",
                description: "Minutes before event to send reminder (default: 30)"
              }
            },
            required: ["eventId"]
          }
        }
      }
    ];
  }

  async processRequest(userId, input, isVoice = false, options = {}) {
    const startTime = Date.now();
    const { sessionId, streaming = false, streamCallback } = options;
    
    try {
      // Log the interaction
      await Log.logInteraction({
        userId,
        interactionType: isVoice ? 'voice_input' : 'text_input',
        details: {
          input,
          processingTime: 0,
          sessionId
        },
        metadata: {
          platform: 'api'
        }
      });

      const messages = [
        { role: "system", content: this.systemPrompt },
        { role: "user", content: input }
      ];

      // Add conversation context if sessionId provided
      if (sessionId) {
        const Chat = require('../models/Chat');
        const chat = await Chat.findBySession(sessionId);
        if (chat && chat.messages.length > 1) {
          // Add recent conversation context
          const recentMessages = chat.getLastMessages(6);
          messages.splice(1, 0, ...recentMessages.map(msg => ({
            role: msg.role,
            content: msg.content
          })));
        }
      }

      let finalResponse = "I'm here to help with your scheduling needs.";

      if (streaming && streamCallback) {
        // Streaming response
        const stream = await this.openai.chat.completions.create({
          model: "gpt-4",
          messages,
          tools: this.tools,
          tool_choice: "auto",
          temperature: 0.7,
          max_tokens: 1000,
          stream: true
        });

        let streamedContent = '';
        for await (const chunk of stream) {
          const content = chunk.choices[0]?.delta?.content || '';
          if (content) {
            streamedContent += content;
            streamCallback(content);
          }
        }

        finalResponse = streamedContent;
      } else {
        // Regular response
        const response = await this.openai.chat.completions.create({
          model: "gpt-4",
          messages,
          tools: this.tools,
          tool_choice: "auto",
          temperature: 0.7,
          max_tokens: 1000
        });

        const message = response.choices[0].message;
        finalResponse = message.content || finalResponse;

        // Handle tool calls
        if (message.tool_calls) {
          const toolResults = await this.executeTools(userId, message.tool_calls);
          
          // Add tool results to conversation
          messages.push(message);
          messages.push({
            role: "tool",
            content: JSON.stringify(toolResults)
          });

          // Get final response with tool results
          const finalResponseData = await this.openai.chat.completions.create({
            model: "gpt-4",
            messages,
            temperature: 0.7,
            max_tokens: 1000
          });

          finalResponse = finalResponseData.choices[0].message.content || finalResponse;
        }
      }

      // Log the response
      await Log.logInteraction({
        userId,
        interactionType: isVoice ? 'voice_response' : 'text_response',
        details: {
          input,
          output: finalResponse,
          processingTime: Date.now() - startTime,
          sessionId
        },
        metadata: {
          platform: 'api'
        }
      });

      return {
        reply: finalResponse,
        success: true,
        processingTime: Date.now() - startTime
      };

    } catch (error) {
      console.error('Error processing ASH request:', error);
      
      // Log the error
      await Log.logInteraction({
        userId,
        interactionType: 'error',
        details: {
          input,
          error: error.message,
          processingTime: Date.now() - startTime,
          sessionId
        },
        metadata: {
          platform: 'api'
        }
      });

      return {
        reply: "I apologize, but I encountered an error while processing your request. Please try again.",
        success: false,
        error: error.message,
        processingTime: Date.now() - startTime
      };
    }
  }

  async executeTools(userId, toolCalls) {
    const results = [];

    for (const toolCall of toolCalls) {
      try {
        const { name, arguments: args } = toolCall.function;
        const parsedArgs = JSON.parse(args);

        let result;
        switch (name) {
          case 'getFreeSlots':
            result = await this.getFreeSlots(userId, parsedArgs);
            break;
          case 'createEvent':
            result = await this.createEvent(userId, parsedArgs);
            break;
          case 'updateEvent':
            result = await this.updateEvent(userId, parsedArgs);
            break;
          case 'deleteEvent':
            result = await this.deleteEvent(userId, parsedArgs);
            break;
          case 'getUpcomingEvents':
            result = await this.getUpcomingEvents(userId, parsedArgs);
            break;
          case 'sendInvite':
            result = await this.sendInvite(userId, parsedArgs);
            break;
          case 'setReminder':
            result = await this.setReminder(userId, parsedArgs);
            break;
          default:
            result = { error: `Unknown tool: ${name}` };
        }

        results.push({
          tool_call_id: toolCall.id,
          result: JSON.stringify(result)
        });

      } catch (error) {
        console.error(`Error executing tool ${toolCall.function.name}:`, error);
        results.push({
          tool_call_id: toolCall.id,
          result: JSON.stringify({ error: error.message })
        });
      }
    }

    return results;
  }

  // Tool implementations
  async getFreeSlots(userId, args) {
    try {
      const { startDate, endDate, duration = 60 } = args;
      const startTime = new Date(startDate);
      const endTime = new Date(endDate);
      
      const freeSlots = await googleService.getFreeSlots(userId, startTime, endTime, duration);
      
      return {
        success: true,
        freeSlots: freeSlots.map(slot => ({
          start: slot.start.toISOString(),
          end: slot.end.toISOString(),
          duration: Math.round((slot.end - slot.start) / (1000 * 60))
        }))
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async createEvent(userId, args) {
    try {
      const { title, description, startTime, endTime, attendees, location } = args;
      
      // Create event in Google Calendar
      const googleEvent = await googleService.createEvent(userId, {
        title,
        description,
        startTime: new Date(startTime),
        endTime: new Date(endTime),
        attendees,
        location
      });

      // Save to our database
      const event = new Event({
        userId,
        googleEventId: googleEvent.id,
        title,
        description,
        startTime: new Date(startTime),
        endTime: new Date(endTime),
        attendees,
        location,
        status: 'scheduled',
        metadata: {
          createdBy: 'ash',
          originalRequest: JSON.stringify(args)
        }
      });

      await event.save();

      // Log the event creation
      await Log.logInteraction({
        userId,
        interactionType: 'event_created',
        details: {
          eventId: event._id,
          googleEventId: googleEvent.id,
          title,
          startTime,
          endTime
        }
      });

      return {
        success: true,
        eventId: event._id,
        googleEventId: googleEvent.id,
        message: `Event "${title}" created successfully`
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async updateEvent(userId, args) {
    try {
      const { eventId, ...updateData } = args;
      
      const event = await Event.findById(eventId);
      if (!event || event.userId !== userId) {
        return { success: false, error: 'Event not found' };
      }

      // Update in Google Calendar
      if (event.googleEventId) {
        await googleService.updateEvent(userId, event.googleEventId, updateData);
      }

      // Update in our database
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

      return {
        success: true,
        eventId: event._id,
        message: `Event updated successfully`
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async deleteEvent(userId, args) {
    try {
      const { eventId } = args;
      
      const event = await Event.findById(eventId);
      if (!event || event.userId !== userId) {
        return { success: false, error: 'Event not found' };
      }

      // Delete from Google Calendar
      if (event.googleEventId) {
        await googleService.deleteEvent(userId, event.googleEventId);
      }

      // Update status in our database
      event.status = 'cancelled';
      await event.save();

      // Log the deletion
      await Log.logInteraction({
        userId,
        interactionType: 'event_cancelled',
        details: {
          eventId: event._id,
          googleEventId: event.googleEventId,
          title: event.title
        }
      });

      return {
        success: true,
        eventId: event._id,
        message: `Event "${event.title}" cancelled successfully`
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getUpcomingEvents(userId, args) {
    try {
      const { limit = 10 } = args;
      const events = await Event.findUpcoming(userId, limit);
      
      return {
        success: true,
        events: events.map(event => ({
          id: event._id,
          title: event.title,
          startTime: event.startTime.toISOString(),
          endTime: event.endTime.toISOString(),
          location: event.location,
          attendees: event.attendees,
          status: event.status
        }))
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async sendInvite(userId, args) {
    try {
      const { eventId, attendees } = args;
      
      const event = await Event.findById(eventId);
      if (!event || event.userId !== userId) {
        return { success: false, error: 'Event not found' };
      }

      await googleService.sendInvite(userId, event, attendees);

      return {
        success: true,
        message: `Invitations sent to ${attendees.length} attendees`
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async setReminder(userId, args) {
    try {
      const { eventId, minutesBefore = 30 } = args;
      
      const event = await Event.findById(eventId);
      if (!event || event.userId !== userId) {
        return { success: false, error: 'Event not found' };
      }

      event.reminderTime = new Date(event.startTime.getTime() - minutesBefore * 60 * 1000);
      await event.save();

      return {
        success: true,
        message: `Reminder set for ${minutesBefore} minutes before the event`
      };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // Audio transcription using OpenAI Whisper
  async transcribeAudio(audioData) {
    try {
      // Convert base64 audio to buffer if needed
      let audioBuffer;
      if (typeof audioData === 'string') {
        audioBuffer = Buffer.from(audioData, 'base64');
      } else {
        audioBuffer = audioData;
      }

      // Create a temporary file for the audio
      const fs = require('fs');
      const path = require('path');
      const tempDir = path.join(__dirname, '../temp');
      
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }
      
      const tempFile = path.join(tempDir, `audio_${Date.now()}.webm`);
      fs.writeFileSync(tempFile, audioBuffer);

      // Transcribe using OpenAI Whisper
      const transcription = await this.openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFile),
        model: "whisper-1",
        language: "en",
        response_format: "verbose_json"
      });

      // Clean up temp file
      fs.unlinkSync(tempFile);

      return {
        text: transcription.text,
        confidence: transcription.segments?.[0]?.avg_logprob || 0.8,
        language: transcription.language,
        duration: transcription.duration
      };
    } catch (error) {
      console.error('Transcription error:', error);
      throw new Error('Failed to transcribe audio');
    }
  }

  // Generate TTS audio
  async generateTTS(text, voice = 'alloy') {
    try {
      const response = await this.openai.audio.speech.create({
        model: "tts-1",
        voice: voice,
        input: text,
        response_format: "mp3",
        speed: 1.0
      });

      // Convert response to base64
      const audioBuffer = Buffer.from(await response.arrayBuffer());
      const audioBase64 = audioBuffer.toString('base64');

      return {
        audio: audioBase64,
        format: 'mp3',
        size: audioBuffer.length,
        url: `data:audio/mp3;base64,${audioBase64}`
      };
    } catch (error) {
      console.error('TTS generation error:', error);
      throw new Error('Failed to generate speech');
    }
  }

  // Enhanced intent detection
  async detectIntent(text) {
    try {
      const response = await this.openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: `Analyze the following text and determine the user's intent. Return a JSON object with:
            - intent: "schedule", "reschedule", "cancel", "query", "other"
            - confidence: 0.0 to 1.0
            - entities: { time, date, attendees, location, title }
            - action: specific action needed
            
            Text: "${text}"`
          },
          {
            role: "user",
            content: text
          }
        ],
        temperature: 0.1,
        max_tokens: 200
      });

      const result = JSON.parse(response.choices[0].message.content);
      return result;
    } catch (error) {
      console.error('Intent detection error:', error);
      return {
        intent: 'other',
        confidence: 0.0,
        entities: {},
        action: 'none'
      };
    }
  }
}

module.exports = new ASHAgent();

