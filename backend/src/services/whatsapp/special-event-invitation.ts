import { getNotificationConfig } from "../../config/notifications.js";
import type { Outing } from "../../types/outings/outing.types.js";

function calendarTimestamp(date: Date): string {
  return date.toISOString().replace(/[-:]|\.\d{3}/g, "");
}

export function specialEventInvitation(outing: Outing & { scheduled_at: Date }) {
  const start = outing.scheduled_at;
  const end = outing.ends_at ?? new Date(start.getTime() + 6 * 60 * 60 * 1000);
  const location = [outing.location_name, outing.location_area].filter(Boolean).join(", ");
  const appUrl = process.env.APP_DOWNLOAD_URL?.trim() || getNotificationConfig().deepLinkBaseUrl;
  const calendar = new URL("https://calendar.google.com/calendar/render");
  calendar.search = new URLSearchParams({
    action: "TEMPLATE",
    text: outing.title,
    dates: `${calendarTimestamp(start)}/${calendarTimestamp(end)}`,
    location,
    ctz: "Africa/Cairo",
  }).toString();
  const dateTime = new Intl.DateTimeFormat("en-GB", {
    dateStyle: "full",
    timeStyle: "short",
    timeZone: "Africa/Cairo",
  }).format(start) + " (Cairo time)";

  return {
    whatsappOptIn: true,
    specialEvent: {
      title: outing.title,
      dateTime,
      location,
      calendarUrl: calendar.toString(),
      appUrl,
    },
  };
}

export function specialEventMessage(outing: Outing & { scheduled_at: Date }): string {
  const event = specialEventInvitation(outing).specialEvent;
  return [
    `You're invited to "${event.title}"!`,
    `When: ${event.dateTime}`,
    `Where: ${event.location}`,
    `Add to Google Calendar: ${event.calendarUrl}`,
    `You can attend without the app. If you'd like to try Yalla 5roga: ${event.appUrl}`,
  ].join("\n");
}
