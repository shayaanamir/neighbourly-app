# Neighbourly --- Architecture

## 1. Purpose and scope

Neighbourly is a SwiftUI local-community marketplace mini project. Users
create accounts, post listings to sell, exchange, or donate items,
browse nearby listings on a map or in a list, view item details, and
chat with the seller in real time. On-device Apple frameworks (Vision
OCR) and a bundled pretrained Core ML model provide optional image
assistance.

**Zero-cost constraint:** the project must run without paid APIs,
subscriptions, or a paid Apple Developer membership. The backend is the
**Firebase Spark (free) plan**: Firebase Authentication (email/password)
and Cloud Firestore. No credit card or Blaze billing plan is required,
and none of the required features may depend on one. MapKit, Core
Location, Vision, Core ML, SwiftUI, and the system share sheet are Apple
frameworks available at no additional usage charge.

Not used, because they need a paid plan or account: Firebase Cloud
Storage (currently requires the Blaze plan for new projects --- verify
in the console), Cloud Functions, Firebase Cloud Messaging / APNs push
notifications, and Sign in with Apple (requires the paid Apple Developer
Program).

## 2. MVP assumptions and boundaries

-   Target: iOS 17+ (adjust to the Xcode/iOS version available); Swift
    5.9+; SwiftUI.
-   The app is **edited on Windows and built on a Mac** (pulled from the
    repository). Xcode is free, but a Mac is required to build.
    Simulator is the guaranteed demo path; physical-device installation
    has free-account signing limits.
-   **Accounts:** email/password sign-up and sign-in through Firebase
    Auth. Browsing is open to guests; posting listings, My Listings, and
    messaging require an account.
-   **Shared data:** listings and chat messages live in Firestore so two
    people on two devices (or two Simulators) see the same data. Chat is
    **text only**, live while the app is open; there are no push
    notifications.
-   **Internet is required** for accounts, shared listings, and chat.
    Firestore's offline cache lets previously loaded data be read and
    queues writes, but sign-in and first load need a connection.
-   **Sample listings** remain local, are marked `isDemo`, and are merged
    into Browse. Their sellers are fictional, so they cannot be chatted
    with; Contact Seller on a demo listing keeps the share-sheet
    behavior.
-   Map location is optional. Ask permission only when the user taps a
    location-related feature.
-   Image classification and OCR are suggestions, not authoritative. The
    user reviews and edits all extracted values before saving.
-   No payments, delivery, push notifications, moderation backend, or
    image/file messages in MVP.

## 3. High-level structure

``` text
NeighbourlyApp
 ├─ App / Navigation (tabs: Browse, My Listings, Messages, Account)
 ├─ Features
 │   ├─ Auth (sign in, sign up, reset password, gate prompt)
 │   ├─ Account (profile, sign out, delete account)
 │   ├─ Browse (list, filters, map)
 │   ├─ ListingDetail
 │   ├─ CreateListing (photos, form, image assist)
 │   ├─ MyListings
 │   └─ Chat (inbox, conversation)
 ├─ Domain
 │   ├─ Listing / ListingCategory / ListingMode
 │   ├─ AppUser
 │   ├─ Conversation / ChatMessage
 │   └─ Protocols: ListingRepository, ChatRepository, AuthService
 ├─ Data
 │   ├─ Local: LocalListingRepository, PhotoStore (cache), SampleListings
 │   └─ Firebase: FirestoreListingRepository, FirestoreChatRepository,
 │                FirebaseAuthService
 ├─ Services
 │   ├─ LocationService (Core Location)
 │   ├─ VisionAssistService (OCR + classification pipeline)
 │   ├─ CoreMLClassificationService (bundled MobileNetV2)
 │   └─ ContactService / share (system UI)
 └─ Components (reusable cards, chips, empty states)
```

Keep feature screens mostly independent. Views render state and forward
user actions; view models hold feature state; services handle framework
work; repositories own persistence. Every network-backed dependency sits
behind a protocol with an in-memory implementation, so previews and unit
tests never touch Firebase.

## 4. Suggested folder layout

