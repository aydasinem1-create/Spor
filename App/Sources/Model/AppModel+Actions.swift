import SwiftUI
import FormaKit

// MARK: - Kurulum ve profil

extension AppModel {

    func completeOnboarding(profile: UserProfile, planMode: PlanMode, supplements: [Supplement], settings: AppSettings) {
        update { d in
            d.profile = profile
            d.settings = settings
            d.settings.planMode = planMode
            d.settings.programDayIndex = 0
            d.supplements = supplements
            d.measurements.append(BodyMeasurement(date: Date(), weightKg: profile.weightKg))
        }
        NotificationService.shared.reschedule(model: self)
        writeWidgetSnapshot()
    }

    func updateProfile(_ change: (inout UserProfile) -> Void) {
        update { d in
            var p = d.profile ?? UserProfile()
            change(&p)
            d.profile = p
        }
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        update { change(&$0.settings) }
        NotificationService.shared.reschedule(model: self)
    }

    func setFeeling(_ value: Int) {
        update { $0.feelings[DayKey.key(Date())] = value }
    }

    func logSoreness(_ muscle: MuscleGroup, level: Int) {
        update { d in
            d.soreness.removeAll { $0.muscle == muscle && Calendar.forma.isDateInToday($0.date) }
            if level > 0 { d.soreness.append(RecoveryEngine.Soreness(muscle: muscle, date: Date(), level: level)) }
            let cutoff = Date().addingTimeInterval(-14 * 86_400)
            d.soreness.removeAll { $0.date < cutoff }
        }
    }

    func resetAllData() {
        update { $0 = FormaData() }
        NotificationService.shared.cancelAll()
        LiveActivityService.shared.end()
    }

    func replaceAllData(_ newData: FormaData) {
        update { $0 = newData }
        NotificationService.shared.reschedule(model: self)
    }
}

// MARK: - Su ve takviye

extension AppModel {

    func logWater(ml: Double, beverage: Beverage = .water, date: Date = Date()) {
        update { $0.waterLogs.append(WaterLog(date: date, ml: ml, beverage: beverage)) }
        Haptics.tap()
        HealthService.shared.saveWater(ml: ml, date: date, enabled: data.settings.healthKitEnabled)
        let total = todayWaterMl
        let target = targets.waterMl
        if total >= target && total - ml < target {
            show(Toast(symbol: "drop.fill", title: "Su hedefi tamam!", subtitle: "\(Fmt.liters(total)) L içtin", tint: Theme.water))
            Haptics.success()
        }
        NotificationService.shared.rescheduleWater(model: self)
    }

    func deleteWater(_ id: UUID) {
        update { $0.waterLogs.removeAll { $0.id == id } }
    }

    func take(_ s: Supplement, amount: Double? = nil, date: Date = Date()) {
        update { $0.supplementLogs.append(SupplementLog(supplementID: s.id, date: date, amount: amount ?? s.dose)) }
        Haptics.success()
        if s.kind == .creatine {
            let streak = creatineStreak
            show(Toast(symbol: "bolt.fill", title: "Kreatin alındı", subtitle: streak > 1 ? "\(streak) günlük seri" : "Seri başladı", tint: Theme.supplement))
        }
        NotificationService.shared.rescheduleSupplements(model: self)
    }

    func untake(_ s: Supplement) {
        update { d in
            if let last = d.supplementLogs.lastIndex(where: { $0.supplementID == s.id && Calendar.forma.isDateInToday($0.date) }) {
                d.supplementLogs.remove(at: last)
            }
        }
        NotificationService.shared.rescheduleSupplements(model: self)
    }

    func toggle(_ s: Supplement) {
        if isDone(s) { untake(s) } else { take(s) }
    }

    func saveSupplement(_ s: Supplement) {
        update { d in
            if let i = d.supplements.firstIndex(where: { $0.id == s.id }) { d.supplements[i] = s } else { d.supplements.append(s) }
        }
        NotificationService.shared.rescheduleSupplements(model: self)
    }

    func deleteSupplement(_ s: Supplement) {
        update { d in
            d.supplements.removeAll { $0.id == s.id }
        }
        NotificationService.shared.rescheduleSupplements(model: self)
    }
}

