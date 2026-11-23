# Spark dating app project — Vibely v0.20.0

This folder contains Vibely v0.20.0: the mobile-first Spark beta connected to the separate `sparkapp` Supabase project (`qhnynlpnqsmytpodzmbx`).

## Put this project in the requested folder

Keep this GitHub repository in:

```text
D:\Spark dating app
```

Keep the files together in that folder. In the existing VS Code terminal, run `py -m http.server 5173 --directory "D:\Spark dating app"` and open `http://localhost:5173/`.

## Included in this build

- Email and password sign-up, a confirmation screen with resend, sign-in, session refresh, and profile setup for adults.
- Password recovery by email with an in-app new-password form; email confirmation links return to the app.
- Discovery from real registered profiles, with optional interests and a conversation prompt, intro requests, acceptance, and matched conversations.
- Messages stored in Supabase and refreshed every five seconds, with recipient-only read receipts, unread badges, and a recent-first inbox with message previews. Members can report a specific incoming message with a reason; moderators see its database-captured excerpt.
- Database-enforced sending limits of 25 intros per 24 hours and 30 messages per minute per member, with duplicate-submit protection in the browser.
- Two-sided chat bubbles with sender labels, safe clickable HTTPS links, emoji picker, photo/camera attachment, and recorded voice notes. Private match-only media is limited to 5 MiB per file.
- A Private Activity premium add-on design and database-enforced read-receipt privacy. Only a trusted entitlement can unlock its profile toggle; checkout is not yet active.
- Searchable chats, private pin and mute controls, and message reactions. Muting suppresses the global unread badge for that conversation while keeping the count inside chat.
- Message reports now accept category and message ID correctly; reported chat media is captured from the database and made available to moderators for review.
- Optional social profile links with per-link Hidden, Matches only, and All signed-in members visibility.
- Up to four photos per member in a private Supabase bucket, with a selectable cover photo. Signed-in, unblocked members can browse the gallery.
- Safety & privacy page to review blocked members, unblock them, and end active matches.
- Moderator-only report queue with reviewed/dismissed decisions and temporary profile pause/restore. Moderator membership is assigned in Supabase by the project owner, not by users.
- Sidebar identity and pending-intro badges use live account data rather than sample names or counts.
- Self-service account deletion from Safety & privacy, with a typed confirmation and server-side removal of photos and the Auth user.
- Saved discovery filters for age, gender, city and relationship goal; a Pause discovery switch hides a member from new people while preserving existing matches.
- Row access rules for every public Spark table; the browser uses only the publishable key.
- Responsive desktop and mobile layouts with a mobile navigation bar.
- Coral and violet visual system in `premium.css` and `live.css`.
- PWA manifest and offline app-shell cache for later serving/installing.

## Current limits

Authentication and data storage are connected, but end-to-end signup, password reset, gallery upload, safety actions, moderation, account deletion, and media playback still need testing with real devices and the public Vercel URL. In Supabase Authentication → URL Configuration, set Site URL to `https://spark-plum-beta.vercel.app/` and add Redirect URLs `https://spark-plum-beta.vercel.app/` and `http://localhost:5173/`. Two confirmed test accounts have exchanged text messages and read receipts; one media message reached the database. No moderator account is assigned yet. Profiles self-report age. Identity review, social sign-in with Google/Facebook, payment/subscriptions, calls, and push notifications are still pending. Messages refresh by polling, not realtime subscriptions. Do not launch publicly until those requirements and adult verification are addressed.

The app is branded **Vibely** because that is the name in the approved UI design. The requested working folder remains **D:\Spark dating app**.