``` text
neighbourly/
  App/
    NeighbourlyApp.swift        (FirebaseApp.configure, scene)
    RootView.swift              (tabs, auth gating)
    AppDependencies.swift       (live / preview / test wiring)
  Domain/
    Listing.swift, ListingEnums.swift, Listing+Validation.swift
    AppUser.swift
    Conversation.swift, ChatMessage.swift
    ListingRepository.swift, ChatRepository.swift, AuthService.swift
  Data/
    LocalListingRepository.swift, InMemoryListingRepository.swift
    PhotoStore.swift, SampleListings.swift
    Firebase/
      FirebaseAuthService.swift
      FirestoreListingRepository.swift
      FirestoreChatRepository.swift
      FirestoreMapping.swift    (model <-> document conversion)
    InMemoryChatRepository.swift, MockAuthService.swift
  Services/
    LocationService.swift
    VisionAssistService.swift
    CoreMLClassificationService.swift
    VisionBuiltInClassifier.swift  (device-only fallback)
    ImageClassifying.swift     (classifier protocol, crop/merge helpers)
    ImageSuggestions.swift
    ContactService.swift
  Features/
    Auth/        (SignInView, SignUpView, ForgotPasswordView,
                  AuthViewModel, AuthValidation)
    Account/     (AccountView)
    Browse/      (BrowseView, BrowseViewModel, ListingMapView, filters)
    ListingDetail/
    CreateListing/
    MyListings/
    Chat/        (InboxView, InboxViewModel, ConversationView,
                  ConversationViewModel, MessageBubble)
  Components/
  Resources/
    Assets.xcassets
    MobileNetV2.mlmodel         (pretrained, see section 8)
firebase/
  firestore.rules               (security rules, pasted into console)
  README.md                     (Firebase setup steps)
```

`GoogleService-Info.plist` is placed in `neighbourly/` on the Mac and
is **git-ignored** (see section 10).

## 5. Domain model

### Listing

Use a `Listing` value model. Fields:

-   `id: UUID`
-   `title: String`, `description: String`
-   `category: ListingCategory`, `mode: ListingMode` (`sell`,
    `exchange`, `donate`)
-   `price: Decimal?` --- required only for sell
-   `condition: ItemCondition`
-   `imageFileNames: [String]` --- cached photo file names (not image
    bytes in the model)
-   `latitude: Double?`, `longitude: Double?`, `areaName: String?`
-   `sellerID: String?` --- Firebase Auth UID of the owner; `nil` for
    demo listings
-   `sellerName: String` --- display name copied at posting time
-   `createdAt: Date`, `isDemo: Bool`

`sellerContact` (email/phone typed into a listing) is **removed from
shared listings**: chat replaces it, and publishing contact details in a
public database is a privacy risk. It may remain for local-only legacy
data until Phase 9 migrates it away.

Validation rules: 1. Title is non-empty, max 80 chars. 2. Description
max 1,000 chars. 3. Sell requires a non-negative price; exchange/donate
have none. 4. Photos are optional (max 5). 5. Coordinates are both
present or both absent and in range. 6. Shared listings require a
`sellerID`. 7. OCR/classification output never saves automatically.

### AppUser

`uid: String`, `displayName: String`, `email: String?` (email is kept
only in Firebase Auth and shown to its owner; it is never written to
Firestore).

### Conversation and ChatMessage

-   `Conversation`: `id` (deterministic: `"{listingID}_{buyerID}"`, so
    one buyer has one thread per listing), `listingID`, `listingTitle`
    (snapshot), `sellerID`, `buyerID`, `participantIDs: [String]`,
    `lastMessageText`, `lastMessageAt`, `lastMessageSenderID`, and
    per-user read markers (`readAt` map keyed by uid).
-   `ChatMessage`: `id`, `senderID`, `text` (1--1,000 chars after
    trimming), `createdAt` (server timestamp).

Messages are immutable: no edit or delete in MVP.

## 6. Data and persistence

### Repository protocols

``` swift
protocol ListingRepository {
    func fetchListings() async throws -> [Listing]
    func save(_ listing: Listing) async throws
    func delete(id: UUID) async throws
    func resetToSampleData() async throws
}

protocol AuthService {
    var currentUser: AppUser? { get }
    func authStateChanges() -> AsyncStream<AppUser?>
    func signUp(name: String, email: String, password: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func sendPasswordReset(email: String) async throws
    func signOut() throws
    func deleteAccount(password: String) async throws
}

protocol ChatRepository {
    func conversations(for userID: String) -> AsyncStream<[Conversation]>
    func messages(in conversationID: String) -> AsyncStream<[ChatMessage]>
    func startConversation(listing: Listing, buyer: AppUser) async throws -> Conversation
    func send(_ text: String, in conversation: Conversation, from user: AppUser) async throws
    func markRead(_ conversation: Conversation, by userID: String) async throws
}
```

