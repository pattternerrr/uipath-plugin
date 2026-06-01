# uipath-mcp-plugin — Ajan Talimatları (ZORUNLU)

> Bu dosya `CLAUDE.md` ile **aynı kanonik kuralları** taşır. Cursor `CLAUDE.md` okumaz; `AGENTS.md`'i okur — bu yüzden ayrı kopya. İçerik değişirse ikisini birlikte güncelle. Kısa guardrail'ler ayrıca `.cursor/rules/uipath-orientation.mdc` + `uipath-xaml.mdc`'de (her ikisi `alwaysApply`) bulunur; bu dosya derin referanstır.

Bu plugin kurulu olduğunda UiPath projelerinde (project.json + .xaml) aşağıdaki kurallar **istisnasız** geçerlidir. Sıfır hafızalı ajan bunları okuyup uygular.

## Stack — üç katman, çakışmaz

| Katman | Ne için | Nasıl |
|---|---|---|
| **Bu plugin'in MCP'si** (`uipath-mcp-csharp`, 7 typed tool) | XAML structural ops, activity metadata, Studio pipe bridge | MCP tool çağrısı |
| **`uip` CLI** | build, publish, run, analyze (validation), package inspect | terminal'den `uip rpa ...` |
| **UiPath resmi skill'leri** (`uip skills install --agent cursor`) | rpa-workflow-architect, coded-workflow-architect rehberleri | otomatik tetiklenir |

## 7 MCP Tool (hepsi bu — başkası YOK)

