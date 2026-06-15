import Foundation

extension KeyedDecodingContainer {
    func decodeMinorAmount(
        forKey key: Key,
        currency: String
    ) throws -> Int {
        if let integer = try? decode(Int.self, forKey: key) {
            guard
                let scale = decimalScale(for: currency),
                !integer.multipliedReportingOverflow(by: scale).overflow
            else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: self,
                    debugDescription: "Money amount overflows Int"
                )
            }
            return integer * scale
        }

        if let decimal = try? decode(Decimal.self, forKey: key),
           let minor = minorAmount(fromDecimal: decimal, currency: currency) {
            return minor
        }

        if let string = try? decode(String.self, forKey: key) {
            return parseMoneyInputToMinor(string, currency: currency)
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Invalid money amount"
        )
    }
}

private func decimalScale(for currency: String) -> Int? {
    var result = 1

    for _ in 0..<getDecimals(currency) {
        let multiplied = result.multipliedReportingOverflow(by: 10)
        guard !multiplied.overflow else { return nil }
        result = multiplied.partialValue
    }

    return result
}
