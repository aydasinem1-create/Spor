import AppIntents

/// "Hey Siri, Forma ile su ekle" gibi kısayollar.
struct FormaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(),
                    phrases: ["\(.applicationName) ile su ekle", "\(.applicationName) su içtim", "Log water in \(.applicationName)"],
                    shortTitle: "Su ekle", systemImageName: "drop.fill")
        AppShortcut(intent: TakeCreatineIntent(),
                    phrases: ["\(.applicationName) kreatinimi aldım", "\(.applicationName) kreatin aldım", "Took creatine in \(.applicationName)"],
                    shortTitle: "Kreatin aldım", systemImageName: "bolt.fill")
        AppShortcut(intent: StartWorkoutIntent(),
                    phrases: ["\(.applicationName) antrenmana başla", "\(.applicationName) ile antrenman başlat", "Start workout in \(.applicationName)"],
                    shortTitle: "Antrenmana başla", systemImageName: "figure.strengthtraining.traditional")
    }
}
