import Foundation

/// Yerleşik besin listesi. Değerler 100 g içindir ve yaklaşıktır.
/// Temel gıdalar USDA FoodData Central ortalamalarına; Türk yemekleri standart tariflerden yapılan hesaplara dayanır.
/// Paketli ürünler için barkod ile Open Food Facts kullanılır.
public enum FoodDatabase {

    private static func f(_ id: String, _ name: String, _ cat: FoodCategory,
                          _ kcal: Double, _ p: Double, _ c: Double, _ fat: Double, _ fiber: Double = 0,
                          _ servings: [Serving] = [], keywords: [String] = []) -> Food {
        Food(id: id, name: name, category: cat,
             per100g: Macros(kcal: kcal, protein: p, carbs: c, fat: fat, fiber: fiber),
             servings: servings, keywords: keywords)
    }

    public static let all: [Food] = protein + dairy + grains + legumes + dishes + soups + fruitVeg + nuts + fats + sweets + drinks + supplements + fastFood

    private static let byID: [String: Food] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func food(_ id: String) -> Food? { byID[id] }

    // MARK: Protein kaynakları
    static let protein: [Food] = [
        f("egg", "Yumurta", .protein, 143, 12.6, 0.7, 9.5, 0, [Serving("1 adet (orta)", 50), Serving("2 adet", 100), Serving("3 adet", 150)], keywords: ["haşlanmış", "rafadan"]),
        f("egg-white", "Yumurta akı", .protein, 52, 10.9, 0.7, 0.2, 0, [Serving("1 adet akı", 33)]),
        f("omelette", "Omlet (2 yumurta, az yağlı)", .protein, 154, 10.6, 1.6, 11.7, 0, [Serving("1 porsiyon", 130)]),
        f("chicken-breast", "Tavuk göğsü (ızgara)", .protein, 165, 31, 0, 3.6, 0, [Serving("1 porsiyon", 150), Serving("1 fileto", 120)], keywords: ["tavuk", "fileto"]),
        f("chicken-thigh", "Tavuk but (derisiz, pişmiş)", .protein, 209, 26, 0, 10.9, 0, [Serving("1 porsiyon", 150)], keywords: ["pirzola", "baget"]),
        f("turkey-breast", "Hindi göğsü (pişmiş)", .protein, 147, 30, 0, 2.1, 0, [Serving("1 porsiyon", 150)]),
        f("turkey-ham", "Hindi füme", .protein, 110, 18, 2, 3.5, 0, [Serving("3 dilim", 45)], keywords: ["jambon"]),
        f("beef-mince-20", "Dana kıyma %20 yağ (pişmiş)", .protein, 254, 25.8, 0, 16.6, 0, [Serving("1 porsiyon", 120)], keywords: ["kıyma"]),
        f("beef-mince-10", "Dana kıyma %10 yağ (pişmiş)", .protein, 217, 26.1, 0, 11.8, 0, [Serving("1 porsiyon", 120)], keywords: ["yağsız kıyma"]),
        f("beef-steak", "Dana bonfile / antrikot (ızgara)", .protein, 205, 28.5, 0, 9.6, 0, [Serving("1 porsiyon", 150)], keywords: ["et", "biftek"]),
        f("lamb", "Kuzu eti (pişmiş)", .protein, 258, 25.5, 0, 16.5, 0, [Serving("1 porsiyon", 150)], keywords: ["pirzola"]),
        f("kofte", "Izgara köfte", .protein, 232, 18.5, 6.5, 14.8, 0.4, [Serving("4 adet", 120), Serving("1 porsiyon (6 adet)", 180)], keywords: ["köfte"]),
        f("salmon", "Somon (pişmiş)", .protein, 206, 22.1, 0, 12.4, 0, [Serving("1 fileto", 150)], keywords: ["balık"]),
        f("tuna-water", "Ton balığı (suda, süzülmüş)", .protein, 116, 25.5, 0, 0.8, 0, [Serving("1 kutu (süzülmüş)", 120)], keywords: ["konserve", "balık"]),
        f("tuna-oil", "Ton balığı (yağlı, süzülmüş)", .protein, 198, 29.1, 0, 8.2, 0, [Serving("1 kutu (süzülmüş)", 120)], keywords: ["konserve", "balık"]),
        f("anchovy", "Hamsi (fırın / ızgara)", .protein, 160, 22, 0, 7.5, 0, [Serving("1 porsiyon", 150)], keywords: ["balık"]),
        f("anchovy-fried", "Hamsi tava", .protein, 270, 19, 8, 18, 0.3, [Serving("1 porsiyon", 150)], keywords: ["balık", "kızartma"]),
        f("sea-bass", "Levrek (ızgara)", .protein, 124, 23.6, 0, 2.6, 0, [Serving("1 porsiyon", 200)], keywords: ["balık"]),
        f("sea-bream", "Çipura (ızgara)", .protein, 128, 24, 0, 3.5, 0, [Serving("1 porsiyon", 200)], keywords: ["balık"]),
        f("shrimp", "Karides (haşlanmış)", .protein, 99, 24, 0.2, 0.3, 0, [Serving("1 porsiyon", 120)]),
        f("sucuk", "Sucuk", .protein, 410, 20, 2, 36, 0, [Serving("4 dilim", 40)]),
        f("pastirma", "Pastırma", .protein, 220, 30, 1, 11, 0, [Serving("4 dilim", 40)]),
        f("chicken-doner-meat", "Tavuk döner (sadece et)", .protein, 190, 22, 3, 10, 0, [Serving("1 porsiyon", 150)], keywords: ["döner"]),
        f("beef-doner-meat", "Et döner (sadece et)", .protein, 250, 20, 2, 18, 0, [Serving("1 porsiyon", 150)], keywords: ["döner"]),
        f("tofu", "Tofu", .protein, 76, 8.1, 1.9, 4.8, 0.3, [Serving("1 porsiyon", 120)])
    ]

