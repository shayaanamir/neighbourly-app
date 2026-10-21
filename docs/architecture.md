# Neighbourly --- Architecture

## 1. Purpose and scope

Neighbourly is a SwiftUI local-community marketplace mini project. Users
can create listings to sell, exchange, or donate items; browse nearby
listings on a map or in a list; view item details; and contact a seller.
On-device Apple frameworks provide optional image classification and
OCR.

**Zero-cost constraint:** the MVP must run without paid APIs,
subscriptions, cloud hosting, or a paid Apple Developer membership. The
default implementation is local-first: listing data and photos stay on
the device. MapKit, Core Location, Vision, SwiftUI, SwiftData (or
Codable + files), and the system share sheet are Apple frameworks
available at no additional usage charge. Do not add Firebase, paid
geocoding, paid AI APIs, or a hosted backend to the required MVP.

## 2. MVP assumptions and boundaries

-   Target: iOS 17+ (adjust to the Xcode/iOS version available); Swift
    5.9+; SwiftUI.
-   Build and demo in Xcode Simulator on a Mac. Xcode is free, but a Mac
    is required for native iOS development. Physical-device
    installation/signing may have free-account limitations; Simulator is
    the guaranteed demo path.
-   Single-device prototype: listings are persisted locally and are not
    shared with other users/devices. Seller contact is a demo contact
    action (Share sheet, email/phone if the user entered one, or a
    clearly labeled mock contact screen).
-   Map location is optional. Ask permission only when the user taps a
    location-related feature. If permission is denied, show a list and a
    manually selected demo area / sample coordinates.
-   Image classification and OCR are suggestions, not authoritative. The
    user reviews and edits all extracted values before saving.
-   No payments, delivery, moderation backend, authentication, chat
    server, or real multi-user synchronization in MVP.

## 3. High-level structure

``` text
NeighbourlyApp
 ├─ App / Navigation
 ├─ Features
 │   ├─ Browse (list, filters, map)
 │   ├─ ListingDetail
 │   ├─ CreateListing (photos, form, AI assist)
 │   ├─ MyListings
 │   └─ ContactSeller (share / local demo)
 ├─ Domain
 │   ├─ Listing
 │   ├─ ListingCategory / ListingMode
 │   └─ ListingRepository protocol
 ├─ Data
 │   ├─ LocalListingRepository
 │   ├─ PhotoStore
 │   └─ SampleData
 ├─ Services
 │   ├─ LocationService (Core Location)
 │   ├─ MapKit presentation
 │   ├─ ImageClassificationService (Vision)
 │   ├─ TextRecognitionService (Vision)
 │   └─ Contact/Share service (system UI)
 └─ DesignSystem (reusable cards, chips, empty states)
```

Keep feature screens mostly independent. Views render state and forward
user actions; services handle framework work; repositories own
persistence.

## 4. Suggested folder layout

``` text
Neighbourly/
  App/
    NeighbourlyApp.swift
    AppRouter.swift
  Domain/
    Listing.swift
    ListingEnums.swift
    ListingRepository.swift
  Data/
    LocalListingRepository.swift
    PhotoStore.swift
    SampleListings.swift
  Services/
    LocationService.swift
    VisionAssistService.swift
    ShareService.swift
  Features/
    Browse/
      BrowseView.swift
      BrowseViewModel.swift
      ListingMapView.swift
      ListingFilters.swift
    ListingDetail/
      ListingDetailView.swift
    CreateListing/
      CreateListingView.swift
      CreateListingViewModel.swift
      ImageAssistReviewView.swift
    MyListings/
      MyListingsView.swift
  Components/
    ListingCard.swift
    CategoryChip.swift
    EmptyStateView.swift
  Resources/
    Assets.xcassets
```

For a very small mini project, combine View and ViewModel files where
convenient, but retain the Domain/Data/Services separation.

## 5. Domain model

Use a `Listing` value model. Suggested fields:

-   `id: UUID`
-   `title: String`
-   `description: String`
-   `category: ListingCategory`
-   `mode: ListingMode` --- `sell`, `exchange`, `donate`
-   `price: Decimal?` --- required only for sell; exchange/donate can be
    nil
-   `condition: ItemCondition`
-   `imageFileNames: [String]` --- stored file names, not giant image
    blobs in the model
-   `latitude: Double?`, `longitude: Double?`
-   `areaName: String?` --- user-entered neighborhood/locality label
-   `sellerName: String`
-   `sellerContact: String?` --- optional; keep local and do not expose
    without user action
-   `createdAt: Date`
-   `isDemo: Bool` (optional, useful to distinguish seeded content)

Enums: - Category examples: electronics, books, furniture, clothing,
home, sports, other. - Condition examples: new, likeNew, good, fair. -
Mode: sell, exchange, donate.

Validation rules: 1. Title is non-empty and has a sensible maximum
(e.g. 80 chars). 2. Description may be empty but has a maximum
(e.g. 1,000 chars). 3. A sell listing requires a non-negative price;
exchange/donate do not require a price. 4. At least one image is
recommended, but permit saving without one for accessibility/testing. 5.
Coordinates must be both present or both absent and within valid ranges.
6. OCR/classification output never saves automatically; user
confirmation is required.

## 6. Data and persistence

### Local repository

Define a small protocol so UI does not depend on persistence details:

``` swift
protocol ListingRepository {
    func fetchListings() async throws -> [Listing]
    func save(_ listing: Listing) async throws
    func delete(id: UUID) async throws
}
```

