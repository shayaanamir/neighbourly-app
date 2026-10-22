//
//  AuthServiceFactory.swift
//  neighbourly
//
//  Chooses the account backend at launch: Firebase when the SDK and config file
//  are present, otherwise the in-memory demo service. Always compiled, so the
//  project builds before Firebase has been set up.
//

import Foundation

enum AuthServiceFactory {
    @MainActor
    static func makeLive() -> (service: any AuthService, isCloudBacked: Bool) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
        if FirebaseBootstrap.configureIfPossible() {
            return (FirebaseAuthService(), true)
        }
        #endif
        return (MockAuthService(), false)
    }
}
