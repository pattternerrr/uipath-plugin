---
description: Web UI elementleri için kanonik selector üretme akışı. Bir web sayfasındaki butona/inputa/dropdown'a UiPath UI aktivitesi (NClick/NTypeInto/NSelectItem) eklerken, webctrl selector üretirken veya "şu elementin selector'ını çıkar / şu sayfayı otomatikleştir" dendiğinde kullan. Chrome DevTools MCP gerektirir.
version: 0.1.0
---

# CDP-Only Selector Pipeline (kanonik — ADR-0018, Kural #12)

Web UI selector ihtiyacında **tek kaynak: Chrome DevTools MCP `evaluate_script`**. CLI snapshot / Object Repository / Studio recorder KULLANILMAZ — manuel DOM inspect + webctrl daha hızlı ve doğru.

## Önkoşul

- `chrome-devtools-mcp` kurulu olmalı (`/plugin install chrome-devtools-mcp@claude-plugins-official`).
- Persistent browser profile (ADR-0017): UiPath kendi profilinde çalışır; fresh profile locale/cookie modal tetikler ve CDP query'lerini bozar. `UserDataFolderPath` **static** olmalı.

## Pipeline

```
1. Adım planı
   A) Kullanıcı adım listesi verir (tercih edilen)
   B) Fallback: CDP ile sayfada gez, adım listesi öner, kullanıcı onayını bekle
   • Beklenmedik adım çıkarsa devam etmeden önce bildir.

2. Adım başına evaluate_script
   • Girdi: querySelector hint (kullanıcı / mevcut workflow / sayfa keşfi)
   • Element handle bul → tüm attribute'leri oku
   • Minimum benzersiz-ve-stabil attribute kombinasyonunu kur (algoritma altta)
   • Tek webctrl XAML string üret

3. Scratch tabloya topla
   • Yol: .scratch/<site>-selectors-<YYYY-MM-DD>.md
   • Kolonlar: # | activity (display name) | activity type | webctrl
   • Adım başına bir satır; altta doğrulama checkbox'ları

4. Batch inject
   • Tablo tamamlanıp gözden geçirilince satır başına edit_workflow çağır
   • Her çağrı, ilgili aktivitenin TargetAnchorable'ındaki FullSelectorArgument'ı değiştirir
   • Guid/Reference/ContentHash/InformativeScreenshot'a DOKUNMA (ölü ama zararsız)
```

## Stabilite hiyerarşisi (attribute önceliği)

`name` (dev-assigned) > `data-testid` > `data-test-id` > `id` (auto-gen değilse) > `aria-label` > `class`

## Benzersizlik algoritması

```
1. [tag, <en güçlü mevcut attr>] ile başla
2. document.querySelectorAll(candidate) çalıştır
3. eşleşme == 1 → bitti
4. değilse sıradaki en güçlü attribute'ü ekle, tekrarla
5. hiçbir stabil-attr kombosu 1 eşleşme vermiyorsa → tabloda "ambiguous, needs anchor" işaretle, kullanıcıya sor
```

Auto-generated heuristic: saf sayısal ID ≥6 hane, CSS-in-JS hash (`^[a-z]+-[a-f0-9]{6,}`).

## Görünürlük check — rect > MIN_SIZE (Kural #14)

Modern CSS: native input/checkbox 1×1 gizli, LABEL tıklanır. `evaluate_script` ile handle alırken rect kontrolü ZORUNLU:

```js
const rect = el.getBoundingClientRect();
if (rect.width < 8 || rect.height < 8) {
  el = el.closest('label') || el.parentElement; // gerçek tıklanabilir parent
}
```

İnsan ne görüp tıklıyorsa o → LABEL (HTML `for=""` ile INPUT'u toggle eder). 1×1 hidden INPUT'u DebuggerApi tıklayamaz.

## Selectable element → NSelectItem (Kural #13)

`<select>` veya custom dropdown → **NSelectItem** tercih et (tek aktivite, race-condition yok), NClick zinciri değil.
- Karar: CDP `el.tagName === 'SELECT'` → evet ise NSelectItem, hayır (custom div) ise NClick zinciri.

## Anti-pattern'ler

- CLI snapshot/resolve ile webctrl üretmek — yanlış çıktı formatı (UIA `<ctrl>`, webctrl değil)
- OR-suz projede OR registry — sadeleştirmeyi bozar
- Studio recorder/Indicate ile hızlı selector — manuel DevTools inspect daha hızlı
- Uniqueness doğrulamadan 4+ attribute elle yazmak — runtime'da sıfır/çoklu eşleşme riski
- Per-activity inject — review'ı böler, riski şişirir; batch yap
