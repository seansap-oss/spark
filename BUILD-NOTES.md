# Vibely v0.2.0 development notes

This package builds on the original Spark v0.1.0 source. Keep every file together in `D:\Spark dating app`.

## Run in the existing VS Code terminal

From `D:\Spark dating app`, run `py -m http.server 5173`, then open `http://localhost:5173/`. If `py` is unavailable, use `python -m http.server 5173`. Press Ctrl+C to stop.

Extract the ZIP contents into the same project folder, replacing the older files. If the browser shows old code after upgrading, refresh once while online so the v0.2.0 service worker replaces its cache.

## This build

The demo now keeps sent likes and intros, discovery preferences, hidden and blocked profiles, and a report log on this device. Discovery respects age, distance and gender settings. Sent intros are shown in Likes & intros. Blocking removes a demo conversation and hides that person from discovery. Profile verification and checkout remain honest previews: neither can grant a real badge nor activate a purchase.

## Launch requirements

This is still a local browser prototype. Authentication, cross-device chat, real user profiles and matching, server-side reports/moderation, identity review, privacy enforcement and payments require a backend and provider configuration before public launch. Demo profiles and message threads are fictional. Never collect real identity documents or payments in this build.
