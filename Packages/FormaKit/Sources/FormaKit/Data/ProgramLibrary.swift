import Foundation

/// Hazır başlangıç programları. Yeni başlayanlar için haftada 2–3 gün, her kasa 1–3 set, 8–12 tekrar (ACSM).
/// Belirli bir süre sonra uygulama toparlanmaya göre otomatik plana geçmeyi önerir.
public enum ProgramLibrary {

    public static let all: [WorkoutProgram] = [beginnerFullBody, machineStarter, homeDumbbell, upperLower, pushPullLegs]

    public static func program(_ id: String) -> WorkoutProgram? { all.first { $0.id == id } }

    public static let beginnerFullBody = WorkoutProgram(
        id: "beginner-full-body",
        name: "Başlangıç Tam Vücut",
        summary: "Haftada 3 gün, A ve B günleri dönüşümlü. Her antrenmanda tüm büyük kas grupları.",
        level: .beginner, daysPerWeek: 3, weeks: 8,
        requiredEquipment: [.machine, .cable, .dumbbell, .bench],
        days: [
            ProgramDay(id: "fb-a", name: "Tam Vücut A", focus: "Bacak · Göğüs · Sırt", slots: [
                ExerciseSlot("leg-press", sets: 3, reps: 10...12, alternatives: ["goblet-squat", "barbell-squat"]),
                ExerciseSlot("machine-chest-press", sets: 3, reps: 10...12, alternatives: ["dumbbell-bench-press", "push-up"]),
                ExerciseSlot("lat-pulldown", sets: 3, reps: 10...12, alternatives: ["assisted-pull-up", "one-arm-dumbbell-row"]),
                ExerciseSlot("machine-shoulder-press", sets: 2, reps: 10...12, alternatives: ["dumbbell-shoulder-press"]),
                ExerciseSlot("lying-leg-curl", sets: 2, reps: 12...15, alternatives: ["seated-leg-curl", "dumbbell-rdl"]),
                ExerciseSlot("plank", sets: 2, reps: 30...45)
            ]),
            ProgramDay(id: "fb-b", name: "Tam Vücut B", focus: "Kalça · Sırt · Omuz · Kol", slots: [
                ExerciseSlot("goblet-squat", sets: 3, reps: 10...12, alternatives: ["leg-press"]),
                ExerciseSlot("seated-cable-row", sets: 3, reps: 10...12, alternatives: ["machine-row", "one-arm-dumbbell-row"]),
                ExerciseSlot("incline-dumbbell-press", sets: 3, reps: 10...12, alternatives: ["machine-chest-press", "push-up"]),
                ExerciseSlot("dumbbell-rdl", sets: 3, reps: 10...12, alternatives: ["romanian-deadlift", "back-extension"]),
                ExerciseSlot("lateral-raise", sets: 2, reps: 12...15, alternatives: ["cable-lateral-raise"]),
                ExerciseSlot("triceps-pushdown", sets: 2, reps: 12...15, alternatives: ["overhead-triceps-extension", "bench-dip"]),
                ExerciseSlot("dumbbell-curl", sets: 2, reps: 12...15, alternatives: ["cable-curl", "hammer-curl"])
            ])
        ],
        notes: ["İlk 2 hafta ağırlığı rahat tut: her sette 2–3 tekrar daha yapabilecek gibi bitir.",
                "Tekrar aralığının üstüne tüm setlerde ulaşınca uygulama ağırlık artırmayı önerir.",
                "Antrenman günleri arasında en az 1 gün dinlen (örn. Pzt-Çar-Cum)."]
    )

    public static let machineStarter = WorkoutProgram(
        id: "machine-starter",
        name: "Makine ile Başlangıç",
        summary: "Hareketleri öğrenmesi en kolay makinelerle haftada 3 gün tam vücut.",
        level: .beginner, daysPerWeek: 3, weeks: 6,
        requiredEquipment: [.machine, .cable],
        days: [
            ProgramDay(id: "ms-a", name: "Makine A", focus: "Tam vücut", slots: [
                ExerciseSlot("leg-press", sets: 3, reps: 10...12),
                ExerciseSlot("machine-chest-press", sets: 3, reps: 10...12),
                ExerciseSlot("machine-row", sets: 3, reps: 10...12, alternatives: ["seated-cable-row"]),
                ExerciseSlot("leg-extension", sets: 2, reps: 12...15),
                ExerciseSlot("lying-leg-curl", sets: 2, reps: 12...15, alternatives: ["seated-leg-curl"]),
                ExerciseSlot("ab-crunch-machine", sets: 2, reps: 12...15, alternatives: ["cable-crunch", "crunch"])
            ]),
            ProgramDay(id: "ms-b", name: "Makine B", focus: "Tam vücut", slots: [
                ExerciseSlot("hack-squat", sets: 3, reps: 10...12, alternatives: ["leg-press"]),
                ExerciseSlot("lat-pulldown", sets: 3, reps: 10...12),
                ExerciseSlot("machine-shoulder-press", sets: 3, reps: 10...12),
                ExerciseSlot("pec-deck", sets: 2, reps: 12...15),
                ExerciseSlot("seated-leg-curl", sets: 2, reps: 12...15, alternatives: ["lying-leg-curl"]),
                ExerciseSlot("triceps-pushdown", sets: 2, reps: 12...15),
                ExerciseSlot("cable-curl", sets: 2, reps: 12...15)
            ])
        ],
        notes: ["Her makinede koltuk ve pedleri ayarlamak için ilk gün 5 dakika ayır; ayarları hareket notuna yaz."]
    )

