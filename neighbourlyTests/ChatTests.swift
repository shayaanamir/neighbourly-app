//
//  ChatTests.swift
//  neighbourlyTests
//
//  Phase 10: conversations, messages, the in-memory chat service, and the view models.
//  None of these touch the network.
//

import Foundation
import Testing
@testable import neighbourly

// MARK: - Shared helpers

private let seller = AppUser(uid: "seller-1", displayName: "Asha", email: "asha@example.com")
private let buyer = AppUser(uid: "buyer-1", displayName: "Bob", email: "bob@example.com")
private let stranger = AppUser(uid: "stranger-1", displayName: "Eve", email: nil)

private func sellerListing(title: String = "Study table") -> Listing {
    Listing(
        title: title, category: .furniture, mode: .donate, condition: .good,
        sellerID: seller.uid, sellerName: seller.displayName
    )
}

private func sampleConversation(listingID: UUID = UUID()) -> Conversation {
    Conversation(
        id: Conversation.makeID(listingID: listingID, buyerID: buyer.uid),
        listingID: listingID, listingTitle: "Study table",
        sellerID: seller.uid, buyerID: buyer.uid,
        sellerName: seller.displayName, buyerName: buyer.displayName
    )
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

/// A clock that moves forward one second each time it is read.
@MainActor
private func tickingClock(from start: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> () -> Date {
    var current = start
    return {
        current.addTimeInterval(1)
        return current
    }
}

// MARK: - Models

struct ConversationModelTests {
    @Test func idIsTheListingAndTheBuyer() {
        let listingID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        #expect(Conversation.makeID(listingID: listingID, buyerID: "b1") == "11111111-1111-1111-1111-111111111111_b1")
    }

    @Test func otherParticipantIsTheOtherSide() {
        let conversation = sampleConversation()
        #expect(conversation.otherParticipantID(for: seller.uid) == buyer.uid)
        #expect(conversation.otherParticipantID(for: buyer.uid) == seller.uid)
        #expect(conversation.otherParticipantName(for: seller.uid) == "Bob")
        #expect(conversation.otherParticipantName(for: buyer.uid) == "Asha")
    }

    @Test func onlyTheTwoPeopleAreParticipants() {
        let conversation = sampleConversation()
        #expect(conversation.isParticipant(seller.uid))
        #expect(conversation.isParticipant(buyer.uid))
        #expect(!conversation.isParticipant(stranger.uid))
        #expect(Set(conversation.participantIDs) == [seller.uid, buyer.uid])
    }

    @Test func unreadMeansTheOtherPersonWroteLastAndYouHaventOpenedItSince() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var conversation = sampleConversation()

        #expect(!conversation.isUnread(for: seller.uid), "no messages yet")

        conversation.lastMessageAt = t0
        conversation.lastMessageSenderID = buyer.uid
        #expect(conversation.isUnread(for: seller.uid), "the buyer wrote, the seller hasn't read")
        #expect(!conversation.isUnread(for: buyer.uid), "your own message is never unread")

        conversation.readAt[seller.uid] = t0.addingTimeInterval(-5)
        #expect(conversation.isUnread(for: seller.uid), "read before the message arrived")

        conversation.readAt[seller.uid] = t0.addingTimeInterval(5)
        #expect(!conversation.isUnread(for: seller.uid), "read after it arrived")
    }

    @Test func conversationsWithoutMessagesSortLast() {
        var active = sampleConversation()
        active.lastMessageAt = Date()
        let empty = sampleConversation()
        #expect(active.sortDate > empty.sortDate)
    }
}

struct ChatMessageValidationTests {
    @Test func textIsTrimmed() throws {
        #expect(try ChatMessage.validated("  hello \n") == "hello")
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func blankMessagesAreRejected(text: String) {
        #expect(throws: ChatError.emptyMessage) { try ChatMessage.validated(text) }
    }

    @Test func lengthLimitIsInclusive() throws {
        let atLimit = String(repeating: "a", count: ChatMessage.maxLength)
        #expect(try ChatMessage.validated(atLimit) == atLimit)
        #expect(throws: ChatError.messageTooLong) {
            try ChatMessage.validated(atLimit + "a")
        }
    }

    @Test func everyErrorHasAMessage() {
        let errors: [ChatError] = [
            .emptyMessage, .messageTooLong, .cannotMessageYourself, .listingNotMessageable,
            .notSignedIn, .permissionDenied, .network, .quotaExceeded, .unknown,
        ]
        let messages = errors.map { $0.errorDescription ?? "" }
        let allNonEmpty = messages.allSatisfy { !$0.isEmpty }
        #expect(allNonEmpty)
        #expect(Set(messages).count == errors.count)
    }
}

struct ChatEligibilityTests {
    @Test func signedInBuyerCanMessageARealListing() {
        #expect(ChatEligibility.check(listing: sellerListing(), user: buyer) == .canMessage)
    }

    @Test func guestsAreAskedToSignIn() {
        #expect(ChatEligibility.check(listing: sellerListing(), user: nil) == .signInRequired)
    }

    @Test func sellersCantMessageThemselves() {
        #expect(ChatEligibility.check(listing: sellerListing(), user: seller) == .ownListing)
    }

    @Test func sampleAndOwnerlessListingsCantBeMessaged() {
        let sample = SampleListings.make()[0]
        #expect(ChatEligibility.check(listing: sample, user: buyer) == .sampleListing)
        #expect(ChatEligibility.check(listing: sample, user: nil) == .sampleListing)

        var legacy = sellerListing()
        legacy.sellerID = nil
        #expect(ChatEligibility.check(listing: legacy, user: buyer) == .sampleListing)
    }
}

// MARK: - Timeline

struct ChatTimelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func item(_ id: String, _ when: Date, sender: String = "a") -> ChatItem {
        ChatItem(id: id, senderID: sender, text: id, createdAt: when)
    }

    @Test func itemsAreGroupedByDayInOrder() {
        let items = [item("c", date(21, 9)), item("a", date(20, 8)), item("b", date(20, 23))]
        let days = ChatTimeline.days(from: items, calendar: calendar)

        #expect(days.count == 2)
        #expect(days[0].items.map { $0.id } == ["a", "b"])
        #expect(days[1].items.map { $0.id } == ["c"])
        #expect(days[0].id == calendar.startOfDay(for: date(20, 12)))
    }

    @Test func messagesAtTheSameInstantKeepAStableOrder() {
        let when = date(20, 8)
        let days = ChatTimeline.days(from: [item("b", when), item("a", when)], calendar: calendar)
        #expect(days[0].items.map { $0.id } == ["a", "b"])
    }

    @Test func noMessagesMeansNoDays() {
        #expect(ChatTimeline.days(from: [], calendar: calendar).isEmpty)
    }

    @Test func dayTitlesAreFriendly() {
        let now = date(21, 15)
        #expect(ChatTimeline.dayTitle(for: calendar.startOfDay(for: date(21, 1)), now: now, calendar: calendar) == "Today")
        #expect(ChatTimeline.dayTitle(for: calendar.startOfDay(for: date(20, 1)), now: now, calendar: calendar) == "Yesterday")
        let older = ChatTimeline.dayTitle(for: calendar.startOfDay(for: date(1, 1)), now: now, calendar: calendar)
        #expect(older != "Today" && older != "Yesterday")
    }

    @Test func confirmedMessagesReplaceTheirLocalCopies() {
        let when = date(20, 8)
        let server = [ChatMessage(id: "m1", senderID: "a", text: "hi", createdAt: when)]
        let outbox = [
            ChatItem(id: "m1", senderID: "a", text: "hi", createdAt: when, delivery: .sent),
            ChatItem(id: "m2", senderID: "a", text: "still sending", createdAt: when.addingTimeInterval(1), delivery: .sending),
        ]
        let merged = ChatTimeline.merge(server: server, outbox: outbox)
        #expect(merged.map { $0.id } == ["m1", "m2"])
        #expect(merged[0].delivery == .sent)
        #expect(merged[1].delivery == .sending)
    }
}

