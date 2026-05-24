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

## Kurulum — Claude Code (arkadaş modu, 4 satır)

```
/plugin marketplace add pattternerrr/uipath-plugin
/plugin install uipath-mcp-plugin@mustafa-uipath
/plugin install chrome-devtools-mcp@claude-plugins-official
uip skills install --agent claude
```

İlk satır bu repo'yu marketplace olarak ekler. İkincisi plugin'i (MCP + skills + hook) kurar. Üçüncüsü web selector pipeline için Chrome DevTools MCP'sini getirir. Dördüncüsü UiPath'in resmi `rpa-workflow-architect` / `coded-workflow-architect` skill'lerini kurar.

Kurulumdan sonra Claude Code'u yeniden başlat (veya `/reload-plugins`).

## Kurulum — Cursor (2.5+)

Cursor'da plugin sistemi aynı primitive'leri (skills, rules, MCP, hooks) destekler. İki parça var:

**Parça 1 — Plugin (skills + rules):** Cursor → **Settings → Plugins → Team Marketplaces → Import** → bu repo URL'ini yapıştır: `https://github.com/pattternerrr/uipath-plugin` → `uipath-mcp-plugin`'i kur. (Team Marketplace import, Cursor Teams/Enterprise planı gerektirir.)

**Parça 2 — Geri kalan her şey TEK KOMUT:** Repo'yu klonladığın klasörde:
```
pwsh -File scripts\setup.ps1 -Yes
```
Bu sihirbaz dizini **otomatik seçer** ve tek seferde kurar:
- **UiPath MCP server** (7 tool) → `bin\UiPathMCP.exe` mutlak yolu `~/.cursor/mcp.json`'a
- **chrome-devtools-mcp** → `npx chrome-devtools-mcp@latest` (web selector pipeline)
- **UiPath resmi skill'leri** → `uip skills install --agent cursor`

İnteraktif menü için `-Yes`'siz çalıştır. Sadece bu proje için: `-Scope local`. Sadece MCP istiyorsan minimal alternatif: `scripts\install-cursor.ps1`.

> **Neden script (MCP için):** Cursor'un henüz plugin-local binary'ye işaret eden `${CURSOR_PLUGIN_ROOT}` değişkeni **yok** ve public-marketplace mutlak yol yasak — yani plugin'in kendisi ~71MB'lık bundled exe'ye portatif işaret edemiyor. Script bu boşluğu kapatır.

Cursor'ı yeniden başlat. **Settings → MCP**'de `uipath-mcp-csharp` (7 tool) + `chrome-devtools` görünmeli; rules (`uipath-orientation` alwaysApply + `uipath-xaml` auto-attach) ve skills aktif olur.

**Not — Claude ↔ Cursor farkları:** Claude'un `SessionStart` hook bootstrap'ı Cursor'da yok; yerine `rules/uipath-orientation.mdc` (alwaysApply) geçer — her istekte context'e enjekte olur, hook'tan daha güvenilir. `uip` CLI komutları Cursor terminalinden çağrılır (validation: `uip rpa analyze`).

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
- Settings → Plugins → `uipath-mcp-plugin` installed (skills + rules)
- Settings → MCP → `uipath-mcp-csharp` connected, **7 tool**
- Rules: `uipath-orientation` (Always) + `uipath-xaml` (Auto Attached, `.xaml`/`project.json`)

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
