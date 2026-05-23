---
description: UiPath proje domain dokümantasyonunu (CONTEXT.md + docs/adr/) keşif öncesi okuma kuralı. Kodda gezinmeye/değişiklik yapmaya başlamadan önce, domain terimlerini kullanırken veya bir çıktı mevcut bir ADR ile çelişiyor olabileceğinde kullan.
version: 0.1.0
---

# Domain Dokümantasyonu

Mühendislik işine başlamadan repo'nun domain dokümanlarını tüket.

## Keşiften önce oku

- Repo kökünde **`CONTEXT.md`**
- **`docs/adr/`** — dokunacağın alana değen ADR'ları oku.

Bu dosyalar yoksa **sessizce devam et**. Yokluğunu işaretleme; baştan oluşturmayı önerme.

## Dosya yapısı (single-context repo)

```
/
├── CONTEXT.md
├── docs/adr/
│   └── 0001-*.md
└── src/
```

## Glossary'nin sözcüklerini kullan

Çıktın bir domain kavramını adlandırdığında, `CONTEXT.md`'de tanımlandığı terimi kullan. Glossary'nin kaçındığı eş anlamlılara kayma.

## ADR çelişkilerini işaretle

Çıktın mevcut bir ADR ile çelişiyorsa, sessizce ezmek yerine açıkça yüzeye çıkar:

> _ADR-0007 ile çelişiyor — ama şu nedenle yeniden açmaya değer…_
