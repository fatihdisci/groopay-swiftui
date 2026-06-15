import Foundation

enum SplitType: String, Codable, Sendable {
    case equal
    case custom
    case subset
}

func computeSplits(
    amount: Int,
    type: SplitType,
    memberIds: [UUID],
    custom: [UUID: Int]? = nil,
    subset: Set<UUID>? = nil
) -> [UUID: Int] {
    let uniqueMembers = orderedUnique(memberIds)
    guard !uniqueMembers.isEmpty else { return [:] }

    switch type {
    case .equal:
        return equalSplits(amount: amount, memberIds: uniqueMembers)

    case .subset:
        let selected = uniqueMembers.filter { subset?.contains($0) == true }
        guard !selected.isEmpty else { return [:] }
        return equalSplits(amount: amount, memberIds: selected)

    case .custom:
        var result = Dictionary(
            uniqueKeysWithValues: uniqueMembers.map {
                ($0, custom?[$0] ?? 0)
            }
        )
        let assigned = result.values.reduce(0, +)
        result[uniqueMembers[0], default: 0] += amount - assigned
        return result
    }
}

private func equalSplits(
    amount: Int,
    memberIds: [UUID]
) -> [UUID: Int] {
    let base = amount / memberIds.count
    let remainder = amount % memberIds.count
    let remainderCount = abs(remainder)
    let direction = remainder < 0 ? -1 : 1

    return Dictionary(
        uniqueKeysWithValues: memberIds.enumerated().map { index, memberID in
            let adjustment = index < remainderCount ? direction : 0
            return (memberID, base + adjustment)
        }
    )
}

private func orderedUnique(_ values: [UUID]) -> [UUID] {
    var seen = Set<UUID>()
    return values.filter { seen.insert($0).inserted }
}
