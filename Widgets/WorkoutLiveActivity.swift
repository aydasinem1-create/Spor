import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import FormaKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenWorkoutView(context: context)
                .activityBackgroundTint(WTheme.bg)
                .activitySystemActionForegroundColor(WTheme.lime)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.exerciseName).font(WTheme.body(13, "SemiBold")).foregroundStyle(WTheme.text).lineLimit(1)
                        Text(s.setCount > 0 ? "Set \(s.setIndex)/\(s.setCount)" : "Tamamlandı").font(WTheme.body(11)).foregroundStyle(WTheme.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = s.restEndsAt, end > Date() {
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(WTheme.display(22)).foregroundStyle(WTheme.water)
                            .monospacedDigit().multilineTextAlignment(.trailing).frame(width: 80)
                    } else {
                        Text(targetText(s)).font(WTheme.display(18)).foregroundStyle(WTheme.lime).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if s.restEndsAt.map({ $0 > Date() }) ?? false {
                        HStack(spacing: 8) {
                            Button(intent: AdjustRestIntent(seconds: -15)) { Text("−15 sn").frame(maxWidth: .infinity) }
                                .tint(WTheme.track)
                            Button(intent: AdjustRestIntent(seconds: 15)) { Text("+15 sn").frame(maxWidth: .infinity) }
                                .tint(WTheme.track)
                            Button(intent: SkipRestIntent()) { Text("Atla").frame(maxWidth: .infinity) }
                                .tint(WTheme.water)
                        }
                        .font(WTheme.body(13, "SemiBold"))
                        .buttonStyle(.borderedProminent)
                    } else if s.setCount > 0 {
                        Button(intent: CompleteSetIntent()) {
                            Label("Seti tamamla · \(targetText(s))", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }
                        .font(WTheme.body(14, "SemiBold"))
                        .tint(WTheme.lime)
                        .foregroundStyle(WTheme.onLime)
                        .buttonStyle(.borderedProminent)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(WTheme.lime)
            } compactTrailing: {
                if let end = s.restEndsAt, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit().frame(width: 44).foregroundStyle(WTheme.water)
                } else {
                    Text("\(s.completedSets)/\(s.totalSets)").foregroundStyle(WTheme.lime).monospacedDigit()
                }
            } minimal: {
                if let end = s.restEndsAt, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true).monospacedDigit().foregroundStyle(WTheme.water).frame(width: 36)
                } else {
                    Image(systemName: "dumbbell.fill").foregroundStyle(WTheme.lime)
                }
            }
            .keylineTint(WTheme.lime)
        }
    }
}

private func targetText(_ s: WorkoutActivityAttributes.ContentState) -> String {
    if s.isTimed { return "\(s.targetReps) sn" }
    if s.targetWeight > 0 {
        let w = s.targetWeight.formattedKg
        return "\(w) kg × \(s.targetReps)"
    }
    return "\(s.targetReps) tekrar"
}

struct LockScreenWorkoutView: View {
    var context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let s = context.state
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(WTheme.lime)
                Text(context.attributes.title).font(WTheme.body(13, "SemiBold")).foregroundStyle(WTheme.secondary)
                Spacer()
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(WTheme.body(13, "SemiBold")).foregroundStyle(WTheme.secondary).monospacedDigit()
                    .multilineTextAlignment(.trailing).frame(width: 70)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.exerciseName).font(WTheme.display(18)).foregroundStyle(WTheme.text).lineLimit(1)
                    Text(s.setCount > 0 ? "Set \(s.setIndex)/\(s.setCount) · \(targetText(s))" : "Tüm setler bitti")
                        .font(WTheme.body(13)).foregroundStyle(WTheme.secondary)
                    if let next = s.nextExerciseName { Text("Sonra: \(next)").font(WTheme.body(11)).foregroundStyle(WTheme.secondary.opacity(0.8)) }
                }
                Spacer()
                if let end = s.restEndsAt, end > Date() {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Dinlenme").font(WTheme.body(11)).foregroundStyle(WTheme.water)
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(WTheme.display(30)).foregroundStyle(WTheme.water).monospacedDigit()
                            .multilineTextAlignment(.trailing).frame(width: 96)
                    }
                }
            }
            if let end = s.restEndsAt, end > Date() {
                HStack(spacing: 8) {
                    Button(intent: AdjustRestIntent(seconds: 15)) { Text("+15 sn").frame(maxWidth: .infinity) }.tint(WTheme.track)
                    Button(intent: SkipRestIntent()) { Text("Atla").frame(maxWidth: .infinity) }.tint(WTheme.water)
                }
                .font(WTheme.body(13, "SemiBold"))
                .buttonStyle(.borderedProminent)
            } else if s.setCount > 0 {
                Button(intent: CompleteSetIntent()) {
                    Label("Seti tamamla", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .font(WTheme.body(14, "SemiBold"))
                .tint(WTheme.lime)
                .foregroundStyle(WTheme.onLime)
                .buttonStyle(.borderedProminent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WTheme.track)
                    Capsule().fill(WTheme.lime).frame(width: geo.size.width * (s.totalSets > 0 ? Double(s.completedSets) / Double(s.totalSets) : 0))
                }
            }
            .frame(height: 5)
        }
        .padding(16)
    }
}
