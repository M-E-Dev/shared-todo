# Shared Todo

Ortak kullanımlı todo uygulaması (iOS & Android). Çoklu kullanıcı senkronu ve ürün kararları netleştikçe genişletilecek.

## Mimari (özet)

- **`core/`** — ortam (`EnvConfig`), uygulama açılış sırası (`bootstrapApp`), ortak hatalar.
- **`features/auth/`** — `domain` (soyut `AuthRepository`), `data` (Supabase + yapılandırmasız stub), `presentation` (`AuthNotifier`: ek state paketi yok).
- **`app/`** — `AppScope` (`InheritedWidget`) ile bağımlılıklara erişim; tema ve `MaterialApp`.
- **`shared/utils/`** — küçük yardımcılar (`display_name`, `context_guard`).
- Supabase detayı UI’ya sızmaz; repository değişince tek dosya etkilenir.

## Statik analiz (TypeScript + ESLint benzeri)

| TS / JS ekosistem | Dart / Flutter karşılığı |
|-------------------|---------------------------|
| `tsc` | Derleyici zaten tip kontrolü yapar; ek katman gerekmez. |
| ESLint | `analysis_options.yaml` + `flutter analyze` |
| strict mode | `analyzer.language.strict-*` (projede açık) |
| knip (ölü export) | Tam eşdeğer yok; `unused_*` lint’leri + elle modül temizliği; isteğe bağlı ücretli araçlar (ör. DCM). |
| `npm audit` | `dart pub get` çıktısındaki [security advisories](https://pub.dev/security); bağımlılık güncellemesi için `dart pub outdated`. |

Önerilen yerel / CI komutu:

```bash
flutter analyze --fatal-infos --fatal-warnings
```

## Ön koşullar

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) kurulu olmalı (`flutter doctor`).
2. Bu klasörde henüz `ios/` ve `android/` yoksa (şu an böyle), bir kez şunu çalıştırın:

```bash
cd /path/to/shared-todo
flutter create . --project-name shared_todo --org com.medev.sharedtodo
```

`--org` değerini kendi paket adınıza göre değiştirebilirsiniz.

3. Bağımlılıklar:

```bash
flutter pub get
```

4. Çalıştırma:

```bash
flutter run
```

## Supabase

1. [Supabase](https://supabase.com) üzerinde proje oluşturun.
2. **Authentication → Providers** içinde **Anonymous** oturumu açın (MVP: anonim + görünen ad).
3. URL ve **anon** public key’i repoya yazmayın; çalıştırırken:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbG...
```

Şema ve RLS politikaları (listeler, üyeler, todo satırları) bir sonraki adımda tasarlanacak.

**Davet bağlantıları:** Her bağlantıda isteğe bağlı **bitiş zamanı** ve **katılım kotası** (`maxJoinCount`) olacak; kullanım sayısı sunucuda tutulup aşılamaz.

## Gizlilik ve mağaza uyumu

- İlk fazda e-posta ve gereksiz kişisel veri toplanmayacak.
- Türkiye / AB kullanıcıları için yayından önce kısa bir **Gizlilik Politikası** ve mağaza formlarında veri işleme beyanı şart; metinleri hukuki danışmanla netleştirin.
- Reklam veya ödeme eklenince ilave izinler ve yaş/API politikaları güncellenmeli.
