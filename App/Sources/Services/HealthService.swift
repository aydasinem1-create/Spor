import Foundation
import HealthKit
import FormaKit

/// Apple Sağlık bağlantısı. İzin yoksa veya HealthKit kullanılamıyorsa sessizce devre dışı kalır.
@MainActor
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantities: [HKQuantityTypeIdentifier] = [.bodyMass, .heartRateVariabilitySDNN, .restingHeartRate, .stepCount, .activeEnergyBurned, .heartRate]
        for q in quantities { if let t = HKObjectType.quantityType(forIdentifier: q) { set.insert(t) } }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        return set
    }

    private var writeTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        let quantities: [HKQuantityTypeIdentifier] = [.dietaryWater, .bodyMass, .dietaryEnergyConsumed, .dietaryProtein,
                                                      .dietaryCarbohydrates, .dietaryFatTotal, .dietaryCaffeine]
        for q in quantities { if let t = HKObjectType.quantityType(forIdentifier: q) { set.insert(t) } }
        return set
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: Okuma

    func refresh(into model: AppModel) async {
        guard isAvailable, model.settings.healthKitEnabled else { return }
        var snap = model.health
        let now = Date()
        let cal = Calendar.forma

        snap.sleepHours = await lastNightSleepHours()
        let hrv = await dailyValues(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 31, option: .discreteAverage)
        snap.hrv = hrv.last.flatMap { cal.isDateInToday($0.0) || cal.isDateInYesterday($0.0) ? $0.1 : nil }
        snap.hrvBaseline = hrv.dropLast().map(\.1)
        let rhr = await dailyValues(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 31, option: .discreteAverage)
        snap.restingHR = rhr.last.flatMap { cal.isDateInToday($0.0) ? $0.1 : nil }
        snap.restingHRBaseline = rhr.dropLast().map(\.1)
        snap.steps = await dailyValues(.stepCount, unit: .count(), days: 1, option: .cumulativeSum).last?.1
        snap.activeEnergy = await dailyValues(.activeEnergyBurned, unit: .kilocalorie(), days: 1, option: .cumulativeSum).last?.1
        snap.weights = await weights(days: 90)
        snap.activities = await externalWorkouts(days: 10)
        snap.lastUpdated = now
        model.health = snap
    }

    private func lastNightSleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.forma
        let end = Date()
        // Dün 18:00'den bugüne
        let start = cal.date(byAdding: .hour, value: -6, to: cal.startOfDay(for: end)) ?? end.addingTimeInterval(-86_400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        let asleepValues: Set<Int> = [HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                      HKCategoryValueSleepAnalysis.asleepREM.rawValue, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
        let asleep = samples.filter { asleepValues.contains($0.value) }
        guard !asleep.isEmpty else { return nil }
        // Örtüşen kayıtları (saat + telefon) birleştir
        let intervals = asleep.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var current = intervals[0]
        for iv in intervals.dropFirst() {
            if iv.0 <= current.1 {
                current.1 = max(current.1, iv.1)
            } else {
                total += current.1.timeIntervalSince(current.0)
                current = iv
            }
        }
        total += current.1.timeIntervalSince(current.0)
        return total / 3600
    }

    private func dailyValues(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, option: HKStatisticsOptions) async -> [(Date, Double)] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        let cal = Calendar.forma
        let end = Date()
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: end)) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: option,
                                                anchorDate: cal.startOfDay(for: start), intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, collection, _ in
                var out: [(Date, Double)] = []
                collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let quantity = option.contains(.cumulativeSum) ? stat.sumQuantity() : stat.averageQuantity()
                    if let quantity { out.append((stat.startDate, quantity.doubleValue(for: unit))) }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    private func weights(days: Int) async -> [WeightPoint] {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let start = Date().addingTimeInterval(-Double(days) * 86_400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 500,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, results, _ in
                let pts = (results as? [HKQuantitySample] ?? [])
                    .filter { $0.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier }
                    .map { WeightPoint(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
                cont.resume(returning: pts)
            }
            store.execute(q)
        }
    }

    private func externalWorkouts(days: Int) async -> [RecoveryEngine.ExternalActivity] {
        let start = Date().addingTimeInterval(-Double(days) * 86_400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 100, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return workouts.compactMap { w in
            // Forma'nın kendi kaydettiği antrenmanlar zaten hesapta
            guard w.sourceRevision.source.bundleIdentifier.hasPrefix(Bundle.main.bundleIdentifier ?? "-") == false else { return nil }
            let kind: RecoveryEngine.ExternalActivity.Kind
            switch w.workoutActivityType {
            case .running: kind = .running
            case .cycling: kind = .cycling
            case .walking, .hiking: kind = .walking
            case .swimming: kind = .swimming
            case .rowing: kind = .rowing
            case .highIntensityIntervalTraining, .crossTraining, .mixedCardio: kind = .hiit
            default: return nil
            }
            return RecoveryEngine.ExternalActivity(kind: kind, start: w.startDate, minutes: w.duration / 60)
        }
    }

    // MARK: Yazma

    private func save(_ id: HKQuantityTypeIdentifier, value: Double, unit: HKUnit, date: Date, enabled: Bool) {
        guard enabled, isAvailable, value > 0, let type = HKObjectType.quantityType(forIdentifier: id),
              store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value), start: date, end: date)
        store.save(sample) { _, _ in }
    }

    func saveWater(ml: Double, date: Date, enabled: Bool) {
        save(.dietaryWater, value: ml, unit: .literUnit(with: .milli), date: date, enabled: enabled)
    }

    func saveWeight(kg: Double, date: Date, enabled: Bool) {
        save(.bodyMass, value: kg, unit: .gramUnit(with: .kilo), date: date, enabled: enabled)
    }

    func saveFood(_ m: Macros, name: String, date: Date, enabled: Bool) {
        save(.dietaryEnergyConsumed, value: m.kcal, unit: .kilocalorie(), date: date, enabled: enabled)
        save(.dietaryProtein, value: m.protein, unit: .gram(), date: date, enabled: enabled)
        save(.dietaryCarbohydrates, value: m.carbs, unit: .gram(), date: date, enabled: enabled)
        save(.dietaryFatTotal, value: m.fat, unit: .gram(), date: date, enabled: enabled)
    }

    func saveWorkout(_ session: WorkoutSession, enabled: Bool) {
        guard enabled, isAvailable, !session.savedToHealthByWatch, let end = session.endedAt,
              store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        builder.beginCollection(withStart: session.startedAt) { ok, _ in
            guard ok else { return }
            var samples: [HKSample] = []
            if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                // Direnç antrenmanı için kaba tahmin: dakikada ~5 kcal
                let kcal = session.activeEnergyKcal ?? (end.timeIntervalSince(session.startedAt) / 60 * 5)
                samples.append(HKQuantitySample(type: energyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                start: session.startedAt, end: end))
            }
            builder.add(samples) { _, _ in
                builder.endCollection(withEnd: end) { _, _ in
                    builder.finishWorkout { _, _ in }
                }
            }
        }
    }
}
