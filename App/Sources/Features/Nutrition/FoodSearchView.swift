import SwiftUI
import VisionKit
import Vision
import FormaKit

struct FoodSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var meal: MealType
    @State private var query = ""
    @State private var category: FoodCategory?
    @State private var selected: Food?
    @State private var showScanner = false
    @State private var showCustom = false
    @State private var lookupState: LookupState = .idle
    @State private var manualBarcode = ""

    enum LookupState: Equatable { case idle, loading, failed(String) }

    private var results: [Food] {
        var foods = model.allFoods()
        if let category { foods = foods.filter { $0.category == category } }
        return FoodDatabase.search(query, in: foods)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    mealPicker
                    actionRow
                    if case .loading = lookupState {
                        HStack { ProgressView().tint(Theme.lime); Text("Ürün aranıyor…").formaFont(.callout, Theme.textSecondary) }
                    }
                    if case .failed(let message) = lookupState {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message).formaFont(.callout, Theme.energy)
                            Button("Değerleri kendim gireyim") { showCustom = true }.buttonStyle(SecondaryButtonStyle(compact: true))
                        }
                        .cardStyle(background: Theme.energy.opacity(0.1))
                    }
                    if query.isEmpty && category == nil {
                        if !model.favoriteFoods.isEmpty { section("Favoriler", model.favoriteFoods) }
                        if !model.recentFoods.isEmpty { section("Son eklenenler", Array(model.recentFoods.prefix(10))) }
                        yesterdayCopy
                    }
                    categoryChips
                    section(query.isEmpty ? (category?.displayName ?? "Tüm yiyecekler") : "Sonuçlar", Array(results.prefix(query.isEmpty && category == nil ? 40 : 120)))
                    if results.isEmpty {
                        EmptyCard(symbol: "magnifyingglass", title: "Bulunamadı", message: "Barkod okut ya da kendi yiyeceğini ekle.")
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 20)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Yemek ara: menemen, tavuk, yoğurt…")
            .screenBackground()
            .navigationTitle("Yiyecek ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
            .sheet(item: $selected) { food in
                FoodPortionSheet(food: food, meal: meal, editing: nil) { dismiss() }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { code in
                    showScanner = false
                    lookup(code)
                }
                .presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showCustom) {
                NavigationStack { CustomFoodView { food in selected = food } }
                    .presentationBackground(Theme.background)
            }
        }
    }

    private var mealPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.isRamadan ? MealType.ramadanDay : MealType.normalDay) { m in
                    Chip(title: m.displayName, systemImage: m.symbol, isOn: meal == m) { meal = m }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { showScanner = true } label: {
                Label("Barkod okut", systemImage: "barcode.viewfinder")
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
            Button { showCustom = true } label: {
                Label("Kendi yiyeceğim", systemImage: "square.and.pencil")
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
            Spacer(minLength: 0)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Chip(title: "Tümü", isOn: category == nil) { category = nil }
                ForEach(FoodCategory.allCases.filter { $0 != .custom || !model.data.customFoods.isEmpty }, id: \.self) { c in
                    Chip(title: c.displayName, isOn: category == c) { category = category == c ? nil : c }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var yesterdayCopy: some View {
        let cal = Calendar.forma
        if let y = cal.date(byAdding: .day, value: -1, to: model.now) {
            let key = DayKey.key(y)
            let logs = model.data.foodLogs.filter { DayKey.key($0.date) == key && $0.meal == meal }
            if !logs.isEmpty {
                Button {
                    model.copyMeal(from: y, meal: meal, to: meal)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc").foregroundStyle(Theme.lime)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dünkü \(meal.displayName.lowercased(with: Locale(identifier: "tr_TR"))) öğününü kopyala").formaFont(.callout)
                            Text(logs.map(\.foodName).joined(separator: ", ")).formaFont(.caption, Theme.textSecondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .cardStyle(padding: 12)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func section(_ title: String, _ foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !foods.isEmpty { Text(title).eyebrow().padding(.top, 4) }
            LazyVStack(spacing: 8) {
                ForEach(foods) { food in
                    Button { selected = food } label: { FoodRow(food: food) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func lookup(_ code: String) {
        lookupState = .loading
        Task {
            do {
                let food = try await FoodLookup.product(barcode: code)
                lookupState = .idle
                selected = food
            } catch {
                lookupState = .failed((error as? LocalizedError)?.errorDescription ?? "Ürün bulunamadı.")
            }
        }
    }
}

struct FoodRow: View {
    @Environment(AppModel.self) private var model
    var food: Food

    var body: some View {
        let s = food.defaultServing
        let m = food.macros(grams: s.grams)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(food.name).formaFont(.callout).lineLimit(1)
                    if model.isFavorite(food) { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.gold) }
                }
                Text("\(s.name) · \(Fmt.int(m.kcal)) kcal" + (food.brand.map { " · \($0)" } ?? ""))
                    .formaFont(.caption, Theme.textTertiary).lineLimit(1)
            }
            Spacer()
            Text("\(Fmt.int(m.protein)) g").formaFont(.callout, Theme.lime)
            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.lime)
        }
        .cardStyle(padding: 12)
    }
}

// MARK: - Porsiyon

struct FoodPortionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var food: Food
    @State var meal: MealType
    var editing: FoodLog?
    var onAdded: (() -> Void)? = nil

    @State private var grams: Double = 100
    @State private var servingName: String?
    @State private var multiplier: Double = 1

    var body: some View {
        let m = food.macros(grams: grams)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).formaFont(.title).fixedSize(horizontal: false, vertical: true)
                        if let brand = food.brand { Text(brand).formaFont(.caption, Theme.textSecondary) }
                    }
                    Spacer()
                    IconButton(systemName: model.isFavorite(food) ? "star.fill" : "star", tint: Theme.gold) { model.toggleFavorite(food) }
                }
                .padding(.top, 20)

                HStack(spacing: 10) {
                    macroTile("Kalori", Fmt.int(m.kcal), "kcal", Theme.energy)
                    macroTile("Protein", Fmt.int(m.protein), "g", Theme.lime)
                    macroTile("Karb.", Fmt.int(m.carbs), "g", Theme.energy)
                    macroTile("Yağ", Fmt.int(m.fat), "g", Theme.water)
                }

                if !food.servings.isEmpty {
                    Text("Porsiyon").eyebrow()
                    FlowLayout(spacing: 8) {
                        ForEach(food.servings, id: \.name) { s in
                            Chip(title: s.name, isOn: servingName == s.name) {
                                servingName = s.name
                                multiplier = 1
                                grams = s.grams
                            }
                        }
                    }
                    if let name = servingName, let s = food.servings.first(where: { $0.name == name }) {
                        NumberStepper(title: "Adet", value: Binding(get: { multiplier }, set: { multiplier = $0; grams = (s.grams * $0).rounded() }),
                                      step: 0.5, range: 0.5...10, unit: "×", format: { Fmt.oneDecimal($0).replacingOccurrences(of: ",0", with: "") })
                    }
                }
                NumberStepper(title: "Miktar", value: Binding(get: { grams }, set: { grams = $0; servingName = nil }),
                              step: grams >= 100 ? 10 : 5, range: 1...2000, unit: "g", format: { Fmt.int($0) })

                Text("Değerler yaklaşıktır; tarif ve porsiyona göre değişebilir.").formaFont(.caption, Theme.textTertiary)
                if case .openFoodFacts = food.source {
                    Text(OpenFoodFacts.attribution).formaFont(.caption, Theme.textTertiary)
                }

                Button(editing == nil ? "\(meal.displayName) öğününe ekle" : "Güncelle") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("food.add")
                if let editing {
                    Button("Sil", role: .destructive) {
                        model.deleteFoodLog(editing.id)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Theme.coral)
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .onAppear {
            if let editing {
                grams = editing.grams
                servingName = nil
            } else {
                let s = food.defaultServing
                grams = s.grams
                servingName = food.servings.isEmpty ? nil : s.name
            }
        }
    }

    private func macroTile(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).formaFont(.numberM, color).contentTransition(.numericText())
            Text("\(label) (\(unit))").formaFont(.caption, Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func save() {
        let label: String? = servingName.map { name in multiplier == 1 ? name : "\(Fmt.oneDecimal(multiplier)) × \(name)" }
        if let editing {
            model.updateFoodLog(editing.id, grams: grams, meal: meal)
        } else {
            model.logFood(food, grams: grams, meal: meal, servingLabel: label)
        }
        dismiss()
        onAdded?()
    }
}

// MARK: - Kendi yiyeceğin

struct CustomFoodView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onSave: (Food) -> Void
    @State private var name = ""
    @State private var kcal: Double = 100
    @State private var protein: Double = 5
    @State private var carbs: Double = 10
    @State private var fat: Double = 3
    @State private var serving: Double = 100

    var body: some View {
        Form {
            Section("Yiyecek") {
                TextField("Adı (örn. Annemin mercimek köftesi)", text: $name)
            }
            Section("100 g için değerler (paketin arkasında)") {
                stepper("Kalori", $kcal, "kcal", 10)
                stepper("Protein", $protein, "g", 1)
                stepper("Karbonhidrat", $carbs, "g", 1)
                stepper("Yağ", $fat, "g", 1)
            }
            Section("Porsiyon") {
                stepper("1 porsiyon", $serving, "g", 10)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Kendi yiyeceğin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") {
                    let food = Food(id: "custom-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces), category: .custom,
                                    per100g: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat),
                                    servings: [Serving("1 porsiyon (\(Int(serving)) g)", serving), Serving("100 g", 100)], source: .custom)
                    model.saveCustomFood(food)
                    dismiss()
                    onSave(food)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .foregroundStyle(Theme.lime)
            }
        }
    }

    private func stepper(_ title: String, _ value: Binding<Double>, _ unit: String, _ step: Double) -> some View {
        Stepper(value: value, in: 0...2000, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Fmt.int(value.wrappedValue)) \(unit)").foregroundStyle(Theme.textSecondary).monospacedDigit()
            }
        }
    }
}

// MARK: - Barkod

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void
    @State private var manual = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScanner(onCode: onCode)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.lime, lineWidth: 3)
                                .frame(width: 260, height: 140)
                        )
                        .frame(maxHeight: 420)
                    Text("Barkodu çerçevenin içine getir.").formaFont(.callout, Theme.textSecondary)
                } else {
                    EmptyCard(symbol: "camera.fill", title: "Kamera kullanılamıyor",
                              message: "Kamera iznini Ayarlar'dan açabilir ya da barkod numarasını elle yazabilirsin.")
                }
                HStack {
                    TextField("Barkod numarası", text: $manual)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button("Ara") { onCode(manual) }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                        .disabled(manual.filter(\.isNumber).count < 8)
                }
                Spacer()
            }
            .padding(Theme.gutter)
            .screenBackground()
            .navigationTitle("Barkod okut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        }
    }
}

struct BarcodeScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
                                           qualityLevel: .balanced, recognizesMultipleItems: false,
                                           isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let value = code.payloadStringValue, value.filter(\.isNumber).count >= 8 {
                    done = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dataScanner.stopScanning()
                    onCode(value)
                    return
                }
            }
        }
    }
}
