import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import swaggerJsdoc from "swagger-jsdoc";

const projectRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function toPosix(value: string): string {
  return value.replaceAll("\\", "/");
}

/**
 * Prefer source files so JSDoc stays the source of truth in development.
 * Fall back to compiled output when only `dist` is present.
 */
function annotationGlobs(): string[] {
  const hasSource = fs.existsSync(path.join(projectRoot, "src", "routes"));
  const root = hasSource ? "src" : "dist";
  const ext = hasSource ? "ts" : "js";

  return [
    toPosix(path.join(projectRoot, root, `app.${ext}`)),
    toPosix(path.join(projectRoot, root, "routes", "**", `*.${ext}`)),
  ];
}

type JsonSchema = Record<string, unknown>;

function ref(name: string): JsonSchema {
  return { $ref: `#/components/schemas/${name}` };
}

function envelope(data: JsonSchema): JsonSchema {
  return {
    allOf: [
      ref("SuccessEnvelope"),
      {
        type: "object",
        required: ["data"],
        properties: { data },
      },
    ],
  };
}

function itemResponse(schemaName: string): JsonSchema {
  return envelope(ref(schemaName));
}

function listResponse(schemaName: string): JsonSchema {
  return envelope({
    type: "array",
    items: ref(schemaName),
  });
}

function errorResponse(description: string, example: string) {
  return {
    description,
    content: {
      "application/json": {
        schema: ref("ErrorResponse"),
        example: { success: false, message: example },
      },
    },
  };
}

const uuid = { type: "string", format: "uuid" };
const dateTime = { type: "string", format: "date-time" };
const firebaseUid = {
  type: "string",
  maxLength: 128,
  description: "Firebase Authentication UID",
};
const phone = {
  type: "string",
  minLength: 10,
  maxLength: 13,
  pattern: "^\\+?[0-9]+$",
  example: "+201234567890",
};
const vibeEnum = ["food", "activity", "outdoor", "movie"];
const priceLevelEnum = ["free", "budget", "moderate", "expensive", "luxury"];
const weekdayEnum = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];
const outingStatusEnum = ["upcoming", "voting", "past", "cancelled"];
const invitationStatusEnum = [
  "pending",
  "accepted",
  "declined",
  "expired",
  "revoked",
];
const occasionEnum = ["none", "birthday", "wedding"];
const attendanceEnum = ["going", "not_going", "not_voted"];
const roleEnum = ["owner", "member"];

