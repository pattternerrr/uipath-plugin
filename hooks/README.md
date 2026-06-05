# Hooks — determinist enforcement

İki ajan, iki mekanizma. Claude Code gerçekten **bloklayabilir**; Cursor'da editör-yazma yapısal olarak önceden bloklanamaz (`beforeFileEdit` yok).

## Claude Code (`hooks.json` — otomatik yüklenir)

| Hook | Olay | Ne yapar | Maliyet |
|---|---|---|---|
| `guard-pretool.ps1` | PreToolUse (Edit/Write/MultiEdit/Bash) | `.xaml`'a elle yazmayı **DENY** (editör + shell). Okuma serbest. | anlık |
| `mark-xaml-touched.ps1` | PostToolUse (`edit_workflow`) | bu session'da xaml düzenlendi diye flag bırakır | anlık |
| `done-gate.ps1` | Stop | xaml düzenlendiyse `uip rpa analyze` → **hata varsa "bitti" demeyi bloklar** | **opt-in** (aşağı bak) |
| `session-start.ps1` | SessionStart | ortam + bağımlılık teşhisi | anlık |

**`guard-pretool` her zaman aktif** — asıl "elle .xaml yazma yasak" enforcement'ı budur, sıfır maliyet.

### done-gate VARSAYILAN KAPALI (opt-in)
analyze, **Studio kapalıyken ~20sn** sürer (açıkken pipe ile ~2sn). Her tamamlamada bunu ödememek için done-gate default kapalıdır. **Sert kapıyı istiyorsan** proje köküne flag koy:
```powershell
New-Item -ItemType File "<proje>\.claude\uipath-done-gate.enabled" -Force
```
Açıkken: xaml düzenlendiği session'larda Stop'ta analyze çalışır; **hata varsa "bitti" engellenir**. **FAIL-OPEN** — uip yoksa / CLI hata / timeout(90s) / proje yoksa → bloklamaz, geçer (kullanıcıyı asla tuzağa düşürmez). Studio açmanı **beklemez/zorlamaz**; kapalıysa sadece yavaş çalışır.

## Cursor (`cursor/` — setup.ps1 proje `.cursor/hooks.json`'a mutlak yolla yazar)

| Hook | Olay | Ne yapar |
|---|---|---|
| `cursor/guard-shell.ps1` | beforeShellExecution | shell `.xaml` yazımını **DENY** |
| `cursor/after-file-edit.ps1` | afterFileEdit | editör `.xaml` düzenlemesini **POST-HOC uyarır** + `.cursor/.xaml-violation` flag bırakır |

⚠️ **Cursor sınırı:** editör-yazma önceden bloklanamaz (`beforeFileEdit` yok). Shell yolu duvar, editör yolu uyarı+iz. Claude Code'da `guard-pretool` editörü de bloklar — o güç Cursor'da yok. Detay: `cursor/README.md`.

## Test
- `guard-pretool`: 7/7 (Edit/Write/Bash .xaml deny, .cs + okuma allow)
- `after-file-edit`: 2/2 (.xaml uyarı+flag, .cs karışmaz)
- `done-gate`: temiz-proje allow+flag-temizle (21sn, Studio kapalı); opt-in kapalı 1.5sn skip
