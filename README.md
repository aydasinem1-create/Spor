# Forma

Spora yeni başlayanlar için antrenman, beslenme, su ve kreatin takibini tek yerde toplayan iOS ve Apple Watch uygulaması.

## iPhone'a kurulum (Windows, ücretsiz yöntem)

Uygulama her kod değişikliğinde GitHub'ın bulut Mac'lerinde otomatik derlenir. Hazır dosya **Releases → latest → Forma.ipa** bölümündedir.

1. **Gerekenler (Windows):**
   - [Sideloadly](https://sideloadly.io)
   - Apple'ın sitesinden indirilen iTunes ve iCloud (Microsoft Store sürümleri değil)
2. Bu depodaki **Releases** sayfasından `Forma.ipa` dosyasını indir.
3. iPhone'u kabloyla bilgisayara bağla, iPhone'da "Bu bilgisayara güven"i onayla.
4. Sideloadly'yi aç, `Forma.ipa` dosyasını pencereye sürükle, Apple kimliğini yaz ve **Start**'a bas.
5. iPhone'da:
   - **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç (telefon yeniden başlar).
   - **Ayarlar → Genel → VPN ve Aygıt Yönetimi** bölümünde Apple kimliğine dokun ve **Güven** de.
6. Forma'yı aç.

**Önemli:** Ücretsiz Apple kimliğiyle yüklenen uygulamalar **7 gün** sonra açılmaz. Telefonu bağlayıp Sideloadly ile tekrar yüklemen yeterli; verilerin silinmez.

Ücretsiz yöntemde Apple Watch uygulaması, widget'lar ve Apple Sağlık bağlantısı çalışmayabilir. Bu özellikler için Apple Developer Programı (yıllık 99 ABD doları) ile TestFlight kullanılabilir; kodda değişiklik gerekmez.

## Özellikler

- **Bugün ekranı:** protein, su ve kalori halkaları, takviye rafı, hızlı su ekleme, günün antrenmanı, hazır olma skoru ve haftalık koç.
- **Antrenman:** hazır başlangıç programları ve toparlanmaya göre otomatik plan. Set ve tekrar tablosu, dinlenme sayacı, ağırlık artırma önerisi, ısınma setleri, plaka hesaplayıcı ve rekorlar.
- **Doğru form:** 78 hareketin başlangıç ve bitiş fotoğrafları, Türkçe form ipuçları ve sık yapılan hatalar.
- **Kas haritası:** setlerden tahmin edilen toparlanma ve haftalık set hacmi. Ağrı bildirerek tahmini düzeltebilirsin.
- **Beslenme:** Türk mutfağı, barkod (Open Food Facts), kendi yiyeceğin, dünkü öğünü kopyalama ve kayıtlarından hesaplanan gerçek harcama.
- **Su, kafein ve takviyeler:** kreatin doygunluk tahmini, seriler ve akıllı hatırlatmalar.
- **İlerleme:** kilo trendi, ölçüler, önce/sonra fotoğrafları, güç grafikleri, süreklilik takvimi, rozetler ve seviyeler.
- **iOS ve saat:** widget'lar, kilit ekranı, Denetim Merkezi, Dynamic Island ve Live Activity, Siri komutları, Apple Watch'ta set ve nabız takibi, Apple Sağlık.
- **Ramazan modu:** konuma göre iftar ve imsak vakitleri; öğün, su ve antrenman saatleri buna göre ayarlanır.
- **Bilgi köşesi:** önerilerin dayandığı araştırmalar ve kaynakları.

## Proje yapısı

| Klasör | İçerik |
|---|---|
| `Packages/FormaKit` | Modeller ve tüm hesaplama motorları. Birim testleri burada. |
| `App` | iPhone uygulaması (SwiftUI) |
| `Widgets` | Widget'lar, Live Activity, Denetim Merkezi |
| `Watch` | Apple Watch uygulaması |
| `Shared` | Uygulama ve widget'ların ortak kodu (Siri kısayolları vb.) |
| `UITests` | Uçtan uca testler ve ekran görüntüleri |
| `project.yml` | XcodeGen proje tanımı |

Mac'te derlemek için: `brew install xcodegen && xcodegen generate`, ardından `Forma.xcodeproj` dosyasını aç.

## Kaynaklar ve lisanslar

- Hareket görselleri: [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (Unlicense)
- Barkod verisi: [Open Food Facts](https://world.openfoodfacts.org) (ODbL)
- Yazı tipleri: Space Grotesk ve DM Sans (SIL Open Font License)
- Beslenme ve antrenman önerileri: ISSN, ACSM ve EFSA pozisyon bildirileri. Ayrıntılar uygulamadaki Bilgi köşesinde.

Forma tıbbi bir uygulama değildir.