    // MARK: Süt ürünleri
    static let dairy: [Food] = [
        f("milk-whole", "Süt (tam yağlı)", .dairy, 61, 3.2, 4.8, 3.3, 0, [Serving("1 su bardağı", 200)]),
        f("milk-semi", "Süt (yarım yağlı)", .dairy, 46, 3.3, 4.8, 1.6, 0, [Serving("1 su bardağı", 200)], keywords: ["light süt"]),
        f("yogurt", "Yoğurt (tam yağlı)", .dairy, 61, 3.5, 4.7, 3.3, 0, [Serving("1 kase", 200), Serving("3 yemek kaşığı", 60)]),
        f("yogurt-light", "Yoğurt (az yağlı)", .dairy, 50, 4, 5, 1.5, 0, [Serving("1 kase", 200)]),
        f("greek-yogurt", "Süzme yoğurt (%2)", .dairy, 73, 9.9, 3.9, 1.9, 0, [Serving("1 kase", 150), Serving("3 yemek kaşığı", 75)], keywords: ["greek", "yunan"]),
        f("ayran-food", "Ayran", .dairy, 36, 1.7, 2.4, 1.8, 0, [Serving("1 bardak", 200), Serving("1 kutu", 285)]),
        f("kefir", "Kefir", .dairy, 52, 3.4, 4.5, 2, 0, [Serving("1 su bardağı", 200)]),
        f("feta", "Beyaz peynir (tam yağlı)", .dairy, 264, 14.2, 4.1, 21.3, 0, [Serving("1 dilim (kibrit kutusu)", 30), Serving("2 dilim", 60)], keywords: ["peynir"]),
        f("feta-light", "Beyaz peynir (yarım yağlı)", .dairy, 200, 17, 3, 13, 0, [Serving("1 dilim", 30)], keywords: ["peynir", "light"]),
        f("lor", "Lor peyniri", .dairy, 98, 11.1, 3.4, 4.3, 0, [Serving("3 yemek kaşığı", 60), Serving("1 kase", 150)], keywords: ["peynir", "cottage"]),
        f("kasar", "Kaşar peyniri", .dairy, 355, 25, 2, 27, 0, [Serving("1 dilim", 20), Serving("2 dilim", 40)], keywords: ["peynir"]),
        f("tulum", "Tulum peyniri", .dairy, 370, 22, 2, 30, 0, [Serving("1 dilim", 30)], keywords: ["peynir"]),
        f("labne", "Labne", .dairy, 236, 6.5, 4, 21, 0, [Serving("1 yemek kaşığı", 20)], keywords: ["krem peynir"]),
        f("kaymak", "Kaymak", .dairy, 450, 3, 3, 47, 0, [Serving("1 yemek kaşığı", 20)])
    ]

