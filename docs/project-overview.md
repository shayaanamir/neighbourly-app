# Neighbourly --- Project Overview

## 1. Project summary

**Neighbourly** is a SwiftUI community marketplace mini project for
finding a second life for everyday items within a local area. People
create an account, post listings to sell, exchange, or donate an item,
browse nearby listings on a list or map, and **chat with the seller**
to arrange the handover. On-device image classification (a bundled
pretrained Core ML model) and text recognition help sellers prepare a
listing faster.

The mini project focuses on a polished iOS experience and a demonstrable
end-to-end flow --- sign up, post, discover, chat --- on a free
backend rather than a production-scale marketplace.

## 2. Problem statement

People often have useful items they no longer need, while others nearby
may be looking for those same items. General marketplaces can feel broad
or cluttered, and creating a listing takes effort. Arranging a handover
usually means swapping phone numbers with a stranger. Neighbourly aims
to make local reuse approachable by combining simple listing creation,
location-aware discovery, optional on-device AI assistance, and
in-app messaging so contact details stay private.

## 3. Objectives

-   Create a native iOS interface using SwiftUI.
-   Support Sell, Exchange, and Donate listing types.
-   Let users sign up, sign in, and manage their account securely.
-   Allow users to add item photos, descriptions, condition, and
    locality, and share listings with other users.
-   Browse listings with search and filters.
-   Display geolocated listings on an interactive MapKit map.
-   Use on-device image classification (pretrained Core ML model) and
    Vision OCR to suggest listing details.
-   Provide real-time text chat between buyer and seller.
-   Keep the required build and demo budget at **₹0**.

## 4. Core user journeys

### Create an account

1.  Open the app and browse as a guest.
2.  Tap Add Listing (or Messages, or Message Seller); the app asks you
    to sign in.
3.  Sign up with a display name, email, and password, or sign in, or
    request a password reset email.
4.  Stay signed in across launches; sign out or delete the account from
    the Account tab.

### Browse nearby items

1.  Open Browse and see shared and sample listings.
2.  Search by item or locality and filter by category or mode.
3.  Switch to Map to see listings with coordinates.
4.  Select a marker and open the listing details.

### Create a listing

1.  Tap Add Listing (signed in).
2.  Select photos from the photo library.
3.  Optionally tap Suggest Details for on-device classification and OCR.
4.  Review and edit title, description, category, mode, condition,
    price, and area.
5.  Save; the listing appears in Browse for everyone and in My Listings.

### Chat with a seller

1.  Open someone else's listing and tap Message Seller.
2.  Send a text message; it appears live on the seller's device.
3.  The seller sees the conversation in the Messages tab (with an unread
    indicator), replies, and the two arrange the handover.
4.  Conversations persist across relaunches. There are no push
    notifications, so replies appear when the app is open.

## 5. Feature scope

### Included in MVP

-   SwiftUI navigation with tabs (Browse, My Listings, Messages,
    Account) and reusable components.
-   Firebase Authentication with email/password: sign up, sign in, sign
    out, password reset, account deletion, guest browsing, gated
    actions.
-   Shared listings in Cloud Firestore with photos stored as compressed
    Firestore data (no Cloud Storage); local sample data for a reliable
    demo.
-   Listing create, browse, detail, edit and delete (owner only).
-   Photo selection, compression, and local photo cache.
-   Search and category/mode filters.
-   MapKit map with coordinates and a permission/no-location fallback.
-   Image assistance: bundled pretrained Core ML model (MobileNetV2) for
    category suggestions plus Vision OCR for text, all on device and
    reviewed by the user.
-   Text-only real-time chat per listing between one buyer and the
    seller, with inbox, unread markers, and send/retry states.
-   Firestore security rules that enforce ownership and conversation
    privacy.
-   Empty, error, offline, signed-out, and permission-denied states.

### Explicitly out of scope

-   Payments, delivery tracking, and escrow.
-   Push notifications, read receipts beyond a simple unread marker,
    typing indicators, and presence.
-   Image, voice, or file messages; message edit or delete.
-   Production moderation, reporting, blocking, and reputation systems.
-   Sign in with Apple and social logins (Sign in with Apple needs a
    paid Apple Developer membership).
-   Cloud Functions, Firebase Cloud Storage, and any other service that
    needs the Blaze billing plan.
-   Custom model training or fine-tuning, and any paid AI API.
-   Production geocoding or server-side recommendation engine.

