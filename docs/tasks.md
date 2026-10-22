# Neighbourly --- Implementation Tasks

## Phase 0 --- Project setup

-   [x] Create a SwiftUI iOS project named `Neighbourly`.
-   [x] Set the minimum iOS version to the version supported by the
    installed Xcode (target iOS 17+ if available).
-   [x] Create folders: App, Domain, Data, Services, Features,
    Components, Resources.
-   [x] Add a simple app theme (colors, spacing, typography) using
    system colors so Dark Mode works.
-   [x] Add a README/project note stating: local-only prototype, no paid
    APIs, Simulator demo.
-   [x] Confirm a clean build and launch in Simulator.

**Acceptance:** app opens to a placeholder Browse screen with no
external dependencies.

## Phase 1 --- Domain and local storage

-   [x] Define `ListingMode` (`sell`, `exchange`, `donate`),
    `ListingCategory`, and `ItemCondition`.
-   [x] Define the `Listing` model with UUID, title, description,
    category, mode, optional price, condition, photo filenames, optional
    coordinates/area, seller fields, and creation date.
-   [x] Implement validation (title, price/mode rules, coordinate
    pair/range).
-   [x] Define `ListingRepository` protocol.
-   [x] Implement `LocalListingRepository` using Codable JSON in
    Application Support (or SwiftData if chosen).
-   [x] Implement `PhotoStore` to copy images into app-owned storage and
    return filenames.
-   [x] Add first-launch sample data with several categories and modes,
    including map coordinates.
-   [x] Add repository tests for create/read/update/delete and
    validation.
-   [x] Verify saved listings survive app termination/relaunch.

**Acceptance:** local listings and photos persist without login,
network, or paid services.

## Phase 2 --- Browse and listing cards

-   [x] Build `ListingCard` with thumbnail, title, mode,
    price/"Free"/"Exchange", category, and area.
-   [x] Build Browse list using repository data.
-   [x] Add search across title, description, and area.
-   [x] Add category and mode filters.
-   [x] Add useful empty states and a clear-filters action.
-   [x] Add a List/Map segmented control.
-   [x] Add basic accessibility labels and Dynamic Type support.

**Acceptance:** search and filters produce the expected results on
sample data.

## Phase 3 --- Map and location fallback

-   [x] Build MapKit map annotations/markers for listings with
    coordinates.
-   [x] Tapping a marker selects a listing and presents a
    preview/detail.
-   [x] Add an optional "Use my location" action and request When-In-Use
    permission only on tap.
-   [x] Keep the list usable if permission is denied or location is
    unavailable.
-   [x] Show a map empty state if no listings have coordinates.
-   [x] Use demo coordinates/locality labels; do not put private
    addresses in sample data.
-   [ ] Test with location permission denied and with network/map tiles
    unavailable.

**Acceptance:** map mode works for seeded listings and never blocks list
browsing.

## Phase 4 --- Create listing

-   [x] Build a form for title, description, category, listing mode,
    condition, price, area, and optional seller contact.
-   [x] Add `PhotosPicker` for selecting one or more images.
-   [x] Show selected image previews and allow removal.
-   [x] Copy selected images into `PhotoStore` on save.
-   [x] Validate form inline (including price only for sell mode).
-   [x] Save through `ListingRepository` and return to Browse/My
    Listings.
-   [x] Add cancel confirmation if the form contains unsaved changes.
-   [x] Add tests for required title and sell/exchange/donate
    validation.

**Acceptance:** a user can create a listing, see it in Browse, and find
it after relaunch.

## Phase 5 --- On-device Vision assist

-   [x] Add `VisionAssistService` with a classification method using
    `VNClassifyImageRequest`.
-   [x] Map a small curated set of labels to listing categories; default
    unknown labels to "Other".
-   [x] Add OCR using `VNRecognizeTextRequest`.
-   [x] Add "Suggest details" action to Create Listing.
-   [x] Show a loading/progress state and graceful no-result/error
    states.
-   [x] Present detected labels/text as suggestions, not final data;
    user must confirm/edit.
-   [x] Ensure Vision requests do not block the main UI.
-   [ ] Add tests for category mapping and manual checks with a book,
    appliance, and item with printed text.
-   [x] Add a short UI disclosure: image analysis runs on device;
    results can be wrong.

**Acceptance:** no API key or upload is used; suggestions can be
dismissed or edited.

## Phase 6 --- Details, contact, and My Listings

-   [x] Build Listing Detail with image gallery, details, area, mode,
    and price.
-   [x] Add Contact Seller action using `ShareLink`/system share sheet
    or a clearly labeled local demo contact flow.
    *(Phase 10 adds in-app chat for real listings; this stays for demo
    listings.)*
-   [x] Never show seeded fictional seller contact as a real person.
-   [x] Build My Listings for items created on this device.
-   [x] Add edit and delete actions; confirm before delete.
-   [x] Handle deleted/missing photo files.

**Acceptance:** user can inspect an item and trigger the demo contact
action; own listings can be managed.

## Phase 7 --- Bundled Core ML classifier