    // MARK: Tahıllar
    static let grains: [Food] = [
        f("bread-white", "Beyaz ekmek", .grains, 265, 9, 49, 3.2, 2.7, [Serving("1 dilim", 30), Serving("2 dilim", 60), Serving("çeyrek ekmek", 75)], keywords: ["ekmek"]),
        f("bread-wholewheat", "Tam buğday ekmeği", .grains, 247, 13, 41, 3.4, 7, [Serving("1 dilim", 30), Serving("2 dilim", 60)], keywords: ["ekmek", "kepekli"]),
        f("simit", "Simit", .grains, 300, 9, 54, 5.5, 2.5, [Serving("1 adet", 120)]),
        f("lavas", "Lavaş", .grains, 280, 9, 56, 1.5, 2.2, [Serving("1 adet", 70)], keywords: ["dürüm ekmeği"]),
        f("pide-bread", "Pide ekmeği", .grains, 270, 9, 53, 2, 2.3, [Serving("çeyrek pide", 80)]),
        f("bazlama", "Bazlama", .grains, 260, 8, 50, 3, 2, [Serving("yarım", 75)]),
        f("rice-plain", "Pirinç (haşlanmış)", .grains, 130, 2.7, 28.2, 0.3, 0.4, [Serving("1 porsiyon", 180), Serving("1 kepçe", 100)], keywords: ["pilav"]),
        f("rice-pilaf", "Pirinç pilavı (tereyağlı)", .grains, 165, 2.7, 28, 4.6, 0.4, [Serving("1 porsiyon", 180)], keywords: ["pilav"]),
        f("bulgur-plain", "Bulgur (haşlanmış)", .grains, 83, 3.1, 18.6, 0.2, 4.5, [Serving("1 porsiyon", 180)]),
        f("bulgur-pilaf", "Bulgur pilavı", .grains, 135, 3.5, 22, 3.8, 4.5, [Serving("1 porsiyon", 180)], keywords: ["pilav"]),
        f("pasta", "Makarna (haşlanmış)", .grains, 158, 5.8, 30.9, 0.9, 1.8, [Serving("1 porsiyon", 200)]),
        f("oats", "Yulaf ezmesi (kuru)", .grains, 379, 13.2, 67.7, 6.5, 10.1, [Serving("4 yemek kaşığı", 40), Serving("1 kase", 60)], keywords: ["yulaf"]),
        f("potato-boiled", "Patates (haşlanmış / fırın)", .grains, 87, 1.9, 20.1, 0.1, 1.8, [Serving("1 orta", 170)], keywords: ["patates"]),
        f("cornflakes", "Mısır gevreği (sade)", .grains, 357, 7.5, 84, 0.4, 3.3, [Serving("1 kase", 30)]),
        f("rice-cake", "Pirinç patlağı", .grains, 387, 8.2, 81.5, 2.8, 4.2, [Serving("1 adet", 9), Serving("3 adet", 27)]),
        f("granola", "Granola", .grains, 471, 10, 64, 20, 6, [Serving("1 kase", 45)])
    ]

