# Neighbourly

A SwiftUI local-community marketplace mini project: sell, exchange, or
donate everyday items to people nearby.

> **Project note**
> - **Accounts and chat use Firebase's free Spark plan** (Authentication
>   and Cloud Firestore): email/password sign-up, shared listings, and
>   real-time text chat between buyer and seller. No credit card or
>   billing plan is needed. Photos are stored as small compressed
>   documents because Cloud Storage requires billing.
> - **No paid APIs.** Apple frameworks (SwiftUI, MapKit, Core Location,
>   Vision, Core ML) plus the free Firebase tier. Image suggestions use a
>   bundled pretrained Core ML model and run on device.
> - **Simulator demo.** Built and demonstrated in the Xcode iOS
>   Simulator; the chat demo uses two Simulators. Total cost: ₹0.
> - **Privacy.** The app stores an email address, a display name,
>   listings, photos, and chat messages in Firebase. Emails are never
>   shown to other users.
> - **Limitations.** No push notifications, moderation, blocking, or
>   payments; free-tier quotas apply.

> **Status:** Phases 0--6 (local app) are built and tested. The code for
> Phases 7--10 (Core ML classifier, accounts, shared listings, chat) is
> written; the Firebase-backed parts are compile-guarded until the
> Firebase package is added on the Mac, and the app runs in an in-memory
> demo mode until then. Phase 11 (polish) is next. See
> [`docs/tasks.md`](docs/tasks.md).

## Requirements

- macOS with Xcode (project created with Xcode 27)
- iOS 17.0+ deployment target; any recent iPhone Simulator

## Run

1. Open `neighbourly.xcodeproj` in Xcode.
2. Select the `neighbourly` scheme and an iPhone Simulator.
3. Press **⌘R** to run, **⌘U** to run the unit tests (`neighbourlyTests`).

The project uses Xcode file-system synchronized groups: any file added
under `neighbourly/` is picked up automatically, so files created on
another machine (e.g. Windows) don't need to be added to the project.

## Structure

```text
neighbourly/
  App/          App entry point and composition root
  Domain/       Listing model, enums, validation, repository protocol
  Data/         Local JSON repository, photo store, sample data
  Services/     Location, Vision/Core ML assist, contact helpers
  Features/     Screens (Browse, ListingDetail, CreateListing, MyListings)
  Components/   Theme and reusable views (cards, chips, empty states)
  Resources/    Asset catalog
```

## Firebase setup (Phase 8 onward)

Steps for the Firebase project, `GoogleService-Info.plist` (git-ignored),
the Swift package, and the Firestore rules are in
[`firebase/README.md`](firebase/README.md).

## Third-party assets

To be filled in as each is added:

| Asset | Source | Version | License | Size |
| ----- | ------ | ------- | ------- | ---- |
| Firebase iOS SDK (Auth, Firestore) | github.com/firebase/firebase-ios-sdk | _tbd_ | _tbd_ | n/a |
| MobileNetV2 Core ML model (`neighbourly/Resources/MobileNetV2.mlmodel`) | Apple Core ML model gallery, `MobileNetV2FP16.mlmodel` (original model: Sandler et al., TensorFlow `models/research/slim`) | 2019 release, 1,001 ImageNet categories | Per the model's metadata, see the TensorFlow repository's license (Apache 2.0); confirm on Apple's model page before submission | 12.4 MB (SHA-256 `c76832208ff4c936365f0f2609f7b77f7f1a6caf62b0b429056d5ad7e48635ad`) |

See [`docs/`](docs/) for the project overview, architecture, and task plan.