// MARK: - Field mapping

struct ChatMappingTests {
    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func newConversationRoundTrips() throws {
        let conversation = sampleConversation()
        let data = ChatMapping.newConversationData(for: conversation)
        let restored = try #require(ChatMapping.conversation(from: data, id: conversation.id))
        #expect(restored == conversation)
    }

    @Test func lastMessageAndReadMarkersAreRead() throws {
        let conversation = sampleConversation()
        var data = ChatMapping.newConversationData(for: conversation)
        data[ChatMapping.ConversationField.lastMessageText] = "See you Saturday"
        data[ChatMapping.ConversationField.lastMessageAt] = when
        data[ChatMapping.ConversationField.lastMessageSenderID] = buyer.uid
        data[ChatMapping.ConversationField.readAt] = [buyer.uid: when, seller.uid: when.addingTimeInterval(-60)] as [String: Any]

        let restored = try #require(ChatMapping.conversation(from: data, id: conversation.id))
        #expect(restored.lastMessageText == "See you Saturday")
        #expect(restored.lastMessageAt == when)
        #expect(restored.lastMessageSenderID == buyer.uid)
        #expect(restored.readAt[buyer.uid] == when)
        #expect(restored.isUnread(for: seller.uid))
    }

    @Test(arguments: [
        ChatMapping.ConversationField.listingID, ChatMapping.ConversationField.listingTitle,
        ChatMapping.ConversationField.sellerID, ChatMapping.ConversationField.buyerID,
    ])
    func conversationsMissingARequiredFieldAreSkipped(field: String) {
        var data = ChatMapping.newConversationData(for: sampleConversation())
        data[field] = nil
        #expect(ChatMapping.conversation(from: data, id: "x") == nil)
    }