    // MARK: Baklagiller
    static let legumes: [Food] = [
        f("lentil-boiled", "Mercimek (haşlanmış)", .legumes, 116, 9, 20.1, 0.4, 7.9, [Serving("1 kase", 200)]),
        f("chickpea-boiled", "Nohut (haşlanmış)", .legumes, 164, 8.9, 27.4, 2.6, 7.6, [Serving("1 kase", 160)], keywords: ["leblebi"]),
        f("white-bean-boiled", "Kuru fasulye (haşlanmış)", .legumes, 139, 9.7, 25.1, 0.4, 6.3, [Serving("1 kase", 180)]),
        f("roasted-chickpea", "Leblebi", .legumes, 360, 22, 55, 5, 12, [Serving("1 avuç", 30)]),
        f("hummus", "Humus", .legumes, 177, 7.9, 14.3, 9.6, 6, [Serving("2 yemek kaşığı", 40)])
    ]

    // MARK: Yemekler (tarif hesaplı, yaklaşık)
    static let dishes: [Food] = [
        f("menemen", "Menemen", .dishes, 110, 6, 4.5, 7.8, 1, [Serving("1 porsiyon", 250)]),
        f("kuru-fasulye-dish", "Kuru fasulye (zeytinyağlı)", .dishes, 120, 6, 15, 4, 5, [Serving("1 porsiyon", 250)], keywords: ["fasulye"]),
        f("etli-kuru-fasulye", "Etli kuru fasulye", .dishes, 140, 8, 14, 6, 5, [Serving("1 porsiyon", 250)], keywords: ["fasulye"]),
        f("nohut-dish", "Nohut yemeği", .dishes, 125, 6, 16, 4, 5, [Serving("1 porsiyon", 250)]),
        f("karniyarik", "Karnıyarık", .dishes, 130, 5, 7, 9, 2.5, [Serving("1 adet", 250)]),
        f("imam-bayildi", "İmambayıldı", .dishes, 120, 1.5, 8, 9.5, 3, [Serving("1 adet", 220)]),
        f("taze-fasulye", "Zeytinyağlı taze fasulye", .dishes, 80, 1.8, 7, 5, 3, [Serving("1 porsiyon", 200)]),
        f("manti", "Mantı (yoğurtlu)", .dishes, 185, 8, 22, 7, 1.2, [Serving("1 porsiyon", 300)]),
        f("lahmacun", "Lahmacun", .dishes, 230, 10, 30, 8, 2, [Serving("1 adet", 150)]),
        f("kiymali-pide", "Kıymalı pide", .dishes, 260, 11, 32, 10, 1.6, [Serving("yarım pide", 200), Serving("1 pide", 400)]),
        f("kasarli-pide", "Kaşarlı pide", .dishes, 280, 12, 31, 12, 1.5, [Serving("yarım pide", 200)]),
        f("chicken-doner-wrap", "Tavuk döner dürüm", .dishes, 215, 13, 22, 8, 1.5, [Serving("1 dürüm", 300)], keywords: ["döner", "dürüm"]),
        f("beef-doner-wrap", "Et döner dürüm", .dishes, 245, 12, 21, 12, 1.4, [Serving("1 dürüm", 300)], keywords: ["döner", "dürüm"]),
        f("iskender", "İskender", .dishes, 170, 10, 10, 10, 0.6, [Serving("1 porsiyon", 400)]),
        f("adana", "Adana kebap (sadece et)", .dishes, 290, 18, 2, 23, 0, [Serving("1 şiş", 150)], keywords: ["kebap"]),
        f("tavuk-sis", "Tavuk şiş", .dishes, 160, 25, 2, 6, 0, [Serving("1 porsiyon", 200)], keywords: ["kebap"]),
        f("kisir", "Kısır", .dishes, 160, 3.5, 25, 5.5, 4, [Serving("1 porsiyon", 150)]),
        f("sigara-boregi", "Sigara böreği", .dishes, 300, 10, 25, 18, 1, [Serving("3 adet", 90)], keywords: ["börek"]),
        f("su-boregi", "Su böreği", .dishes, 250, 10, 25, 12, 1, [Serving("1 dilim", 150)], keywords: ["börek"]),
        f("gozleme", "Gözleme (peynirli)", .dishes, 240, 9, 30, 9, 1.5, [Serving("1 adet", 250)]),
        f("cig-kofte", "Çiğ köfte (etsiz)", .dishes, 180, 5, 32, 3.5, 6, [Serving("1 dürüm", 250), Serving("5 adet", 100)]),
        f("tavuk-sote", "Tavuk sote", .dishes, 140, 16, 5, 6, 1.2, [Serving("1 porsiyon", 250)]),
        f("et-sote", "Et sote", .dishes, 180, 16, 5, 11, 1.2, [Serving("1 porsiyon", 250)]),
        f("tas-kebabi", "Tas kebabı", .dishes, 150, 12, 6, 9, 1.5, [Serving("1 porsiyon", 250)]),
        f("dolma", "Zeytinyağlı yaprak sarma", .dishes, 160, 2.5, 20, 8, 3, [Serving("5 adet", 120)], keywords: ["sarma"]),
        f("ispanak-yemegi", "Ispanak yemeği", .dishes, 75, 3.5, 5, 4.5, 2.5, [Serving("1 porsiyon", 250)]),
        f("cobansalata", "Çoban salata", .vegetables, 45, 1, 5, 2.5, 1.5, [Serving("1 kase", 200)], keywords: ["salata"]),
        f("mevsim-salata", "Mevsim salata (yağlı)", .vegetables, 55, 1.2, 4, 4, 1.8, [Serving("1 kase", 150)], keywords: ["salata"])
    ]

