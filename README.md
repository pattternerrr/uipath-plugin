# uipath-mcp-plugin

UiPath Studio/RPA workflow otomasyonu için Claude Code plugin'i. Kurulduğunda, sıfır hafızalı bir ajan UiPath kanonik akışlarını (typed MCP tool'ları, CDP selector pipeline, Studio pipe oracle, structural guard) tek bir kural öğretilmeden uygular.

## Ne içerir

- **MCP server** (`uipath-mcp-csharp`, 7 typed tool): `mcp_orientation`, `set_project_root`, `get_activity_metadata`, `get_workflow_outline`, `read_workflow`, `edit_workflow`, `fill_activity`
- **5 skill**: `ui-activity`, `cdp-selector-pipeline`, `issue-tracker`, `triage-labels`, `domain`
- **SessionStart hook**: ortam sağlık kontrolü + eksik bağımlılık teşhisi + mcp_orientation bootstrap
- **Self-contained**: .NET 8 runtime exe'ye gömülü — ayrı runtime kurmana gerek yok

## Önkoşullar

- **Windows 10/11** (UiPath Studio Windows-only)
- **UiPath Studio** kurulu (Studio pipe bridge + bundled net8 runtime için)
- **UiPath CLI** (`uip`) — https://docs.uipath.com/uipath-cli/standalone/latest
  - `uip --version` ile doğrula, `uip login` ile giriş yap

## Kurulum (arkadaş modu — 4 satır)

```
/plugin marketplace add pattternerrr/uipath-plugin
/plugin install uipath-mcp-plugin@mustafa-uipath
/plugin install chrome-devtools-mcp@claude-plugins-official
uip skills install --agent claude
```

İlk satır bu repo'yu marketplace olarak ekler. İkincisi plugin'i (MCP + skills + hook) kurar. Üçüncüsü web selector pipeline için Chrome DevTools MCP'sini getirir. Dördüncüsü UiPath'in resmi `rpa-workflow-architect` / `coded-workflow-architect` skill'lerini kurar.

Kurulumdan sonra Claude Code'u yeniden başlat (veya `/reload-plugins`).

## İlk kullanım

```
set_project_root C:\Path\To\UiPathProject
```

Sonra doğal dille iste — ajan kalanı halleder:
> "Main.xaml'a bir Log Message ekle, 'Merhaba' yazsın."
> "Bu sayfadaki arama kutusuna NTypeInto ile metin yaz, sonra arama butonuna NClick."

Ajan her UiPath/.xaml işine başlamadan önce `mcp_orientation` çağırır (kanonik kurallar + tool sözlüğü oradadır).

## Doğrulama

- `/plugin` → `uipath-mcp-plugin` enabled
- `/mcp` → `uipath-mcp-csharp` connected, **7 tool**
- `/help` → skill'ler `uipath-mcp-plugin:<skill>` namespace'iyle görünür

## Geliştirici notları

- `scripts/publish-bins.ps1` — `bin/`'i kaynaktan (mcp-csharp) yeniden üretir. Arkadaşlar çalıştırmaz; `bin/` repo'da commit'li gelir.
- MCP server kaynağı ayrı repo: `mcp-csharp` (.NET 8). Bu plugin sadece publish çıktısını taşır.
- `bin/` self-contained net8 (~71MB, 191 dosya) — `MetadataLoadContext` runtime DLL'lerini diskte arar, o yüzden single-file DEĞİL.

## Mimari karar

`uip mcp serve` (UiPath CLI'nin kendi MCP'si, tek `run_command` tool) dahil edilmedi — UiPath'in resmi tavsiyesi "skills primary, mcp for integrations". CLI komutları Bash ile çağrılır. Bu plugin'in 7 typed tool'u CLI'nin kapatmadığı boşluğu (XAML structural ops, activity metadata merge, Studio pipe live edit) doldurur.

## Lisans

MIT
