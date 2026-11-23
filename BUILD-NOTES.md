# Vibely v0.22.0 build notes

This build uses the Spark Supabase project `qhnynlpnqsmytpodzmbx`. The app offers email and password sign-up, confirmation links, password recovery, profile setup for adults, photo galleries, discovery preferences, social profile links with per-link visibility, intro requests, accepted matches, chat, reporting, blocking, moderator review, and self-service account deletion.

## Email confirmation

After sign-up without a session, members see a confirmation screen with their email and a resend action. An unconfirmed sign-in opens the same screen. Resend uses Supabase `/auth/v1/resend` with `type: signup` and a return URL to this app; the UI waits at least a minute between requests. Real email delivery and redirect configuration still require testing with a mailbox.

## Message reporting

Members can report an incoming message or a profile with a selected category and explanation. A database trigger verifies the reported message belongs to the other participant in an accepted match and copies the message text for moderator review, so the browser cannot invent the evidence. Existing reports default to Other. Migration: `supabase/20261123_message_reports.sql`.

## Profile personality

Members may select up to five of twelve interests and answer one optional conversation prompt. The profile editor, own profile and discovery card show the saved data. The database limits allowed tags and answer length. Older profiles receive empty defaults. Migration: `supabase/20261123_profile_personality.sql`.

## Chat inbox

Matched conversations are ordered by their latest visible message. The inbox shows a preview, time, and unread count; a conversation without messages shows its intro. Previews are escaped before rendering. The inbox refreshes while open without replacing the message composer. The latest-message query uses a recent 500-message window; older quiet chats fall back to their match date.

## Chat receipts

The `spark_messages.read_at` column records when the recipient opens a matched conversation. A trigger stamps database time; only the recipient has a permitted update path, and the authenticated role can update only `read_at`, not message text. Both participants may read the timestamp on their accepted, active match. Unread messages appear in the desktop and mobile Chats badges. The active chat polls every five seconds; other views check unread counts every fifteen seconds. The migration is `supabase/20261123_message_receipts.sql`.

## Sending limits

The database limits each account to 25 intros in a rolling 24 hours and 30 chat messages per rolling minute. A transaction lock serializes concurrent sends from one member; server time sets creation timestamps and new messages start unread. The interface also prevents repeated clicks while a send is pending. Migration: `supabase/20261123_spam_limits.sql`. The live two-account conversation has produced messages from both senders; rate-limit edge cases still need a live check.

## Rich chat

Messages identify the sender and use separate left and right layouts. The composer accepts emojis and safe HTTPS links, takes or chooses a photo, and records a voice note on supported browsers. Tap the microphone once to start, again to stop and preview, then Send. The browser compresses photos to WebP; each uploaded image or audio note is capped at 5 MiB. A private Storage bucket checks active match membership before upload or download, and a message trigger verifies the uploaded file belongs to the sender and conversation. Migration: `supabase/20261123_chat_media.sql`. The account deletion function removes both participants' chat media before cascading their match. One media message reached the live database; camera and voice playback across devices still require testing.

## Private Activity add-on

The premium and profile screens show an optional, separately entitled Private Activity setting. It is locked unless trusted billing code grants a nonexpired entitlement; the browser cannot grant or extend one. When enabled, opening an incoming message writes a private view marker for the recipient's unread badge but does not stamp a public `read_at` receipt. The database read trigger also rejects direct attempts to stamp a receipt while the mode is active. Switching the setting off does not reveal reads that happened in private mode; earlier public Seen receipts remain visible. There is no online status, last seen, typing indicator, checkout, or price in this beta. Migration: `supabase/20261123_private_activity.sql`. Billing webhook provisioning and a live paid-account test remain pending.

## Conversation tools and reporting

Members can pin or mute a match privately, search by name or recent message, and react to a message with one of six emojis. Pinned chats sort first; muted chats keep their own unread count but do not contribute to the global Chats badge. Database policies restrict reaction reads and writes to active matched participants and conversation controls to their owner. Migration: `supabase/20261123_conversation_tools.sql`.

The report insert privilege was missing the `category` and `message_id` columns; those grants are repaired. A message report captures its attachment path and type from the verified message on the server. A moderator can review the reported photo or voice note even if the match is later blocked. Ordinary members cannot forge media evidence or access another match's media. Migration: `supabase/20261123_report_media_fix.sql`. A real moderator account is still needed for end-to-end review.

## Owner console and member outreach

The footer © opens an owner PIN prompt after a five-second hold without press feedback. The PIN hash is stored privately in Supabase, never in browser code or this repository. The owner must also be a signed-in member assigned to `spark_owners`; the 30-minute server unlock is required for all pricing and campaign writes. Five failures lock attempts for fifteen minutes. The confirmed avit test account has been assigned as owner; verify the browser sign-in and PIN flow on the live site. Migration: `supabase/20261123_owner_console.sql`. The actual PIN hash was provisioned directly into the private schema without recording the password in a migration file.

The console edits per-currency INR/USD/AUD monthly or yearly plan prices, benefits and descriptions, and scheduled percentage campaign drafts. The member premium screen reads the active prices and campaigns. Checkout and redemption-limit enforcement are not connected. The console lists aggregate member intros, matches, messages and last saved activity, which does not prove app presence. Members opt in to at most two official in-app product notices per week; these appear on their profile and never impersonate a match. No notices were sent by this build.

`supabase/20261123_discovery_tiers.sql` adds payment-provisioned member tier entitlements and a server-filtered discovery weight. Three paid candidates may appear before one rotating Basic candidate, subject to each member's filters and visibility. No paid membership was provisioned. No verification claim or guaranteed likes are generated.

## Profile history

My profile now includes dated Timeline, Sent, Received, Passed, Chats, Blocked, and Gifts tabs, plus real intro, match, chat and pass counts. Intro and block timestamps were already stored; future accepted/declined matches get server timestamps and future Pass actions are saved per member. Historical accepted matches have no known acceptance timestamp and are not assigned an invented date. The first chat date and message count come from a caller-scoped aggregate. Gifts remain an honest empty state until checkout and recipient consent exist. Migration: `supabase/20261124_activity_history.sql`. The owner account is now assigned to the confirmed `avit` profile and the private PIN hash is configured; no live owner browser session was used in this build.

## Run locally

Keep this project in `D:\Spark dating app`. In the existing VS Code terminal run `py -m http.server 5173 --directory "D:\Spark dating app"`, then open `http://localhost:5173/`. The app needs internet for Supabase. Refresh after updating to replace old service-worker assets.

## Before public launch

In Supabase Authentication → URL Configuration, verify Site URL `https://spark-plum-beta.vercel.app/` and Redirect URLs `https://spark-plum-beta.vercel.app/` and `http://localhost:5173/`. Test email confirmation, password recovery, gallery upload, two-account matching and chat receipts, blocking, moderation, and account deletion with real accounts on the final domain. No moderator has been assigned by this build. Profiles still use self-declared age; identity verification, billing, calls, and push notifications are pending.

All public Spark tables use Row Level Security. The browser includes only the public project URL and publishable key in `config.js`. Never put a service-role or other secret key in the browser or repository.
