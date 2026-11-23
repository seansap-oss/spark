# Vibely v0.15.0 build notes

This build uses the Spark Supabase project `qhnynlpnqsmytpodzmbx`. The app offers email and password sign-up, confirmation links, password recovery, profile setup for adults, photo galleries, discovery preferences, social profile links with per-link visibility, intro requests, accepted matches, chat, reporting, blocking, moderator review, and self-service account deletion.

## Email confirmation

After sign-up without a session, members see a confirmation screen with their email and a resend action. An unconfirmed sign-in opens the same screen. Resend uses Supabase `/auth/v1/resend` with `type: signup` and a return URL to this app; the UI waits at least a minute between requests. Real email delivery and redirect configuration still require testing with a mailbox.

## Profile personality

Members may select up to five of twelve interests and answer one optional conversation prompt. The profile editor, own profile and discovery card show the saved data. The database limits allowed tags and answer length. Older profiles receive empty defaults. Migration: `supabase/20261123_profile_personality.sql`.

## Chat inbox

Matched conversations are ordered by their latest visible message. The inbox shows a preview, time, and unread count; a conversation without messages shows its intro. Previews are escaped before rendering. The inbox refreshes while open without replacing the message composer. The latest-message query uses a recent 500-message window; older quiet chats fall back to their match date.

## Chat receipts

The `spark_messages.read_at` column records when the recipient opens a matched conversation. A trigger stamps database time; only the recipient has a permitted update path, and the authenticated role can update only `read_at`, not message text. Both participants may read the timestamp on their accepted, active match. Unread messages appear in the desktop and mobile Chats badges. The active chat polls every five seconds; other views check unread counts every fifteen seconds. The migration is `supabase/20261123_message_receipts.sql`.

## Run locally

Keep this project in `D:\Spark dating app`. In the existing VS Code terminal run `py -m http.server 5173 --directory "D:\Spark dating app"`, then open `http://localhost:5173/`. The app needs internet for Supabase. Refresh after updating to replace old service-worker assets.

## Before public launch

In Supabase Authentication → URL Configuration, verify Site URL `https://spark-plum-beta.vercel.app/` and Redirect URLs `https://spark-plum-beta.vercel.app/` and `http://localhost:5173/`. Test email confirmation, password recovery, gallery upload, two-account matching and chat receipts, blocking, moderation, and account deletion with real accounts on the final domain. No moderator has been assigned by this build. Profiles still use self-declared age; identity verification, billing, calls, and push notifications are pending.

All public Spark tables use Row Level Security. The browser includes only the public project URL and publishable key in `config.js`. Never put a service-role or other secret key in the browser or repository.
