import { notification_event_type } from "@prisma/client";
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
const outingStatusEnum = ["draft", "voting", "confirmed", "cancelled", "past"];
const invitationStatusEnum = [
  "pending",
  "accepted",
  "declined",
  "expired",
  "revoked",
];
const occasionEnum = ["none", "birthday", "wedding"];
const outingTypeEnum = ["group", "special_event"];
const attendanceEnum = ["going", "not_going", "maybe"];
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
        "Sections (in order): System, Authentication, Users, Groups, Group Invitations, Invitations, Outings, Saved Outings, Places, Notifications, Chat, Media.",
        "Every client uses the same `/api` paths and the same response shape.",
        "",
        "Protected operations require a Firebase Authentication ID token (JWT), not an FCM device token.",
        "The auth middleware reads `Authorization: Bearer <token>` and verifies it with Firebase Admin `verifyIdToken`.",
        "In Swagger UI: click Authorize, paste the ID token only, then Execute. Swagger adds the `Bearer` prefix — do not paste `Bearer ` yourself.",
        "Neon PostgreSQL is the only application data store (profiles, passwords, groups, outings, etc.).",
        "Phone/password credentials are stored in Neon (`users.password_hash`). Canonical clients call `POST /api/auth/signup` and `POST /api/auth/login`, which return `idToken` + `customToken`.",
        "Firebase Auth is identity-only: a UID, verified phone credential and ID tokens. Signup verifies phoneVerificationToken and retains its OTP UID. Application profiles and passwords stay in Neon.",
        "POST /api/users/sync links verified-phone pending invitations without accepting them. An optional recent phoneVerificationToken can repair an unused legacy OTP identity without merging registered accounts.",
        "Mobile clients can also use Flutter `currentUser.getIdToken(true)`. ID tokens expire after one hour.",
        "Authorize with a Firebase phone OTP ID token or the ID token returned by signup or login. Sync a new phone identity before accessing account resources.",
        "`GET /api/users/cuser` returns 404 until a Neon profile row exists.",
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
          "Phone/password against Neon with Firebase OTP proof at signup",
      },
      {
        name: "Users",
        description:
          "Authenticated user operations, Firebase sync, FCM device tokens, and user listing/management",
      },
      {
        name: "Groups",
        description: "My groups and group CRUD",
      },
      {
        name: "Group Members",
        description: "Group membership list, add, and remove",
      },
      {
        name: "Group Invitations",
        description: "Add by phone and revoke pending phone memberships",
      },
      {
        name: "Invitations",
        description:
          "Invitee inbox: list pending group invitations, accept, and decline",
      },
      {
        name: "Outings",
        description: "My outings, outing CRUD, and cancel",
      },
      {
        name: "Outing Drafts",
        description: "Create, list, update, and delete outing drafts",
      },
      {
        name: "Saved Outings",
        description: "List, save, and unsave outings for the authenticated user",
      },
      {
        name: "Outing Participants",
        description: "Attendance, guests, and outing invitation accept/decline",
      },
      {
        name: "Outing Voting",
        description: "Vote options, votes, voting state, and tie-break",
      },
      {
        name: "Outing Chat",
        description: "Outing messages and mark-read under /api/outings/{outingId}",
      },
      {
        name: "Places",
        description:
          "Nearby places, place CRUD, saved places, opening hours, images, and prices",
      },
      {
        name: "Notifications",
        description: "List notifications and mark them as read",
      },
      {
        name: "Media",
        description:
          "Direct-to-R2 media uploads, access-checked delivery URLs, and owner deletes. Private media (profiles, groups, outings, chat) is only served through short-lived signed URLs; public place media uses the Cloudflare CDN.",
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
        Conflict: errorResponse("Resource changed or conflicts with existing state", "Draft changed; reload before saving"),
        TooManyRequests: errorResponse("HTTP API request limit exceeded; honor Retry-After", "Too many requests. Try again later."),
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
        MediaUploadRequest: {
          required: true,
          content: {
            "application/json": { schema: ref("MediaUploadRequest") },
          },
        },
        MediaSignedUrlsRequest: {
          required: true,
          content: {
            "application/json": { schema: ref("MediaSignedUrlsRequest") },
          },
        },
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
          required: ["phone", "password"],
          properties: {
            phone: phone,
            password: { type: "string", minLength: 6, maxLength: 128 },
          },
        },
        SignupRequest: {
          type: "object",
          required: ["name", "password", "phoneVerificationToken"],
          anyOf: [{ required: ["phone"] }, { required: ["phoneNumber"] }],
          properties: {
            name: { type: "string", minLength: 1, maxLength: 30 },
            password: { type: "string", minLength: 6, maxLength: 128, description: "New passwords are limited to 72 UTF-8 bytes." },
            phoneNumber: {
              type: "string", minLength: 8, maxLength: 20, pattern: "^\\+?[0-9\\s().-]+$",
              description: "Accepted alias of phone",
            },
            phone: { type: "string", minLength: 8, maxLength: 20, pattern: "^\\+?[0-9\\s().-]+$" },
            phoneVerificationToken: {
              type: "string", minLength: 1, maxLength: 10000,
              description: "Firebase ID token from a phone OTP sign-in within ten minutes, matching the signup phone.",
            },
          },
          description:
            "Provide phone or phoneNumber plus phoneVerificationToken. Signup retains the verified OTP UID and links pending invitation identities without accepting them.",
        },
        AuthSession: {
          type: "object",
          required: ["idToken", "refreshToken", "expiresIn", "uid", "customToken"],
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
            customToken: {
              type: "string",
              description:
                "Firebase custom token. Mobile clients call signInWithCustomToken so Auth can refresh ID tokens.",
            },
            user: {
              allOf: [ref("User")],
              nullable: true,
              description:
                "Neon profile without credential fields. Present after phone/password signup or login when a password_hash row exists.",
            },
          },
        },
        AuthSessionResponse: itemResponse("AuthSession"),
        SyncUserRequest: {
          type: "object",
          properties: {
            phoneVerificationToken: {
              type: "string", minLength: 1, maxLength: 10000,
              description: "Optional recent Firebase phone OTP ID token to repair an unused OTP identity. Caller remains the Bearer UID. Registered identities are never merged.",
            },
            name: {
              type: "string",
              minLength: 1,
              maxLength: 200,
              description:
                "Optional create-time bootstrap only. Ignored when a profile already exists.",
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
            "Use the application session from signup or login. Body fields cannot overwrite an existing profile.",
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
                "claimed means pending rows were linked to this verified account, not accepted. phone_verification_required means no verified phone is available.",
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
          required: ["id", "name", "has_password", "created_at", "updated_at"],
          properties: {
            id: firebaseUid,
            name: { type: "string", maxLength: 30 },
            phone: {
              type: "string",
              maxLength: 16,
              description: "Unique E.164 lookup number.",
            },
            has_password: { type: "boolean" },
            image_url: { type: "string", nullable: true },
            created_at: dateTime,
            updated_at: dateTime,
          },
        },
        UserResponse: itemResponse("User"),
        UserListResponse: listResponse("User"),
        UserSummary: {
          type: "object",
          required: ["id", "name", "created_at", "updated_at"],
          properties: {
            id: firebaseUid,
            name: { type: "string", maxLength: 30 },
            image_url: { type: "string", nullable: true },
            created_at: dateTime,
            updated_at: dateTime,
          },
          description:
            "Directory-safe profile fields. Phone and credential state are never included.",
        },
        UserSummaryListResponse: listResponse("UserSummary"),
        UserSummaryResponse: itemResponse("UserSummary"),
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
            role: { type: "string", enum: ["member"], default: "member" },
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
            member_count: {
              type: "integer",
              minimum: 0,
              description:
                "Accepted group_members count. Starts at 1 after create (creator/owner).",
            },
            my_role: {
              type: "string",
              enum: roleEnum,
              description: "Caller's membership role when returned from scoped list/create.",
            },
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
            name: { type: "string", description: "Profile display name" },
            phone: { type: "string", nullable: true },
            image_url: { type: "string", nullable: true },
          },
        },
        GroupMemberResponse: itemResponse("GroupMember"),
        GroupMemberListResponse: {
          allOf: [
            listResponse("GroupMember"),
            {
              type: "object",
              required: ["pending_members", "invitation_history"],
              properties: {
                invitation_history: {
                  type: "array",
                  description: "Group-scoped invitation history, newest first. Only active group members can read it.",
                  items: {
                    type: "object",
                    required: ["invitation_id", "invited_phone", "invitee_name", "inviter_name", "status", "created_at"],
                    properties: {
                      invitation_id: uuid,
                      invited_phone: { type: "string" },
                      invitee_name: { type: "string", nullable: true },
                      inviter_name: { type: "string" },
                      status: { type: "string", enum: ["pending", "accepted", "declined", "expired", "revoked"] },
                      created_at: dateTime,
                    },
                  },
                },
                pending_members: {
                  type: "array",
                  items: {
                    type: "object",
                    required: ["invitation_id", "phone", "status"],
                    properties: {
                      invitation_id: uuid,
                      phone: { type: "string", example: "+201001234567" },
                      status: { type: "string", enum: ["pending"] },
                    },
                  },
                },
              },
            },
          ],
        },
        InviteToGroupRequest: {
          type: "object",
          required: ["phoneNumber"],
          properties: {
            whatsappOptIn: { type: "boolean", description: "Organizer attests that the recipient agreed to a WhatsApp invitation." },
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
            notification_queued: { type: "boolean" },
            whatsapp_url: {
              type: "string",
              format: "uri",
              nullable: true,
              description:
                "Legacy field. Group invitations no longer require a click-to-chat URL.",
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
        UserInvitation: {
          type: "object",
          required: [
            "invitation_id",
            "group_id",
            "group_name",
            "group_image",
            "invited_phone",
            "status",
            "created_at",
            "inviter_name",
          ],
          properties: {
            invitation_id: uuid,
            group_id: uuid,
            group_name: { type: "string" },
            group_image: { type: "string" },
            invited_phone: {
              type: "string",
              example: "+201001234567",
              description: "Normalized E.164 phone on the invitation record",
            },
            status: { type: "string", enum: invitationStatusEnum },
            created_at: dateTime,
            inviter_name: { type: "string" },
          },
        },
        UserInvitationListResponse: listResponse("UserInvitation"),
        InvitationDecisionResult: {
          type: "object",
          required: ["invitation_id", "group_id", "status"],
          properties: {
            invitation_id: uuid,
            group_id: uuid,
            status: {
              type: "string",
              enum: invitationStatusEnum,
              description:
                "Persisted status after the request. A repeated accept or decline returns the stored status instead of rewriting it.",
            },
          },
        },
        AcceptInvitationResponse: itemResponse("InvitationDecisionResult"),
        DeclineInvitationResponse: itemResponse("InvitationDecisionResult"),
        SendMessageRequest: {
          type: "object",
          required: ["text"],
          properties: {
            text: { type: "string", minLength: 1, maxLength: 2000, description: "Plain text or stable mention tokens <@URI-encoded-user-id|URI-encoded-name>. Mention IDs must be current chat participants. Names are canonicalized from Neon; malformed encodings and overlength canonical text return 400. Legacy @name remains plain text." },
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
            "sent_at",
          ],
          properties: {
            id: uuid,
            outing_id: uuid,
            sender_id: firebaseUid,
            sender: { type: "string" },
            avatar: { type: "string", nullable: true },
            text: { type: "string", maxLength: 2000 },
            client_message_id: { ...uuid, nullable: true },
            sent_at: dateTime,
          },
        },
        ChatMessageResponse: itemResponse("ChatMessage"),
        ChatMessageListResponse: {
          allOf: [listResponse("ChatMessage"), {
            type: "object", properties: { next_cursor: { ...uuid, nullable: true } },
          }],
        },
        ChatRead: {
          type: "object",
          required: ["outing_id", "user_id", "last_read_at"],
          properties: {
            outing_id: uuid,
            user_id: firebaseUid,
            last_read_at: dateTime,
          },
        },
        ChatReadResponse: itemResponse("ChatRead"),
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
            eventType: { type: "string", enum: [...Object.values(notification_event_type), "outing_created", "place_vote", "outing", "group", "chat", "vote", "invitation", "system"], description: "Specific event used by the inbox to select a destination" },
            messageId: { ...uuid, description: "Chat message targeted by the notification" },
            outing_id: { ...uuid, nullable: true },
            group_id: { ...uuid, nullable: true },
            action_required: { type: "boolean" },
            is_read: { type: "boolean" },
            created_at: dateTime,
          },
        },
        NotificationResponse: itemResponse("Notification"),
        NotificationListResponse: {
          allOf: [
            listResponse("Notification"),
            {
              type: "object",
              properties: {
                pagination: { type: "object", required: ["limit", "nextCursor"], properties: { limit: { type: "integer", default: 20, maximum: 100 }, nextCursor: { type: "string", nullable: true } } },
                next_cursor: {
                  type: "string", nullable: true,
                  description: "Opaque cursor for the next older page; null means no more rows.",
                },
              },
            },
          ],
        },
        MarkAllNotificationsReadResult: {
          type: "object",
          required: ["count"],
          properties: {
            count: {
              type: "integer",
              minimum: 0,
              description: "Number of notifications flipped from unread to read",
            },
          },
        },
        MarkAllNotificationsReadResponse: itemResponse(
          "MarkAllNotificationsReadResult",
        ),
        CreateOutingRequest: {
          type: "object",
          required: ["title"],
          description:
            "The server derives the initial status: voting with initial options, confirmed with a fixed venue, otherwise draft. A future vote_ends_at or vote_deadline_hours is required. Group outings require group_id and occasion 'none' (default). Special events omit group_id and must set occasion to 'birthday' or 'wedding'.",
          properties: {
            create_request_key: { type: "string", maxLength: 80, description: "Creator-scoped idempotency key. Required for special-event phone invitations and recommended for group voting." },
            initial_vote_options: {
              type: "array",
              minItems: 2,
              maxItems: 5,
              description: "Ordered candidates for a group outing with no fixed location. Saved atomically with the outing.",
              items: { $ref: "#/components/schemas/CreateVoteOptionRequest" },
            },
            guest_phones: { type: "array", maxItems: 50, items: { type: "string" }, description: "Special-event phone guests." },
            guest_phones_whatsapp_opt_in: { type: "boolean", description: "Required recipient opt-in confirmation when guest_phones is supplied." },
            title: { type: "string", minLength: 3, maxLength: 20 },
            image_url: { type: "string", format: "uri", maxLength: 2048 },
            group_id: { ...uuid, nullable: true },
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
            type: { type: "string", enum: outingTypeEnum },
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
            vote_closed_at: { ...dateTime, nullable: true },
            vote_close_reason: {
              type: "string",
              enum: [
                "all_voted",
                "deadline",
                "unique_winner",
                "tie_break",
                "owner_confirmed",
                "zero_votes",
              ],
              nullable: true,
            },
            winning_option_id: { ...uuid, nullable: true },
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
        AttendanceSummary: {
          type: "object",
          properties: {
            my_response: { type: "string", enum: attendanceEnum, nullable: true },
            summary: {
              type: "object",
              properties: {
                going: { type: "integer" },
                maybe: { type: "integer" },
                not_going: { type: "integer" },
              },
            },
          },
        },
        AttendanceResponse: {
          allOf: [itemResponse("Attendance"), ref("AttendanceSummary"), {
            type: "object", properties: { items: { type: "array", items: ref("Attendance") } },
          }],
        },
        AttendanceListResponse: {
          allOf: [listResponse("Attendance"), ref("AttendanceSummary")],
        },
        AddGuestRequest: {
          type: "object",
          required: ["user_id"],
          properties: { user_id: firebaseUid },
        },
        Guest: {
          type: "object",
          required: ["outing_id", "user_id", "invited_at"],
          properties: {
            users: { type: "object", properties: { name: { type: "string" }, image_url: { type: "string" } } },
            status: { type: "string", enum: invitationStatusEnum },
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
        VoteResolution: {
          type: "object",
          required: ["outing", "outcome"],
          properties: {
            outing: ref("Outing"),
            outcome: { type: "string", enum: ["confirmed", "tie", "cancelled", "still_open"] },
            winningOptionId: uuid,
            tiedOptionIds: { type: "array", items: uuid },
          },
        },
        VoteResolutionResponse: itemResponse("VoteResolution"),
        BallotResponse: envelope({
          type: "object", required: ["votes", "resolution"], properties: {
            votes: { type: "array", items: ref("Vote") },
            resolution: { oneOf: [ref("VoteResolution"), { type: "object", nullable: true, enum: [null] }] },
          },
        }),
        CastVoteResponse: envelope({
          type: "object",
          required: ["vote", "resolution"],
          properties: {
            vote: ref("Vote"),
            resolution: { oneOf: [ref("VoteResolution"), { type: "object", nullable: true, enum: [null] }] },
          },
        }),
        VotingStateResponse: envelope({
          type: "object",
          required: ["outing", "options", "votes", "tiedOptionIds", "isTied", "isClosed", "my_option_ids", "voted_count"],
          properties: {
            outing: ref("Outing"),
            options: { type: "array", items: { allOf: [ref("VoteOption"), {
              type: "object", properties: { vote_count: { type: "integer" } },
            }] } },
            my_option_id: { ...uuid, nullable: true },
            my_option_ids: { type: "array", uniqueItems: true, items: uuid },
            voted_count: { type: "integer" },
            eligible_voter_count: { type: "integer" },
            votes: { type: "array", items: ref("Vote") },
            tiedOptionIds: { type: "array", items: uuid },
            isTied: { type: "boolean" },
            isClosed: { type: "boolean" },
          },
        }),
        OutingArrivalsResponse: envelope({
          type: "object",
          required: ["arrivals", "open"],
          properties: {
            open: { type: "boolean" },
            closes_at: { ...dateTime, nullable: true },
            radius_meters: { type: "number" },
            opens_at: { ...dateTime, nullable: true },
            max_accuracy_meters: { type: "number" },
            venue: {
              type: "object", nullable: true,
              properties: { latitude: { type: "number" }, longitude: { type: "number" } },
            },
            automatic_eligible: { type: "boolean", enum: [true] },
            can_confirm_arrivals: { type: "boolean" },
            total_confirmed: { type: "integer" },
            unconfirmed: { type: "array", items: {
              type: "object", properties: { id: firebaseUid, name: { type: "string" } },
            } },
            arrivals: {
              type: "array",
              items: {
                type: "object",
                required: ["user_id", "name", "arrived_at"],
                properties: {
                  user_id: firebaseUid,
                  name: { type: "string" },
                  arrived_at: dateTime,
                  verification_method: { type: "string", enum: ["legacy", "manual_gps", "automatic_gps", "gps"] },
                },
              },
            },
          },
        }),
        OutingArrivalResponse: envelope({
          type: "object",
          required: ["arrived"],
          properties: { arrived: { type: "boolean" } },
        }),
        PasswordUpdateResponse: envelope({
          type: "object",
          required: ["updated"],
          properties: { updated: { type: "boolean", enum: [true] } },
        }),
        PasswordVerificationResponse: envelope({
          type: "object",
          required: ["verified"],
          properties: { verified: { type: "boolean", enum: [true] } },
        }),
        RegisteredFcmTokenResponse: envelope({
          type: "object",
          required: ["user_id", "token", "platform"],
          properties: {
            user_id: firebaseUid,
            token: { type: "string" },
            platform: { type: "string", nullable: true },
          },
        }),
        UnregisteredFcmTokenResponse: envelope({
          type: "object",
          required: ["deleted"],
          properties: { deleted: { type: "integer", minimum: 0 } },
        }),
        SavedPlace: {
          type: "object",
          required: ["user_id", "place_id", "saved_at"],
          properties: { user_id: firebaseUid, place_id: uuid, saved_at: dateTime },
        },
        SavedPlaceResponse: itemResponse("SavedPlace"),
        SavedPlaceListResponse: listResponse("SavedPlace"),
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
            scheduled_date: { type: "string", format: "date-time", nullable: true },
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
        MediaUploadRequest: {
          type: "object",
          required: ["purpose", "mime_type", "file_size"],
          properties: {
            purpose: {
              type: "string",
              enum: ["profile", "group", "outing", "place", "chat"],
              description:
                "Drives visibility (place is public, everything else private) and object-key layout.",
            },
            mime_type: {
              type: "string",
              enum: ["image/jpeg", "image/png", "image/webp", "image/gif"],
            },
            file_size: {
              type: "integer",
              minimum: 1,
              maximum: 10485760,
              description: "Bytes. Server re-verifies the real size on confirm.",
            },
            entity_id: {
              ...uuid,
              nullable: true,
              description:
                "Group/outing UUID required for group, outing, and chat uploads. Omit for profile and place uploads.",
            },
            media_id: {
              ...uuid,
              nullable: true,
              description:
                "Re-issue a fresh presigned PUT URL for a still-pending asset (expired URL retry).",
            },
          },
        },
        MediaSignedUrlsRequest: {
          type: "object",
          required: ["media_ids"],
          properties: {
            media_ids: {
              type: "array",
              minItems: 1,
              maxItems: 50,
              items: uuid,
            },
          },
        },
        MediaUploadIntentData: {
          type: "object",
          properties: {
            media_id: uuid,
            object_key: { type: "string", example: "profiles/2026-11/uuid.jpg" },
            bucket: { type: "string" },
            visibility: { type: "string", enum: ["public", "private"] },
            status: { type: "string", enum: ["pending", "ready", "failed"] },
            upload_url: {
              type: "string",
              format: "uri",
              description:
                "Presigned PUT URL. Send the file bytes directly; do not add the Firebase Authorization header.",
            },
            upload_expires_at: dateTime,
            media_reference: {
              type: "string",
              example: "media://0f8fad5b-d9cb-469f-a165-70867728950e",
              description:
                "Stable reference to store in an entity image field (group/outing/profile) after confirm.",
            },
          },
        },
        MediaUploadIntentResponse: envelope(ref("MediaUploadIntentData")),
        MediaAssetData: {
          type: "object",
          properties: {
            media_id: uuid,
            object_key: { type: "string" },
            visibility: { type: "string", enum: ["public", "private"] },
            status: { type: "string", enum: ["pending", "ready", "failed"] },
            file_size: { type: "integer" },
            media_reference: { type: "string", example: "media://0f8fad5b-d9cb-469f-a165-70867728950e" },
            verified_at: { ...dateTime, nullable: true },
          },
        },
        MediaAssetResponse: envelope(ref("MediaAssetData")),
        MediaUrlData: {
          type: "object",
          properties: {
            media_id: uuid,
            object_key: { type: "string" },
            url: {
              type: "string",
              format: "uri",
              description:
                "Permanent CDN URL for public assets; short-lived signed GET URL for private assets.",
            },
            visibility: { type: "string", enum: ["public", "private"] },
            expires_at: {
              ...dateTime,
              nullable: true,
              description: "Null for public CDN URLs.",
            },
          },
        },
        MediaUrlResponse: envelope(ref("MediaUrlData")),
        MediaUrlListResponse: envelope({
          type: "array",
          items: ref("MediaUrlData"),
        }),
        MediaDeletedData: {
          type: "object",
          properties: {
            deleted: { type: "boolean" },
            media_id: uuid,
          },
        },
        MediaDeletedResponse: envelope(ref("MediaDeletedData")),
      },
    },
  },
  apis: annotationGlobs(),
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Shared /api middleware applies this response to every HTTP API operation.
const generated = swaggerSpec as { paths?: Record<string, Record<string, { responses?: Record<string, unknown> }>> };
for (const [route, item] of Object.entries(generated.paths ?? {})) {
  if (!route.startsWith("/api/")) continue;
  for (const [method, operation] of Object.entries(item)) {
    if (!["get", "post", "put", "patch", "delete"].includes(method)) continue;
    operation.responses ??= {};
    operation.responses["429"] ??= { $ref: "#/components/responses/TooManyRequests" };
  }
}
