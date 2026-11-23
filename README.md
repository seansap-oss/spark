# Spark dating app project — Vibely v0.3.0

This folder contains the v0.3.0 mobile-first Vibely prototype with a refreshed visual design. See BUILD-NOTES.md for the current features and launch requirements.

## Put this project in the requested folder

Keep this GitHub repository in:

```text
D:\Spark dating app
```

Keep the files together in that folder. In the existing VS Code terminal, run `py -m http.server 5173 --directory "D:\Spark dating app"` and open `http://localhost:5173/`.

## Included in this build

- Discover profiles with For you, Nearby, New, and Popular tabs.
- Friendly intro prompts, like/pass actions, incoming requests, and accept-to-chat flow.
- Chat list, conversation screen, idea prompts, and messages saved locally in the browser.
- Profile editor, local privacy toggles, verification flow preview, subscription plans, checkout preview, boost choices, and report/block screens.
- Responsive desktop and mobile layouts with a mobile navigation bar.
- Refreshed coral and violet visual system in `premium.css`.
- PWA manifest and offline app-shell cache for later serving/installing.

## Current limits

This is a front-end prototype. Demo profiles are sample content; profile edits, privacy settings, and chat drafts are stored only in local browser storage on the current device. Authentication, database, real profile photos, live chat, identity review, payments, subscriptions, moderation queues, and push notifications are not connected. The payment and verification screens explicitly remain demos and do not charge money or submit identity information.

The app is branded **Vibely** because that is the name in the approved UI design. The requested working folder remains **D:\Spark dating app**.
