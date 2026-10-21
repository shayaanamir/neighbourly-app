//
//  SampleListings.swift
//  neighbourly
//
//  First-launch demo data. Sellers are fictional and marked "(demo)";
//  coordinates are approximate locality centres, never real addresses.
//

import Foundation

nonisolated enum SampleListings {
    static func make(now: Date = .now) -> [Listing] {
        func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        return [
            Listing(
                title: "Study table with drawer",
                description: "Solid wood table, fits a small room. Minor scratches on top.",
                category: .furniture, mode: .sell, price: 1800, condition: .good,
                latitude: 19.0790, longitude: 72.8970, areaName: "Vidyavihar",
                sellerName: "Asha (demo)", createdAt: hoursAgo(2), isDemo: true
            ),
            Listing(
                title: "Engineering Mathematics textbooks",
                description: "Set of 3 books for first and second year. Some pencil notes inside.",
                category: .books, mode: .donate, condition: .fair,
                latitude: 19.0860, longitude: 72.9080, areaName: "Ghatkopar East",
                sellerName: "Rohan (demo)", createdAt: hoursAgo(5), isDemo: true
            ),
            Listing(
                title: "Bluetooth speaker",
                description: "Works well, battery lasts about 6 hours. Charging cable included.",
                category: .electronics, mode: .sell, price: 950, condition: .likeNew,
                latitude: 19.1176, longitude: 72.9060, areaName: "Powai",
                sellerName: "Meera (demo)", createdAt: hoursAgo(9), isDemo: true
            ),
            Listing(
                title: "Cricket bat for a football",
                description: "Kashmir willow bat, looking to exchange for a size 5 football.",
                category: .sports, mode: .exchange, condition: .good,
                latitude: 19.0622, longitude: 72.9005, areaName: "Chembur",
                sellerName: "Kabir (demo)", createdAt: hoursAgo(20), isDemo: true
            ),
            Listing(
                title: "Pressure cooker, 3 litre",
                description: "Barely used, new gasket fitted.",
                category: .home, mode: .sell, price: 600, condition: .likeNew,
                latitude: 19.0726, longitude: 72.8790, areaName: "Kurla West",
                sellerName: "Fatima (demo)", createdAt: hoursAgo(30), isDemo: true
            ),
            Listing(
                title: "Winter jackets (kids, age 6–8)",
                description: "Two warm jackets, outgrown. Free to anyone who needs them.",
                category: .clothing, mode: .donate, condition: .good,
                latitude: 19.1100, longitude: 72.9280, areaName: "Vikhroli",
                sellerName: "Neha (demo)", createdAt: hoursAgo(48), isDemo: true
            ),
            Listing(
                title: "Board games bundle",
                description: "Ludo, snakes & ladders, and a chess set. Would swap for puzzles.",
                category: .toys, mode: .exchange, condition: .fair,
                latitude: 19.0400, longitude: 72.8620, areaName: "Sion",
                sellerName: "Arjun (demo)", createdAt: hoursAgo(72), isDemo: true
            ),
            Listing(
                title: "Desk lamp",
                description: "LED lamp with adjustable arm. No location shared for this one.",
                category: .other, mode: .sell, price: 300, condition: .good,
                areaName: "Location not shared",
                sellerName: "Sam (demo)", createdAt: hoursAgo(96), isDemo: true
            ),
        ]
    }
}
