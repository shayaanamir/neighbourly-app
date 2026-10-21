# Neighbourly --- Project Overview

## 1. Project summary

**Neighbourly** is a SwiftUI community marketplace mini project for
finding a second life for everyday items within a local area. A user can
create a listing to sell, exchange, or donate an item, browse nearby
listings, view them on a map, and contact a seller. On-device image
classification and text recognition help the user prepare a listing
faster.

The mini project focuses on a polished iOS experience and a demonstrable
end-to-end flow rather than a production-scale marketplace backend.

## 2. Problem statement

People often have useful items they no longer need, while others nearby
may be looking for those same items. General marketplaces can feel broad
or cluttered, and creating a listing takes effort. Neighbourly aims to
make local reuse approachable by combining simple listing creation,
location-aware discovery, and optional AI assistance.

## 3. Objectives

-   Create a native iOS interface using SwiftUI.
-   Support Sell, Exchange, and Donate listing types.
-   Allow users to add item photos, descriptions, condition, and
    locality.
-   Browse listings with search and filters.
-   Display geolocated demo/listing items on an interactive MapKit map.
-   Use Apple Vision on-device classification and OCR to suggest listing
    details.
-   Persist data locally so the app works without a server.
-   Keep the required build and demo budget at **₹0**.

## 4. Core user journeys

### Browse nearby items

1.  Open Browse and see sample/local listings.
2.  Search by item or locality and filter by category or mode.
3.  Switch to Map to see listings with coordinates.
4.  Select a marker and open the listing details.

### Create a listing

1.  Tap Add Listing.
2.  Select photos from the photo library.
3.  Optionally tap Suggest Details for on-device classification/OCR.
4.  Review and edit title, description, category, mode, condition,
    price, and area.
5.  Save; the listing appears in Browse and My Listings.

### Contact a seller

1.  Open a listing.
2.  Tap Contact Seller.
3.  Use the iOS share sheet or a demo contact flow. The prototype does
    not provide server-backed chat.

## 5. Feature scope

### Included in MVP

-   SwiftUI navigation and reusable components.
-   Local listing model and JSON/file persistence.
-   Sample data for a reliable demo.
-   Listing create, browse, detail, edit/delete (at minimum create,
    browse, detail, delete).
-   Photo selection and local photo storage.
-   Search and category/mode filters.
-   MapKit map with sample coordinates and permission fallback.
-   Vision classification and OCR suggestions, reviewed by the user.
-   System share/contact action.
-   Empty, error, and permission-denied states.

### Explicitly out of scope

-   User accounts, authentication, and cross-device sync.
-   Hosted database or cloud storage.
-   Payments, delivery tracking, and escrow.
-   Real-time in-app messaging.
-   Production moderation, reporting, and trust/reputation systems.
-   Custom model training or paid AI API.
-   Production geocoding or server-side recommendation engine.

## 6. Technology stack

  --------------------------------------------------------------------------
  Layer                   Technology                 Why
  ----------------------- -------------------------- -----------------------
  UI                      SwiftUI                    Native declarative iOS
                                                     interface

  App state               SwiftUI state /            Lightweight state
                          Observation                management

  Persistence             Codable JSON + Application Local, no server bill
                          Support (or SwiftData)     

  Photos                  PhotosPicker + local file  System photo picker and
                          storage                    app-owned copies

  Map                     MapKit                     Native map and
                                                     annotations

  Location                Core Location              Optional
                                                     current-location access

  Image labels            Vision                     On-device image
                          `VNClassifyImageRequest`   classification

  OCR                     Vision                     On-device text
                          `VNRecognizeTextRequest`   recognition

  Seller contact          ShareLink / system share   No messaging backend
                          sheet                      
  --------------------------------------------------------------------------

## 7. ₹0 budget plan

The required version has no paid dependencies: - **Development:** Xcode
and SwiftUI are free; use the iOS Simulator for the presentation. -
**Map:** MapKit, with network access for map tiles; no paid map API key
is needed for this prototype. - **AI:** Apple Vision runs locally on
supported devices/simulator; no AI API subscription. - **Storage:**
listing JSON and photos remain in the app sandbox; no cloud bill. -
**Distribution:** demonstrate in Simulator or submit source/project
files. A paid Apple Developer Program membership is not required to
build and run in Simulator. Device distribution and App Store
publication have separate signing/account constraints and are not part
of the ₹0 requirement.

Important: native iOS development requires access to a Mac capable of
running Xcode. If no Mac is available, the project cannot be built
natively with Xcode on a Windows-only setup; arrange access to a college
Mac/lab or use a Mac you already have. Do not pay for a cloud Mac just
for this mini project.

## 8. Demo plan (3--5 minutes)

1.  Show Browse with sample listings and explain Sell/Exchange/Donate.
2.  Search for an item and apply a category/mode filter.
3.  Switch to Map and select a marker.
4.  Open details and show the contact/share action.
5.  Create a listing, choose a photo, run Vision suggestions,
    review/edit, and save.
6.  Show the saved item in My Listings and relaunch persistence.
7.  State the prototype's limitations: local-only data, no real
    chat/accounts/payments, and user-reviewed AI suggestions.

## 9. Success criteria

-   The app builds and launches in iOS Simulator.
-   A listing can be created, saved, and displayed after relaunch.
-   Sell, Exchange, and Donate are represented correctly.
-   Search/filter and map browsing work.
-   Vision assistance returns suggestions when available and degrades
    gracefully.
-   The project does not require a paid API, service, subscription, or
    cloud account.
-   The project clearly distinguishes a local demo from a real
    multi-user marketplace.

## 10. Future enhancements (only if time/budget permits)

-   Backend sync using a free tier, after verifying current limits and
    privacy requirements.
-   User accounts and seller profiles.
-   Moderation/reporting and abuse prevention.
-   Real chat or structured contact requests.
-   Better location selection and distance sorting.
-   More robust item taxonomy and multilingual OCR.
-   Accessibility and localization improvements.

These are future work, not prerequisites for the mini project.