    @Test func messagesMapAndRejectIncompleteDocuments() throws {
        let data: [String: Any] = [
            ChatMapping.MessageField.senderID: buyer.uid,
            ChatMapping.MessageField.text: "Hello",
            ChatMapping.MessageField.createdAt: when,
        ]
        let message = try #require(ChatMapping.message(from: data, id: "m1"))
        #expect(message == ChatMessage(id: "m1", senderID: buyer.uid, text: "Hello", createdAt: when))

        for missing in [ChatMapping.MessageField.senderID, ChatMapping.MessageField.text, ChatMapping.MessageField.createdAt] {
            var broken = data
            broken[missing] = nil
            #expect(ChatMapping.message(from: broken, id: "m1") == nil)
        }
    }

    @Test func newConversationFieldsStayWithinWhatTheSecurityRulesAllow() {
        // Keep in sync with the conversations create rule in firebase/firestore.rules.
        let allowed: Set<String> = [
            "listingID", "listingTitle", "sellerID", "buyerID", "sellerName", "buyerName",
            "participantIDs", "readAt",
        ]
        let keys = Set(ChatMapping.newConversationData(for: sampleConversation()).keys)
        #expect(keys.isSubset(of: allowed))
        #expect(Set(["listingID", "listingTitle", "sellerID", "buyerID", "sellerName", "buyerName", "participantIDs"]).isSubset(of: keys))
    }
}

// MARK: - In-memory chat service

@MainActor
struct InMemoryChatRepositoryTests {
    @Test func buyerCanStartAConversation() async throws {
        let chat = InMemoryChatRepository()
        let listing = sellerListing()
        let conversation = try await chat.startConversation(listing: listing, buyer: buyer)

        #expect(conversation.id == Conversation.makeID(listingID: listing.id, buyerID: buyer.uid))
        #expect(conversation.sellerID == seller.uid)
        #expect(conversation.buyerID == buyer.uid)
        #expect(conversation.listingTitle == "Study table")
        #expect(conversation.otherParticipantName(for: buyer.uid) == "Asha")
    }

