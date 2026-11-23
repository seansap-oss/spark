# Vibely v0.10.0 build notes

This build uses the connected Spark Supabase project `qhnynlpnqsmytpodzmbx`. Social links are stored in `spark_social_links` with RLS-enforced visibility and a default of Hidden. Pasted links are not identity verification. Up to four profile photos use the private `spark-profile-photos` bucket and `spark_profile_photos` table; `spark_profiles.photo_path` marks the cover photo. The browser resizes images to WebP. Members can review blocks, unblock, end matches and pause discovery in Safety & privacy. Discovery filters are saved to `spark_discovery_preferences`; paused profiles are restricted by database policies while accepted matches remain visible. Moderators can review reports and pause/restore accounts; role membership is never self-service. The sidebar uses the signed-in member name, city, and real incoming intro count.

All database objects are prefixed `spark_`, and every public table has Row Level Security enabled. The browser includes only the public project URL and publishable key in `config.js`. Never put a secret or service-role key in the browser or repository.

## Run locally

Keep this project in `D:\Spark dating app`. In the existing VS Code terminal run `py -m http.server 5173 --directory "D:\Spark dating app"`, then open `http://localhost:5173/`. The app needs internet access to use Supabase. Refresh after an update to let the service worker replace old assets.

## Connected features

Sign up using an email address and password, confirm email if requested, then complete a profile with age 18+. A second adult test account can browse that profile, send an intro, and receive acceptance. Only an accepted request permits messages. Chat checks for new messages every five seconds. Blocking hides a profile and stops messages for both sides. Reports are saved for later moderation review.

## Before a public launch

Set the production Site URL and allowed redirect URLs in Supabase Auth URL Configuration after Vercel is deployed. Test email confirmation, gallery upload, unblocking, ending a match, moderation, and account deletion on the final domain. The `spark-delete-account` Edge Function verifies a user JWT, removes that user's photo objects through Storage, then deletes their Auth user with the server-only secret key; the database foreign keys cascade the member's Spark records. To make the owner a moderator after their Spark account exists, the project owner can add that account's `auth.users.id` to `public.spark_moderators` in the Supabase SQL editor. No moderator has been assigned by this build. Profiles still rely on self-declared age; there is no verification provider or billing. The old v0.3.0 sample prototype remains in `app.js` as fallback if the live configuration is removed; the online beta renders from `live.js` when `config.js` is present.
