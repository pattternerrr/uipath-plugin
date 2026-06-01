# uipath-mcp-plugin

UiPath Studio/RPA workflow otomasyonu için **Claude Code + Cursor** plugin'i. Kurulduğunda, sıfır hafızalı bir ajan UiPath kanonik akışlarını (typed MCP tool'ları, CDP selector pipeline, Studio pipe oracle, structural guard) tek bir kural öğretilmeden uygular.

Tek repo iki ekosistemi besler: `.claude-plugin/` (Claude Code) ve `.cursor-plugin/` (Cursor) manifest'leri yan yana durur, `skills/` ikisinde de aynen kullanılır.

## Ne içerir

- **MCP server** (`uipath-mcp-csharp`, 7 typed tool): `mcp_orientation`, `set_project_root`, `get_activity_metadata`, `get_workflow_outline`, `read_workflow`, `edit_workflow`, `fill_activity`
- **5 skill** (Claude + Cursor ortak): `ui-activity`, `cdp-selector-pipeline`, `issue-tracker`, `triage-labels`, `domain`
- **Cursor rules** (`rules/*.mdc`): `uipath-orientation` (alwaysApply bootstrap) + `uipath-xaml` (`.xaml`/`project.json` auto-attach)
- **SessionStart hook** (Claude): ortam sağlık kontrolü + eksik bağımlılık teşhisi + mcp_orientation bootstrap
- **Self-contained**: .NET 8 runtime exe'ye gömülü — ayrı runtime kurmana gerek yok

## Önkoşullar

- **Windows 10/11** (UiPath Studio Windows-only)
- **UiPath Studio** kurulu (Studio pipe bridge + bundled net8 runtime için)
- **UiPath CLI** (`uip`) — https://docs.uipath.com/uipath-cli/standalone/latest
  - `uip --version` ile doğrula, `uip login` ile giriş yap

## Kurulum — TEK KOMUT (arkadaş modu)

Repo'yu klonla, tek komut çalıştır, sorulan **"Cursor mı, Claude mı?"** sorusunu cevapla:

```
git clone https://github.com/pattternerrr/uipath-plugin
cd uipath-plugin
pwsh -File scripts\setup.ps1
```

Sihirbaz **global kapsamda** (`~/.cursor` / `~/.claude` — tüm projeler) şunları kurar:
- **UiPath MCP server** (7 tool) → bundled `bin\UiPathMCP.exe` mutlak yolu
- **chrome-devtools-mcp** → `npx chrome-devtools-mcp@latest` (web selector pipeline)
- **UiPath resmi skill'leri** → `uip skills install --agent <cursor|claude>`

Soru sormadan default (Cursor + global): `pwsh -File scripts\setup.ps1 -Yes`. Sadece bu proje için: `-Scope local`.

Her iki ekosistemde de **MCP + chrome + UiPath resmi skill'lerini script kurar**. **Cursor için** script ayrıca plugin'in kendi **rules + skills + AGENTS.md**'sini de projeye kopyalar — ek adım yok. **Claude için** plugin'in kendi parçası slash-command ile gelir (aşağıda).

### Cursor — ek adım YOK
Script şunların hepsini yapar: MCP repoint + chrome + resmi skill'ler + `rules/*.mdc` (`uipath-orientation` + `uipath-xaml`, ikisi alwaysApply) → `<proje>\.cursor\rules\`, 5 plugin skill → `<proje>\.cursor\skills\`, `AGENTS.md` → proje kökü. Ayrıca eski/bozuk kurulum kalmışsa (bayat global rule, çift marketplace kaydı) tespit edip onarır. **Marketplace import gerekmez** (opsiyonel Enterprise alternatifi: Settings → Plugins → Team Marketplaces → Import → repo URL).

### Claude Code — ek adım (plugin)
Script `uip` skill'lerini kurar ve şu 3 satırı ekrana yazar (ps1 slash-command çalıştıramaz) — Claude Code içine yapıştır:
```
/plugin marketplace add pattternerrr/uipath-plugin
/plugin install uipath-mcp-plugin@mustafa-uipath
/plugin install chrome-devtools-mcp@claude-plugins-official
```
İlki repo'yu marketplace ekler, ikincisi plugin'i (MCP + skills + SessionStart hook) kurar, üçüncüsü Chrome DevTools MCP'sini getirir.