    @Test func startingTwiceReopensTheSameConversation() async throws {
        let chat = InMemoryChatRepository()
        let listing = sellerListing()
        let first = try await chat.startConversation(listing: listing, buyer: buyer)
        try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "Hi", createdAt: .now), in: first)

        let second = try await chat.startConversation(listing: listing, buyer: buyer)
        #expect(second.id == first.id)
        #expect(second.lastMessageText == "Hi", "the existing history is kept")
    }

    @Test func differentBuyersGetSeparateConversations() async throws {
        let chat = InMemoryChatRepository()
        let listing = sellerListing()
        let one = try await chat.startConversation(listing: listing, buyer: buyer)
        let two = try await chat.startConversation(listing: listing, buyer: stranger)
        #expect(one.id != two.id)
    }

    @Test func sellersCannotMessageThemselves() async {
        let chat = InMemoryChatRepository()
        await #expect(throws: ChatError.cannotMessageYourself) {
            try await chat.startConversation(listing: sellerListing(), buyer: seller)
        }
    }

    @Test func sampleListingsCannotBeMessaged() async {
        let chat = InMemoryChatRepository()
        await #expect(throws: ChatError.listingNotMessageable) {
            try await chat.startConversation(listing: SampleListings.make()[0], buyer: buyer)
        }
    }

    @Test func sendingStoresTheMessageAndUpdatesTheSummary() async throws {
        let chat = InMemoryChatRepository()
        chat.now = tickingClock()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)

        try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "  Is it free?  ", createdAt: .now), in: conversation)

        var iterator = chat.messages(in: conversation.id).makeAsyncIterator()
        let messages = await iterator.next() ?? []
        #expect(messages.map { $0.text } == ["Is it free?"])

        let stored = try #require(chat.conversation(withID: conversation.id))
        #expect(stored.lastMessageText == "Is it free?")
        #expect(stored.lastMessageSenderID == buyer.uid)
        #expect(!stored.isUnread(for: buyer.uid))
        #expect(stored.isUnread(for: seller.uid))
    }

    @Test func invalidTextIsRejected() async throws {
        let chat = InMemoryChatRepository()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)

        await #expect(throws: ChatError.emptyMessage) {
            try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "   ", createdAt: .now), in: conversation)
        }
        await #expect(throws: ChatError.messageTooLong) {
            let long = String(repeating: "a", count: ChatMessage.maxLength + 1)
            try await chat.send(ChatMessage(id: "m2", senderID: buyer.uid, text: long, createdAt: .now), in: conversation)
        }
    }

    @Test func outsidersCannotSend() async throws {
        let chat = InMemoryChatRepository()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)

        await #expect(throws: ChatError.permissionDenied) {
            try await chat.send(ChatMessage(id: "m1", senderID: stranger.uid, text: "Hi", createdAt: .now), in: conversation)
        }
    }

    @Test func resendingTheSameMessageDoesNotDuplicateIt() async throws {
        let chat = InMemoryChatRepository()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)
        let message = ChatMessage(id: "m1", senderID: buyer.uid, text: "Hi", createdAt: .now)

        try await chat.send(message, in: conversation)
        try await chat.send(message, in: conversation)

        var iterator = chat.messages(in: conversation.id).makeAsyncIterator()
        let messages = await iterator.next() ?? []
        #expect(messages.count == 1)
    }

    @Test func onlyParticipantsSeeAConversation() async throws {
        let chat = InMemoryChatRepository()
        _ = try await chat.startConversation(listing: sellerListing(), buyer: buyer)

        var sellerView = chat.conversations(for: seller.uid).makeAsyncIterator()
        var buyerView = chat.conversations(for: buyer.uid).makeAsyncIterator()
        var strangerView = chat.conversations(for: stranger.uid).makeAsyncIterator()

        let sellerList = await sellerView.next() ?? []
        let buyerList = await buyerView.next() ?? []
        let strangerList = await strangerView.next() ?? []
        #expect(sellerList.count == 1)
        #expect(buyerList.count == 1)
        #expect(strangerList.isEmpty, "a third account must not see the chat")
    }

    @Test func listenersHearAboutNewMessagesLive() async throws {
        let chat = InMemoryChatRepository()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)

        var stream = chat.messages(in: conversation.id).makeAsyncIterator()
        let initial = await stream.next() ?? []
        #expect(initial.isEmpty)

        try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "Hi", createdAt: .now), in: conversation)
        let afterSend = await stream.next() ?? []
        #expect(afterSend.map { $0.text } == ["Hi"])
    }

    @Test func markReadClearsTheUnreadMarker() async throws {
        let chat = InMemoryChatRepository()
        chat.now = tickingClock()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)
        try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "Hi", createdAt: .now), in: conversation)
        let before = try #require(chat.conversation(withID: conversation.id))
        #expect(before.isUnread(for: seller.uid))

        try await chat.markRead(conversation, by: seller.uid)
        let after = try #require(chat.conversation(withID: conversation.id))
        #expect(!after.isUnread(for: seller.uid))
    }

    @Test func outsidersCannotMarkRead() async throws {
        let chat = InMemoryChatRepository()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)
        await #expect(throws: ChatError.permissionDenied) {
            try await chat.markRead(conversation, by: stranger.uid)
        }
    }
}

