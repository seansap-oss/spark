# Vibely v0.4.0 build notes

This build uses the connected Spark Supabase project `qhnynlpnqsmytpodzmbx`. All database objects are prefixed `spark_`, and every public table has Row Level Security enabled. The browser includes only the public project URL and publishable key in `config.js`. Never put a secret or service-role key in the browser or repository.

## Run locally

Keep this project in `D:\Spark dating app`. In the existing VS Code terminal run `py -m http.server 5173 --directory "D:\Spark dating app"`, then open `http://localhost:5173/`. The app needs internet access to use Supabase. Refresh after an update to let the service worker replace old assets.

## Connected features

Sign up using an email address and password, confirm email if requested, then complete a profile with age 18+. A second adult test account can browse that profile, send an intro, and receive acceptance. Only an accepted request permits messages. Chat checks for new messages every five seconds. Blocking hides a profile and stops messages for both sides. Reports are saved for later moderation review.

## Before a public launch

Set the production Site URL and allowed redirect URLs in Supabase Auth URL Configuration after Vercel is deployed. Test email confirmation on the final domain. Profiles currently rely on self-declared age; there is no verification provider, photo upload, moderation dashboard, billing, or account deletion flow yet. The old v0.3.0 sample prototype remains in `app.js` as fallback if the live configuration is removed; the online beta renders from `live.js` when `config.js` is present.
