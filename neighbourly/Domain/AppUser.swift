//
//  AppUser.swift
//  neighbourly
//

import Foundation

/// The signed-in person. The email lives in the auth provider only: it is shown to
/// its owner on the Account screen and is never written to the shared database.
nonisolated struct AppUser: Equatable, Identifiable, Sendable {
    let uid: String
    var displayName: String
    var email: String?

    var id: String { uid }
}