// MARK: - Beslenme

extension AppModel {

    func allFoods() -> [Food] { data.customFoods + FoodDatabase.all }

    func food(_ id: String) -> Food? {
        data.customFoods.first { $0.id == id } ?? FoodDatabase.food(id)
    }

    var recentFoods: [Food] { data.recentFoodIDs.compactMap(food) }
    var favoriteFoods: [Food] { data.favoriteFoodIDs.compactMap(food) }

    func logFood(_ food: Food, grams: Double, meal: MealType, servingLabel: String? = nil, date: Date = Date()) {
        update { d in
            if case .openFoodFacts = food.source, !d.customFoods.contains(where: { $0.id == food.id }) {
                d.customFoods.append(food)
            }
            d.foodLogs.append(FoodLog(date: date, meal: meal, food: food, grams: grams, servingLabel: servingLabel))
            d.recentFoodIDs.removeAll { $0 == food.id }
            d.recentFoodIDs.insert(food.id, at: 0)
            if d.recentFoodIDs.count > 30 { d.recentFoodIDs.removeLast(d.recentFoodIDs.count - 30) }
        }
        Haptics.tap()
        HealthService.shared.saveFood(food.macros(grams: grams), name: food.name, date: date, enabled: data.settings.healthKitEnabled)
        let p = todayMacros.protein, target = targets.proteinG
        if p >= target && p - food.macros(grams: grams).protein < target {
            show(Toast(symbol: "fork.knife", title: "Protein hedefi tamam!", subtitle: "\(Fmt.int(p)) g", tint: Theme.lime))
        }
    }

    func updateFoodLog(_ id: UUID, grams: Double, meal: MealType) {
        update { d in
            guard let i = d.foodLogs.firstIndex(where: { $0.id == id }) else { return }
            d.foodLogs[i].grams = grams
            d.foodLogs[i].meal = meal
        }
    }

    func deleteFoodLog(_ id: UUID) {
        update { $0.foodLogs.removeAll { $0.id == id } }
    }

    /// Dünkü bir öğünü bugüne kopyala.
    func copyMeal(from day: Date, meal: MealType, to target: MealType) {
        let key = DayKey.key(day)
        let logs = data.foodLogs.filter { DayKey.key($0.date) == key && $0.meal == meal }
        update { d in
            for l in logs {
                var copy = l
                copy.id = UUID()
                copy.date = Date()
                copy.meal = target
                d.foodLogs.append(copy)
            }
        }
    }

    func saveCustomFood(_ food: Food) {
        update { d in
            if let i = d.customFoods.firstIndex(where: { $0.id == food.id }) { d.customFoods[i] = food } else { d.customFoods.append(food) }
        }
    }

    func toggleFavorite(_ food: Food) {
        update { d in
            if d.favoriteFoodIDs.contains(food.id) { d.favoriteFoodIDs.removeAll { $0 == food.id } } else { d.favoriteFoodIDs.insert(food.id, at: 0) }
        }
    }

    func isFavorite(_ food: Food) -> Bool { data.favoriteFoodIDs.contains(food.id) }
}

// MARK: - Vücut

extension AppModel {

    func addMeasurement(_ m: BodyMeasurement) {
        update { $0.measurements.append(m) }
        if let w = m.weightKg {
            HealthService.shared.saveWeight(kg: w, date: m.date, enabled: data.settings.healthKitEnabled)
            if Calendar.forma.isDateInToday(m.date) { updateProfile { $0.weightKg = w } }
        }
    }

    func deleteMeasurement(_ id: UUID) {
        update { $0.measurements.removeAll { $0.id == id } }
    }

    func addPhoto(_ image: UIImage, pose: PhotoPose) {
        guard let fileName = PhotoStore.save(image) else { return }
        update { $0.photos.append(ProgressPhoto(pose: pose, fileName: fileName, weightKg: latestWeight)) }
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        PhotoStore.delete(photo.fileName)
        update { $0.photos.removeAll { $0.id == photo.id } }
    }
}

enum PhotoStore {
    static var directory: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
