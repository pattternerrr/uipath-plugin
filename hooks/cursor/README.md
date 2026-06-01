# Cursor hooks (deneysel, opt-in)

Cursor 1.7+ hook'ları (`beforeShellExecution` vb.) için. **Henüz `setup.ps1` otomatik kurmuyor** — bilinçli, çünkü kapsamı sınırlı.

## guard-shell.ps1 — `beforeShellExecution`
`.xaml`'a **shell ile** yazmayı (`echo >`, `Set-Content`, `sed -i`, `Out-File`) `permission: deny` ile bloklar → Kural #3 ("elle .xaml yazma yasak").

### DÜRÜST KAPSAM (overclaim yok)
- ✅ Tutar: shell üzerinden `.xaml` yazma.
- ❌ TUTMAZ: Cursor'ın **editörüyle** `.xaml` yazma. Cursor'da `beforeFileEdit` event'i yok; `afterFileEdit` iş olduktan sonra çalışır, bloklayamaz. Ajanlar `.xaml`'ı genelde editörle yazar → asıl yaygın yol açık kalır.
- ❌ Bypass: `[IO.File]::WriteAllText`, `python open(...)` gibi yollar denylist'te değil.
- Sonuç: **hız tümseği, duvar değil.** Tek başına "elle xaml engellendi" garantisi vermez; rule + edit_workflow disiplini esas.

## Manuel kurulum (istersen)
`<proje>\.cursor\hooks.json`:
```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      { "command": "pwsh -NoProfile -File C:/MUTLAK/YOL/uipath-mcp-plugin/hooks/cursor/guard-shell.ps1" }
    ]
  }
}
```
Cursor'ı yeniden başlat. (Yol mutlak olmalı — repo kalıcı klasörde.)