    // MARK: Çorbalar
    static let soups: [Food] = [
        f("mercimek-corbasi", "Mercimek çorbası", .soups, 60, 3.2, 8.5, 1.6, 1.8, [Serving("1 kase", 250)]),
        f("ezogelin", "Ezogelin çorbası", .soups, 58, 2.6, 8.5, 1.6, 1.8, [Serving("1 kase", 250)]),
        f("tavuk-corbasi", "Tavuk suyu çorba", .soups, 42, 2.8, 4.5, 1.3, 0.3, [Serving("1 kase", 250)]),
        f("yayla-corbasi", "Yayla çorbası", .soups, 52, 2.3, 6, 2, 0.2, [Serving("1 kase", 250)]),
        f("domates-corbasi", "Domates çorbası", .soups, 45, 1.2, 6, 2, 0.8, [Serving("1 kase", 250)]),
        f("iskembe", "İşkembe çorbası", .soups, 60, 5, 2, 3.5, 0, [Serving("1 kase", 250)])
    ]

    // MARK: Meyve ve sebze
    static let fruitVeg: [Food] = [
        f("banana", "Muz", .fruit, 89, 1.1, 22.8, 0.3, 2.6, [Serving("1 orta", 120)]),
        f("apple", "Elma", .fruit, 52, 0.3, 13.8, 0.2, 2.4, [Serving("1 orta", 180)]),
        f("orange", "Portakal", .fruit, 47, 0.9, 11.8, 0.1, 2.4, [Serving("1 orta", 150)]),
        f("mandarin", "Mandalina", .fruit, 53, 0.8, 13.3, 0.3, 1.8, [Serving("1 adet", 80)]),
        f("strawberry", "Çilek", .fruit, 32, 0.7, 7.7, 0.3, 2, [Serving("1 kase", 150)]),
        f("grapes", "Üzüm", .fruit, 69, 0.7, 18.1, 0.2, 0.9, [Serving("1 kase", 150)]),
        f("watermelon", "Karpuz", .fruit, 30, 0.6, 7.6, 0.2, 0.4, [Serving("1 dilim", 300)]),
        f("melon", "Kavun", .fruit, 34, 0.8, 8.2, 0.2, 0.9, [Serving("1 dilim", 250)]),
        f("date", "Hurma", .fruit, 282, 2.5, 75, 0.4, 8, [Serving("1 adet", 8), Serving("3 adet", 24)]),
        f("dried-apricot", "Kuru kayısı", .fruit, 241, 3.4, 62.6, 0.5, 7.3, [Serving("5 adet", 35)]),
        f("dried-fig", "Kuru incir", .fruit, 249, 3.3, 63.9, 0.9, 9.8, [Serving("2 adet", 40)]),
        f("tomato", "Domates", .vegetables, 18, 0.9, 3.9, 0.2, 1.2, [Serving("1 orta", 120)]),
        f("cucumber", "Salatalık", .vegetables, 15, 0.7, 3.6, 0.1, 0.5, [Serving("1 adet", 150)]),
        f("broccoli", "Brokoli (haşlanmış)", .vegetables, 35, 2.4, 7.2, 0.4, 3.3, [Serving("1 porsiyon", 150)]),
        f("spinach", "Ispanak (çiğ)", .vegetables, 23, 2.9, 3.6, 0.4, 2.2, [Serving("1 kase", 60)]),
        f("olive", "Zeytin", .vegetables, 145, 1, 3.8, 15.3, 3.3, [Serving("5 adet", 20), Serving("10 adet", 40)])
    ]

