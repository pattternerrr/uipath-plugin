---
description: UiPath proje issue/PRD takibi yerel markdown ile. Kullanıcı "issue oluştur", "PRD yaz", "ticket'ı getir", "bu işi takibe al" dediğinde veya .scratch/ altında iş kalemi yönetimi gerektiğinde kullan.
version: 0.1.0
---

# Issue Tracker — Yerel Markdown

UiPath projelerinde issue ve PRD'ler `.scratch/` altında markdown dosyası olarak yaşar.

## Konvansiyonlar

- Bir özellik = bir dizin: `.scratch/<feature-slug>/`
- PRD: `.scratch/<feature-slug>/PRD.md`
- Implementation issue'ları: `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, `01`'den numaralı
- Triage durumu her issue dosyasının üstünde `Status:` satırı (rol string'leri için `triage-labels` skill'ine bak)
- Yorumlar/konuşma geçmişi dosyanın altında `## Comments` başlığı altına eklenir

## "issue tracker'a yayınla" denildiğinde

`.scratch/<feature-slug>/` altında yeni dosya oluştur (dizin yoksa yarat).

## "ilgili ticket'ı getir" denildiğinde

Verilen yoldaki dosyayı oku. Kullanıcı normalde yolu veya issue numarasını doğrudan verir.
