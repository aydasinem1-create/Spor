import Foundation
import FormaKit

/// Barkoddan ürün bilgisi (Open Food Facts).
enum FoodLookup {
    enum LookupError: LocalizedError {
        case invalidBarcode, notFound, noNutrition, network

        var errorDescription: String? {
            switch self {
            case .invalidBarcode: return "Barkod okunamadı."
            case .notFound: return "Bu ürün veritabanında yok. Değerlerini kendin ekleyebilirsin."
            case .noNutrition: return "Ürün bulundu ama besin değerleri eksik."
            case .network: return "İnternet bağlantısı gerekiyor."
            }
        }
    }

    static func product(barcode: String) async throws -> Food {
        guard let url = OpenFoodFacts.productURL(barcode: barcode) else { throw LookupError.invalidBarcode }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("Forma iOS - kişisel fitness takip uygulaması", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LookupError.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { throw LookupError.notFound }
        do {
            return try OpenFoodFacts.parse(data, barcode: barcode.filter(\.isNumber))
        } catch OpenFoodFacts.ParseError.missingNutrition {
            throw LookupError.noNutrition
        } catch {
            throw LookupError.notFound
        }
    }
}
