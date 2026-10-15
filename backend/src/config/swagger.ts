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
const outingStatusEnum = ["upcoming", "voting", "past"];
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
        "Routes are grouped by resource: Users, Groups, Outings, Saved Outings, Places, Notifications, and Chat.",
        "Every client uses the same `/api` paths and the same response shape.",
        "",
        "Protected operations require a Firebase Authentication ID token.",
        "The existing auth middleware reads the `Authorization: Bearer <token>` header and verifies it with Firebase Admin `verifyIdToken`.",
        "In Swagger UI, use Authorize and paste the ID token only. Swagger adds the Bearer prefix.",
        "Passwords are handled by Firebase and are never accepted by these endpoints.",
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
      { name: "System", description: "Process and database health" },
      { name: "Users", description: "User profiles" },
      { name: "Groups", description: "Groups and membership" },
      { name: "Outings", description: "Outings, drafts, guests, attendance, and voting" },
      { name: "Saved Outings", description: "Outings saved by the authenticated user" },
      { name: "Places", description: "Places and their hours, images, and prices" },
      { name: "Notifications", description: "Notifications" },
      { name: "Chat", description: "Outing chat" },
    ],
    security: [{ bearerAuth: [] }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "Firebase ID token",
          description:
            "Firebase Authentication ID token. Send as `Authorization: Bearer <token>`. Verified by the existing auth middleware.",
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
        SyncUser: {
          required: true,
          description:
            "Profile written after Firebase sign-up or sign-in. Do not send a password.",
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
        SyncUserRequest: {
          type: "object",
          required: ["name", "email"],
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
            email: { type: "string", format: "email", maxLength: 254 },
            phoneNumber: phone,
            phone: {
              ...phone,
              description: "Accepted alias of phoneNumber",
            },
            image_url: {
              type: "string",
              format: "uri",
              maxLength: 2048,
              nullable: true,
            },
          },
          description:
            "Phone is optional. Google and Apple sign-in can omit it. A phone in this body is not treated as verified.",
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
          required: ["name", "image_url"],
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
            bio: { type: "string", maxLength: 160 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
          },
        },
        UpdateGroupRequest: {
          type: "object",
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
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
              enum: ["pending", "accepted", "expired", "revoked"],
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
            },
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
          properties: {
            title: { type: "string", minLength: 1, maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
            status: { type: "string", enum: outingStatusEnum },
            occasion: { type: "string", enum: occasionEnum },
            scheduled_at: { ...dateTime, nullable: true },
            location_place_id: { ...uuid, nullable: true },
            location_name: { type: "string", maxLength: 100, nullable: true },
            location_area: { type: "string", maxLength: 100, nullable: true },
            location_latitude: { type: "number", nullable: true },
            location_longitude: { type: "number", nullable: true },
            vote_deadline_hours: { type: "integer", nullable: true },
            vote_ends_at: { ...dateTime, nullable: true },
          },
        },
        UpdateOutingRequest: {
          type: "object",
          properties: {
            title: { type: "string", minLength: 1, maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
            status: { type: "string", enum: outingStatusEnum },
            occasion: { type: "string", enum: occasionEnum },
            scheduled_at: { ...dateTime, nullable: true },
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
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        PlaceResponse: itemResponse("Place"),
        PlaceListResponse: listResponse("Place"),
        UpsertPlaceHourRequest: {
          type: "object",
          required: ["day"],
          properties: {
            day: { type: "string", enum: weekdayEnum },
            opens_at: { ...dateTime, nullable: true },
            closes_at: { ...dateTime, nullable: true },
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
