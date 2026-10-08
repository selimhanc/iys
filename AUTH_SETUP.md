# Kullanıcı sistemi / GitHub Pages

Bu paket GitHub Pages'e doğrudan yüklenebilir.

## Önemli güvenlik notu
`index.html` içindeki kullanıcı sistemi **yerel-first demo/fallback** olarak çalışır. Kullanıcılar farklı telefon/PC'lerden aynı hesapları görecekse gerçek bir backend gerekir. GitHub Pages tek başına ortak kullanıcı veritabanı değildir.

Önerilen üretim kurulumu: **Supabase Auth + profiles tablosu**. `supabase-schema.sql` bunun başlangıç şemasını içerir.

- Şifreler düz metin tutulmamalı.
- Service-role anahtarı kesinlikle GitHub'a konulmamalı.
- Kullanıcı kayıtları `pending` başlar.
- Admin onayından sonra `active` olur.
- Admin 8 karakterlik rastgele geçici şifre üretebilir; kopyalama ve WhatsApp paylaşımı arayüzü hazırdır.

## İlk yerel yönetici
İlk açılışta yerel mod otomatik olarak `admin` kullanıcı adını ve rastgele 8 karakterli bir şifreyi üretir ve sadece ilk kurulum ekranında gösterir. Telefon numarası daha sonra kullanıcı yönetiminden eklenebilir.

Gerçek çok cihazlı yayın için Supabase bağlantısını ekleyip bu yerel adaptörü backend adaptörüyle değiştirmek gerekir.