    public static let homeDumbbell = WorkoutProgram(
        id: "home-dumbbell",
        name: "Evde Dambıl",
        summary: "Bir çift dambıl ve sehpa ile haftada 3 gün tam vücut.",
        level: .beginner, daysPerWeek: 3, weeks: 8,
        requiredEquipment: [.dumbbell, .bench, .bodyweight],
        days: [
            ProgramDay(id: "hd-a", name: "Ev A", focus: "Tam vücut", slots: [
                ExerciseSlot("goblet-squat", sets: 3, reps: 10...15),
                ExerciseSlot("dumbbell-bench-press", sets: 3, reps: 8...12, alternatives: ["push-up"]),
                ExerciseSlot("one-arm-dumbbell-row", sets: 3, reps: 10...12),
                ExerciseSlot("dumbbell-rdl", sets: 3, reps: 10...12),
                ExerciseSlot("lateral-raise", sets: 2, reps: 12...20),
                ExerciseSlot("plank", sets: 2, reps: 30...60)
            ]),
            ProgramDay(id: "hd-b", name: "Ev B", focus: "Tam vücut", slots: [
                ExerciseSlot("bulgarian-split-squat", sets: 3, reps: 8...12, alternatives: ["walking-lunge"]),
                ExerciseSlot("push-up", sets: 3, reps: 8...15),
                ExerciseSlot("dumbbell-shoulder-press", sets: 3, reps: 8...12),
                ExerciseSlot("glute-bridge", sets: 3, reps: 12...20),
                ExerciseSlot("hammer-curl", sets: 2, reps: 10...15),
                ExerciseSlot("overhead-triceps-extension", sets: 2, reps: 10...15),
                ExerciseSlot("dead-bug", sets: 2, reps: 8...12)
            ])
        ]
    )

    public static let upperLower = WorkoutProgram(
        id: "upper-lower",
        name: "Üst / Alt",
        summary: "Haftada 4 gün. Her kas haftada 2 kez, biraz daha yüksek hacim. 2–3 aydan sonra iyi bir sonraki adım.",
        level: .intermediate, daysPerWeek: 4, weeks: 8,
        requiredEquipment: [.barbell, .dumbbell, .machine, .cable, .bench],
        days: [
            ProgramDay(id: "ul-u1", name: "Üst A", focus: "Göğüs · Sırt · Omuz · Kol", slots: [
                ExerciseSlot("barbell-bench-press", sets: 3, reps: 6...10, alternatives: ["dumbbell-bench-press", "machine-chest-press"]),
                ExerciseSlot("barbell-row", sets: 3, reps: 8...10, alternatives: ["seated-cable-row", "machine-row"]),
                ExerciseSlot("dumbbell-shoulder-press", sets: 3, reps: 8...12, alternatives: ["machine-shoulder-press"]),
                ExerciseSlot("lat-pulldown", sets: 3, reps: 10...12),
                ExerciseSlot("triceps-pushdown", sets: 2, reps: 10...15),
                ExerciseSlot("dumbbell-curl", sets: 2, reps: 10...15)
            ]),
            ProgramDay(id: "ul-l1", name: "Alt A", focus: "Ön bacak · Kalça", slots: [
                ExerciseSlot("barbell-squat", sets: 3, reps: 6...8, alternatives: ["hack-squat", "leg-press"]),
                ExerciseSlot("romanian-deadlift", sets: 3, reps: 8...10, alternatives: ["dumbbell-rdl"]),
                ExerciseSlot("leg-press", sets: 2, reps: 10...12),
                ExerciseSlot("lying-leg-curl", sets: 3, reps: 10...15, alternatives: ["seated-leg-curl"]),
                ExerciseSlot("standing-calf-raise", sets: 3, reps: 10...15, alternatives: ["leg-press-calf"]),
                ExerciseSlot("cable-crunch", sets: 2, reps: 10...15, alternatives: ["crunch"])
            ]),
            ProgramDay(id: "ul-u2", name: "Üst B", focus: "Sırt · Göğüs · Omuz", slots: [
                ExerciseSlot("pull-up", sets: 3, reps: 6...10, alternatives: ["assisted-pull-up", "lat-pulldown"]),
                ExerciseSlot("incline-dumbbell-press", sets: 3, reps: 8...12),
                ExerciseSlot("seated-cable-row", sets: 3, reps: 10...12),
                ExerciseSlot("lateral-raise", sets: 3, reps: 12...20),
                ExerciseSlot("face-pull", sets: 2, reps: 12...15, alternatives: ["reverse-pec-deck"]),
                ExerciseSlot("hammer-curl", sets: 2, reps: 10...12),
                ExerciseSlot("overhead-triceps-extension", sets: 2, reps: 10...15)
            ]),
            ProgramDay(id: "ul-l2", name: "Alt B", focus: "Arka bacak · Kalça", slots: [
                ExerciseSlot("deadlift", sets: 3, reps: 3...6, alternatives: ["romanian-deadlift", "dumbbell-rdl"]),
                ExerciseSlot("bulgarian-split-squat", sets: 3, reps: 8...12, alternatives: ["walking-lunge"]),
                ExerciseSlot("hip-thrust", sets: 3, reps: 8...12, alternatives: ["glute-bridge"]),
                ExerciseSlot("leg-extension", sets: 2, reps: 12...15),
                ExerciseSlot("seated-calf-raise", sets: 3, reps: 12...20, alternatives: ["standing-calf-raise"]),
                ExerciseSlot("hanging-leg-raise", sets: 2, reps: 8...15, alternatives: ["dead-bug"])
            ])
        ]
    )

