---
description: UI automation aktiviteleri (NTypeInto / NClick / NSelectItem / NKeyboardShortcuts / NCheckState / NApplicationCard) üretirken kanonik kurallar. Bir web/desktop UI'ı otomatikleştirirken, tıklama/yazma/dropdown seçme aktivitesi eklerken, InteractionMode/WaitForReady/delay ayarlarken veya selector port ederken kullan.
version: 0.1.0
---

# UI Activity Workflow (NTypeInto / NClick / NSelectItem / NKeyboardShortcuts)

Bu doküman UI aktivitelerinin nasıl üretileceğini ve neyi referans alacağını tanımlar. **Kural #2 (tahmin yasak) ile birlikte okunur.**

## En önemli kural — "X nasıl yapılır" → ÖNCE UiPath docs, SONRA dış dünya

UiPath'te her "nasıl yapılır" sorusunun **ilk adımı**: ilgili aktivitenin `.local/docs/packages/*/activities/*.md`'sini grep + `get_activity_metadata`. UiPath property'si çoğu zaman vardır (`UserDataFolderMode`, `UserDataFolderPath`, `IsIncognito`, vs.). Generic web/CLI bilgisinden başlarsak saatlerce dolambaç + yanlış tavsiye.

**Eticaret kanıtı:** Chrome izole profile için `TargetApp.Arguments` + `--user-data-dir` ile 30+ dakika uğraştık → UiPath o flag'leri ignore etti. `ApplicationCard.md` grep'i `UserDataFolderMode="CustomFolder"` + `UserDataFolderPath="..."` resmi property'lerini anında verdi. Önce docs okusak 1 dakikalık iş.

## Sıfır kuralı — Recorder artifact ara

Her UI iş başlangıcında **adım 0**, projede recorder-üretimi referans var mı diye taramak:

```
Glob: **/*.xaml
Grep .xaml içinde: Guid=" Reference=" ContentHash=" InformativeScreenshot=" IsResponsive="
Match eden dosya = recorder artifact = ground truth
```

Tipik isimler: `test.xaml`, `scratch.xaml`, `recorder.xaml`, kullanıcı initial'ları içeren dosyalar.

**Bulduysan:** o dosyayı baştan sona oku. Her property için "bu varsayım ne?" sorusunu cevapla. Port ederken **bütünsel** port et — kısmi port = sessiz tahmin.

**Bulamadıysan:** kullanıcıdan **tek bir aktivite** için recorder ile örnek istemeden devam etme. CLAUDE.md kural #5 (etrafından dolaşma — sor). Web selector üretimi için `cdp-selector-pipeline` skill'ini kullan.

## P1 — InteractionMode card-level set edilir (KESİN — agent .local/docs + reflection)