    // MARK: Kuruyemiş
    static let nuts: [Food] = [
        f("almond", "Badem", .nuts, 579, 21.2, 21.6, 49.9, 12.5, [Serving("1 avuç (~20 adet)", 28)]),
        f("walnut", "Ceviz", .nuts, 654, 15.2, 13.7, 65.2, 6.7, [Serving("3 adet (iç)", 15), Serving("1 avuç", 28)]),
        f("hazelnut", "Fındık", .nuts, 628, 15, 16.7, 60.8, 9.7, [Serving("1 avuç (~20 adet)", 28)]),
        f("pistachio", "Antep fıstığı", .nuts, 560, 20.2, 27.2, 45.3, 10.6, [Serving("1 avuç", 28)]),
        f("cashew", "Kaju", .nuts, 553, 18.2, 30.2, 43.9, 3.3, [Serving("1 avuç", 28)]),
        f("sunflower-seed", "Ay çekirdeği (iç)", .nuts, 584, 20.8, 20, 51.5, 8.6, [Serving("1 avuç", 28)]),
        f("peanut-butter", "Fıstık ezmesi", .nuts, 588, 25, 20, 50, 6, [Serving("1 yemek kaşığı", 16), Serving("2 yemek kaşığı", 32)])
    ]

    // MARK: Yağlar
    static let fats: [Food] = [
        f("olive-oil", "Zeytinyağı", .fats, 884, 0, 0, 100, 0, [Serving("1 tatlı kaşığı", 5), Serving("1 yemek kaşığı", 13.5)]),
        f("butter", "Tereyağı", .fats, 717, 0.9, 0.1, 81, 0, [Serving("1 tatlı kaşığı", 5), Serving("1 yemek kaşığı", 14)]),
        f("tahini", "Tahin", .fats, 595, 17, 21, 53.8, 9.3, [Serving("1 yemek kaşığı", 15)])
    ]

    // MARK: Tatlılar ve atıştırmalıklar
    static let sweets: [Food] = [
        f("honey", "Bal", .sweets, 304, 0.3, 82.4, 0, 0.2, [Serving("1 tatlı kaşığı", 7), Serving("1 yemek kaşığı", 21)]),
        f("jam", "Reçel", .sweets, 278, 0.4, 69, 0.1, 1, [Serving("1 yemek kaşığı", 20)]),
        f("pekmez", "Pekmez", .sweets, 290, 0.5, 72, 0.1, 0, [Serving("1 yemek kaşığı", 20)]),
        f("tahin-pekmez", "Tahin pekmez", .sweets, 440, 8.5, 47, 27, 4.5, [Serving("2 yemek kaşığı", 35)]),
        f("hazelnut-spread", "Fındık kreması", .sweets, 539, 6.3, 57.5, 30.9, 3.4, [Serving("1 yemek kaşığı", 15)]),
        f("dark-chocolate", "Bitter çikolata (%70)", .sweets, 598, 7.8, 45.9, 42.6, 10.9, [Serving("2 kare", 20)]),
        f("milk-chocolate", "Sütlü çikolata", .sweets, 535, 7.6, 59.4, 29.7, 3.4, [Serving("1 kare", 10), Serving("1 tablet", 80)]),
        f("sutlac", "Sütlaç", .sweets, 120, 3.5, 21, 2.5, 0.1, [Serving("1 kase", 180)]),
        f("baklava", "Baklava", .sweets, 430, 6, 50, 23, 2, [Serving("1 dilim", 40), Serving("3 dilim", 120)]),
        f("kunefe", "Künefe", .sweets, 370, 8, 40, 20, 0.5, [Serving("1 porsiyon", 180)]),
        f("protein-bar", "Protein bar (ortalama)", .sweets, 370, 30, 38, 12, 6, [Serving("1 adet", 60)]),
        f("sugar", "Şeker", .sweets, 387, 0, 100, 0, 0, [Serving("1 küp", 4), Serving("1 tatlı kaşığı", 5)])
    ]