const swaggerOptions: swaggerJsdoc.OAS3Options = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "Yalla 5roga API",
      version: "1.0.0",
      description: [
        "API documentation for the Yalla 5roga backend.",
        "",
        "Sections (in order): System, Authentication, Users, Groups, Outings, Saved Outings, Places, Notifications, Chat.",
        "Every client uses the same `/api` paths and the same response shape.",
        "",
        "Protected operations require a Firebase Authentication ID token (JWT), not an FCM device token.",
        "The auth middleware reads `Authorization: Bearer <token>` and verifies it with Firebase Admin `verifyIdToken`.",
        "In Swagger UI: click Authorize, paste the ID token only, then Execute. Swagger adds the `Bearer` prefix — do not paste `Bearer ` yourself.",
        "Email/password credentials are stored in Neon (`users.password_hash`). `POST /api/auth/signup` and `POST /api/auth/login` verify against Neon, then return a Firebase ID token via a custom-token exchange.",
        "Firebase Auth is identity-only for Google, Apple, phone OTP, and ID token issuance — not the application profile or password database.",
        "Mobile clients can also use Flutter `currentUser.getIdToken(true)`. ID tokens expire after one hour.",
        "A valid token that has never been synced still authenticates. Create the database row with `POST /api/users/sync` after Google, Apple, or phone sign-in; email/password signup already creates the profile.",
        "`GET /api/users/cuser` returns 404 until a profile row exists.",
        "",
        "Successful responses use `{ success: true, data }`.",
        "Handled errors use `{ success: false, message }`.",
      ].join("\n"),
    },
    servers: [
      {
        url: "/",
        description: "This server",
      },
    ],
    tags: [
      {
        name: "System",
        description: "Process health and database health checks",
      },
      {
        name: "Authentication",
        description:
          "Email/password against Neon; Firebase ID tokens for API authorization",
      },
      {
        name: "Users",
        description:
          "Authenticated user operations, Firebase user synchronization, and user listing/management",
      },
      {
        name: "Groups",
        description:
          "My groups, group CRUD, members, and invitations",
      },
      {
        name: "Outings",
        description:
          "My outings, outing CRUD, drafts, attendance, guests, voting options, and votes",
      },
      {
        name: "Saved Outings",
        description: "List, save, and unsave outings for the authenticated user",
      },
      {
        name: "Places",
        description:
          "Nearby places, place CRUD, opening hours, images, and prices",
      },
      {
        name: "Notifications",
        description: "List notifications and mark them as read",
      },
      {
        name: "Chat",
        description: "Outing messages and sending messages",
      },
    ],
    security: [{ bearerAuth: [] }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
          description:
            "Firebase Authentication ID token from `getIdToken()`. Paste the JWT only. Swagger sends `Authorization: Bearer <token>`. Do not paste an FCM token or a second Bearer prefix.",
        },
      },
      parameters: {
        UserId: {
          name: "id",
          in: "path",
          required: true,
          description: "Firebase UID of the user",
          schema: firebaseUid,
        },
        UuidId: {
          name: "id",
          in: "path",
          required: true,
          description: "Resource UUID",
          schema: uuid,
        },
        MemberUserId: {
          name: "userId",
          in: "path",
          required: true,
          description: "Firebase UID of the member or guest",
          schema: firebaseUid,
        },
        ChatOutingId: {
          name: "outingId",
          in: "path",
          required: true,
          description: "Outing UUID",
          schema: uuid,
        },
        InvitationId: {
          name: "invitationId",
          in: "path",
          required: true,
          description: "Group invitation UUID",
          schema: uuid,
        },
        HourId: {
          name: "hourId",
          in: "path",
          required: true,
          schema: uuid,
        },
        ImageId: {
          name: "imageId",
          in: "path",
          required: true,
          schema: uuid,
        },
        PriceId: {
          name: "priceId",
          in: "path",
          required: true,
          schema: uuid,
        },
        OptionId: {
          name: "optionId",
          in: "path",
          required: true,
          description: "Vote option UUID",
          schema: uuid,
        },
      },
      responses: {
        BadRequest: errorResponse(
          "The request body, query, or path failed validation",
          "name: name is required",
        ),
        Unauthorized: errorResponse(
          "Missing, invalid, or expired Firebase ID token",
          "Missing Bearer token",
        ),
        Forbidden: errorResponse(
          "The authenticated user is not allowed to perform this action",
          "Forbidden",
        ),
        NotFound: errorResponse(
          "The requested resource does not exist",
          "Resource not found",
        ),
        InternalServerError: errorResponse(
          "Unexpected server error",
          "Internal server error",
        ),
      },
      requestBodies: {
        Login: {
          required: true,
          content: {
            "application/json": { schema: ref("LoginRequest") },
          },
        },
        Signup: {
          required: true,
          content: {
            "application/json": { schema: ref("SignupRequest") },
          },
        },
        SyncUser: {
          required: false,
          description:
            "Optional bootstrap fields for the first sync only. Identity comes from the Bearer token. Do not send a password. Existing profile fields are never overwritten by this body.",
          content: {
            "application/json": { schema: ref("SyncUserRequest") },
          },
        },
        UpdateUser: {
          required: true,
          content: {
            "application/json": { schema: ref("UpdateUserRequest") },
          },
        },
        CreateGroup: {
          required: true,
          content: {
            "application/json": { schema: ref("CreateGroupRequest") },
          },
        },
        UpdateGroup: {
          required: true,
          content: {
            "application/json": { schema: ref("UpdateGroupRequest") },
          },
        },
        AddGroupMember: {
          required: true,
          content: {
            "application/json": { schema: ref("AddGroupMemberRequest") },
          },
        },
        InviteToGroup: {
          required: true,
          description:
            "Phone number to invite. International numbers and Egyptian numbers without a country code are accepted.",
          content: {
            "application/json": { schema: ref("InviteToGroupRequest") },
          },
        },
        SendMessage: {
          required: true,
          content: {
            "application/json": { schema: ref("SendMessageRequest") },
          },
        },
        CreateOuting: {
          required: true,
          content: {
            "application/json": { schema: ref("CreateOutingRequest") },
          },
        },
        UpdateOuting: {
          required: true,
          content: {
            "application/json": { schema: ref("UpdateOutingRequest") },
          },
        },
        Attendance: {
          required: true,
          content: {
            "application/json": { schema: ref("AttendanceRequest") },
          },
        },
        AddGuest: {
          required: true,
          content: {
            "application/json": { schema: ref("AddGuestRequest") },
          },
        },
        CreateVoteOption: {
          required: true,
          content: {
            "application/json": { schema: ref("CreateVoteOptionRequest") },
          },
        },
        CastVote: {
          required: true,
          content: {
            "application/json": { schema: ref("CastVoteRequest") },
          },
        },
        OutingDraft: {
          required: true,
          content: {
            "application/json": { schema: ref("OutingDraftRequest") },
          },
        },
        CreatePlace: {
          required: true,
          content: {
            "application/json": { schema: ref("CreatePlaceRequest") },
          },
        },
        UpdatePlace: {
          required: true,
          content: {
            "application/json": { schema: ref("UpdatePlaceRequest") },
          },
        },
        UpsertPlaceHour: {
          required: true,
          content: {
            "application/json": { schema: ref("UpsertPlaceHourRequest") },
          },
        },
        CreatePlaceImage: {
          required: true,
          content: {
            "application/json": { schema: ref("CreatePlaceImageRequest") },
          },
        },
        CreatePlacePrice: {
          required: true,
          content: {
            "application/json": { schema: ref("CreatePlacePriceRequest") },
          },
        },
      },
      schemas: {
        SuccessEnvelope: {
          type: "object",
          required: ["success"],
          properties: {
            success: { type: "boolean", example: true },
          },
        },
        ErrorResponse: {
          type: "object",
          required: ["success", "message"],
          properties: {
            success: { type: "boolean", example: false },
            message: { type: "string" },
          },
        },
        HealthOk: {
          type: "object",
          required: ["success", "message", "database"],
          properties: {
            success: { type: "boolean", example: true },
            message: { type: "string", example: "OK" },
            database: { type: "string", example: "connected" },
          },
        },
        HealthError: {
          type: "object",
          required: ["success", "message", "database"],
          properties: {
            success: { type: "boolean", example: false },
            message: {
              type: "string",
              example: "Database connection failed",
            },
            database: { type: "string", example: "disconnected" },
            error: { type: "string" },
          },
        },
        LoginRequest: {
          type: "object",
          required: ["email", "password"],
          properties: {
            email: { type: "string", format: "email", maxLength: 254 },
            password: { type: "string", minLength: 6, maxLength: 128 },
          },
        },
        SignupRequest: {
          type: "object",
          required: ["name", "email", "password", "phone"],
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
            email: { type: "string", format: "email", maxLength: 254 },
            password: { type: "string", minLength: 6, maxLength: 128 },
            phoneNumber: {
              ...phone,
              description: "Accepted alias of phone",
            },
            phone: phone,
          },
          description:
            "Provide phone or phoneNumber. The phone is stored on the profile but is not verified.",
        },
        AuthSession: {
          type: "object",
          required: ["idToken", "refreshToken", "expiresIn", "uid"],
          properties: {
            idToken: {
              type: "string",
              description: "Firebase Authentication ID token (JWT)",
            },
            refreshToken: { type: "string" },
            expiresIn: {
              type: "string",
              description: "ID token lifetime in seconds",
              example: "3600",
            },
            uid: firebaseUid,
            user: {
              allOf: [ref("User")],
              nullable: true,
              description:
                "Neon profile without credential fields. Present after email/password signup or login when a password_hash row exists.",
            },
          },
        },
        AuthSessionResponse: itemResponse("AuthSession"),
        SyncUserRequest: {
          type: "object",
          properties: {
            name: {
              type: "string",
              minLength: 1,
              maxLength: 200,
              description:
                "Optional create-time bootstrap only. Ignored when a profile already exists.",
            },
            email: {
              type: "string",
              format: "email",
              maxLength: 254,
              description:
                "Optional create-time fallback when the token has no email. Never overwrites a stored email.",
            },
            phoneNumber: {
              ...phone,
              description:
                "Alias of phone. Unverified. Ignored when a profile phone already exists.",
            },
            phone: {
              ...phone,
              description:
                "Accepted alias of phoneNumber. Unverified. Never treated as Firebase-verified.",
            },
            image_url: {
              type: "string",
              format: "uri",
              maxLength: 2048,
              nullable: true,
              description:
                "Optional create-time bootstrap only. Ignored when a profile already exists.",
            },
          },
          description:
            "All fields optional. Sync creates a minimal profile on first call and returns the existing profile afterward without overwriting name, phone, email, or image_url from the body. Send phone or phoneNumber, not conflicting values of both.",
        },
        InvitationSyncState: {
          type: "object",
          required: ["phoneVerified", "status", "claimedGroupIds"],
          properties: {
            phoneVerified: { type: "boolean" },
            status: {
              type: "string",
              enum: ["claimed", "none", "phone_verification_required"],
              description:
                "phone_verification_required means no verified phone is on the token. It includes no invitation records.",
            },
            claimedGroupIds: {
              type: "array",
              items: uuid,
            },
          },
        },
        SyncUserResponse: {
          allOf: [
            ref("SuccessEnvelope"),
            {
              type: "object",
              required: ["data", "invitations"],
              properties: {
                data: ref("User"),
                invitations: ref("InvitationSyncState"),
              },
            },
          ],
        },
        UpdateUserRequest: {
          type: "object",
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
            email: {
              type: "string",
              format: "email",
              maxLength: 254,
              nullable: true,
            },
            phoneNumber: phone,
            phone: phone,
            image_url: {
              type: "string",
              format: "uri",
              maxLength: 2048,
              nullable: true,
            },
          },
        },
        User: {
          type: "object",
          required: ["id", "name", "created_at", "updated_at"],
          properties: {
            id: firebaseUid,
            name: { type: "string", maxLength: 30 },
            phone: {
              type: "string",
              maxLength: 16,
              nullable: true,
              description: "E.164 phone when one is stored. Null for Google or Apple until a phone is verified.",
            },
            email: { type: "string", format: "email", nullable: true },
            image_url: { type: "string", nullable: true },
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        UserResponse: itemResponse("User"),
        UserListResponse: listResponse("User"),
        CreateGroupRequest: {
          type: "object",
          required: ["name"],
          properties: {
            name: { type: "string", minLength: 3, maxLength: 30 },
            bio: { type: "string", maxLength: 160 },
            image_url: {
              type: "string",
              format: "uri",
              maxLength: 2048,
              description: "Optional. Omit or send empty string to use the default cover.",
            },
          },
        },
        UpdateGroupRequest: {
          type: "object",
          properties: {
            name: { type: "string", minLength: 3, maxLength: 30 },
            bio: { type: "string", maxLength: 160 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
          },
        },
        AddGroupMemberRequest: {
          type: "object",
          required: ["phoneNumber"],
          properties: {
            phoneNumber: phone,
            role: { type: "string", enum: roleEnum, default: "member" },
          },
        },
        Group: {
          type: "object",
          required: [
            "id",
            "name",
            "bio",
            "image_url",
            "created_by",
            "created_at",
            "updated_at",
          ],
          properties: {
            id: uuid,
            name: { type: "string", maxLength: 30 },
            bio: { type: "string", maxLength: 160 },
            image_url: { type: "string" },
            created_by: firebaseUid,
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        GroupResponse: itemResponse("Group"),
        GroupListResponse: listResponse("Group"),
        GroupMember: {
          type: "object",
          required: ["group_id", "user_id", "role", "joined_at"],
          properties: {
            group_id: uuid,
            user_id: firebaseUid,
            role: { type: "string", enum: roleEnum },
            joined_at: dateTime,
          },
        },
        GroupMemberResponse: itemResponse("GroupMember"),
        GroupMemberListResponse: listResponse("GroupMember"),
        InviteToGroupRequest: {
          type: "object",
          required: ["phoneNumber"],
          properties: {
            phoneNumber: {
              type: "string",
              minLength: 8,
              maxLength: 20,
              example: "+201001234567",
            },
          },
        },
        GroupInvitationResult: {
          type: "object",
          required: ["outcome", "invitation_id", "whatsapp_url"],
          properties: {
            outcome: {
              type: "string",
              enum: ["member_added", "invited"],
            },
            invitation_id: { ...uuid, nullable: true },
            whatsapp_url: {
              type: "string",
              format: "uri",
              nullable: true,
              description:
                "WhatsApp click-to-chat URL. Present for a new invitee. Generating it does not send the message.",
            },
            status: {
              type: "string",
              enum: invitationStatusEnum,
            },
            invited_phone: {
              type: "string",
              description: "Normalized E.164 phone number",
              example: "+201001234567",
            },
            member: ref("GroupMember"),
          },
        },
        GroupInvitationResponse: itemResponse("GroupInvitationResult"),
        GroupInvitationRecord: {
          type: "object",
          properties: {
            id: uuid,
            group_id: uuid,
            invited_by_user_id: firebaseUid,
            invited_phone: { type: "string", example: "+201001234567" },
            user_id: { ...firebaseUid, nullable: true },
            status: { type: "string", enum: invitationStatusEnum },
            expires_at: dateTime,
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        GroupInvitationRecordResponse: itemResponse("GroupInvitationRecord"),
        GroupInvitationConflict: {
          allOf: [
            ref("ErrorResponse"),
            {
              type: "object",
              properties: {
                data: {
                  type: "object",
                  properties: {
                    outcome: {
                      type: "string",
                      enum: ["already_pending", "already_member"],
                    },
                    invitation_id: { ...uuid, nullable: true },
                    whatsapp_url: { type: "string", format: "uri", nullable: true },
                    status: { type: "string", enum: ["pending"] },
                    member: ref("GroupMember"),
                  },
                },
              },
            },
          ],
        },
        SendMessageRequest: {
          type: "object",
          required: ["text"],
          properties: {
            text: { type: "string", minLength: 1, maxLength: 2000 },
            clientMessageId: {
              ...uuid,
              description:
                "Optional client-generated idempotency key. Resending with the same value returns the stored message instead of creating a duplicate.",
            },
          },
        },
        ChatMessage: {
          type: "object",
          required: [
            "id",
            "outing_id",
            "sender_id",
            "text",
            "delivery_status",
            "sent_at",
          ],
          properties: {
            id: uuid,
            outing_id: uuid,
            sender_id: firebaseUid,
            text: { type: "string", maxLength: 2000 },
            delivery_status: {
              type: "string",
              enum: ["pending", "sent", "delivered", "seen"],
              deprecated: true,
              description:
                "Deprecated. A group chat cannot carry a single delivery status; derive seen state from chat_reads.",
            },
            client_message_id: { ...uuid, nullable: true },
            sent_at: dateTime,
          },
        },
        ChatMessageResponse: itemResponse("ChatMessage"),
        ChatMessageListResponse: listResponse("ChatMessage"),
        Notification: {
          type: "object",
          required: [
            "id",
            "user_id",
            "body",
            "type",
            "action_required",
            "is_read",
            "created_at",
          ],
          properties: {
            id: uuid,
            user_id: firebaseUid,
            body: { type: "string", maxLength: 500 },
            image_url: { type: "string", nullable: true },
            type: {
              type: "string",
              enum: ["outing", "group", "chat", "vote", "invitation", "system"],
            },
            outing_id: { ...uuid, nullable: true },
            group_id: { ...uuid, nullable: true },
            action_required: { type: "boolean" },
            is_read: { type: "boolean" },
            created_at: dateTime,
          },
        },
        NotificationResponse: itemResponse("Notification"),
        NotificationListResponse: listResponse("Notification"),
        CreateOutingRequest: {
          type: "object",
          required: ["title"],
          description:
            "Group outings require group_id and occasion 'none' (default). Special events omit group_id and must set occasion to 'birthday' or 'wedding'.",
          properties: {
            title: { type: "string", minLength: 3, maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
            status: { type: "string", enum: outingStatusEnum },
            occasion: { type: "string", enum: occasionEnum },
            scheduled_at: { ...dateTime, nullable: true },
            ends_at: {
              ...dateTime,
              nullable: true,
              description: "Must be later than scheduled_at. Defaults to scheduled_at + 6h for completion.",
            },
            location_place_id: { ...uuid, nullable: true },
            location_name: { type: "string", maxLength: 100, nullable: true },
            location_area: { type: "string", maxLength: 100, nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            vote_deadline_hours: {
              type: "integer",
              minimum: 1,
              maximum: 72,
              nullable: true,
            },
            vote_ends_at: { ...dateTime, nullable: true },
          },
        },
        UpdateOutingRequest: {
          type: "object",
          description:
            "When changing group_id or occasion, the same group/special-event pairing rules as create apply.",
          properties: {
            title: { type: "string", minLength: 3, maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
            status: { type: "string", enum: outingStatusEnum },
            occasion: { type: "string", enum: occasionEnum },
            scheduled_at: { ...dateTime, nullable: true },
            ends_at: {
              ...dateTime,
              nullable: true,
              description: "Must be later than scheduled_at.",
            },
            location_place_id: { ...uuid, nullable: true },
            location_name: { type: "string", maxLength: 100, nullable: true },
            location_area: { type: "string", maxLength: 100, nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            vote_deadline_hours: { type: "integer", nullable: true },
            vote_ends_at: { ...dateTime, nullable: true },
            vote_finalized: { type: "boolean" },
            suggested_by_user_id: { ...firebaseUid, nullable: true },
          },
        },
        Outing: {
          type: "object",
          properties: {
            id: uuid,
            title: { type: "string", maxLength: 20 },
            image_url: { type: "string" },
            group_id: { ...uuid, nullable: true },
            created_by: firebaseUid,
            status: { type: "string", enum: outingStatusEnum },
            occasion: { type: "string", enum: occasionEnum },
            scheduled_at: { ...dateTime, nullable: true },
            ends_at: { ...dateTime, nullable: true },
            location_place_id: { ...uuid, nullable: true },
            location_name: { type: "string", nullable: true },
            location_area: { type: "string", nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            vote_deadline_hours: { type: "integer", nullable: true },
            vote_ends_at: { ...dateTime, nullable: true },
            vote_finalized: { type: "boolean" },
            suggested_by_user_id: { ...firebaseUid, nullable: true },
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        OutingResponse: itemResponse("Outing"),
        OutingListResponse: listResponse("Outing"),
        AttendanceRequest: {
          type: "object",
          required: ["status"],
          properties: {
            status: { type: "string", enum: attendanceEnum },
          },
        },
        Attendance: {
          type: "object",
          required: ["outing_id", "user_id", "status", "updated_at"],
          properties: {
            outing_id: uuid,
            user_id: firebaseUid,
            status: { type: "string", enum: attendanceEnum },
            updated_at: dateTime,
          },
        },
        AttendanceResponse: itemResponse("Attendance"),
        AttendanceListResponse: listResponse("Attendance"),
        AddGuestRequest: {
          type: "object",
          required: ["user_id"],
          properties: { user_id: firebaseUid },
        },
        Guest: {
          type: "object",
          required: ["outing_id", "user_id", "invited_at"],
          properties: {
            outing_id: uuid,
            user_id: firebaseUid,
            invited_at: dateTime,
          },
        },
        GuestResponse: itemResponse("Guest"),
        GuestListResponse: listResponse("Guest"),
        CreateVoteOptionRequest: {
          type: "object",
          required: ["label"],
          properties: {
            place_id: { ...uuid, nullable: true },
            label: { type: "string", minLength: 1, maxLength: 100 },
            area: { type: "string", maxLength: 100 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            vibe: { type: "string", enum: vibeEnum },
            latitude: { type: "number", nullable: true },
            longitude: { type: "number", nullable: true },
            sort_order: { type: "integer" },
          },
        },
        VoteOption: {
          type: "object",
          properties: {
            id: uuid,
            outing_id: uuid,
            place_id: { ...uuid, nullable: true },
            label: { type: "string" },
            area: { type: "string" },
            image_url: { type: "string" },
            vibe: { type: "string", enum: vibeEnum },
            latitude: { type: "number", nullable: true },
            longitude: { type: "number", nullable: true },
            sort_order: { type: "integer" },
          },
        },
        VoteOptionResponse: itemResponse("VoteOption"),
        VoteOptionListResponse: listResponse("VoteOption"),
        CastVoteRequest: {
          type: "object",
          required: ["option_id"],
          properties: { option_id: uuid },
        },
        Vote: {
          type: "object",
          required: ["outing_id", "user_id", "option_id", "created_at"],
          properties: {
            outing_id: uuid,
            user_id: firebaseUid,
            option_id: uuid,
            created_at: dateTime,
          },
        },
        VoteResponse: itemResponse("Vote"),
        VoteListResponse: listResponse("Vote"),
        OutingDraftRequest: {
          type: "object",
          properties: {
            title: { type: "string", maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
            occasion: { type: "string", enum: occasionEnum },
            special_event: { type: "boolean" },
            vibe: { type: "string", enum: vibeEnum },
            scheduled_date: {
              type: "string",
              format: "date-time",
              nullable: true,
              description: "Coerced to a date. Date-only strings are accepted.",
            },
            scheduled_hour: {
              type: "integer",
              minimum: 0,
              maximum: 23,
              nullable: true,
            },
            scheduled_minute: {
              type: "integer",
              minimum: 0,
              maximum: 59,
              nullable: true,
            },
            location_name: { type: "string", maxLength: 100, nullable: true },
            location_area: { type: "string", maxLength: 100, nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            let_vote: { type: "boolean" },
            vote_deadline_hours: { type: "integer", nullable: true },
            guest_ids: {
              description: "Stored as JSON. Typically an array of user ids.",
            },
            selected_places: {
              description: "Stored as JSON. Typically an array of place selections.",
            },
          },
        },
        OutingDraft: {
          type: "object",
          properties: {
            id: uuid,
            user_id: firebaseUid,
            title: { type: "string" },
            image_url: { type: "string" },
            group_id: { ...uuid, nullable: true },
            occasion: { type: "string", enum: occasionEnum },
            special_event: { type: "boolean" },
            vibe: { type: "string", enum: vibeEnum },
            scheduled_date: { type: "string", format: "date", nullable: true },
            scheduled_hour: { type: "integer", nullable: true },
            scheduled_minute: { type: "integer", nullable: true },
            location_name: { type: "string", nullable: true },
            location_area: { type: "string", nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            let_vote: { type: "boolean" },
            vote_deadline_hours: { type: "integer", nullable: true },
            guest_ids: {},
            selected_places: {},
            updated_at: dateTime,
            created_at: dateTime,
          },
        },
        OutingDraftResponse: itemResponse("OutingDraft"),
        OutingDraftListResponse: listResponse("OutingDraft"),
        SavedOuting: {
          type: "object",
          required: ["user_id", "outing_id", "saved_at"],
          properties: {
            user_id: firebaseUid,
            outing_id: uuid,
            saved_at: dateTime,
          },
        },
        SavedOutingResponse: itemResponse("SavedOuting"),
        SavedOutingListResponse: listResponse("SavedOuting"),
        CreatePlaceRequest: {
          type: "object",
          required: ["name"],
          properties: {
            name: { type: "string", minLength: 1, maxLength: 100 },
            area: { type: "string", maxLength: 100 },
            vibe: { type: "string", enum: vibeEnum },
            description: { type: "string", maxLength: 1000 },
            cover_image_url: { type: "string", format: "uri", maxLength: 2048 },
            price_level: { type: "string", enum: priceLevelEnum },
            price_min: { type: "number", minimum: 0, nullable: true },
            price_max: { type: "number", minimum: 0, nullable: true },
            currency: { type: "string", minLength: 3, maxLength: 3, example: "EGP" },
            latitude: { type: "number", nullable: true },
            longitude: { type: "number", nullable: true },
            featured: { type: "boolean" },
          },
        },
        UpdatePlaceRequest: {
          type: "object",
          description: "Any subset of the create-place fields.",
          properties: {
            name: { type: "string", minLength: 1, maxLength: 100 },
            area: { type: "string", maxLength: 100 },
            vibe: { type: "string", enum: vibeEnum },
            description: { type: "string", maxLength: 1000 },
            cover_image_url: { type: "string", format: "uri", maxLength: 2048 },
            price_level: { type: "string", enum: priceLevelEnum },
            price_min: { type: "number", minimum: 0, nullable: true },
            price_max: { type: "number", minimum: 0, nullable: true },
            currency: { type: "string", minLength: 3, maxLength: 3 },
            latitude: { type: "number", nullable: true },
            longitude: { type: "number", nullable: true },
            featured: { type: "boolean" },
          },
        },
        Place: {
          type: "object",
          properties: {
            id: uuid,
            name: { type: "string" },
            area: { type: "string" },
            vibe: { type: "string", enum: vibeEnum },
            description: { type: "string" },
            cover_image_url: { type: "string" },
            price_level: { type: "string", enum: priceLevelEnum },
            price_min: {
              type: "string",
              nullable: true,
              description: "Decimal serialized as a string",
              example: "50.00",
            },
            price_max: {
              type: "string",
              nullable: true,
              description: "Decimal serialized as a string",
            },
            currency: { type: "string", example: "EGP" },
            latitude: { type: "number", nullable: true },
            longitude: { type: "number", nullable: true },
            featured: { type: "boolean" },
            is_active: {
              type: "boolean",
              description: "Inactive places are hidden from listings and nearby search",
            },
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        PlaceResponse: itemResponse("Place"),
        PlaceListResponse: listResponse("Place"),
        NearbyPlace: {
          type: "object",
          properties: {
            id: uuid,
            name: { type: "string" },
            area: { type: "string" },
            vibe: { type: "string", enum: vibeEnum },
            cover_image_url: { type: "string" },
            price_level: { type: "string", enum: priceLevelEnum },
            price_min: { type: "string", nullable: true },
            price_max: { type: "string", nullable: true },
            currency: { type: "string", example: "EGP" },
            latitude: { type: "number" },
            longitude: { type: "number" },
            distance_km: { type: "number", example: 1.73 },
          },
        },
        NearbyPlaceListResponse: listResponse("NearbyPlace"),
        UpsertPlaceHourRequest: {
          type: "object",
          required: ["day"],
          description:
            "When is_closed is false or omitted, opens_at and closes_at are required (HH:mm, HH:mm:ss, or ISO datetime). When is_closed is true, times are cleared.",
          properties: {
            day: { type: "string", enum: weekdayEnum },
            opens_at: {
              type: "string",
              nullable: true,
              example: "09:00:00",
              description: "HH:mm, HH:mm:ss, or ISO datetime",
            },
            closes_at: {
              type: "string",
              nullable: true,
              example: "23:00:00",
              description: "HH:mm, HH:mm:ss, or ISO datetime",
            },
            is_closed: { type: "boolean" },
          },
        },
        PlaceHour: {
          type: "object",
          properties: {
            id: uuid,
            place_id: uuid,
            day: { type: "string", enum: weekdayEnum },
            opens_at: { type: "string", nullable: true, example: "09:00:00" },
            closes_at: { type: "string", nullable: true, example: "23:00:00" },
            is_closed: { type: "boolean" },
          },
        },
        PlaceHourResponse: itemResponse("PlaceHour"),
        PlaceHourListResponse: listResponse("PlaceHour"),
        CreatePlaceImageRequest: {
          type: "object",
          required: ["image_url"],
          properties: {
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            caption: { type: "string", maxLength: 200, nullable: true },
            sort_order: { type: "integer" },
          },
        },
        PlaceImage: {
          type: "object",
          properties: {
            id: uuid,
            place_id: uuid,
            image_url: { type: "string" },
            caption: { type: "string", nullable: true },
            sort_order: { type: "integer" },
          },
        },
        PlaceImageResponse: itemResponse("PlaceImage"),
        PlaceImageListResponse: listResponse("PlaceImage"),
        CreatePlacePriceRequest: {
          type: "object",
          required: ["label", "amount"],
          properties: {
            label: { type: "string", minLength: 1, maxLength: 80 },
            amount: { type: "number", minimum: 0 },
            currency: { type: "string", minLength: 3, maxLength: 3, example: "EGP" },
          },
        },
        PlacePrice: {
          type: "object",
          properties: {
            id: uuid,
            place_id: uuid,
            label: { type: "string" },
            amount: {
              type: "string",
              description: "Decimal serialized as a string",
              example: "120.00",
            },
            currency: { type: "string", example: "EGP" },
          },
        },
        PlacePriceResponse: itemResponse("PlacePrice"),
        PlacePriceListResponse: listResponse("PlacePrice"),
      },
    },
  },
  apis: annotationGlobs(),
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);
