import XCTest
@testable import Groopay

final class UserDataExportTests: XCTestCase {
    private let groupID = Fixtures.uuid("11111111-1111-1111-1111-111111111111")
    private let userID = Fixtures.uuid("22222222-2222-2222-2222-222222222222")
    private let meID = Fixtures.uuid("33333333-3333-3333-3333-333333333301")
    private let exp1 = Fixtures.uuid("44444444-4444-4444-4444-444444444401")

    private func profile() -> Profile {
        Profile(
            id: userID,
            displayName: "Fatih",
            avatarColor: "#6366F1",
            locale: "tr",
            preferredCurrency: "TRY",
            expoPushToken: "ExponentPushToken[SECRET-DEVICE-TOKEN]",
            userPro: true,
            userProPurchasedAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_690_000_000)
        )
    }

    private func snapshot() -> GroupSnapshot {
        GroupSnapshot(
            group: Fixtures.group(id: groupID, name: "Hafta Sonu"),
            members: [Fixtures.member(id: meID, groupId: groupID, userId: userID, name: "Fatih")],
            expenses: [Fixtures.expense(id: exp1, groupId: groupID, amount: 12840, currency: "EUR", paidBy: meID)],
            splits: [Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 12840, currency: "EUR")],
            settlements: []
        )
    }

    func testEncodeRoundTrip() throws {
        let export = UserDataExport.make(
            snapshots: [snapshot()],
            profile: profile(),
            activities: [],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000) // tam saniye (iso8601 yuvarlama yok)
        )
        let data = try export.jsonData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserDataExport.self, from: data)
        XCTAssertEqual(decoded, export)
    }

    func testMinorUnitIntegerIsPreserved() throws {
        let export = UserDataExport.make(
            snapshots: [snapshot()],
            profile: profile(),
            activities: []
        )
        let json = String(data: try export.jsonData(), encoding: .utf8) ?? ""
        // Minor-unit Int olarak korunmalı: 12840 (decimal 128.40 DEĞİL).
        XCTAssertTrue(json.contains("12840"))
        XCTAssertFalse(json.contains("128.4"))
        XCTAssertFalse(json.contains("128.40"))
    }

    func testNoSensitiveFieldsInExport() throws {
        let export = UserDataExport.make(
            snapshots: [snapshot()],
            profile: profile(),
            activities: []
        )
        let json = (String(data: try export.jsonData(), encoding: .utf8) ?? "").lowercased()
        for forbidden in ["expopushtoken", "expo_push_token", "exponentpushtoken", "secret-device-token", "access_token", "accesstoken", "revenuecat", "anon_key"] {
            XCTAssertFalse(json.contains(forbidden), "Export içinde hassas alan bulundu: \(forbidden)")
        }
    }

    func testEmptyGroupsProduceValidJSON() throws {
        let export = UserDataExport.make(snapshots: [], profile: nil, activities: [])
        let data = try export.jsonData()
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
        XCTAssertEqual(export.schemaVersion, UserDataExport.currentSchemaVersion)
    }

    func testFileNameContainsDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 UTC
        XCTAssertEqual(UserDataExport.fileName(for: date), "groopay-export-2023-11-14.json")
    }
}