    // MARK: İçecekler (kalorili)
    static let drinks: [Food] = [
        f("orange-juice", "Portakal suyu", .drinks, 45, 0.7, 10.4, 0.2, 0.2, [Serving("1 su bardağı", 200)]),
        f("cola", "Kola", .drinks, 42, 0, 10.6, 0, 0, [Serving("1 kutu", 330)]),
        f("latte", "Latte (sütlü kahve)", .drinks, 54, 2.9, 4.4, 2.8, 0, [Serving("orta boy", 350)])
    ]

    // MARK: Takviyeler
    static let supplements: [Food] = [
        f("whey", "Whey protein tozu (ortalama)", .supplements, 390, 78, 7, 6, 0, [Serving("1 ölçek", 30), Serving("2 ölçek", 60)], keywords: ["protein tozu"]),
        f("casein", "Kazein protein tozu", .supplements, 360, 80, 6, 2, 0, [Serving("1 ölçek", 33)], keywords: ["protein tozu"]),
        f("mass-gainer", "Gainer (kilo aldırıcı)", .supplements, 380, 15, 75, 3, 1, [Serving("1 porsiyon", 100)])
    ]

    // MARK: Dışarıda yemek
    static let fastFood: [Food] = [
        f("hamburger", "Hamburger", .fastFood, 250, 13, 25, 11, 1.5, [Serving("1 adet", 220)]),
        f("pizza", "Pizza (karışık)", .fastFood, 266, 11, 33, 10, 2.3, [Serving("1 dilim", 110), Serving("2 dilim", 220)]),
        f("tost", "Kaşarlı tost", .fastFood, 300, 13, 30, 14, 1.5, [Serving("1 adet", 150)]),
        f("french-fries", "Patates kızartması", .fastFood, 312, 3.4, 41, 15, 3.8, [Serving("orta porsiyon", 120)]),
        f("kumpir", "Kumpir", .fastFood, 180, 5, 20, 9, 2, [Serving("1 adet", 450)])
    ]

    // MARK: Arama

    /// Türkçe karakterlere duyarsız, kelime başlarına öncelik veren arama.
    public static func search(_ query: String, in foods: [Food]) -> [Food] {
        let q = normalize(query)
        guard !q.isEmpty else { return foods }
        let tokens = q.split(separator: " ").map(String.init)
        var scored: [(Food, Int)] = []
        for food in foods {
            let haystack = normalize(([food.name, food.brand ?? ""] + food.keywords).joined(separator: " "))
            guard tokens.allSatisfy({ haystack.contains($0) }) else { continue }
            var score = 0
            let name = normalize(food.name)
            if name == q { score += 100 }
            if name.hasPrefix(q) { score += 50 }
            let words = name.split(separator: " ")
            if words.contains(where: { $0.hasPrefix(tokens[0]) }) { score += 20 }
            score -= name.count / 10
            scored.append((food, score))
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    public static func normalize(_ s: String) -> String {
        var out = s.lowercased(with: Locale(identifier: "tr_TR"))
        let map: [Character: Character] = ["ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u"]
        out = String(out.map { map[$0] ?? $0 })
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
