import SwiftUI

struct ActivityFilter: Equatable, Sendable {
    var groupID: UUID?
    var currency: String?
    var startDate: Date?
    var endDate: Date?
    var onlyMine = false

    var activeCount: Int {
        [groupID != nil, currency != nil, startDate != nil, endDate != nil, onlyMine]
            .filter { $0 }.count
    }

    var isActive: Bool { activeCount > 0 }

    mutating func reset() {
        self = ActivityFilter()
    }

    func matches(
        _ activity: Activity,
        groups: [GroupSnapshot],
        userID: UUID?,
        calendar: Calendar = .current
    ) -> Bool {
        if let groupID, activity.groupId != groupID { return false }

        if let currency {
            guard activity.metadata["currency"]?.stringValue?.uppercased() == currency else {
                return false
            }
        }

        if let startDate {
            guard let createdAt = activity.createdAt,
                  createdAt >= calendar.startOfDay(for: startDate) else {
                return false
            }
        }

        if let endDate {
            guard let createdAt = activity.createdAt,
                  let exclusiveEnd = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: endDate)
                  ),
                  createdAt < exclusiveEnd else {
                return false
            }
        }

        if onlyMine {
            guard activity.actionType.lowercased().contains("expense"),
                  let userID,
                  let snapshot = groups.first(where: { $0.id == activity.groupId }),
                  let memberID = snapshot.currentMember(userID: userID)?.id,
                  activity.actorMemberId == memberID else {
                return false
            }
        }

        return true
    }
}

struct ActivityFilterButton: View {
    @Binding var filter: ActivityFilter
    let groups: [GroupSnapshot]
    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("Filtrele")
                if filter.activeCount > 0 {
                    Text("\(filter.activeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.primaryTheme)
                        .clipShape(Circle())
                }
            }
            .font(.body(13, weight: .semibold))
            .foregroundStyle(Color.primaryTheme)
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(Color.surfaceTinted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $presented) {
            NavigationStack {
                ActivityFilterSheet(filter: $filter, groups: groups)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ActivityFilterSheet: View {
    @Binding var filter: ActivityFilter
    let groups: [GroupSnapshot]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Grup") {
                Picker("Grup", selection: $filter.groupID) {
                    Text("Tüm gruplar").tag(nil as UUID?)
                    ForEach(groups) { snapshot in
                        Text(snapshot.group.name).tag(snapshot.id as UUID?)
                    }
                }
            }

            Section("Para Birimi") {
                Picker("Para Birimi", selection: $filter.currency) {
                    Text("Tümü").tag(nil as String?)
                    ForEach(Currency.supported.filter { ["TRY", "USD", "EUR"].contains($0) }, id: \.self) {
                        Text($0).tag($0 as String?)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Tarih Aralığı") {
                OptionalDateRow(title: "Başlangıç", date: $filter.startDate)
                OptionalDateRow(title: "Bitiş", date: $filter.endDate)
            }

            Section {
                Toggle("Sadece benim harcamalarım", isOn: $filter.onlyMine)
                    .tint(.primaryTheme)
            }

            if filter.isActive {
                Section {
                    Button("Tüm Filtreleri Temizle", role: .destructive) {
                        filter.reset()
                    }
                }
            }
        }
        .navigationTitle("Aktivite Filtreleri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bitti") { dismiss() }
            }
        }
    }
}

private struct OptionalDateRow: View {
    let title: LocalizedStringResource
    @Binding var date: Date?

    var body: some View {
        if date == nil {
            Button {
                date = Date()
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("Seç")
                        .foregroundStyle(Color.primaryTheme)
                }
            }
        } else {
            HStack {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { date = $0 }
                    ),
                    displayedComponents: .date
                )
                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tarihi temizle")
            }
        }
    }
}