// MARK: - Conversation view model

@MainActor
struct ConversationViewModelTests {
    private func makeViewModel(
        as user: AppUser,
        chat: InMemoryChatRepository,
        conversation: Conversation
    ) -> ConversationViewModel {
        ConversationViewModel(conversation: conversation, currentUser: user, chat: chat)
    }

    private func makeChat() async throws -> (InMemoryChatRepository, Conversation) {
        let chat = InMemoryChatRepository()
        chat.now = tickingClock()
        let conversation = try await chat.startConversation(listing: sellerListing(), buyer: buyer)
        return (chat, conversation)
    }

    @Test func draftValidation() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)

        #expect(!viewModel.canSend)
        viewModel.draft = "   "
        #expect(!viewModel.canSend)
        viewModel.draft = " Hello "
        #expect(viewModel.canSend)
        #expect(viewModel.remainingCharacters == ChatMessage.maxLength - 5)

        viewModel.draft = String(repeating: "a", count: ChatMessage.maxLength + 1)
        #expect(!viewModel.canSend)
        #expect(viewModel.isOverLimit)
        #expect(viewModel.remainingCharacters == -1)
    }

    @Test func sendingClearsTheDraftAndDeliversTrimmedText() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        let listener = Task { await viewModel.start() }
        defer { listener.cancel() }

        viewModel.draft = "  Hello there  "
        await viewModel.send()
        #expect(viewModel.draft.isEmpty)

        let arrived = await waitUntil { viewModel.serverMessages.count == 1 && viewModel.outbox.isEmpty }
        #expect(arrived)
        #expect(viewModel.items.map { $0.text } == ["Hello there"])
        #expect(viewModel.items.first?.delivery == .sent)
    }

    @Test func aMessageNeverAppearsTwice() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        let listener = Task { await viewModel.start() }
        defer { listener.cancel() }

        for text in ["one", "two", "three"] {
            viewModel.draft = text
            await viewModel.send()
        }
        let arrived = await waitUntil { viewModel.serverMessages.count == 3 && viewModel.outbox.isEmpty }
        #expect(arrived)
        #expect(viewModel.items.map { $0.text } == ["one", "two", "three"])
    }

    @Test func emptyDraftsSendNothing() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        viewModel.draft = "   "
        await viewModel.send()
        #expect(viewModel.outbox.isEmpty)
    }

    @Test func failedSendsShowAReasonAndCanBeRetried() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        let listener = Task { await viewModel.start() }
        defer { listener.cancel() }

        chat.failNextSend = .network
        viewModel.draft = "Hello"
        await viewModel.send()

        let failed = try #require(viewModel.items.first)
        #expect(failed.delivery == .failed(ChatError.network.errorDescription ?? ""))
        #expect(viewModel.draft.isEmpty, "the text isn't lost: it stays in the list")

        await viewModel.retry(failed.id)
        let arrived = await waitUntil { viewModel.serverMessages.count == 1 && viewModel.outbox.isEmpty }
        #expect(arrived)
        #expect(viewModel.items.map { $0.text } == ["Hello"], "retrying sends it once")
    }

    @Test func failedMessagesCanBeDiscarded() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)

        chat.failNextSend = .network
        viewModel.draft = "Hello"
        await viewModel.send()
        let id = try #require(viewModel.items.first?.id)

        viewModel.discard(id)
        #expect(viewModel.items.isEmpty)
    }

    @Test func retryOnlyAppliesToFailedMessages() async throws {
        let (chat, conversation) = try await makeChat()
        let viewModel = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        viewModel.draft = "Hello"
        await viewModel.send() // delivered, so not failed

        let id = try #require(viewModel.outbox.first?.id)
        await viewModel.retry(id)
        #expect(viewModel.outbox.first?.delivery == .sent)
    }

    @Test func messagesFromTheOtherPersonAppearLive() async throws {
        let (chat, conversation) = try await makeChat()
        let sellerScreen = makeViewModel(as: seller, chat: chat, conversation: conversation)
        let buyerScreen = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        let sellerListener = Task { await sellerScreen.start() }
        let buyerListener = Task { await buyerScreen.start() }
        defer { sellerListener.cancel(); buyerListener.cancel() }

        buyerScreen.draft = "Is it still available?"
        await buyerScreen.send()
        let sellerSees = await waitUntil { sellerScreen.items.count == 1 }
        #expect(sellerSees)
        let received = try #require(sellerScreen.items.first)
        #expect(!sellerScreen.isFromCurrentUser(received))

        sellerScreen.draft = "Yes! Come by Saturday."
        await sellerScreen.send()
        let buyerSees = await waitUntil { buyerScreen.items.count == 2 }
        #expect(buyerSees)
        #expect(buyerScreen.items.map { $0.text } == ["Is it still available?", "Yes! Come by Saturday."])
    }

    @Test func messagesOnlyCountAsReadWhileTheScreenIsShowing() async throws {
        let (chat, conversation) = try await makeChat()
        try await chat.send(ChatMessage(id: "m1", senderID: buyer.uid, text: "Hi", createdAt: .now), in: conversation)

        let screen = makeViewModel(as: seller, chat: chat, conversation: conversation)
        let listener = Task { await screen.start() }
        defer { listener.cancel() }

        let loaded = await waitUntil { screen.hasLoaded }
        #expect(loaded)
        let hidden = try #require(chat.conversation(withID: conversation.id))
        #expect(hidden.isUnread(for: seller.uid), "not marked read while the screen isn't visible")

        screen.isActive = true
        await screen.markReadIfNeeded()
        let visible = try #require(chat.conversation(withID: conversation.id))
        #expect(!visible.isUnread(for: seller.uid))
    }

    @Test func yourOwnMessagesNeverTriggerAReadReceipt() async throws {
        let (chat, conversation) = try await makeChat()
        let screen = makeViewModel(as: buyer, chat: chat, conversation: conversation)
        screen.isActive = true
        let listener = Task { await screen.start() }
        defer { listener.cancel() }

        screen.draft = "Hi"
        await screen.send()
        let arrived = await waitUntil { screen.serverMessages.count == 1 }
        #expect(arrived)
        #expect(screen.otherName == "Asha")
    }
}

