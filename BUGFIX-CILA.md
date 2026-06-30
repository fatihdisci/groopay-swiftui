# Bugfix Cila

## 2026-06-30

- Free/Pro kapsamı ürün kararına göre sadeleştirildi: core expense splitting özellikleri Free kaldı, Pro kapsamı sınırsız grup oluşturma ve gelişmiş dashboard analitikleriyle sınırlandı.
- Free oluşturulan aktif grup limiti 10'a çıkarıldı; davetle gruba katılma limiti etkilemeyecek şekilde server-side `create_group_with_limit` enforcement güncellendi.
