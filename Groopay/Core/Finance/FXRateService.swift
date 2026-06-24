import Foundation

// MARK: - Frankfurter API FX Rate Service (DESIGN.md §6.4)
//
// ECB (Avrupa Merkez Bankası) referans kurları, günlük güncellenir.
// Ücretsiz, API key gerekmez. In-memory cache, aynı çift için 1 saat TTL.
// Kur bilgisi ASLA kalıcı kaydedilmez — yalnızca görüntüleme.

actor FXRateService {
    static let shared = FXRateService()

    private let baseURL = URL(string: "https://api.frankfurter.dev/v1")!
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private var cache: [String: CachedRate] = [:]

    private struct CachedRate {
        let rate: Double
        let asOf: Date
        let cachedAt: Date

        var isValid: Bool {
            Date().timeIntervalSince(cachedAt) < 3600 // 1 saat TTL
        }
    }

    private struct FrankfurterResponse: Decodable {
        let amount: Double
        let base: String
        let date: String
        let rates: [String: Double]
    }

    /// İki para birimi arasındaki kuru döndürür.
    /// - Parameters:
    ///   - from: Kaynak para birimi (örn. "EUR")
    ///   - to: Hedef para birimi (örn. "TRY")
    /// - Returns: Kur ve kurun geçerli olduğu tarih
    func fetchRate(from: String, to: String) async throws -> (rate: Double, asOf: Date) {
        let key = "\(from.uppercased())-\(to.uppercased())"

        // Cache kontrolü
        if let cached = cache[key], cached.isValid {
            return (cached.rate, cached.asOf)
        }

        // Frankfurter API: /v1/latest?base=EUR&symbols=TRY
        var components = URLComponents(
            url: baseURL.appendingPathComponent("latest"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "base", value: from.uppercased()),
            URLQueryItem(name: "symbols", value: to.uppercased())
        ]

        guard let url = components?.url else {
            throw FXRateError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FXRateError.serverError
        }

        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

        guard let rate = decoded.rates[to.uppercased()] else {
            throw FXRateError.currencyNotFound
        }

        // Tarihi parse et
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "CET")
        let asOf = dateFormatter.date(from: decoded.date) ?? Date()

        // Cache'le
        let cached = CachedRate(rate: rate, asOf: asOf, cachedAt: Date())
        cache[key] = cached

        return (rate, asOf)
    }

    /// Cache'i temizle (uygulama arka plana gittiğinde veya test için)
    func clearCache() {
        cache.removeAll()
    }
}

enum FXRateError: LocalizedError {
    case invalidURL
    case serverError
    case currencyNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz kur API adresi"
        case .serverError:
            return "Kur sunucusu yanıt vermedi"
        case .currencyNotFound:
            return "Bu para birimi için kur bulunamadı"
        }
    }
}