Replaces the Simulator-limited Vision classifier with a pretrained model
that also runs in the Simulator. No training or fine-tuning.

-   [x] Download Apple's pretrained **MobileNetV2** Core ML model (FP16,
    12.4 MB, from `ml-assets.apple.com`). Check the license and
    attribution terms on Apple's model page.
-   [ ] Add the model to `neighbourly/Resources/`; confirm Xcode compiles
    it (the synchronized folder picks it up) and note its size.
-   [x] Record the model's source, version, license, and size under
    "Third-party assets" in the README.
-   [x] Add `*.mlmodel binary` to `.gitattributes` before committing the
    file.
-   [x] Add `CoreMLClassificationService` using `VNCoreMLRequest`;
    use `computeUnits = .cpuOnly` on the Simulator; return the top labels
    with confidences.
-   [x] Extend `ListingCategoryMapper` to map ImageNet labels (comma
    separated synonyms) to app categories by keyword, with phrase
    overrides ("book jacket" is a book) and total-confidence voting;
    unknown labels map to "Other"; "notebook computer" is Electronics.
-   [x] Make Core ML the primary classifier in `VisionAssistService`;
    keep Vision's built-in classification only as a fallback on a
    physical device; remove the Simulator-skip workaround.
-   [x] Keep OCR unchanged; keep OCR text out of price/contact fields.
-   [x] Update the "All detected labels" row and the on-device
    disclosure to name the model and say results can be wrong.
-   [x] Handle model-load failure gracefully (clear message, manual
    category still works).
-   [x] Add tests: label-to-category mapping (chair, book jacket, laptop,
    sneaker, unknown), top-label ordering, failure fallback with a stub.
-   [ ] Manual checks in the Simulator with a rocking chair, a book
    cover, a laptop, and a shoe photo.

**Acceptance:** in the Simulator a chair photo suggests Furniture and a
book photo suggests Books, with no network and no API key.

## Phase 8 --- Firebase project and authentication

-   [ ] Developer setup (manual, once): create a Firebase project on the
    Spark plan; enable Email/Password sign-in; register the iOS app with
    bundle ID `com.kjsce.neighbourly`; download
    `GoogleService-Info.plist`.
-   [ ] On the Mac, add `GoogleService-Info.plist` to `neighbourly/`
    (git-ignored) and add the `firebase-ios-sdk` package with only the
    FirebaseAuth and FirebaseFirestore products; commit
    `Package.resolved`.
-   [ ] Create the Firestore database (production mode, nearby region)
    and add `firebase/README.md` documenting the setup steps.
-   [ ] Add `.gitignore` entry for `GoogleService-Info.plist`.
-   [ ] Define `AppUser` and the `AuthService` protocol.
-   [ ] Implement `FirebaseAuthService` (sign up with display name, sign
    in, sign out, password reset, delete account with re-authentication)
    and `MockAuthService`.
-   [ ] Call `FirebaseApp.configure()` once at launch; keep Firebase
    imports inside `Data/Firebase`.
-   [ ] Add `AuthViewModel` exposing session state (signed out, signing
    in, signed in, error) driven by auth state changes.
-   [ ] Add `AuthValidation` (email format, password at least 8
    characters, display name 2--40 characters, matching confirmation)
    and map Firebase errors to friendly messages (wrong password, email
    in use, weak password, network failure, too many attempts).
-   [ ] Build Sign In, Sign Up, and Forgot Password screens with inline
    validation, loading and error states, and Dynamic Type support.
-   [ ] Build the Account tab: name, email, sign out, delete account
    (confirmation plus password).
-   [ ] Keep guest browsing; gate Add Listing, My Listings, Messages, and
    Message Seller behind a sign-in prompt that returns the user to what
    they were doing.
-   [ ] Create a `users/{uid}` profile document with the display name on
    sign-up; never write the email or password to Firestore.
-   [ ] Add tests: validators, error mapping, and `AuthViewModel`
    transitions with `MockAuthService`.

**Acceptance:** a user can sign up, sign in, sign out, reset a password,
and delete their account; the session survives app relaunch; guests can
still browse.

## Phase 9 --- Shared listings in Firestore

-   [ ] Add `sellerID` to `Listing`; stop publishing `sellerContact` for
    shared listings; define what happens to pre-account local listings
    (discard or re-post; sample reset clears them).
-   [ ] Write `firebase/firestore.rules` for `users` and `listings`
    (public read, owner-only write, field and size limits) and publish
    them in the console.
-   [ ] Implement `FirestoreMapping` (Listing to/from documents,
    tolerant of missing fields).
-   [ ] Implement `FirestoreListingRepository` conforming to
    `ListingRepository` (limited queries, newest first).
-   [ ] Compress photos to about 150 KB or less each, store them as
    `Bytes` in `listings/{id}/photos/{n}`, and store a small thumbnail
    (about 25 KB or less) inline on the listing document; cap shared
    listings at 5 photos.
-   [ ] Fetch full photos lazily on the detail screen and cache them in
    `PhotoStore`; keep cards on thumbnails only.
-   [ ] Merge local demo listings with shared listings in Browse; mark
    demo listings clearly.
