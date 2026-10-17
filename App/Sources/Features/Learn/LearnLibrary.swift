import SwiftUI

/// Uygulamanın dayandığı bilgilerin özeti. Her makale kaynak gösterir.
struct Article: Identifiable, Hashable {
    struct Block: Hashable {
        enum Kind: Hashable { case paragraph, heading, bullet, callout, number(String, String) }
        var kind: Kind
        var text: String
    }

    var id: String
    var title: String
    var subtitle: String
    var symbol: String
    var colorHex: UInt32
    var minutes: Int
    var blocks: [Block]
    var sources: [(String, String)]

    static func == (l: Article, r: Article) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    var color: Color { Color(hex: colorHex) }
}

private func p(_ t: String) -> Article.Block { .init(kind: .paragraph, text: t) }
private func h(_ t: String) -> Article.Block { .init(kind: .heading, text: t) }
private func b(_ t: String) -> Article.Block { .init(kind: .bullet, text: t) }
private func c(_ t: String) -> Article.Block { .init(kind: .callout, text: t) }
private func n(_ value: String, _ label: String) -> Article.Block { .init(kind: .number(value, label), text: "") }

enum LearnLibrary {
    static func article(_ id: String) -> Article? { all.first { $0.id == id } }

    static let all: [Article] = [
        Article(id: "beginner", title: "Yeni başlayanlar için antrenman", subtitle: "Kaç gün, kaç set, kaç tekrar?", symbol: "figure.walk", colorHex: 0xC6F24E, minutes: 3, blocks: [
            n("2–3", "gün / hafta"), n("8–12", "tekrar"), n("1–3", "set"),
            p("Amerikan Spor Hekimliği Koleji (ACSM), daha önce düzenli ağırlık çalışmamış kişiler için haftada 2–3 gün, büyük kas gruplarını çalıştıran 8–12 tekrarlık setler öneriyor. Setler arası 1–2 dakika dinlenmek yeterli."),
            h("Neden makinelerle başlıyoruz?"),
            p("Makineler hareketin yolunu belirler; sen sadece itmeyi ve çekmeyi öğrenirsin. İlk haftalarda kuvvet artışının büyük kısmı sinir sisteminin hareketi öğrenmesinden gelir. Bu yüzden ağırlıktan önce form önemli."),
            h("Ne kadar zorlanmalıyım?"),
            p("Her seti, aynı formla 1–3 tekrar daha yapabileceğin bir noktada bitir. Buna \"yedekte kalan tekrar\" (RIR) denir. Tükenişe kadar gitmek gerekli değil ve toparlanmayı uzatır."),
            h("Ne zaman ağırlık artırmalı?"),
            p("Forma \"çift ilerleme\" kullanır: önce tekrar aralığının üst sınırına ulaşırsın (örn. 3 × 12), sonra ağırlık bir adım artar ve tekrar 10'a döner. ACSM, hedef tekrar art arda iki seansta 1–2 fazla yapılabildiğinde yükün %2–10 artırılmasını öneriyor."),
            c("İlk 2 hafta ağırlığı bilerek hafif tut. Kaslar hızlı uyum sağlar ama tendonlar daha yavaş güçlenir.")
        ], sources: [("ACSM Position Stand: Progression Models in Resistance Training for Healthy Adults (2009)", "https://pubmed.ncbi.nlm.nih.gov/19204579/")]),

        Article(id: "hypertrophy", title: "Kas nasıl büyür?", subtitle: "Hacim, sıklık ve aşamalı yüklenme", symbol: "figure.strengthtraining.traditional", colorHex: 0xC6F24E, minutes: 4, blocks: [
            n("10+", "set / kas / hafta"), n("2×", "haftada çalış"), n("0–3", "yedek tekrar"),
            p("Bir kasın haftada aldığı set sayısı arttıkça kas gelişimi de artar, ama getiri giderek azalır. Meta-analizler haftada kas başına 10 ve üzeri setin daha az sete göre belirgin şekilde daha fazla gelişim sağladığını gösteriyor."),
            p("Forma setleri \"kesirli\" sayar: bench press göğse 1 set, ön omuz ve arka kola yarım set yazar. Böylece arka kolun dolaylı olarak da çalıştığı hesaba katılır."),
            h("Tekrar sayısı ne kadar önemli?"),
            p("Setler tükenişe yakın yapıldığında kabaca 5 ile 30 tekrar arasında benzer kas gelişimi görülür. Ağır ve az tekrar daha çok kuvvet, hafif ve çok tekrar daha çok dayanıklılık getirir. Yeni başlayanlar için 8–15 tekrar hem güvenli hem etkili."),
            h("Sıklık"),
            p("Aynı kası haftada en az iki kez çalıştırmak, aynı toplam hacmi tek güne yığmaktan genellikle daha iyidir. Tam vücut ve üst/alt programları bu yüzden yeni başlayanlar için idealdir."),
            h("Bölgesel kas geliştirmek"),
            p("Belirli bir kasa daha fazla set vermek o kasın daha çok gelişmesini sağlar. Profilinde \"odak bölgeleri\" seçersen Forma o kaslara haftada birkaç set fazla ayırır.")
        ], sources: [("Schoenfeld ve ark. (2017) Dose-response relationship between weekly resistance training volume and increases in muscle mass", "https://pubmed.ncbi.nlm.nih.gov/27433992/"),
                     ("Remmert, Pelland ve ark. (2025) Is there too much of a good thing? Per-session volume meta-regressions", "https://sportrxiv.org/index.php/server/preprint/view/537")]),

        Article(id: "recovery-map", title: "Kas haritası nasıl hesaplanıyor?", subtitle: "Toparlanma tahmini ve sınırları", symbol: "figure.arms.open", colorHex: 0xFF9B4A, minutes: 3, blocks: [
            p("Hiçbir uygulama kaslarının ne kadar yorgun olduğunu doğrudan ölçemez. Forma, Fitbod gibi uygulamaların kullandığı yaklaşımla, antrenman kayıtlarından bir tahmin yapar."),
            b("Her tamamlanan set, ana kasa 1, yardımcı kaslara 0,5 birim yorgunluk ekler."),
            b("Sete ne kadar zorlandıysan (yedek tekrar azsa) yük o kadar büyür. Tükenişe kadar yapılan setler toparlanmayı 24–48 saat uzatabildiği için daha ağır sayılır."),
            b("Yorgunluk zamanla azalır: büyük kaslar (bacak, sırt, göğüs) yaklaşık 60–72 saatte, küçük kaslar (kol, omuz, karın) 36–48 saatte büyük ölçüde toparlanır."),
            b("Apple Sağlık'tan gelen koşu, bisiklet gibi antrenmanlar da bacak kaslarına yük olarak eklenir."),
            b("Kalan yük, deneyimine göre bir seansta kaldırabileceğin set sayısına bölünür ve yüzdeye çevrilir. %80 ve üstü \"hazır\" sayılır."),
            c("Kasında ağrı varsa haritada o bölgeye dokunup \"ağrı\" işaretle. Tahmin senin hissine göre düzeltilir. Vücudunun sinyali her zaman hesaptan önce gelir."),
            p("Bu yöntem bilimsel genel kurallara dayanan bir yaklaşımdır; kişiden kişiye fark olabilir. Uyku, stres ve beslenme de toparlanmayı etkiler; bunun için hazır olma skoruna bak.")
        ], sources: [("Morán-Navarro ve ark. (2017) Time course of recovery following resistance training leading or not to failure", "https://pubmed.ncbi.nlm.nih.gov/28965198/"),
                     ("Fitbod: Muscle Recovery", "https://help.fitbod.me/hc/en-us/articles/360006269014-Muscle-Recovery")]),

        Article(id: "protein", title: "Protein", subtitle: "Ne kadar, ne zaman, nereden?", symbol: "fork.knife", colorHex: 0xC6F24E, minutes: 3, blocks: [
            n("1,4–2,0", "g / kg / gün"), n("20–40", "g / öğün"), n("3–4", "saatte bir"),
            p("Uluslararası Spor Beslenmesi Derneği (ISSN), düzenli egzersiz yapanlar için günde vücut ağırlığının kilogramı başına 1,4–2,0 g protein öneriyor. Kalori açığındayken kası korumak için 2,3–3,1 g/kg'a kadar çıkmak faydalı olabilir."),
            p("Öğün başına yaklaşık 0,25 g/kg (çoğu kişi için 20–40 g) proteini gün içine yaymak kas protein sentezini daha iyi destekler. Uyumadan önce 30–40 g kazein (süzme yoğurt, lor) gece boyunca toparlanmaya yardımcı olabilir."),
            h("Pratik örnekler"),
            b("3 yumurta ≈ 19 g"),
            b("150 g tavuk göğsü ≈ 46 g"),
            b("200 g süzme yoğurt ≈ 20 g"),
            b("100 g lor ≈ 11 g"),
            b("1 kutu ton balığı ≈ 30 g"),
            b("1 ölçek whey ≈ 24 g"),
            c("Fazla kilolu biri için protein hedefini toplam kiloya göre hesaplamak gereğinden yüksek çıkar. Forma bu durumda boyuna göre bir referans kilo kullanır.")
        ], sources: [("ISSN Position Stand: protein and exercise (2017)", "https://pubmed.ncbi.nlm.nih.gov/28642676/")]),

        Article(id: "creatine", title: "Kreatin", subtitle: "En çok araştırılmış takviye", symbol: "bolt.fill", colorHex: 0xB9A6FF, minutes: 3, blocks: [
            n("3–5", "g / gün"), n("~4", "haftada doygunluk"), n("~1", "hafta (yükleme ile)"),
            p("Kreatin monohidrat, kısa ve yoğun eforlarda enerji üretimini destekleyerek antrenman kalitesini ve zamanla kuvvet ile kas kazanımını artırır. ISSN'e göre sağlıklı kişilerde önerilen dozlarda güvenlidir."),
            h("Nasıl kullanılır?"),
            b("Her gün 3–5 g. Antrenman olmayan günler de dahil."),
            b("Ne zaman aldığın pek önemli değil; her gün almak önemli."),
            b("İstersen ilk 5–7 gün günde ~0,3 g/kg'ı 4 doza bölerek \"yükleme\" yapabilirsin. Bu sadece doygunluğu hızlandırır; uzun vadede sonuç aynıdır."),
            b("Kas hücresine su çektiği için ilk haftalarda 1–2 kg artış normaldir; bu yağ değildir."),
            c("Böbrek hastalığın varsa, hamileysen veya düzenli ilaç kullanıyorsan başlamadan önce doktoruna danış."),
            p("Forma'daki doygunluk yüzdesi, kayıtlarına dayanan basit bir modeldir: günde 5 g ile ~3 haftada, 20 g yüklemeyle ~1 haftada doygunluğa ulaşır; bıraktığında 4–6 haftada başlangıca döner.")
        ], sources: [("ISSN Position Stand: safety and efficacy of creatine supplementation (2017)", "https://pubmed.ncbi.nlm.nih.gov/28615996/"),
                     ("ISSN Position Stand: creatine supplementation and exercise (2007)", "https://pmc.ncbi.nlm.nih.gov/articles/PMC2048496/")]),

        Article(id: "water", title: "Su ve sıvı", subtitle: "Ne kadar içmeli?", symbol: "drop.fill", colorHex: 0x5AB0FF, minutes: 2, blocks: [
            n("~30", "ml / kg"), n("+500", "ml / antrenman saati"), n("<%2", "kilo kaybı"),
            p("Avrupa Gıda Güvenliği Otoritesi (EFSA), yiyeceklerden gelen su dahil yetişkin erkekler için günde 2,5 L, kadınlar için 2,0 L toplam su öneriyor. Bunun yaklaşık %70–80'i içeceklerden gelir."),
            p("Forma günlük içecek hedefini kilonun ~30 katı ml olarak belirler, antrenman günü ve sıcak havada artırır. Terleme kişiden kişiye çok değiştiği için bu bir başlangıç noktasıdır."),
            h("Antrenmanda"),
            b("ACSM, egzersiz sırasında vücut ağırlığının %2'sinden fazlasını sıvı olarak kaybetmemeyi öneriyor."),
            b("Antrenmandan 2–4 saat önce kilo başına 5–7 ml su iç."),
            b("Açık sarı idrar iyi bir göstergedir."),
            c("Çay ve kahve de sıvı sayılır; ılımlı kafein vücudun su dengesini bozmaz.")
        ], sources: [("EFSA Scientific Opinion on Dietary Reference Values for water (2010)", "https://www.efsa.europa.eu/en/efsajournal/pub/1459"),
                     ("ACSM Position Stand: Exercise and fluid replacement (2007)", "https://pubmed.ncbi.nlm.nih.gov/17277604/")]),

        Article(id: "fatloss", title: "Yağ kaybı", subtitle: "Ve bölgesel incelme efsanesi", symbol: "flame.fill", colorHex: 0xFF9B4A, minutes: 3, blocks: [
            n("%0,5–1", "kilo / hafta"), n("2,2", "g/kg protein"), n("3+", "gün ağırlık"),
            p("Yağ kaybı için kalori açığı gerekir. Haftada vücut ağırlığının yaklaşık %0,5–1'i kadar kayıp, kas kaybını en aza indirirken sürdürülebilir bir hızdır."),
            p("Ağırlık antrenmanına devam etmek ve proteini yüksek tutmak, kaybedilen kilonun yağdan gelmesine yardımcı olur."),
            h("Bölgesel yağ yakmak mümkün mü?"),
            p("Hayır. 13 çalışmayı ve 1.100'den fazla kişiyi inceleyen 2021 tarihli bir meta-analiz, belirli bir bölgeyi çalıştırmanın o bölgedeki yağı azaltmadığını gösterdi. Yağ, kana karışıp tüm vücutta enerji olarak kullanılır."),
            c("Mekik karın kaslarını güçlendirir ama göbek yağını tek başına eritmez. Görünür karın kası için toplam yağ oranının düşmesi gerekir."),
            h("Kilo durursa"),
            p("Forma kayıtlarından gerçek harcamanı hesaplar (MacroFactor yaklaşımı). 2–3 hafta kilo değişmezse ve kayıtlar doğruysa hedefini biraz düşürmeyi önerir. Tek tek tartılara değil, trend çizgisine bak.")
        ], sources: [("Helms ve ark. (2014) Evidence-based recommendations for natural bodybuilding contest preparation", "https://pubmed.ncbi.nlm.nih.gov/24864135/"),
                     ("Sidney Üniversitesi (2023): Bölgesel incelme neden işe yaramaz", "https://www.sydney.edu.au/news-opinion/news/2023/11/07/spot-reduction--why-targeting-weight-loss-to-a-specific-area-is-.html")]),

        Article(id: "caffeine", title: "Kafein", subtitle: "Performans ve uyku dengesi", symbol: "cup.and.saucer.fill", colorHex: 0xFF6B5B, minutes: 2, blocks: [
            n("3–6", "mg / kg"), n("~60", "dk önce"), n("400", "mg / gün üst sınır"),
            p("ISSN'e göre 3–6 mg/kg kafein performansı tutarlı şekilde artırır. 9 mg/kg gibi yüksek dozlar yan etkileri artırır ve ek fayda sağlamaz."),
            p("Sağlıklı yetişkinler için günlük toplam 400 mg genel üst sınır kabul edilir. Bir Türk kahvesi ~55 mg, bir ince belli bardak çay ~20 mg kafein içerir."),
            c("Kafeinin yarılanma süresi ~5 saat. Uykunu bozmaması için yatmadan 6 saat önce kes; kötü uyku antrenmandan kazandığından fazlasını götürür.")
        ], sources: [("ISSN Position Stand: caffeine and exercise performance (2021)", "https://pmc.ncbi.nlm.nih.gov/articles/PMC7777221/")]),

        Article(id: "sleep", title: "Uyku ve hazır olma", subtitle: "Skor neye bakıyor?", symbol: "moon.zzz.fill", colorHex: 0xB9A6FF, minutes: 2, blocks: [
            p("Apple Watch takıyorsan Forma her sabah şu verilere bakar ve kendi 30 günlük ortalamanla karşılaştırır:"),
            b("Uyku süresi: hedefinin (varsayılan 8 saat) ne kadarını uyudun?"),
            b("Kalp atış hızı değişkenliği (HRV): ortalamanın belirgin altındaysa vücut yorgun ya da stres altında olabilir."),
            b("Dinlenik nabız: ortalamanın belirgin üstündeyse yorgunluk, hastalık veya stres işareti olabilir."),
            b("Kas toparlanması ve kendi hissin."),
            p("Skor düşükse Forma o gün setleri bir azaltır ve ağırlık artırma önerisini kapatır. Bu tıbbi bir değerlendirme değil, antrenman yoğunluğunu ayarlamak için bir öneridir."),
            c("Yetişkinler için 7–9 saat uyku önerilir. Kas antrenmanda yıkılır, uykuda onarılır.")
        ], sources: []),

        Article(id: "ramadan", title: "Ramazan'da spor", subtitle: "Antrenman, su ve beslenme", symbol: "moon.stars.fill", colorHex: 0xFFC94D, minutes: 3, blocks: [
            p("Oruçluyken ağır antrenman, iftardan 1–3 saat sonra yapıldığında daha iyi tolere edilir; o saatte sıvı ve enerji alınmış olur. İftar öncesi ise sadece hafif yürüyüş veya mobilite önerilir."),
            b("İlk hafta antrenman hacmini biraz azalt, dinlenmeleri uzat."),
            b("Orucu su ve birkaç hurmayla aç, sonra ana yemeğe geç."),
            b("Sıvıyı iftardan uykuya kadar küçük yudumlarla yay (yaklaşık 30 dakikada bir 200 ml); sahurda bir anda çok su içmek iyi tolere edilmez."),
            b("Proteini iftar, antrenman sonrası ve sahura böl. Akşam antrenmanı sonrası süzme yoğurt veya lor iyi bir seçimdir."),
            b("Kreatini iftarda alabilirsin."),
            c("Ramazan modunu açtığında Forma öğünleri sahur/iftar olarak düzenler, su ve takviye hatırlatmalarını iftar–imsak arasına taşır ve antrenman saatini iftar sonrasına önerir. Vakitler konumuna göre hesaplanır; Diyanet takvimiyle farkı ayarlardan birkaç dakika düzeltebilirsin.")
        ], sources: [("Aspetar: Ramadan evidence-informed guide", "https://www.aspetar.com/en/professionals/ramadan-evidence-informed-guide")]),

        Article(id: "warmup", title: "Isınma ve sakatlıktan korunma", subtitle: "5 dakika yeterli", symbol: "thermometer.medium", colorHex: 0xE8C547, minutes: 2, blocks: [
            b("5 dakika hafif kardiyo (bisiklet, eliptik, hızlı yürüyüş)."),
            b("İlk büyük harekette 2–3 ısınma seti: boş bar veya hafif ağırlıkla başlayıp çalışma ağırlığına yaklaş. Forma bunları otomatik ekler."),
            b("Ağrı (keskin, batıcı) ile kas yorgunluğu (yanma) farklıdır. Ağrıda dur."),
            b("Formu bozulan son tekrarları yapma; o tekrarlar gelişimden çok risk getirir."),
            c("Makinelerde koltuk ve pedleri ilk seferde vücuduna göre ayarla ve harekete not olarak kaydet.")
        ], sources: [])
    ]
}