| Tool | Ne yapar |
|---|---|
| `mcp_orientation` | Kanonik handshake — **ilk çağrı, zorunlu** (ADR-0012) |
| `set_project_root` | Proje kökünü ayarla (orientation'dan sonra ilk) |
| `get_activity_metadata` | Property kind/type/required — `.local/docs` → DLL reflection, tahmin yok |
| `get_workflow_outline` | Aktivite hiyerarşisi (düzenlemeden önce) |
| `read_workflow` | Workflow oku — startLine+endLine ver, son çare |
| `edit_workflow` | XAML string replace + .bak backup + namespace auto-inject (ADR-0004) |
| `fill_activity` | Kanonik aktivite iskeleti (Studio pipe → CLI fallback) |

Validation/build/run/install MCP'de **YOK** — `uip` CLI ile terminal'den yap (örn. `uip rpa analyze --project-path . --output json`).

## ZORUNLU KURALLAR

### 1. MCP #1 HEDEFTİR
MCP araçları düzgün çalışmadan XAML düzenleme yapılmaz. MCP'de sorun varsa önce onu çöz.

### 2. TAHMİN YASAKTI
MCP araçları sadece `.local/docs` veya DLL reflection'dan veri döndürür. Hardcoded map, uydurma namespace, tahminî property kind YOK. Veri yoksa `BULUNAMADI` — asla tahmin etme. xmlns prefix / property kind / assembly adı için her zaman `get_activity_metadata` çağır. **Yanlış veri (KESİN etiketiyle) BULUNAMADI'dan kötüdür.**

### 3. XAML DOĞRUDAN DÜZENLENEMEZ
Editör (Cursor dosya düzenleyici) ile .xaml dosyasına dokunmak YASAK. Her XAML değişikliği `edit_workflow` ile. Etrafından dolaşmak da yasak — MCP çalışmıyorsa önce MCP'yi düzelt.

### 4. DOĞRULAMA ZORUNLU
Her değişiklikten sonra `uip rpa analyze` çalıştır (terminal). Studio açıksa fill_activity'nin bridge'i anlık state verir.

### 5. ETRAFINDAN DOLAŞMAK YASAK — SORU SOR
Bir şeyi nasıl yapacağını bilmiyorsan uydurma, **kullanıcıya sor**. Numaralı liste, her soru tek ve net, beklenen cevap formatını belirt. Workaround bulmak yerine doğru çözümü öğren.

### 6. STUDIO PIPE — typed CoreIpc bridge
`fill_activity` Studio açıkken named pipe (`UiPath.Ipc`) ile anlık default XAML alır; kapalıysa `uip` CLI fallback. Bridge `bin/UiPathStudioBridge.dll`, Studio'nun bundled net8 `dotnet.exe`'siyle çalışır. Transport binary-framed (JSON-RPC değil).

### 7. UI AKTİVİTELERİ — RECORDER/CDP ZORUNLU
NTypeInto/NClick/NSelectItem/NKeyboardShortcuts iş başında **adım 0**: projede recorder artifact tara (`Guid=`, `Reference=`, `ContentHash=` içeren .xaml). Bulduysan ground truth, bütünsel port et. Bulamadıysan web selector için **`cdp-selector-pipeline` skill'ini** kullan (CDP → webctrl → edit_workflow inject). Hand-write 4-attribute selector = tahmin, YASAK. Detay: `ui-activity` skill.

### 8. BİLGİ KAYNAĞI HİYERARŞİSİ
Her UiPath sorusunda kaynak sırası: (1) `.local/docs` → (2) DLL reflection (`get_activity_metadata`) → (3) recorder artifact → (4) mevcut `~/Documents/UiPath/*` xaml örnekleri → (5) hiçbiri yoksa **kullanıcıya sor**. Dış dünya (generic web/CLI) yalnızca 1-4 tükenince + kullanıcı onayıyla.

### 9. CLI'DAN ÖNCE --help SORGULA
`uip` alt komutunu ilk kez kullanıyorsan parametre isimlerini tahmin etme, `--help` ile kontrol et.

### 10. ORIENTATION HANDSHAKE — İLK ÇAĞRI
Yan etkili tool'lardan önce `mcp_orientation` çağır (ADR-0012). Tool sözlüğü + determinizm sözleşmesi döner.

### 11. SELECTABLE ELEMENT → NSelectItem
`<select>` veya custom dropdown → NSelectItem tercih et (tek aktivite, race yok), NClick zinciri değil. CDP `el.tagName === 'SELECT'` kontrol et. Detay: `cdp-selector-pipeline` skill.

### 12. CDP-FIRST SELECTOR PIPELINE (kanonik)
Web selector ihtiyacında: CDP `evaluate_script` ile element bul → attribute oku → stabilite önceliği (`name` > `data-testid` > `id` > `aria-label` > `class`) → webctrl XAML üret → `edit_workflow` ile inject. OR/recorder/CLI snapshot pipeline GEREKSİZ. Detay: `cdp-selector-pipeline` skill (ADR-0018).

### 13. GÖRÜNÜRLÜK CHECK — rect > 8px
CDP handle alırken rect kontrolü zorunlu: `rect.width < 8 || rect.height < 8` ise gerçek tıklanabilir parent'a çık (`el.closest('label')`). 1×1 gizli INPUT tıklanamaz; insan ne görüyorsa o (LABEL).

### 14. PERSISTENT BROWSER PROFILE
`UserDataFolderPath` **static** olmalı (her run aynı). Dinamik = fresh profile = her run modal = bot detection. Detay: `ui-activity` skill (WebDriverMode="DevTools").

## Kanonik tool çağrı sırası

```
mcp_orientation → set_project_root → get_activity_metadata → fill_activity → edit_workflow → (terminal) uip rpa analyze
```

## ADR özetleri (one-liner)

- **0001** Studio pipe = tek validation oracle
- **0004** edit_workflow `{clr-namespace:NS;assembly=ASM}Type` marker'ı xmlns'i auto-inject eder (ham prefix DEĞİL)
- **0012** mcp_orientation zorunlu ilk çağrı handshake
- **0016→0018** CDP-only selector pipeline (0016 superseded)
- **0017** persistent browser profile ile modal bypass

## Yasak akışlar

- OR-tabanlı selector pipeline (OR-suz projede)
- JS-inject native element için (CDP yeterli)
- Repair-loop (fail sonrası körlemesine tekrar)
- Elle minimal webctrl (4 attribute) — uniqueness doğrulamadan
- Editör ile .xaml'a doğrudan dokunmak

## Sık XAML hataları

| Hata | Doğrusu |
|---|---|
| `<uia:Assign>` | `<Assign>` (prefix yok) |
| `Level="UiPath.Core.LogLevel.Info"` | `Level="Info"` |
| `String[]` için `x:String[]` | `s:String[]` (xmlns:s = System) |
| Property hem attribute hem child element | Sadece biri |
| `WaitForReadyArgument="Complete"` SPA'da | `Interactive` |
| NTypeInto Text içinde `[k(enter)]` Simulate'de | NClick on submit |
