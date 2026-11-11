/** Recover routing metadata from the durable event key, including older rows. */
export function notificationTarget(eventKey: string | null, fallback: string) {
  const [event, id] = eventKey?.split(":", 3) ?? [];
  let type = event || fallback;
  switch (type) {
    case "attendance":
      type = "attendance_changed";
      break;
    case "outing_initial_vote_options":
      type = "outing_created";
      break;
    case "outing_invite_accepted":
      type = "outing_invite";
      break;
    case "vote_options_reset":
    case "vote_options_replace":
    case "vote_tie":
      type = "place_vote";
      break;
  }

  return {
    type,
    ...(type === "chat_message" && id ? { messageId: id } : {}),
  };
}
