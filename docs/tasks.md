# Neighbourly --- Implementation Tasks

## Phase 0 --- Project setup

-   [ ] Create a SwiftUI iOS project named `Neighbourly`.
-   [ ] Set the minimum iOS version to the version supported by the
    installed Xcode (target iOS 17+ if available).
-   [ ] Create folders: App, Domain, Data, Services, Features,
    Components, Resources.
-   [ ] Add a simple app theme (colors, spacing, typography) using
    system colors so Dark Mode works.
-   [ ] Add a README/project note stating: local-only prototype, no paid
    APIs, Simulator demo.
-   [ ] Confirm a clean build and launch in Simulator.

**Acceptance:** app opens to a placeholder Browse screen with no
external dependencies.

## Phase 1 --- Domain and local storage

-   [ ] Define `ListingMode` (`sell`, `exchange`, `donate`),
    `ListingCategory`, and `ItemCondition`.
-   [ ] Define the `Listing` model with UUID, title, description,
    category, mode, optional price, condition, photo filenames, optional
    coordinates/area, seller fields, and creation date.
-   [ ] Implement validation (title, price/mode rules, coordinate
    pair/range).
-   [ ] Define `ListingRepository` protocol.
-   [ ] Implement `LocalListingRepository` using Codable JSON in
    Application Support (or SwiftData if chosen).
-   [ ] Implement `PhotoStore` to copy images into app-owned storage and
    return filenames.
-   [ ] Add first-launch sample data with several categories and modes,
    including map coordinates.
-   [ ] Add repository tests for create/read/update/delete and
    validation.
-   [ ] Verify saved listings survive app termination/relaunch.

**Acceptance:** local listings and photos persist without login,
network, or paid services.

## Phase 2 --- Browse and listing cards

-   [ ] Build `ListingCard` with thumbnail, title, mode,
    price/"Free"/"Exchange", category, and area.
-   [ ] Build Browse list using repository data.
-   [ ] Add search across title, description, and area.
-   [ ] Add category and mode filters.
-   [ ] Add useful empty states and a clear-filters action.
-   [ ] Add a List/Map segmented control.
-   [ ] Add basic accessibility labels and Dynamic Type support.

**Acceptance:** search and filters produce the expected results on
sample data.

## Phase 3 --- Map and location fallback

-   [ ] Build MapKit map annotations/markers for listings with
    coordinates.
-   [ ] Tapping a marker selects a listing and presents a
    preview/detail.
-   [ ] Add an optional "Use my location" action and request When-In-Use
    permission only on tap.
-   [ ] Keep the list usable if permission is denied or location is
    unavailable.
-   [ ] Show a map empty state if no listings have coordinates.
-   [ ] Use demo coordinates/locality labels; do not put private
    addresses in sample data.
-   [ ] Test with location permission denied and with network/map tiles
    unavailable.

**Acceptance:** map mode works for seeded listings and never blocks list
browsing.

## Phase 4 --- Create listing

-   [ ] Build a form for title, description, category, listing mode,
    condition, price, area, and optional seller contact.
-   [ ] Add `PhotosPicker` for selecting one or more images.
-   [ ] Show selected image previews and allow removal.
-   [ ] Copy selected images into `PhotoStore` on save.
-   [ ] Validate form inline (including price only for sell mode).
-   [ ] Save through `ListingRepository` and return to Browse/My
    Listings.
-   [ ] Add cancel confirmation if the form contains unsaved changes.
-   [ ] Add tests for required title and sell/exchange/donate
    validation.

**Acceptance:** a user can create a listing, see it in Browse, and find
it after relaunch.

## Phase 5 --- On-device Vision assist

-   [ ] Add `VisionAssistService` with a classification method using
    `VNClassifyImageRequest`.
-   [ ] Map a small curated set of labels to listing categories; default
    unknown labels to "Other".
-   [ ] Add OCR using `VNRecognizeTextRequest`.
-   [ ] Add "Suggest details" action to Create Listing.
-   [ ] Show a loading/progress state and graceful no-result/error
    states.
-   [ ] Present detected labels/text as suggestions, not final data;
    user must confirm/edit.
-   [ ] Ensure Vision requests do not block the main UI.
-   [ ] Add tests for category mapping and manual checks with a book,
    appliance, and item with printed text.
-   [ ] Add a short UI disclosure: image analysis runs on device;
    results can be wrong.

**Acceptance:** no API key or upload is used; suggestions can be
dismissed or edited.

## Phase 6 --- Details, contact, and My Listings

-   [ ] Build Listing Detail with image gallery, details, area, mode,
    and price.
-   [ ] Add Contact Seller action using `ShareLink`/system share sheet
    or a clearly labeled local demo contact flow.
-   [ ] Never show seeded fictional seller contact as a real person.
-   [ ] Build My Listings for items created on this device.
-   [ ] Add edit and delete actions; confirm before delete.
-   [ ] Handle deleted/missing photo files.

**Acceptance:** user can inspect an item and trigger the demo contact
action; own listings can be managed.

## Phase 7 --- Polish and final verification

-   [ ] Add app icon/title and consistent navigation.
-   [ ] Check loading, empty, error, and permission-denied states.
-   [ ] Test Dark Mode, Dynamic Type, and VoiceOver labels on core
    controls.
-   [ ] Test fresh install, populated install, relaunch, and reset
    sample data.
-   [ ] Remove unused packages and API keys (there should be none).
-   [ ] Record a demo flow: Browse → search/filter → map → detail →
    create listing → Vision suggestion → save → My Listings.
-   [ ] Add screenshots and architecture notes to the submission/report.
-   [ ] Confirm the app can be demonstrated with ₹0 spent.

## Suggested build order for a tight deadline

1.  Domain + JSON persistence + sample data.
2.  Browse cards, search, and filters.
3.  Create listing and photo persistence.
4.  Listing detail + My Listings.
5.  Map with seeded coordinates.
6.  Vision classification/OCR.
7.  UI polish and tests.

Do not begin with authentication, cloud sync, real chat, payments, or a
custom ML model; they are not required for the zero-cost local mini
project.