## 6. Technology stack

  --------------------------------------------------------------------------
  Layer                   Technology                 Why
  ----------------------- -------------------------- -----------------------
  UI                      SwiftUI                    Native declarative iOS
                                                     interface

  App state               SwiftUI state /            Lightweight state
                          Observation                management

  Authentication          Firebase Auth              Free email/password
                          (email/password)           accounts, session kept
                                                     in Keychain

  Shared data and chat    Cloud Firestore            Free-tier real-time
                                                     database with offline
                                                     cache

  Local persistence       Codable JSON + Application Sample data, previews,
                          Support, `PhotoStore`      tests, photo cache

  Photos                  PhotosPicker + JPEG        System picker; photos
                          compression                stored in Firestore as
                                                     small blobs

  Map                     MapKit                     Native map and
                                                     annotations

  Location                Core Location              Optional
                                                     current-location access

  Image labels            Core ML (pretrained        On-device classification
                          MobileNetV2) via Vision    that also works in the
                                                     Simulator

  OCR                     Vision                     On-device text
                          `VNRecognizeTextRequest`   recognition

  Contact                 In-app chat; share sheet   No contact details are
                          for demo listings          published
  --------------------------------------------------------------------------

Third-party code: the Firebase iOS SDK (Swift Package Manager; only the
FirebaseAuth and FirebaseFirestore products). Third-party assets: the
pretrained MobileNetV2 model. Record both, with versions and licenses,
in the README.

## 7. ₹0 budget plan

The required version has no paid dependencies: - **Development:** Xcode
and SwiftUI are free; use the iOS Simulator for the presentation (two
Simulators side by side for the chat demo). - **Backend:** Firebase
**Spark** plan --- free, no credit card, no Blaze upgrade. Authentication
and Firestore are used within the free quotas, which are far above a
classroom demo. Features that would require billing (Cloud Storage,
Cloud Functions, push notifications) are excluded by design. A Google
account is needed to create the Firebase project. - **Map:** MapKit,
with network access for map tiles; no paid map API key. - **AI:** Core
ML and Vision run locally; the MobileNetV2 model is a free download. No
AI API subscription. - **Distribution:** demonstrate in Simulator or
submit source/project files. A paid Apple Developer Program membership
is not required to build and run in Simulator.

Important: native iOS development requires access to a Mac capable of
running Xcode. This project is edited on Windows and built on a Mac;
the Firebase package, the `GoogleService-Info.plist`, and the Core ML
model are added on the Mac. Do not pay for a cloud Mac just for this
mini project.

## 8. Demo plan (4--6 minutes)

1.  Show Browse as a guest with listings and explain
    Sell/Exchange/Donate.
2.  Search and filter, then switch to Map and select a marker.
3.  Sign up as **Alice** on Simulator A. Create a listing: pick a photo,
    run Suggest Details (Core ML category plus OCR text), edit, and
    save.
4.  On Simulator B, sign up as **Bob**, find Alice's new listing in
    Browse, and tap Message Seller.
5.  Exchange a few messages live between the two Simulators; show the
    inbox and unread marker on Alice's side.
6.  Show My Listings, edit/delete, then sign out and relaunch to show
    the persisted session.
7.  State the limitations: free-tier quotas, no push notifications, no
    moderation or blocking, no payments, user-reviewed AI suggestions.

## 9. Success criteria

-   The app builds and launches in iOS Simulator.
-   A user can sign up, sign in, sign out, reset a password, and delete
    the account; the session persists across relaunch.
-   A listing created on one device is visible on another, with photos.
-   Sell, Exchange, and Donate are represented correctly.
-   Search/filter and map browsing work.
-   Image suggestions work in the Simulator via the bundled Core ML
    model and OCR, and degrade gracefully.
-   Two accounts can chat in near real time and see the history after
    relaunch.
-   Security rules prevent users from editing others' listings or
    reading others' conversations.
-   The project does not require a paid API, billing plan, subscription,
    or credit card.
-   Limitations of the prototype are clearly stated.

## 10. Future enhancements (only if time/budget permits)

-   Push notifications (needs a paid Apple Developer membership and
    Cloud Functions or another sender).
-   Reporting and blocking users, moderation, and abuse prevention.
-   Photo and location messages; message edit and delete.
-   Seller profiles, ratings, and reputation.
-   Better location selection and distance sorting.
-   Sign in with Apple and other providers.
-   More robust item taxonomy, a custom-trained model, and multilingual
    OCR.
-   Accessibility and localization improvements.

These are future work, not prerequisites for the mini project.
