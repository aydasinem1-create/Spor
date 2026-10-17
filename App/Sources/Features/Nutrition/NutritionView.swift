import SwiftUI
import Charts
import FormaKit

struct NutritionView: View {
    @Environment(AppModel.self) private var model
    @State private var addMeal: MealType?
    @State private var editLog: FoodLog?
    @State private var showWater = false
    @State private var showSupplements = false
    @State private var showTargets = false

    private var meals: [MealType] { model.isRamadan ? MealType.ramadanDay : MealType.normalDay }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: Fmt.dayMonth.string(from: model.now), title: "Beslenme") {
                        IconButton(systemName: "slider.horizontal.3") { showTargets = true }
                    }
                    summaryCard
                    proteinTip
                    ForEach(meals) { meal in mealSection(meal) }
                    let other = model.todayFoodLogs.filter { !meals.contains($0.meal) }
                    if !other.isEmpty { mealSection(nil, logs: other) }
                    HStack(spacing: 10) {
                        quickTile("Su", "\(Fmt.liters(model.todayWaterMl)) L", "drop.fill", Theme.water) { showWater = true }
                        quickTile("Takviye", "\(model.todaysSupplements.filter(model.isDone).count)/\(model.todaysSupplements.count)", "pills.fill", Theme.supplement) { showSupplements = true }
                    }
                    weekChart
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $addMeal) { meal in
                FoodSearchView(meal: meal).presentationBackground(Theme.background)
            }
            .sheet(item: $editLog) { log in
                FoodPortionSheet(food: model.food(log.foodID) ?? fallbackFood(log), meal: log.meal, editing: log)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showWater) { WaterSheet().presentationDetents([.medium, .large]).presentationBackground(Theme.background) }
            .sheet(isPresented: $showSupplements) { NavigationStack { SupplementsView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showTargets) { NavigationStack { TargetsView() }.presentationBackground(Theme.background) }
        }
    }

    private func fallbackFood(_ log: FoodLog) -> Food {
        Food(id: log.foodID, name: log.foodName, category: .custom, per100g: log.per100g, servings: [Serving("100 g", 100)])
    }

    private var summaryCard: some View {
        let t = model.targets
        let m = model.todayMacros
        let remaining = t.kcal - m.kcal
        return VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining >= 0 ? "Kalan" : "Fazla").eyebrow()
                    Text(Fmt.int(abs(remaining))).formaFont(.numberXL, remaining >= 0 ? Theme.textPrimary : Theme.energy)
                        .contentTransition(.numericText())
                    Text("kcal · hedef \(Fmt.int(t.kcal))").formaFont(.caption, Theme.textSecondary)
                }
                Spacer()
                ZStack {
                    RingView(progress: m.kcal / max(1, t.kcal), color: Theme.energy, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(Fmt.int(m.kcal)).formaFont(.numberS)
                        Text("alındı").font(.forma(.micro)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 96, height: 96)
            }
            VStack(spacing: 12) {
                MacroRow(label: "Protein", value: m.protein, target: t.proteinG, color: Theme.protein)
                MacroRow(label: "Karbonhidrat", value: m.carbs, target: t.carbsG, color: Theme.carbs)
                MacroRow(label: "Yağ", value: m.fat, target: t.fatG, color: Theme.fat)
                MacroRow(label: "Lif", value: m.fiber, target: t.fiberG, color: Theme.supplement)
            }
            if let est = model.adaptiveEstimate, est.confidence >= 0.5, !model.settings.targetsAreManual {
                Label("Hedefin gerçek harcamana göre ayarlandı: ~\(Fmt.int(est.tdee)) kcal/gün", systemImage: "wand.and.stars")
                    .formaFont(.caption, Theme.supplement)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle(padding: 18)
    }

    @ViewBuilder private var proteinTip: some View {
        let remaining = model.targets.proteinG - model.todayMacros.protein
        let hour = Calendar.forma.component(.hour, from: model.now)
        if remaining > 20 && hour >= 14 {
            let per = NutritionEngine.perMealProtein(weightKg: model.latestWeight)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill").foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Proteine \(Fmt.int(remaining)) g kaldı").formaFont(.bodyMedium)
                    Text("Öğün başına ~\(Fmt.int(per)) g iyi bir hedef. Örn. 200 g süzme yoğurt + 1 ölçek whey ≈ 44 g, 150 g tavuk göğsü ≈ 46 g, 3 yumurta + 60 g lor ≈ 26 g.")
                        .formaFont(.caption, Theme.textSecondary)
                }
            }
            .cardStyle(background: Theme.gold.opacity(0.08))
        }
    }

    private func mealSection(_ meal: MealType?, logs: [FoodLog]? = nil) -> some View {
        let items = logs ?? model.todayFoodLogs.filter { $0.meal == meal }
        let total = items.reduce(Macros.zero) { $0 + $1.macros }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: meal?.symbol ?? "ellipsis.circle").foregroundStyle(Theme.lime).frame(width: 22)
                Text(meal?.displayName ?? "Diğer").formaFont(.headline)
                Spacer()
                if total.kcal > 0 {
                    Text("\(Fmt.int(total.kcal)) kcal · \(Fmt.int(total.protein)) g P").formaFont(.caption, Theme.textSecondary)
                }
                if let meal {
                    Button { addMeal = meal } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.onLime)
                            .frame(width: 30, height: 30).background(Theme.lime, in: Circle())
                    }
                    .accessibilityLabel("\(meal.displayName) öğününe ekle")
                    .accessibilityIdentifier("meal.add.\(meal.rawValue)")
                }
            }
            if items.isEmpty {
                if let meal {
                    Button { addMeal = meal } label: {
                        Text("Ekle").formaFont(.callout, Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(items) { log in
                    Button { editLog = log } label: { FoodLogRow(log: log) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { model.deleteFoodLog(log.id) } label: { Label("Sil", systemImage: "trash") }
                        }
                }
            }
        }
        .cardStyle()
    }

    private func quickTile(_ title: String, _ value: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(color).frame(width: 34, height: 34).background(color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).eyebrow()
                    Text(value).formaFont(.numberS)
                }
                Spacer(minLength: 0)
            }
            .cardStyle(padding: 12)
        }
        .buttonStyle(PressableStyle())
    }

    private var weekChart: some View {
        let cal = Calendar.forma
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: model.now) }
        let target = model.baseTargets
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Son 7 gün")
            Chart {
                ForEach(days, id: \.self) { d in
                    let m = model.macros(on: d)
                    BarMark(x: .value("Gün", d, unit: .day), y: .value("Protein", m.protein))
                        .foregroundStyle(m.protein >= target.proteinG * 0.9 ? Theme.lime : Theme.lime.opacity(0.4))
                        .cornerRadius(5)
                }
                RuleMark(y: .value("Hedef", target.proteinG))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.textTertiary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .frame(height: 150)
            Text("Protein (g) · kesikli çizgi hedef").formaFont(.caption, Theme.textTertiary)
        }
        .cardStyle()
    }
}

