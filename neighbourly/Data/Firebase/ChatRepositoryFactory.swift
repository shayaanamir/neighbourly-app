//
//  ChatRepositoryFactory.swift
//  neighbourly
//
//  Chooses where chat lives: Firestore when Firebase is set up, otherwise an
//  in-memory demo. Always compiled, so the project builds before Firebase exists.
//

import Foundation

enum ChatRepositoryFactory {
    @MainActor
    static func makeLive(isCloudBacked: Bool) -> any ChatRepository {
        #if canImport(FirebaseFirestore)
        if isCloudBacked { return FirestoreChatRepository() }
        #endif
        return InMemoryChatRepository()
    }
}
