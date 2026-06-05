# Cursor hooks (setup.ps1 OTOMATIK kurar)

Cursor 1.7+ hook'ları. `setup.ps1` / `update.ps1` artık bunları proje `.cursor\hooks.json`'a **mutlak yolla otomatik** yazar (Cursor'da `${CURSOR_PLUGIN_ROOT}` yok → mutlak yol zorunlu).

## guard-shell.ps1 — `beforeShellExecution` (BLOKLAR)
`.xaml`'a **shell ile** yazmayı (`echo >`, `Set-Content`, `sed -i`, `Out-File`, `[IO.File]::WriteAllText`) `permission: deny` ile bloklar → Kural #3.

## after-file-edit.ps1 — `afterFileEdit` (UYARIR, bloklayamaz)
Cursor **editörüyle** `.xaml` düzenlenince POST-HOC çalışır: sert uyarı (`agent_message`: "geri al + edit_workflow kullan") + proje `.cursor\.xaml-violation` flag'i bırakır.

### DÜRÜST KAPSAM (overclaim yok)
- ✅ Shell `.xaml` yazma → **bloklanır** (guard-shell).
- ⚠️ Editör `.xaml` yazma → **önceden bloklanamaz** (Cursor'da `beforeFileEdit` YOK — yapısal sınır). `afterFileEdit` iş olduktan sonra uyarır + flag bırakır.
- Sonuç: shell yolu duvar, editör yolu hız-tümseği + iz (violation flag). Asıl güvence: rule + `edit_workflow` disiplini.
- **Claude Code tarafı ayrı:** `hooks/guard-pretool.ps1` (PreToolUse) Edit/Write/MultiEdit `.xaml`'ı GERÇEKTEN bloklar — Cursor'da o güç yok.

## Kurulum
`setup.ps1`/`update.ps1` otomatik yazar. Elle istersen `<proje>\.cursor\hooks.json`:
```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": "pwsh -NoProfile -File \"C:/MUTLAK/YOL/uipath-mcp-plugin/hooks/cursor/guard-shell.ps1\"" }
    ],
    "afterFileEdit": [
      { "command": "pwsh -NoProfile -File \"C:/MUTLAK/YOL/uipath-mcp-plugin/hooks/cursor/after-file-edit.ps1\"" }
    ]
  }
}
```
Cursor'ı yeniden başlat.
