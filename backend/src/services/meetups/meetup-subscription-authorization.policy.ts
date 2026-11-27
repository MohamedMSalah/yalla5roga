import { prisma } from "../../config/database.js";
import { isDeletedAccount } from "../users/account-deletion-access.js";

type SubscriptionState = {
  input_version: number;
  status: "ACTIVE" | "CANCELLED" | "EXPIRED";
  active: boolean;
  audience: string[];
  attempt: number | null;
  calculation_status: string | null;
};

export class MeetupSubscriptionAuthorizationPolicy {
  async current(sessionId: string): Promise<SubscriptionState | undefined> {
    // Take one database snapshot of access and version. This mirrors the REST scope
    // and keeps location consent separate from the right to see group readiness.
    const [state] = await prisma.$queryRaw<SubscriptionState[]>`
      SELECT s.input_version, s.status::text,
        s.status = 'ACTIVE' AND s.expires_at > statement_timestamp() AS active,
        CASE
          WHEN s.session_type = 'STANDALONE' AND s.group_id IS NULL AND s.outing_id IS NULL
            THEN ARRAY[s.created_by_user_id]
          WHEN s.session_type = 'GROUP' AND s.group_id IS NOT NULL AND
            (s.outing_id IS NULL OR EXISTS (SELECT 1 FROM outings o WHERE o.id = s.outing_id AND o.group_id = s.group_id))
            THEN ARRAY(SELECT m.user_id FROM group_members m WHERE m.group_id = s.group_id)
          ELSE ARRAY[]::varchar[]
        END AS audience,
        latest.attempt, latest.calculation_status::text
      FROM meetup_sessions s
      LEFT JOIN LATERAL (
        SELECT c.attempt, c.calculation_status FROM meetup_calculations c
        WHERE c.meetup_session_id = s.id AND c.input_version = s.input_version
        ORDER BY c.attempt DESC LIMIT 1
      ) latest ON true
      WHERE s.id = ${sessionId}::uuid
    `;
    return state;
  }

  permits(state: SubscriptionState | undefined, uid: unknown): state is SubscriptionState {
    return typeof uid === "string" && !isDeletedAccount(uid) && (state?.audience.includes(uid) ?? false);
  }
}