    public static let pushPullLegs = WorkoutProgram(
        id: "push-pull-legs",
        name: "İtme / Çekme / Bacak",
        summary: "3 gün (veya iki tur yaparak 6 gün). İtme, çekme ve bacak günleri ayrı.",
        level: .intermediate, daysPerWeek: 3, weeks: 8,
        requiredEquipment: [.barbell, .dumbbell, .machine, .cable, .bench],
        days: [
            ProgramDay(id: "ppl-push", name: "İtme", focus: "Göğüs · Omuz · Arka kol", slots: [
                ExerciseSlot("barbell-bench-press", sets: 3, reps: 6...10, alternatives: ["dumbbell-bench-press", "machine-chest-press"]),
                ExerciseSlot("incline-dumbbell-press", sets: 3, reps: 8...12),
                ExerciseSlot("machine-shoulder-press", sets: 3, reps: 8...12, alternatives: ["dumbbell-shoulder-press"]),
                ExerciseSlot("lateral-raise", sets: 3, reps: 12...20),
                ExerciseSlot("pec-deck", sets: 2, reps: 12...15, alternatives: ["cable-crossover", "dumbbell-fly"]),
                ExerciseSlot("rope-pushdown", sets: 3, reps: 10...15, alternatives: ["triceps-pushdown"])
            ]),
            ProgramDay(id: "ppl-pull", name: "Çekme", focus: "Sırt · Arka omuz · Pazu", slots: [
                ExerciseSlot("lat-pulldown", sets: 3, reps: 8...12, alternatives: ["pull-up"]),
                ExerciseSlot("barbell-row", sets: 3, reps: 8...10, alternatives: ["machine-row"]),
                ExerciseSlot("seated-cable-row", sets: 2, reps: 10...12),
                ExerciseSlot("face-pull", sets: 3, reps: 12...15, alternatives: ["reverse-pec-deck"]),
                ExerciseSlot("barbell-curl", sets: 3, reps: 8...12, alternatives: ["dumbbell-curl"]),
                ExerciseSlot("hammer-curl", sets: 2, reps: 10...15)
            ]),
            ProgramDay(id: "ppl-legs", name: "Bacak", focus: "Ön/arka bacak · Kalça · Baldır", slots: [
                ExerciseSlot("barbell-squat", sets: 3, reps: 6...8, alternatives: ["hack-squat", "leg-press"]),
                ExerciseSlot("romanian-deadlift", sets: 3, reps: 8...10, alternatives: ["dumbbell-rdl"]),
                ExerciseSlot("leg-press", sets: 3, reps: 10...12),
                ExerciseSlot("lying-leg-curl", sets: 3, reps: 10...15),
                ExerciseSlot("standing-calf-raise", sets: 4, reps: 10...15),
                ExerciseSlot("plank", sets: 2, reps: 30...60)
            ])
        ]
    )

    /// Profile göre önerilen ilk program.
    public static func recommended(for profile: UserProfile) -> WorkoutProgram {
        let eq = profile.equipment
        let gymLike = eq.contains(.machine) && eq.contains(.cable)
        if profile.experience == .beginner {
            if !gymLike { return homeDumbbell }
            return eq.contains(.dumbbell) ? beginnerFullBody : machineStarter
        }
        if profile.trainingDaysPerWeek >= 4 && eq.contains(.barbell) { return upperLower }
        if eq.contains(.barbell) { return pushPullLegs }
        return gymLike ? beginnerFullBody : homeDumbbell
    }
}