(Signatures are guidance; adjust to what compiles cleanly.)

### Local storage (kept)

`LocalListingRepository` (Codable JSON in Application Support) still
backs the sample/demo listings, previews, and unit tests.
`PhotoStore` becomes a **disk cache** for photos downloaded from
Firestore as well as photos picked on this device.

### Cloud storage (new)

`FirestoreListingRepository` stores shared listings; Browse shows
Firestore listings merged with local demo listings. Photos cannot use
Firebase Storage on the free plan, so they are stored in Firestore:

-   Each photo is downscaled and JPEG-compressed to **about 150 KB or
    less** (longest edge about 1,200 px) and saved as a Firestore
    `Bytes` field in `listings/{id}/photos/{photoID}` (document limit is
    1 MiB; keep well under it).
-   A tiny **thumbnail** (about 300 px, 25 KB or less) is stored inline
    in the listing document so Browse cards load without downloading
    full photos.
-   Detail screens fetch full photos lazily and cache them in
    `PhotoStore`.
-   Limit shared listings to 5 photos.

Repository responsibilities: load listings, add/update/delete (owner
only), seed sample data locally on first launch, handle malformed or
missing documents gracefully, and surface friendly errors.

## 7. Feature flows

### Sign up / sign in

1.  Guest opens the app and can browse. Tapping Add Listing, My
    Listings, Messages, or Message Seller shows a sign-in prompt.
2.  Sign up collects display name, email, password (and confirmation);
    validate client-side, then call Firebase. Sign in takes email and
    password. Forgot password sends Firebase's reset email.
3.  The session persists across relaunches (Firebase stores it in the
    Keychain). Sign out returns to guest mode.
4.  Account tab shows name and email, sign out, and **delete account**
    (requires re-entering the password; also removes the user's
    listings and profile document).

### Browse

-   Start with shared listings plus local samples.
-   Search title, description, and area name; filter by category and
    mode; toggle List / Map; map pins open a preview then detail.

### Create listing

1.  Signed-in user selects up to 5 photos with `PhotosPicker`.
2.  User may tap "Suggest details" (Core ML + OCR, section 8).
3.  User edits title, description, category, mode, condition, price,
    area.
4.  Validate, compress photos, and save through the repository; the
    listing appears for everyone.

### Listing detail

-   Photos, price, condition, area, description, and seller name.
-   **Message Seller** (signed in, real listing, not your own) opens or
    creates the conversation for that listing and buyer. On your own
    listing the button is replaced by an Edit/Delete menu. Demo listings
    keep the share-sheet Contact Seller.

### Chat

1.  **Messages tab (inbox):** conversations the user is part of, newest
    first, showing the other person's name, listing title, last message
    preview, time, and an unread indicator. Empty state explains how to
    start a chat from a listing.
2.  **Conversation screen:** message bubbles (mine right, theirs left),
    day separators, a multi-line composer, Send disabled for empty or
    over-long text, auto-scroll to the newest message, and a header
    linking back to the listing.
3.  Messages stream live through Firestore snapshot listeners. Attach the
    listener when the screen appears and detach on disappear and on
    sign-out.
4.  Sends are optimistic: Firestore queues a write offline and shows it
    as pending; failures show a Retry affordance.
5.  Opening a conversation marks it read for the current user.

### My Listings

-   Listings whose `sellerID` equals the signed-in user's UID.
-   Edit/delete with confirmation. A reset-sample-data action only
    affects local demo data.

## 8. On-device image assistance (Core ML + Vision)

Image assistance stays on device: no photo is uploaded for analysis.

**Classification:** a bundled pretrained **MobileNetV2** Core ML model
(Apple's published ImageNet classifier, 1,001 categories; the FP16
version used here is about 12.4 MB). It is used through Vision's
`VNCoreMLRequest`.

