import assert from "node:assert/strict";
import test from "node:test";
import { getNotificationConfig } from "../src/config/notifications.js";
import { WhatsAppChannel } from "../src/services/notifications/channels/whatsapp.channel.js";
import { specialEventInvitation, specialEventMessage } from "../src/services/whatsapp/special-event-invitation.js";
import type { Outing } from "../src/types/outings/outing.types.js";

const outing = {
  title: "Birthday & cake",
  scheduled_at: new Date("2026-11-09T17:30:00Z"),
  ends_at: new Date("2026-11-09T20:30:00Z"),
  location_name: "Café",
  location_area: "Cairo",
} as Outing & { scheduled_at: Date };

test("special-event invite contains calendar dates, venue and optional app link", () => {
  const { specialEvent } = specialEventInvitation(outing);
  const calendar = new URL(specialEvent.calendarUrl);
  assert.equal(calendar.hostname, "calendar.google.com");
  assert.equal(calendar.searchParams.get("text"), outing.title);
  assert.equal(calendar.searchParams.get("dates"), "20261109T173000Z/20261109T203000Z");
  assert.equal(calendar.searchParams.get("location"), "Café, Cairo");
  assert.match(specialEventMessage(outing), /attend without the app/);
  assert.ok(specialEventMessage(outing).includes(specialEvent.appUrl));
});

test("WhatsApp uses the special-event template only after recipient opt-in", async () => {
  const config = getNotificationConfig();
  config.whatsapp.provider = "meta";
  config.whatsapp.accessToken = "test-only";
  config.whatsapp.phoneNumberId = "test-sender";
  config.whatsapp.specialEventTemplateName = "event_test";
  const requests: Array<{ template: { name: string; components: Array<{ parameters: unknown[] }> } }> = [];
  const fetchImpl: typeof fetch = async (_, options) => {
    requests.push(JSON.parse(String(options?.body)));
    return Response.json({ messages: [{ id: "fake-id" }] });
  };
  const channel = new WhatsAppChannel(config, fetchImpl);
  const input = {
    channel: "whatsapp" as const,
    eventId: "test",
    recipientPhone: "+201001234567",
    recipientUserId: null,
    payload: specialEventInvitation(outing),
  };
  const denied = await channel.send({ ...input, payload: { ...input.payload, whatsappOptIn: false } });
  assert.equal(denied.status, "failed");
  assert.equal(requests.length, 0);
  assert.equal((await channel.send(input)).status, "sent");
  assert.equal(requests[0]?.template.name, "event_test");
  assert.equal(requests[0]?.template.components[0]?.parameters.length, 5);
});
