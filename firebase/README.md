# Firebase setup (free Spark plan)

Neighbourly uses Firebase Authentication (email/password) and Cloud
Firestore. Everything below works on the **Spark** plan: no credit card,
no Blaze upgrade. Do **not** enable Cloud Storage, Cloud Functions, or
billing; the app is designed not to need them.

These steps are done once, by the developer, mostly on the Mac. They are
introduced in Phase 8 of [`docs/tasks.md`](../docs/tasks.md).

## 1. Create the project

1. Sign in to the [Firebase console](https://console.firebase.google.com)
   with a Google account.
2. Create a project (disable Google Analytics; the app collects none).
3. Confirm the plan is **Spark** (bottom-left of the console).

## 2. Enable email/password sign-in

Build → Authentication → Sign-in method → **Email/Password** → enable
(leave "Email link" off).

## 3. Create the Firestore database

Build → Firestore Database → Create database → **production mode** → pick
a nearby location (for example `asia-south1`, Mumbai). The location
cannot be changed later.

## 4. Register the iOS app

Project settings → Add app → iOS, bundle ID `com.kjsce.neighbourly`.
Download `GoogleService-Info.plist`.

## 5. Add the plist and SDK on the Mac

1. Copy `GoogleService-Info.plist` into the `neighbourly/` folder (next to
   `App/`). It is git-ignored, so it never goes into the repository. The
   file holds project identifiers rather than private secrets, but still
   do not post it publicly.
2. In Xcode: File → Add Package Dependencies →
   `https://github.com/firebase/firebase-ios-sdk`. Add only
   **FirebaseAuth** and **FirebaseFirestore** to the `neighbourly`
   target.
3. Commit the updated project file and
   `neighbourly.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## 6. Publish the security rules

Firestore Database → Rules → paste the contents of
[`firestore.rules`](firestore.rules) → Publish. Re-publish after every
change to that file. The rules, not the plist, are what stop users from
editing each other's listings or reading each other's chats.

`firestore.rules` covers `users`, `listings` (Phase 9), and
`conversations` with their `messages` (Phase 10). Re-publish it whenever
the file changes. If a chat action is refused even though the app looks
right, the Rules tab's "Rules Playground" shows exactly which condition
failed.

## Free-plan quotas

Check the current Spark limits in the console (Usage tab) before the
demo. A classroom demo is far below them. Avoid unbounded queries and
large photo payloads: photos are stored in Firestore documents and must
stay well under the 1 MiB document limit.

## Optional: test the rules locally

The Firebase Emulator Suite needs Node.js and Java:

```bash
npm install -g firebase-tools
firebase emulators:start --only firestore
```

Use `@firebase/rules-unit-testing` to check that non-participants cannot
read a conversation, that `senderID` cannot be spoofed, and that only
owners can edit listings.
