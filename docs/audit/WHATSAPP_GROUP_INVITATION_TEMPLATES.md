# WhatsApp group invitation templates

Prepared 2026-11-22 for the Yalla 5roga business portfolio. The supplied account is labeled **Test Messaging Account**, asset 2264290257829755. Templates are not evidence of a configured production sender.

Both `group_invite` versions were submitted with the app logo header and verified as **In review** in WhatsApp Manager: English (`en`, template ID 1697092591770652) and Arabic (`ar`, template ID 1824125282128340). The user attached the logo through the browser after automated file selection was blocked; previews were visually checked before submission. Existing sample templates were not changed. The category selected was Marketing, with no messages sent. Approval is pending; runtime delivery was not exercised.

## Template contract

- Name: `group_invite`; languages: English (`en`) and Arabic (`ar`).
- Header: image, using `flutter/assets/branding/yalla_5roga_logo.png` as the review sample. Runtime sends must provide an image header parameter.
- Body parameters: `{{1}}` inviter display name, `{{2}}` group name, `{{3}}` full invitation HTTPS link.
- Link shape: `https://yalla5roga.com/invite/{invitationId}?groupId={groupId}`. It identifies an existing phone-addressed invitation; it does not grant group membership.
- Review samples use fictional names/groups and a clearly labeled review-only link. They are not production environment values or real invitations.

## English

You have a group invitation!

{{1}} invited you to join the group "{{2}}" on Yalla 5roga.

Open your invitation: {{3}}

New here? Create an account using the phone number that received this invitation. After signup, find your group invitation notification in the app and accept or decline.

Already have an account? Sign in to review your invitation.

Footer: Yalla 5roga • Plan outings together

## Arabic

عندك دعوة للانضمام لجروب!

{{1}} دعاك للانضمام لجروب «{{2}}» على يلا خروجة.

افتح دعوتك: {{3}}

أول مرة تستخدم يلا خروجة؟ اعمل حساب بنفس رقم الموبايل اللي وصلك عليه الدعوة. بعد التسجيل هتلاقي إشعار بدعوة الجروب جوه التطبيق، وتقدر تقبل الدعوة أو ترفضها.

عندك حساب بالفعل؟ سجّل دخولك علشان تراجع دعوتك.

Footer: يلا خروجة • خططوا لخروجاتكم مع بعض

## Verified source behavior and integration gaps

Signup verifies the phone and calls `ClaimGroupInvitationsUseCase`. `PrismaInvitationClaimStore.activate` links pending invitations to that identity and calls `persistGroupInvitation`, which creates an inbox notification containing the group name. Membership still requires explicit acceptance. `InviteDeepLinkProvider` stores logged-out links until authenticated navigation, and `InviteDeepLinkNavigator` opens InvitationsPage.

The existing WhatsApp sender supplies three body text parameters, but no image header. It uses one environment-wide language (`WHATSAPP_INVITE_TEMPLATE_LANG`), not recipient language. Both language versions can exist in Meta; per-recipient selection and image sending need a separate implementation change before enabling this media template. No production sender token or environment value is invented.

The public website/install landing page, Android assetlinks and iOS association files must be hosted and verified for HTTPS taps before installation. Source-level pending-link storage cannot itself preserve a link across a fresh app installation. Signing and real-device signup/notification delivery remain unverified. Production API and CORS origins were intentionally left empty in the preceding configuration task.

No messages sent, production records changed, migrations run or deployment performed by this template preparation.
