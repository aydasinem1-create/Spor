import Foundation

/// Open Food Facts (açık ve ücretsiz, ODbL lisanslı) barkod sonucu çözümleyici.
public enum OpenFoodFacts {

    public static func productURL(barcode: String) -> URL? {
        let digits = barcode.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        return URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=code,product_name,product_name_tr,brands,nutriments,serving_size,serving_quantity")
    }

    public static let attribution = "Ürün verisi: Open Food Facts (ODbL)"

    public enum ParseError: Error, Equatable {
        case notFound
        case missingNutrition
        case invalid
    }

    /// API yanıtından Food üretir. Değerler 100 g başınadır.
    public static func parse(_ data: Data, barcode: String) throws -> Food {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ParseError.invalid }
        if let status = root["status"] as? Int, status == 0 { throw ParseError.notFound }
        guard let product = root["product"] as? [String: Any] else { throw ParseError.notFound }
        let nutr = product["nutriments"] as? [String: Any] ?? [:]

        func number(_ key: String) -> Double? {
            if let d = nutr[key] as? Double { return d }
            if let i = nutr[key] as? Int { return Double(i) }
            if let s = nutr[key] as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }

        var kcal = number("energy-kcal_100g")
        if kcal == nil, let kj = number("energy_100g") ?? number("energy-kj_100g") { kcal = kj / 4.184 }
        guard let energy = kcal else { throw ParseError.missingNutrition }
        let macros = Macros(kcal: energy.rounded(),
                            protein: number("proteins_100g") ?? 0,
                            carbs: number("carbohydrates_100g") ?? 0,
                            fat: number("fat_100g") ?? 0,
                            fiber: number("fiber_100g") ?? 0)

        let rawName = (product["product_name_tr"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (product["product_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? "Barkodlu ürün"
        let brand = (product["brands"] as? String)?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }

        var servings: [Serving] = []
        if let q = product["serving_quantity"] as? Double, q > 0 {
            servings.append(Serving("1 porsiyon (\(Int(q)) g)", q))
        } else if let qs = product["serving_quantity"] as? String, let q = Double(qs), q > 0 {
            servings.append(Serving("1 porsiyon (\(Int(q)) g)", q))
        }
        servings.append(Serving("100 g", 100))

        return Food(id: "off-\(barcode)", name: rawName, brand: brand, category: .custom, per100g: macros,
                    servings: servings, source: .openFoodFacts(barcode: barcode))
    }
}