// MARK: - Görünümler

struct LearnView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Uygulamanın önerileri bu bilgilere dayanır. Her yazının altında kaynaklar var.")
                    .formaFont(.caption, Theme.textSecondary)
                ForEach(LearnLibrary.all) { a in
                    NavigationLink { ArticleView(article: a) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: a.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(a.color)
                                .frame(width: 46, height: 46).background(a.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.title).formaFont(.bodyMedium)
                                Text(a.subtitle).formaFont(.caption, Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(a.minutes) dk").formaFont(.caption, Theme.textTertiary)
                        }
                        .cardStyle(padding: 12)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Bilgi köşesi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArticleView: View {
    var article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: article.symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(article.color)
                    .frame(width: 58, height: 58).background(article.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 8)
                Text(article.title).formaFont(.display).fixedSize(horizontal: false, vertical: true)
                Text(article.subtitle).formaFont(.body, Theme.textSecondary)
                let numbers = article.blocks.compactMap { block -> (String, String)? in
                    if case .number(let v, let l) = block.kind { return (v, l) }
                    return nil
                }
                if !numbers.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(numbers.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.0).formaFont(.numberM, article.color).lineLimit(1).minimumScaleFactor(0.6)
                                Text(item.1).formaFont(.caption, Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle(padding: 12)
                        }
                    }
                }
                ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
                if !article.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kaynaklar").eyebrow()
                        ForEach(Array(article.sources.enumerated()), id: \.offset) { _, s in
                            if let url = URL(string: s.1) {
                                Link(destination: url) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "arrow.up.right.square").font(.system(size: 12))
                                        Text(s.0).multilineTextAlignment(.leading)
                                    }
                                    .formaFont(.caption, Theme.water)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                Text("Bu içerik genel bilgilendirme amaçlıdır, tıbbi tavsiye değildir.").formaFont(.caption, Theme.textTertiary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func blockView(_ block: Article.Block) -> some View {
        switch block.kind {
        case .paragraph:
            Text(block.text).formaFont(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        case .heading:
            Text(block.text).formaFont(.headline).padding(.top, 6)
        case .bullet:
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(article.color).frame(width: 6, height: 6).padding(.top, 8)
                Text(block.text).formaFont(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        case .callout:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill").foregroundStyle(Theme.gold)
                Text(block.text).formaFont(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .cardStyle(padding: 14, background: Theme.gold.opacity(0.08))
        case .number:
            EmptyView()
        }
    }
}
