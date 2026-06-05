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

## Performans (ölçüldü)
| | Süre | Not |
|---|---|---|
| pwsh `-NoProfile` cold/warm | ~1500 / ~950ms | hook tabanı; native binary olmadan kırılamaz (kapsam dışı) |
| guard-pretool — `.xaml` YOK (early-out) | ~1085ms | JSON parse+regex atlanır (ham girdide `.xaml` yoksa anında çık) |
| guard-pretool — `.xaml` (full) | ~1350ms | deny/allow kararı |
| MCP cold start + orientation | ~2400ms | tek sefer, session boyunca warm |
| done-gate analyze (Studio kapalı) | ~21sn | bu yüzden **opt-in**; Studio açıkken pipe ile ~2sn |

`powershell.exe` 5.1 daha hızlı değil (~1400ms). En büyük hız kazançları zaten F1/F2'de geldi (sonsuz disconnect + BULUNAMADI döngüsü → 0); kalan per-hook ~1s pwsh process maliyetidir.

## Test
- `guard-pretool`: 7/7 (Edit/Write/Bash .xaml deny, .cs + okuma allow)
- `after-file-edit`: 2/2 (.xaml uyarı+flag, .cs karışmaz)
- `done-gate`: temiz-proje allow+flag-temizle (21sn, Studio kapalı); opt-in kapalı 1.5sn skip