-   [ ] Enforce ownership in the UI (edit/delete only for the owner) and
    in the rules; My Listings filters by `sellerID`.
-   [ ] Enable Firestore offline persistence; show an offline banner and
    friendly errors (including quota exhausted).
-   [ ] Delete a listing's photos subcollection when the listing is
    deleted; delete a user's listings and profile on account deletion.
-   [ ] Add tests with an in-memory fake: ownership rules, mapping
    round-trip, photo size limits, demo/shared merge ordering.
-   [ ] Optional: test the rules with the Firebase Emulator Suite.

**Acceptance:** a listing posted as Alice on one Simulator appears, with
photos, for Bob on another Simulator; Bob cannot edit or delete it.

## Phase 10 --- Text chat between buyer and seller

-   [ ] Define `Conversation` and `ChatMessage` with deterministic
    conversation IDs (`listingID_buyerID`).
-   [ ] Define `ChatRepository`; implement `FirestoreChatRepository`
    (snapshot listeners exposed as `AsyncStream`) and
    `InMemoryChatRepository` for tests and previews.
-   [ ] Add rules for `conversations` and `messages`: participants only;
    `senderID == request.auth.uid`; text length 1--1,000;
    `createdAt == request.time`; buyer cannot be the seller; no update or
    delete.
-   [ ] Add **Message Seller** to the listing detail for signed-in users
    on someone else's real listing; create or reopen the conversation;
    keep the share-sheet Contact Seller for demo listings; show Edit and
    Delete on your own listing instead.
-   [ ] Build the Messages tab inbox: newest first, other person's name,
    listing title, last message preview, time, unread indicator, and
    empty/signed-out states.
-   [ ] Build the conversation screen: message bubbles, day separators,
    multi-line composer with trimmed 1--1,000 character limit, Send
    disabled when invalid, auto-scroll to the newest message, and a link
    to the listing.
-   [ ] Show pending and failed sends with Retry; handle offline and
    permission-denied states.
-   [ ] Mark a conversation read when opened; show an unread badge on
    the Messages tab.
-   [ ] Attach listeners on appear and detach on disappear and on
    sign-out so no data leaks between accounts.
-   [ ] Render messages as plain text; add VoiceOver labels for sender
    and time and Dynamic Type support.
-   [ ] Add tests with `InMemoryChatRepository`: conversation ID,
    trimming and length limits, ordering, unread logic, cannot message
    your own listing.
-   [ ] Manual test with two Simulators exchanging messages both ways,
    plus airplane mode and relaunch.
-   [ ] Optional: rules tests for non-participant reads, spoofed
    `senderID`, and oversized messages.

**Acceptance:** two accounts on two Simulators exchange messages within
about two seconds; history persists after relaunch; a third account
cannot read the conversation.

## Phase 11 --- Polish and final verification

-   [ ] Add app icon/title and consistent navigation across the four
    tabs.
-   [ ] Check loading, empty, error, offline, signed-out, and
    permission-denied states for every screen.
-   [ ] Test Dark Mode, Dynamic Type, and VoiceOver labels on core
    controls, including auth forms and chat.
-   [ ] Test fresh install, populated install, relaunch, sign-out then
    sign-in as a different user (no leftover data), and reset sample
    data.
-   [ ] Re-read Firestore rules against the checklist in
    `architecture.md` section 10; re-test as a non-owner and a
    non-participant.
-   [ ] Confirm the Firebase project is still on the Spark plan with no
    billing account attached, and note the quota numbers in the report.
-   [ ] Confirm the repository contains no secrets (no service-account
    keys; the plist is git-ignored) and no unused packages.
-   [ ] Update the README: setup steps for a fresh Mac, third-party
    assets and licenses, privacy summary, and known limitations.
-   [ ] Record a demo flow: guest Browse → search/filter → map → sign up
    → create listing with Suggest Details → second Simulator signs up,
    finds the listing, messages the seller → reply → My Listings → sign
    out/relaunch.
-   [ ] Add screenshots, the data layout, and the security-rules summary
    to the submission/report.
-   [ ] Confirm the app can be demonstrated with ₹0 spent.

## Suggested build order for a tight deadline

1.  Domain + JSON persistence + sample data. *(done)*
2.  Browse cards, search, and filters. *(done)*
3.  Create listing and photo persistence. *(done)*
4.  Listing detail + My Listings. *(done)*
5.  Map with seeded coordinates. *(done)*
6.  Vision OCR and on-device suggestions. *(done)*
7.  Bundled Core ML classifier (independent of the backend).
8.  Firebase setup and authentication.
9.  Shared listings in Firestore (needed before chat is meaningful).
10. Text chat.
11. UI polish, rules review, and tests.

Phases 8--10 depend on each other in that order. If time runs short,
cut optional items (rules emulator tests, unread badge, day separators)
before cutting security rules or the two-Simulator demo.

Do not begin with payments, push notifications, Sign in with Apple,
image messages, Cloud Functions, Cloud Storage, or custom model
training; they need paid plans or are not required for the zero-cost
mini project.