-   Download the model on the Mac from Apple's Core ML model gallery,
    check the license/attribution terms on that page, and record the
    source, version, license, and size in the README ("Third-party
    assets"). Place it in `neighbourly/Resources/`; the synchronized
    Xcode group compiles it automatically.
-   Core ML runs on the Simulator's CPU, which fixes the Simulator
    limitation seen with Vision's built-in classifier. Set
    `MLModelConfiguration.computeUnits = .cpuOnly` when running on the
    Simulator.
-   `ListingCategoryMapper` maps ImageNet labels (for example "rocking
    chair, rocker", "book jacket, dust cover", "laptop, laptop
    computer") to a small set of app categories by keyword, with phrase
    overrides ("book jacket" is a book, "table lamp" is home) and
    total-confidence voting across the top labels; unknown labels map to
    **Other**. ImageNet's "notebook" means a laptop, so "notebook
    computer" maps to Electronics. The mapper is pure Swift and unit
    tested.
-   The model is loaded by name at runtime (not through Xcode's
    generated class), so a missing model degrades to "classification
    unavailable" instead of breaking the build. Photos are classified
    whole and as a centre crop, keeping each label's best score.
-   Show the top labels with confidences in the collapsible "All
    detected labels" row so users can see why a suggestion was made.
-   If the model fails to load, fall back to Vision's built-in
    `VNClassifyImageRequest` on a physical device, and otherwise report
    that classification is unavailable. OCR and manual category choice
    always work.

**OCR:** `VNRecognizeTextRequest` returns recognized lines as untrusted
plain text. Users can use a line as the title or add it to the
description. OCR text is never applied to price or contact fields.

Requests run off the main actor; show a loading state and handle
no-result and failure states. State clearly in the UI that analysis runs
on device and may be wrong. This is lightweight pretrained recognition,
**not a custom-trained marketplace model**; do not train or fine-tune
models.

## 9. Location and maps at ₹0

-   Use MapKit (`Map`, `Marker`) and Core Location.
-   Request When-In-Use authorization only after a user action; keep
    browsing usable without permission.
-   Use demo coordinates for sample data; do not seed private addresses.
    User-posted listings carry only a locality label.
-   Avoid geocoding dependencies. Location never leaves the device
    except for the locality label a user types into a listing.
-   MapKit needs network access for tiles; features must still work
    if tiles are unavailable.

## 10. Firebase backend

### Setup (one time, done by the developer)

1.  Create a Firebase project on the **Spark** plan (no billing).
2.  Enable **Authentication → Email/Password**.
3.  Create a **Cloud Firestore** database in production mode, in a
    nearby region (for example Mumbai, `asia-south1`).
4.  Register an iOS app with bundle ID `com.kjsce.neighbourly` and
    download `GoogleService-Info.plist`.
5.  On the Mac: copy the plist into `neighbourly/` (it is git-ignored),
    and add the `firebase-ios-sdk` Swift package with the
    **FirebaseAuth** and **FirebaseFirestore** products only. Commit
    the resulting `Package.resolved`.
6.  Publish `firebase/firestore.rules` in the console (Firestore →
    Rules). Re-publish whenever the file changes.

The plist holds project identifiers, not private secrets; real access
control is enforced by Firestore security rules, so **the rules matter
more than hiding the plist**. Do not add admin/service-account keys to
the repository.

### Data layout

``` text
users/{uid}                         displayName, createdAt
listings/{listingID}                listing fields, sellerID, thumbnail
listings/{listingID}/photos/{n}     data (Bytes), order
conversations/{listingID_buyerID}   participantIDs, listing info,
                                    last message summary, readAt map
conversations/{id}/messages/{id}    senderID, text, createdAt
```

### Security rules (intent)

-   `users/{uid}`: anyone signed in can read `displayName`; only the
    owner can write their own document.
-   `listings`: anyone (including guests) can read; create requires
    `request.auth.uid == sellerID`; update/delete only by the owner;
    field type and length limits (title, description, price,
    photo count).
-   `listings/{id}/photos`: public read; write only by the listing's
    owner; size-limited.
-   `conversations`: read/write only if `request.auth.uid` is in
    `participantIDs`; create must list exactly the buyer and the
    listing's seller, and the buyer cannot be the seller.
-   `messages`: read only by participants; create only by a participant
    with `senderID == request.auth.uid`, `text` a string of 1--1,000
    characters, and `createdAt == request.time`; no update or delete.

Keep the rules in `firebase/firestore.rules` under version control.
Optionally test them with the Firebase Emulator Suite
(`@firebase/rules-unit-testing`; requires Node and Java).

### Free-plan limits

The Spark plan has daily read/write quotas and about 1 GiB of Firestore
storage. A classroom demo is far below them, but avoid unbounded
listeners (always limit queries) and large photo payloads. Check the
current limits in the Firebase console before the demo. If a quota is
ever exhausted, the app should show a friendly error rather than crash.

## 11. State management and concurrency

-   `@State` for view-local state; `@Observable` view models for
    feature state; inject repositories and services from
    `AppDependencies` (live, preview, and test variants).
-   An `AuthViewModel` (or session object) at the root exposes the
    signed-in user and drives gating. Listen to auth state changes with
    an `AsyncStream`; cancel listeners on sign-out.
-   Chat listeners are `AsyncStream`-based and owned by the screen's
    view model; tie them to `.task` so they cancel automatically.
-   Keep expensive work (Core ML, Vision, JPEG compression) off the main
    actor; update UI state on the main actor.
-   Avoid global mutable singletons; `FirebaseApp.configure()` is called
    once at launch and Firebase objects are only touched inside the
    `Data/Firebase` layer.

## 12. Privacy, safety, and errors

-   The app now collects an email address, a display name, listings,
    photos, and chat messages, stored in Firebase (Google Cloud). Say so
    in the README and presentation. Do not collect analytics or
    background location.
-   Never store passwords in the app or in Firestore; Firebase Auth
    handles credentials. Never log emails, passwords, or message text.
-   Keep emails private: they live in Firebase Auth only and are not
    written to Firestore or shown to other users.
-   Account deletion removes the user's profile and listings and deletes
    the Auth account. Conversations may keep messages for the other
    participant; explain this in the UI.
-   Ask permission in context and provide a fallback.
-   Treat OCR text and chat messages as plain text: render them as
    ordinary `Text`, never as markup or links that execute anything.
-   Provide states for loading, empty, signed-out, offline,
    permission-denied, missing image, quota/persistence errors, and
    model unavailable.
-   A real marketplace also needs reporting, blocking, moderation, rate
    limiting, spam controls, and push notifications. These are outside
    the MVP and must be called out as limitations in the presentation.

## 13. Testing strategy

-   Unit tests: listing validation, mode/price rules, category mapping
    (ImageNet and Vision labels), repository CRUD, photo compression
    limits, auth validators and error mapping, auth view-model state
    transitions (with `MockAuthService`), chat view-model behavior (send
    trimming, length limit, ordering, read markers) with
    `InMemoryChatRepository`.
-   No unit test may need the network or a Firebase project.
-   Optional: Firestore rules tests with the Emulator Suite, covering
    non-participant reads, spoofed `senderID`, oversized messages, and
    editing someone else's listing.
-   UI tests: sign up/in flow with a mock service, create a listing,
    filter browse, open details, start a chat, delete listing.
-   Manual tests: two Simulators signed in as different users exchanging
    messages, airplane mode, wrong password, relaunch persistence, no
    location permission, no photos, no OCR text, map tiles unavailable.

## 14. Definition of done

The mini project is complete when: 1. The app builds and launches in
Simulator. 2. Sample listings appear in Browse for guests. 3. A user can
sign up, sign in, sign out, reset a password, and delete their account;
the session survives relaunch. 4. A listing posted by one account is
visible to a second account on another device or Simulator, including
photos. 5. Search, filters, and List/Map work, with a no-coordinate
fallback. 6. Photo suggestions work in the Simulator through the bundled
Core ML model and OCR, and users can ignore or edit them. 7. Message
Seller starts a conversation; two accounts can exchange text messages in
near real time, see them in the inbox, and keep them after relaunch.
8. Only owners can edit or delete their listings, and only participants
can read a conversation (enforced by security rules, not just the UI).
9. No paid service, billing plan, or credit card is required. 10. Known
limitations (no push notifications, no moderation, free-tier quotas)
are documented.