struct FoodLogRow: View {
    var log: FoodLog

    var body: some View {
        let m = log.macros
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.foodName).formaFont(.callout).lineLimit(1)
                Text(log.servingLabel ?? "\(Fmt.int(log.grams)) g").formaFont(.caption, Theme.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Fmt.int(m.kcal)) kcal").formaFont(.callout)
                Text("\(Fmt.int(m.protein)) g protein").formaFont(.caption, Theme.lime)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Hedefler

struct TargetsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var manual = false
    @State private var kcal: Double = 2200
    @State private var protein: Double = 130
    @State private var carbs: Double = 250
    @State private var fat: Double = 70
    @State private var water: Double = 2500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $manual) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hedefleri elle belirle").formaFont(.bodyMedium)
                        Text("Kapalıyken profilin, kilo trendin ve kayıtlarına göre otomatik hesaplanır.").formaFont(.caption, Theme.textSecondary)
                    }
                }
                .tint(Theme.lime)
                .cardStyle()

                if manual {
                    VStack(spacing: 14) {
                        NumberStepper(title: "Kalori", value: $kcal, step: 50, range: 1000...6000, unit: "kcal", format: { Fmt.int($0) })
                        NumberStepper(title: "Protein", value: $protein, step: 5, range: 40...350, unit: "g", format: { Fmt.int($0) })
                        NumberStepper(title: "Karbonhidrat", value: $carbs, step: 10, range: 0...800, unit: "g", format: { Fmt.int($0) })
                        NumberStepper(title: "Yağ", value: $fat, step: 5, range: 20...300, unit: "g", format: { Fmt.int($0) })
                        NumberStepper(title: "Su", value: $water, step: 250, range: 1000...6000, unit: "ml", format: { Fmt.int($0) })
                    }
                    .cardStyle()
                    Text("Makrolardan hesaplanan: \(Fmt.int(protein * 4 + carbs * 4 + fat * 9)) kcal").formaFont(.caption, Theme.textSecondary)
                } else {
                    explanation
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Günlük hedefler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") { save() }.foregroundStyle(Theme.lime)
            }
        }
        .onAppear {
            manual = model.settings.targetsAreManual
            let t = model.baseTargets
            kcal = t.kcal; protein = t.proteinG; carbs = t.carbsG; fat = t.fatG; water = t.waterMl
        }
    }

    private var explanation: some View {
        let p = model.profile
        let bmr = NutritionEngine.bmr(profile: p, weightKg: model.latestWeight)
        let tdee = NutritionEngine.formulaTDEE(profile: p, weightKg: model.latestWeight)
        let t = model.baseTargets
        return VStack(alignment: .leading, spacing: 10) {
            row("Bazal metabolizma (Mifflin–St Jeor)", "\(Fmt.int(bmr)) kcal")
            row("Günlük harcama (aktivite + antrenman)", "\(Fmt.int(tdee)) kcal")
            if let est = model.adaptiveEstimate {
                row("Kayıtlarından hesaplanan harcama", "\(Fmt.int(est.tdee)) kcal (güven %\(Int(est.confidence * 100)))")
            }
            row("Hedef (\(p.goal.displayName.lowercased(with: Locale(identifier: "tr_TR"))))", "\(Fmt.int(t.kcal)) kcal")
            row("Protein", "\(Fmt.int(t.proteinG)) g (\(Fmt.oneDecimal(t.proteinG / model.latestWeight)) g/kg)")
            row("Yağ (en az %25)", "\(Fmt.int(t.fatG)) g")
            row("Karbonhidrat (kalan)", "\(Fmt.int(t.carbsG)) g")
            row("Su", "\(Fmt.liters(t.waterMl)) L + antrenman günü ekstra")
            Text("Protein önerisi ISSN'in egzersiz yapanlar için 1,4–2,0 g/kg aralığına, kalori açığında kası korumak için biraz üstüne dayanır. Yağ kaybında haftada vücut ağırlığının yaklaşık %0,5–1'i hedeflenir.")
                .formaFont(.caption, Theme.textTertiary)
                .padding(.top, 6)
        }
        .cardStyle()
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).formaFont(.caption, Theme.textSecondary)
            Spacer()
            Text(v).formaFont(.callout).multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        model.updateSettings { s in
            s.targetsAreManual = manual
            if manual {
                s.manualTargets = DailyTargets(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat,
                                               fiberG: model.baseTargets.fiberG, waterMl: water, creatineG: model.baseTargets.creatineG)
            }
        }
        dismiss()
    }
}
