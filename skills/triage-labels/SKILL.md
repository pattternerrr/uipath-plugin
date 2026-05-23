---
description: UiPath proje issue'larının triage etiket taksonomisi. Issue durumu atarken/değiştirirken (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix) veya "şu issue'yu triyaj et / etiketle / AFK-hazır işaretle" dendiğinde kullan.
version: 0.1.0
---

# Triage Etiketleri

Beş kanonik triage rolü:

| Etiket | Anlam |
|---|---|
| `needs-triage` | Bakımcı bu issue'yu değerlendirmeli |
| `needs-info` | Bildiren kişiden daha fazla bilgi bekleniyor |
| `ready-for-agent` | Tam tanımlı, AFK ajan için hazır |
| `ready-for-human` | İnsan implementasyonu gerektiriyor |
| `wontfix` | Aksiyon alınmayacak |

Bir rol bahsedildiğinde (örn. "AFK-hazır triage etiketini uygula") bu tablodaki karşılık gelen string'i kullan. Issue dosyasında `Status:` satırına yazılır (`issue-tracker` skill).