**İki ayrı enum (KESİN — .local/docs `common/*.md`):**
| Aktivite | Property tipi (FQN) | Üyeler |
|---|---|---|
| `NApplicationCard` (card) | `UiPath.UIAutomationNext.Enums.NInteractionMode` | `HardwareEvents`, `Simulate`, `DebuggerApi`, `WindowMessages`, `Background` |
| `NClick`/`NTypeInto`/`NKeyboardShortcuts` (child) | `UiPath.UIAutomationNext.API.Models.NChildInteractionMode` | yukarıdaki 4 + `SameAsCard` (card'da YOK) |

- Card `DebuggerApi` kabul eder.
- **`SameAsCard` resolve:** card `DebuggerApi` ise child→`DebuggerApi`; **card ayarsız (default) ise → `Simulate`** (Chrome için UiPath default'u).
- `Background` = mümkün olan yerde Simulate, karmaşık aktivitelerde foreground'a düşer.
- **`DebuggerApi` (kod) = "Chromium API" (Studio designer etiketi) — aynı şey.**
- ⚠️ **enum üyeleri için `.local/docs/.../common/<EnumName>.md` oku** — MetadataLoadContext bağımlı DLL'i çözemeyince enum üyelerini eksik döndürebilir (NInteractionMode 5 yerine 3 gösterdi). Reflection'ı doc ile cross-check yap.

```xml
<uix:NApplicationCard ... InteractionMode="DebuggerApi" ...>
  <child uix:NTypeInto ... InteractionMode="SameAsCard" ...>
```

- Card belirler, child'lar `SameAsCard` ile inherit (mixed mod = tutarsızlık).
- **Mod davranışı (kesin):**
  | Mode | Mekanizma | `[k(enter)]` | Background | CDP çakışma |
  |---|---|---|---|---|
  | `DebuggerApi` | UiPath Chrome extension üzerinden CDP | ✅ | ✅ | sadece DevTools açıksa |
  | `Simulate` | UIA/Accessibility API, tüm metni atomik | ⚠️ sınırlı | ✅ | ❌ |
  | `HardwareEvents` | OS kernel input | ✅ | ❌ foreground şart | ❌ |
  | `WindowMessages` | Win32 WM_*, desktop | ✅ | kısmi | ❌ |

- **Default tercih: `DebuggerApi`** (background + özel tuş + extension ile uyumlu). Ön koşul: DevTools kapalı, leftover chrome process yok. `Simulate` sadece DebuggerApi mümkün değilse (özel tuş gerekmiyorsa).

## P1b — Delay attribute'ları SANİYE (KESİN — TypeInto.md)

`NTypeInto` (V5) delay attribute'ları, birim **saniye (double)**:

| Amaç | Attribute | Default |
|---|---|---|
| Aksiyon öncesi | `DelayBefore` | `0.2` |
| Tuşlar arası | `DelayBetweenKeys` | max `1` saniye |
| Aksiyon sonrası | `DelayAfter` | `0.3` |

⚠️ **`DelayBetweenKeys="50"` = 50 SANİYE, felaket.** Leading-char loss için `0.05`–`0.1`.

> **Docs dosya-adı kuralı:** `.local/docs/.../activities/*.md` dosya adı aktivitenin **display name**'inden türer. `TypeInto.md` = modern V5 `UiPath.UIAutomationNext.Activities.NTypeInto`. md içindeki FQN'e bak.

## P2 — Submit: NClick on suggestion/button, NOT NKeyboardShortcuts/Enter

```
type → click submit (autosuggest item veya search magnifier button)
```

Anti-pattern: `NKeyboardShortcuts` Hardware Events ile Enter → focus kaybı. `NTypeInto.Text` içinde `[k(enter)]` Simulate modunda → validation hatası.

## P3 — Selector enrichment recorder'ın işidir

| Attribute | Runtime | Port ederken |
|---|---|---|
| Guid, BrowserURL, ScopeSelectorArgument, Reference, FullSelectorArgument, FuzzySelectorArgument | ✅ | **Tut** |
| ContentHash | ⚠️ fuzzy fallback | At |
| InformativeScreenshot, IsResponsive, DesignTimeRectangle | ❌ designer | At |

Port: cosmetic'leri sil, geri kalanını taşı. `ScopeIdentifier` sadece kendi card'ının GUID'ine değiştir. **Elle FullSelector yazma — `cdp-selector-pipeline` veya recorder kullan.**

**Reference + Guid:** `Guid` tek başına kopyalanabilir; `Reference` anchor ile çift halinde kopyalanır.

## P4 — Anchor semantic content içermeli

```xml
<uix:Target FuzzySelectorArgument="&lt;webctrl id='nav-search-label-id' tag='SPAN' aaname='Tüm Kategoriler' check:innerText='Tüm Kategoriler' /&gt;" />
```

Sadece id değil, **aaname + check:innerText** kombinasyonu — DOM rename'ine dayanıklı.

## P5 — NSelectItem.Items design-time cache

`<uix:NSelectItem.Items>` = sadece design-time cache. Runtime'da yalnızca `Item` değeri canlı DOM `<option>`'larına eşlenir. **Port ederken Items bloğu atılabilir** — `Item` + `Target` yeterli.

## P6 — WaitForReadyArgument = Interactive (Complete değil)

SPA'lar sürekli arka plan XHR yapar → `Complete` asla tetiklenmez → stall. Default: `Interactive`. `None` = anlık (race riski). `Complete` = sadece klasik server-rendered.

## P7 — VerifyOptions Mode

| Mode | Ne yapar | Risk |
|---|---|---|
| `Appears` | Type sonrası value'da text bekler | autosuggest → false-fail |
| `Vanishes` | Element kaybolmasını bekler | field clear |
| `None` | Doğrulama yok | hızlı, silent fail riski |

Şüpheli durumda `None` + ayrı `NCheckState`.

## P8 — Conditional element (cookie, popup) → NCheckState

Class: **`UiPath.UIAutomationNext.Activities.NCheckState`** ("Check App State"). **Default Timeout = 5s.**

```xml
<uix:NCheckState DisplayName="X varsa Y yap" Version="V4">
  <uix:NCheckState.IfExists>
    <Sequence DisplayName="X var"><uix:NClick ... /></Sequence>
  </uix:NCheckState.IfExists>
  <uix:NCheckState.IfNotExists>
    <Sequence DisplayName="X yok, atla" />
  </uix:NCheckState.IfNotExists>
  <uix:NCheckState.Target><uix:TargetAnchorable ... /></uix:NCheckState.Target>
</uix:NCheckState>
```

- Body delegate: **`IfExists` / `IfNotExists`**. `Mode` enum `NCheckStateMode` = `WaitAppear`(default)/`WaitDisappear`/`WindowNotActive`.
- Kullanım: cookie banner, kategori filtresi varyantı, popup dismiss.
- **Anti-pattern:** `NClick + ContinueOnError=True` → element yoksa 30sn timeout. Hep NCheckState ile sar.

## Cross-workflow attach (init + search pattern)

```xml
<!-- Main.xaml -->
<uix:NApplicationCard OpenMode="Always" CloseMode="Never" ScopeGuid="amz-init-001">
  <NGoToUrl Url="https://www.amazon.com.tr" /> <Delay />
</uix:NApplicationCard>

<!-- SearchAmazon.xaml -->
<uix:NApplicationCard OpenMode="Never" AttachMode="ByInstance"
                       Selector="&lt;html app='chrome.exe' url='*amazon.com.tr*' /&gt;"
                       ScopeGuid="amz-scope-001">
  ... search activities ...
</uix:NApplicationCard>
```

- ScopeGuid X ≠ Y olabilir (selector match yeterli).
- **Duplicate-open kök nedeni:** `CloseMode` default'u "bu card açtıysa kapat". Fix: **HER İKİ card'da da `CloseMode="Never"`.**
- `WSSessionData` InvokeWorkflowFile sınırını geçemez → selector-based reattach (`AttachMode="ByInstance"` + URL selector) tek yol.

## Çözülmüş altın pattern'ler (eticaret, kanıtlı)

1. **`NApplicationCard.WebDriverMode="DevTools"` — web automation'da ilk koy.** Extension YOK, CDP slot çakışması YOK, kişisel Chrome'a dokunmaz. Default `Disabled` = extension zorunlu (hatalar, CDP lock).
2. **CSS-gizli native `<select>` → `ElementVisibilityArgument="None"`.** Gizli-ama-fonksiyonel element için görünürlük check'i kapat.
3. **SPA async element → NCheckState element-driven wait (kör Delay DEĞİL).** NCheckState (Timeout=10) bekçi: `IfExists`→çalıştır, `IfNotExists`→atla.

## Anti-pattern özet (yapmaya kalkma)

1. Elle FullSelector yazıp 4 attribute koymak (→ `cdp-selector-pipeline` kullan).
2. NTypeInto'da `[k(enter)]` Simulate modunda göndermek.
3. NKeyboardShortcuts Hardware Events ile Enter (focus kaybı).
4. WaitForReadyArgument="Complete" SPA için.
5. Anchor'ı sadece id ile yazmak (check:innerText yok).
6. Card'da InteractionMode set etmeden child'larda override etmek.
7. Cookie banner için NClick + ContinueOnError.
8. Recorder artifact varken hand-port (yarım port = sessiz tahmin).
9. ScopeIdentifier'ı port ederken eski card'ın GUID'ini bırakmak.
10. `NApplicationCard.TargetApp.Url` + `OpenMode="Always"` + Body'de aynı URL'e `NGoToUrl` → DUPLICATE NAVIGATION.
11. Recorder-native selector taşırken metadata kaybetmek (Guid/Reference/FuzzySelector hepsini koru).