Implement `LocalListingRepository` using one of: - **Recommended for a
mini project:** Codable JSON in Application Support plus a separate
photo directory. Easy to inspect and avoids schema setup. -
**Alternative:** SwiftData if the target deployment and course setup
support it. Store photo filenames separately from image bytes.

Repository responsibilities: - Load saved listings on launch. -
Add/update/delete listings. - Seed sample listings only on first launch
(or provide a reset-demo button). - Handle malformed/missing files
gracefully and show a friendly empty state. - Keep writes atomic where
practical.

`PhotoStore` responsibilities: - Copy selected photos into the app's
local documents/Application Support directory. - Generate unique
filenames. - Return filenames to persist in Listing. - Delete orphaned
image files when a listing is deleted (optional cleanup task). - Use
`PhotosPicker` and request only selected photo access.

## 7. Feature flows

### Browse

-   Start with a list of seeded/local listings.
-   Search title, description, and area name.
-   Filter by category and listing mode.
-   Toggle List / Map.
-   Map pins use listing coordinates; selecting a pin opens a compact
    preview or detail view.
-   If no listing has coordinates, map mode shows an explanatory empty
    state and a button to return to List.

### Create listing

1.  User selects one or more photos with `PhotosPicker`.
2.  App copies photos to local storage.
3.  User may tap "Suggest details."
4.  Vision classification proposes a category/label; OCR proposes text
    snippets. Treat text as untrusted and do not auto-fill price or
    contact data without explicit review.
5.  User edits title, description, category, mode, condition, price, and
    location.
6.  Validate and save through repository.
7.  Return to Browse/My Listings with a success state.

### Listing detail and seller contact

-   Show images, title, mode, price (if sell), condition, description,
    area, and seller.
-   "Contact seller" opens a system share sheet with a prefilled message
    or an entered email/phone action.
-   For seeded listings, use an explicitly fictional contact or a demo
    contact screen. Do not imply the local prototype sends in-app
    messages.

### My Listings

-   Show listings created on this device.
-   Edit/delete actions.
-   Confirm before deletion.
-   A reset sample-data action is optional and should be clearly marked.

## 8. AI/image assistance at ₹0

Use Apple's on-device **Vision** framework: - `VNClassifyImageRequest`
for broad image labels. Map a small set of known labels to app
categories (e.g. book, chair, electronics) and otherwise suggest
"Other". - `VNRecognizeTextRequest` for OCR. Show recognized lines as a
reviewable suggestion. OCR may detect labels, brand names, or model
numbers; it is not a reliable source for price or item condition. - Run
requests off the main thread / in an async task, show a loading state,
and handle no-result or failure gracefully. - Do not upload images.
Explain in the UI that analysis runs on-device. - Avoid promising
specialized AI understanding. This is lightweight OS-provided image
recognition, not a custom trained marketplace model.

## 9. Location and maps at ₹0

-   Use MapKit (`Map`, `Annotation`/`Marker`) and Core Location
    (`CLLocationManager` or a small wrapper).
-   Request When-In-Use authorization only after a user action.
-   Keep browsing usable without location permission.
-   For the demo, use fixed sample coordinates in a fictional/demo
    neighborhood or user-entered locality. Do not use real private
    addresses in seeded data.
-   Avoid a geocoding dependency. A location can be entered as an area
    label; coordinates may be selected from a demo map or obtained from
    device location with consent.
-   MapKit map display is free within Apple's platform terms, but it
    requires network access for map tiles. App features must still work
    if tiles are unavailable.

## 10. State management and concurrency

-   Use `@State` for view-local presentation state.
-   Use `@Observable` (or `ObservableObject` if the project's deployment
    target requires it) for feature state.
-   Inject `ListingRepository` and service dependencies at app
    composition/root level.
-   Keep expensive Vision work off the main actor; update UI state on
    the main actor.
-   Avoid global mutable singletons. A simple dependency container is
    enough for this scope.

## 11. Privacy, safety, and errors

-   Do not collect accounts, analytics, or background location.
-   Keep photos and contact details on device.
-   Ask permission in context and provide a fallback.
-   Validate inputs and escape/display OCR text as ordinary text.
-   Provide states for loading, empty, permission denied, missing image,
    persistence error, and Vision unavailable.
-   In a real marketplace, user-generated listings need reporting,
    moderation, authentication, and privacy controls. These are
    explicitly outside this local-only prototype and must be called out
    in the project presentation.

## 12. Testing strategy

-   Unit tests: listing validation, mode/price rules, category mapping,
    repository CRUD, photo filename generation.
-   UI tests: create a listing, filter browse, open details, delete
    listing, permission-denied fallback.
-   Manual tests: no location permission, no photos, Vision returns no
    text, app relaunch persistence, map network unavailable.
-   Keep a few sample listings to make the map and browse screens
    demonstrable without backend data.

## 13. Definition of done

The mini project is complete when: 1. The app builds and launches in
Simulator. 2. Sample listings appear in Browse. 3. Search and filters
work. 4. List/Map switch works with seeded coordinates and has a
no-coordinate fallback. 5. A user can create a listing with a photo,
save it, relaunch, and see it persist. 6. Vision can suggest a
category/OCR text when available, and the user can ignore/edit
suggestions. 7. Listing details and a seller contact/share action work.
8. No paid service, API key, subscription, or cloud account is required.
