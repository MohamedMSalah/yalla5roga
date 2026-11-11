import assert from "node:assert/strict";
import test from "node:test";
import { getNotificationConfig } from "../src/config/notifications.js";
import { WhatsAppChannel } from "../src/services/notifications/channels/whatsapp.channel.js";

const defaults = getNotificationConfig();
const configured = {
  ...defaults,
  whatsapp: {
    ...defaults.whatsapp,
    provider: "meta" as const,
    accessToken: "test-token",
    phoneNumberId: "test-number-id",
  },
};
const input = {
  eventId: "group-event",
  channel: "whatsapp" as const,
  recipientPhone: "+12025550101",
  recipientUserId: null,
  payload: {
    whatsappOptIn: true,
    inviterName: "Mohamed",
    groupName: "Weekend plans",
    deepLink: "https://example.com/invite",
  },
};

test("Meta provider records acceptance only when an approved template response has a message ID", async () => {
  const channel = new WhatsAppChannel(configured, async (_url, init) => {
    const sent = JSON.parse(init?.body as string);
    assert.equal(sent.type, "template");
    assert.equal(sent.template.name, configured.whatsapp.templateName);
    assert.equal(sent.to, "12025550101");
    return Response.json({ messages: [{ id: "wamid.fixture" }] });
  });
  const result = await channel.send(input);
  assert.equal(result.status, "sent");
  assert.equal(result.providerMessageId, "wamid.fixture");

  const missing = new WhatsAppChannel(configured, async () => Response.json({}));
  assert.equal((await missing.send(input)).status, "failed");
});

test("WhatsApp never claims delivery without consent or a configured provider", async () => {
  const unusedFetch: typeof fetch = async () => assert.fail("Must not contact the provider");
  const channel = new WhatsAppChannel(configured, unusedFetch);
  const optedOut = await channel.send({ ...input, payload: { whatsappOptIn: false } });
  assert.equal(optedOut.status, "failed");
  assert.equal(optedOut.retryable, false);
  const disabled = new WhatsAppChannel({ ...defaults, whatsapp: {
    ...defaults.whatsapp, provider: "stub",
  } }, unusedFetch);
  assert.equal((await disabled.send(input)).status, "failed");
});

test("WhatsApp distinguishes provider throttling from a permanently rejected template", async () => {
  for (const [status, retryable] of [[429, true], [503, true], [400, false]] as const) {
    const channel = new WhatsAppChannel(configured, async () =>
      Response.json({ error: { message: "Fixture rejection" } }, { status }));
    const result = await channel.send(input);
    assert.equal(result.status, "failed");
    assert.equal(result.retryable, retryable);
  }
});