// MARK: - Inbox view model

@MainActor
struct InboxViewModelTests {
    private func makeChatWithTwoListings() async throws -> (InMemoryChatRepository, Conversation, Conversation) {
        let chat = InMemoryChatRepository()
        chat.now = tickingClock()
        let first = try await chat.startConversation(listing: sellerListing(title: "Table"), buyer: buyer)
        let second = try await chat.startConversation(listing: sellerListing(title: "Chair"), buyer: buyer)
        return (chat, first, second)
    }

    @Test func newestActivityComesFirst() async throws {
        let (chat, first, second) = try await makeChatWithTwoListings()
        try await chat.send(ChatMessage(id: "a", senderID: buyer.uid, text: "About the table", createdAt: .now), in: first)
        try await chat.send(ChatMessage(id: "b", senderID: buyer.uid, text: "About the chair", createdAt: .now), in: second)
        try await chat.send(ChatMessage(id: "c", senderID: buyer.uid, text: "Table again", createdAt: .now), in: first)

        let inbox = InboxViewModel(chat: chat)
        let task = Task { await inbox.run(userID: seller.uid) }
        defer { task.cancel() }

        let loaded = await waitUntil { inbox.hasLoaded && inbox.conversations.count == 2 }
        #expect(loaded)
        #expect(inbox.conversations.map { $0.listingTitle } == ["Table", "Chair"])
    }