Kurulum sonrası ilgili uygulamayı yeniden başlat (Claude'da `/reload-plugins` de olur).

> **Neden script (Cursor için):** Cursor'un plugin-local binary'ye işaret eden `${CURSOR_PLUGIN_ROOT}` değişkeni **yok** ve public-marketplace mutlak yol yasak — plugin kendisi ~71MB bundled exe'ye portatif işaret edemiyor. Ayrıca Cursor rules dosya-tabanlı **sadece proje-scope** yüklenir (global `~/.cursor/rules` dokümante load path değil). Script bu iki boşluğu birden kapatır: MCP'nin mutlak yolunu config'e yazar + rules/skills/AGENTS'ı projeye kopyalar. (Sadece MCP isteyen için minimal alternatif: `scripts\install-cursor.ps1`.)

> **Antivirüs notu:** `bin\UiPathMCP.exe` self-contained .NET exe olduğu için bazı antivirüsler clone sonrası **karantinaya** alabilir. Script (`.ps1`) çalışır ama MCP bağlanmazsa: exe'yi AV'de **exclusion**'a ekle (clone klasörünü tümüyle izin listesine almak en temizi), karantinadan geri yükle, Cursor'ı yeniden başlat. Build gerekmez — exe repoda hazır gelir.

**Not — Claude ↔ Cursor farkı:** Claude'un `SessionStart` hook bootstrap'ı Cursor'da yok; yerine `rules/uipath-orientation.mdc` (alwaysApply) geçer — her istekte context'e enjekte, hook'tan güvenilir. `uip` komutları Cursor terminalinden çağrılır.

## İlk kullanım

```
set_project_root C:\Path\To\UiPathProject
```

Sonra doğal dille iste — ajan kalanı halleder:
> "Main.xaml'a bir Log Message ekle, 'Merhaba' yazsın."
> "Bu sayfadaki arama kutusuna NTypeInto ile metin yaz, sonra arama butonuna NClick."

Ajan her UiPath/.xaml işine başlamadan önce `mcp_orientation` çağırır (kanonik kurallar + tool sözlüğü oradadır).

## Doğrulama

**Claude Code:**
- `/plugin` → `uipath-mcp-plugin` enabled
- `/mcp` → `uipath-mcp-csharp` connected, **7 tool**
- `/help` → skill'ler `uipath-mcp-plugin:<skill>` namespace'iyle görünür

**Cursor:**
- Settings → MCP → `uipath-mcp-csharp` connected, **7 tool**
- Rules: `uipath-orientation` (Always) + `uipath-xaml` (Always) — `<proje>\.cursor\rules\`
- Skills: `<proje>\.cursor\skills\` altında 5 klasör (`ui-activity`, `cdp-selector-pipeline`, ...)
- `<proje>\AGENTS.md` mevcut

## Geliştirici notları

- `scripts/publish-bins.ps1` — `bin/`'i kaynaktan (mcp-csharp) yeniden üretir. Arkadaşlar çalıştırmaz; `bin/` repo'da commit'li gelir.
- `scripts/install-cursor.ps1` — Cursor için MCP server'ı `~/.cursor/mcp.json`'a bağlar (plugin-root değişkeni olmadığı için mutlak yol workaround'u). `-Project` ile proje-scope.
- MCP server kaynağı ayrı repo: `mcp-csharp` (.NET 8). Bu plugin sadece publish çıktısını taşır.
- `bin/` self-contained net8 (~71MB, 191 dosya) — `MetadataLoadContext` runtime DLL'lerini diskte arar, o yüzden single-file DEĞİL.

## Dosya düzeni (dual-format)

```
.claude-plugin/plugin.json   .cursor-plugin/plugin.json      # manifest'ler (yan yana, çakışmaz)
.claude-plugin/marketplace.json   .cursor-plugin/marketplace.json
.mcp.json (Claude)           mcp.json yerine → scripts/install-cursor.ps1 (Cursor)
hooks/hooks.json (Claude)    rules/*.mdc (Cursor bootstrap)
skills/                      # ORTAK — her iki sistemde aynen kullanılır
bin/                         # ORTAK — self-contained MCP exe
```

## Mimari karar

`uip mcp serve` (UiPath CLI'nin kendi MCP'si, tek `run_command` tool) dahil edilmedi — UiPath'in resmi tavsiyesi "skills primary, mcp for integrations". CLI komutları Bash ile çağrılır. Bu plugin'in 7 typed tool'u CLI'nin kapatmadığı boşluğu (XAML structural ops, activity metadata merge, Studio pipe live edit) doldurur.

## Lisans

MIT
