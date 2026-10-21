# Neighbourly

A SwiftUI local-community marketplace mini project: sell, exchange, or
donate everyday items to people nearby.

> **Project note**
> - **Local-only prototype.** Listings and photos are stored on the device.
>   There is no server, account, sync, chat, or payment system.
> - **No paid APIs.** Only free Apple frameworks are used (SwiftUI, MapKit,
>   Core Location, Vision). No API keys, subscriptions, or cloud services.
> - **Simulator demo.** The app is built and demonstrated in the Xcode iOS
>   Simulator. Total cost: ₹0.

## Requirements

- macOS with Xcode (project created with Xcode 27)
- iOS 17.0+ deployment target; any recent iPhone Simulator

## Run

1. Open `neighbourly.xcodeproj` in Xcode.
2. Select the `neighbourly` scheme and an iPhone Simulator.
3. Press **⌘R**.

The project uses Xcode file-system synchronized groups: any file added
under `neighbourly/` is picked up automatically, so files created on
another machine (e.g. Windows) don't need to be added to the project.

## Structure

```text
neighbourly/
  App/          App entry point and composition root
  Domain/       Listing model, enums, validation, repository protocol
  Data/         Local JSON repository, photo store, sample data
  Services/     Location, Vision assist, share/contact helpers
  Features/     Screens (Browse, ListingDetail, CreateListing, MyListings)
  Components/   Theme and reusable views (cards, chips, empty states)
  Resources/    Asset catalog
```

See [`docs/`](docs/) for the project overview, architecture, and task plan.
