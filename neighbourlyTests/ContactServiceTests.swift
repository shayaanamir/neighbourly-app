//
//  ContactServiceTests.swift
//  neighbourlyTests
//

import Foundation
import Testing
@testable import neighbourly

struct ContactServiceTests {
    private func listing(
        mode: ListingMode = .sell,
        contact: String? = nil,
        isDemo: Bool = false
    ) -> Listing {
        Listing(
            title: "Study table", category: .furniture, mode: mode,
            price: mode == .sell ? 1800 : nil, condition: .good,
            sellerName: "Asha", sellerContact: contact, isDemo: isDemo
        )
    }

    // MARK: - Message

    @Test func messageMentionsTheListing() {
        let message = ContactService.message(for: listing())
        #expect(message.contains("Study table"))
        #expect(message.contains("Neighbourly"))
    }

    @Test func messageReflectsMode() {
        #expect(ContactService.message(for: listing(mode: .donate)).contains("free"))
        #expect(ContactService.message(for: listing(mode: .exchange)).contains("exchange"))
    }

    @Test func subjectIncludesTitle() {
        #expect(ContactService.subject(for: listing()) == "Neighbourly: Study table")
    }

    // MARK: - Contact actions

    @Test func emailContactBecomesMailtoLink() throws {
        let action = try #require(ContactService.action(for: listing(contact: "seller@example.com")))
        #expect(action.title == "Email Seller")
        #expect(action.url.scheme == "mailto")
        #expect(action.url.absoluteString.hasPrefix("mailto:seller@example.com?"))
        #expect(action.url.absoluteString.contains("subject="))
    }

    @Test func phoneContactBecomesSMSLink() throws {
        let action = try #require(ContactService.action(for: listing(contact: "+91 98200-12345")))
        #expect(action.title == "Message Seller")
        #expect(action.url.absoluteString == "sms:+919820012345")
    }

    @Test(arguments: [nil, "", "   ", "call me maybe", "12", "not@valid"])
    func unusableContactGivesNoAction(contact: String?) {
        #expect(ContactService.action(for: listing(contact: contact)) == nil)
    }

    @Test func demoListingsNeverGetAContactAction() {
        let demo = listing(contact: "seller@example.com", isDemo: true)
        #expect(ContactService.action(for: demo) == nil)
    }

    // MARK: - Detection helpers

    @Test(arguments: ["a@b.co", "first.last@mail.example.org"])
    func validEmails(text: String) {
        #expect(ContactService.isEmail(text))
    }

    @Test(arguments: ["", "a@", "@b.co", "a@b", "a b@c.com", "a@@b.com", "a@b."])
    func invalidEmails(text: String) {
        #expect(!ContactService.isEmail(text))
    }

    @Test func phoneNumberNormalisation() {
        #expect(ContactService.phoneNumber("98200 12345") == "9820012345")
        #expect(ContactService.phoneNumber("(022) 2345-6789") == "02223456789")
        #expect(ContactService.phoneNumber("+1 415 555 0100") == "+14155550100")
        #expect(ContactService.phoneNumber("123") == nil)
        #expect(ContactService.phoneNumber("98200 abc") == nil)
    }
}