    @Test func unreadCountsOnlyConversationsWaitingOnYou() async throws {
        let (chat, first, second) = try await makeChatWithTwoListings()
        try await chat.send(ChatMessage(id: "a", senderID: buyer.uid, text: "Hi", createdAt: .now), in: first)
        try await chat.send(ChatMessage(id: "b", senderID: seller.uid, text: "Hello", createdAt: .now), in: second)

        let sellerInbox = InboxViewModel(chat: chat)
        let sellerTask = Task { await sellerInbox.run(userID: seller.uid) }
        let buyerInbox = InboxViewModel(chat: chat)
        let buyerTask = Task { await buyerInbox.run(userID: buyer.uid) }
        defer { sellerTask.cancel(); buyerTask.cancel() }

        let loaded = await waitUntil { sellerInbox.conversations.count == 2 && buyerInbox.conversations.count == 2 }
        #expect(loaded)
        #expect(sellerInbox.unreadCount == 1, "the buyer's message in the table chat")
        #expect(buyerInbox.unreadCount == 1, "the seller's reply in the chair chat")

        // The inbox's own copies carry the latest messages (the originals here are stale).
        let tableChat = try #require(sellerInbox.conversations.first { $0.id == first.id })
        let chairChat = try #require(sellerInbox.conversations.first { $0.id == second.id })
        #expect(sellerInbox.isUnread(tableChat))
        #expect(!sellerInbox.isUnread(chairChat))
    }

    @Test func readingAConversationLowersTheCount() async throws {
        let (chat, first, _) = try await makeChatWithTwoListings()
        try await chat.send(ChatMessage(id: "a", senderID: buyer.uid, text: "Hi", createdAt: .now), in: first)

        let inbox = InboxViewModel(chat: chat)
        let task = Task { await inbox.run(userID: seller.uid) }
        defer { task.cancel() }
        let unread = await waitUntil { inbox.unreadCount == 1 }
        #expect(unread)

        try await chat.markRead(first, by: seller.uid)
        let cleared = await waitUntil { inbox.unreadCount == 0 }
        #expect(cleared)
    }

    @Test func signingOutEmptiesTheInbox() async throws {
        let (chat, first, _) = try await makeChatWithTwoListings()
        try await chat.send(ChatMessage(id: "a", senderID: buyer.uid, text: "Hi", createdAt: .now), in: first)

        let inbox = InboxViewModel(chat: chat)
        let task = Task { await inbox.run(userID: seller.uid) }
        let loaded = await waitUntil { inbox.conversations.count == 2 }
        #expect(loaded)

        task.cancel()
        await inbox.run(userID: nil) // what the root does when the account signs out
        #expect(inbox.conversations.isEmpty)
        #expect(inbox.unreadCount == 0)
        #expect(inbox.userID == nil)
    }

    @Test func switchingAccountsNeverShowsTheOldAccountsChats() async throws {
        let (chat, _, _) = try await makeChatWithTwoListings()

        let inbox = InboxViewModel(chat: chat)
        let sellerTask = Task { await inbox.run(userID: seller.uid) }
        let sellerLoaded = await waitUntil { inbox.conversations.count == 2 }
        #expect(sellerLoaded)
        sellerTask.cancel()

        let strangerTask = Task { await inbox.run(userID: stranger.uid) }
        defer { strangerTask.cancel() }
        let strangerLoaded = await waitUntil { inbox.hasLoaded && inbox.userID == stranger.uid }
        #expect(strangerLoaded)
        #expect(inbox.conversations.isEmpty)
    }
}
