# Spark dating app project — Vibely v0.5.0

This folder contains Vibely v0.5.0: the mobile-first Spark beta connected to the separate `sparkapp` Supabase project (`qhnynlpnqsmytpodzmbx`).

## Put this project in the requested folder

Keep this GitHub repository in:

```text
D:\Spark dating app
```

Keep the files together in that folder. In the existing VS Code terminal, run `py -m http.server 5173 --directory "D:\Spark dating app"` and open `http://localhost:5173/`.

## Included in this build

- Email and password sign-up, sign-in, session refresh, and profile setup for adults.
- Discovery from real registered profiles, intro requests, acceptance, and matched conversations.
- Messages stored in Supabase and refreshed every five seconds; reports and blocks are stored in the database.
- Optional social profile links with per-link Hidden, Matches only, and All signed-in members visibility.
- Row access rules for every public Spark table; the browser uses only the publishable key.
- Responsive desktop and mobile layouts with a mobile navigation bar.
- Coral and violet visual system in `premium.css` and `live.css`.
- PWA manifest and offline app-shell cache for later serving/installing.

## Current limits

Authentication and data storage are connected, but end-to-end signup and two-account chat still need testing with real test accounts and the public Vercel URL. Email confirmation redirect URLs may need updating in Supabase Authentication settings. Profiles self-report age. Photo upload, identity review, social sign-in with Google/Facebook, a moderation dashboard, payment/subscriptions, calls, push notifications, and account deletion are still pending. Messages refresh by polling, not realtime subscriptions. Do not launch publicly until those requirements and adult verification are addressed.

The app is branded **Vibely** because that is the name in the approved UI design. The requested working folder remains **D:\Spark dating app**.
