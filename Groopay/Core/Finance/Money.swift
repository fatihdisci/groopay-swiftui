import Foundation

func getDecimals(_ currency: String) -> Int {
    switch currency.uppercased() {
    case "JPY", "KRW", "VND", "CLP", "ISK":
        return 0
    case "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND":
        return 3
    default:
        return 2
    }
}

func parseMoneyInputToMinor(_ input: String, currency: String) -> Int {
    let decimals = getDecimals(currency)
    let allowed = input.filter {
        $0.isNumber || $0 == "," || $0 == "." || $0 == "-"
    }

    guard !allowed.isEmpty else { return 0 }

    let isNegative = allowed.first == "-"
    let unsigned = allowed.filter { $0 != "-" }
    guard !unsigned.isEmpty else { return 0 }

    let separatorIndex = decimalSeparatorIndex(
        in: unsigned,
        decimals: decimals
    )
    let wholePart: Substring
    let fractionPart: Substring

    if let separatorIndex {
        wholePart = unsigned[..<separatorIndex]
        fractionPart = unsigned[unsigned.index(after: separatorIndex)...]
    } else {
        wholePart = Substring(unsigned)
        fractionPart = ""
    }

    let wholeDigits = wholePart.filter(\.isNumber)
    let fractionDigits = fractionPart.filter(\.isNumber)

    guard
        let whole = integer(from: wholeDigits.isEmpty ? "0" : wholeDigits),
        let scale = powerOfTen(decimals)
    else {
        return 0
    }
    let scaled = whole.multipliedReportingOverflow(by: scale)
    guard !scaled.overflow else { return 0 }
    let scaledWhole = scaled.partialValue

    var fraction = 0
    if decimals > 0 {
        let padded = fractionDigits.prefix(decimals)
            + String(repeating: "0", count: max(0, decimals - fractionDigits.count))
        guard let parsedFraction = integer(from: padded) else { return 0 }
        fraction = parsedFraction

    }

    let combined = scaledWhole.addingReportingOverflow(fraction)
    guard !combined.overflow else { return 0 }

    if isNegative {
        let negated = 0.subtractingReportingOverflow(combined.partialValue)
        return negated.overflow ? 0 : negated.partialValue
    }

    return combined.partialValue
}

func decimalAmount(fromMinor minor: Int, currency: String) -> Decimal {
    var amount = Decimal(minor)
    for _ in 0..<getDecimals(currency) {
        amount /= 10
    }
    return amount
}

func minorAmount(fromDecimal amount: Decimal, currency: String) -> Int? {
    var scaled = amount
    for _ in 0..<getDecimals(currency) {
        scaled *= 10
    }

    var rounded = Decimal()
    var source = scaled
    NSDecimalRound(&rounded, &source, 0, .plain)
    return Int(NSDecimalString(&rounded, Locale(identifier: "en_US_POSIX")))
}

func formatAmount(_ minor: Int, currency: String) -> String {
    let decimals = getDecimals(currency)
    var amount = Decimal(minor)

    for _ in 0..<decimals {
        amount /= 10
    }

    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "tr_TR")
    formatter.numberStyle = .currency
    formatter.currencyCode = currency.uppercased()
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals

    return formatter.string(from: NSDecimalNumber(decimal: amount))
        ?? "\(minor) \(currency.uppercased())"
}

private func decimalSeparatorIndex(
    in value: String,
    decimals: Int
) -> String.Index? {
    guard decimals > 0 else { return nil }

    let separators = value.indices.filter {
        value[$0] == "," || value[$0] == "."
    }
    guard let lastSeparator = separators.last else { return nil }

    let digitsAfter = value[value.index(after: lastSeparator)...]
        .filter(\.isNumber)
        .count

    guard digitsAfter <= decimals else { return nil }

    if separators.count == 1 {
        return digitsAfter == 0 || digitsAfter <= decimals
            ? lastSeparator
            : nil
    }

    return lastSeparator
}

private func integer<S: StringProtocol>(from digits: S) -> Int? {
    var result = 0

    for character in digits {
        guard let digit = character.wholeNumberValue else { return nil }
        let multiplied = result.multipliedReportingOverflow(by: 10)
        guard !multiplied.overflow else { return nil }

        let added = multiplied.partialValue.addingReportingOverflow(digit)
        guard !added.overflow else { return nil }
        result = added.partialValue
    }

    return result
}

private func powerOfTen(_ exponent: Int) -> Int? {
    var result = 1

    for _ in 0..<exponent {
        let multiplied = result.multipliedReportingOverflow(by: 10)
        guard !multiplied.overflow else { return nil }
        result = multiplied.partialValue
    }

    return result
}
