# Kullanıcı sistemi / GitHub Pages

Bu paket GitHub Pages'e doğrudan yüklenir: https://selimhanc.github.io/iys/

## İki çalışma modu

`supabase-config.js` içindeki `mode` değerine göre:

| mode | Davranış |
| --- | --- |
| `local` | Kullanıcılar `localStorage`'da tutulur. Cihaz başına bağımsız çalışır, kurulum gerektirmez. |
| `supabase` | Giriş `auth.users`, profil `public.profiles` tablosunda. Tüm cihazlarda ortak kullanıcı havuzu. |

Kampanya / içerik / ekip verisi her iki modda da cihazda (IndexedDB) kalır.

## Veri katmanı

`projects`, `campaigns`, `storyboards`, `team`, `countries`, `institutions` ve `settings`
Supabase'de tutulur. IndexedDB artık yalnızca **yerel önbellek** görevi görür ve
çevrimdışı çalışmayı sağlar.

| Durum | Kaynak |
| --- | --- |
| Giriş yapılmış, çevrimiçi | Supabase (kaynak gerçek) |
| Giriş yapılmış, çevrimdışı | IndexedDB önbelleği, bağlantı gelince eşitlenir |
| `mode: 'local'` | IndexedDB (yedekleme / geri dönüş yolu) |

Her satırın tamamı `data` jsonb sütununda saklanır; ayrıca `name`, `campaign_id`,
`deadline` gibi kolonlar sorgulamak için kopyalanır. Yazmalar diff tabanlıdır,
650 ms debounce ile toplanır ve sadece değişen kayıtlar gönderilir.

### Veri taşıma (önemli)

Supabase boşken bir cihazda veri varsa **hiçbir şey sessizce silinmez**. Uygulama
"bu cihazdaki N kaydı Supabase'e taşınsın mı?" diye sorar; onaylanırsa taşır.
Aynı işlem `⚙ Ayarlar → ☁ Cihaz Verisini Taşı` ile elle de yapılabilir.

Supabase'de kayıt varsa cihazdakiler **geçersiz kılınır** (bulut kazanır). Bu yüzden
taşımayı ilk girişten hemen sonra yap.

## Edge Function (opsiyonel)

## Supabase kurulumu

1. Proje oluştur, ardından `supabase-schema.sql` içeriğini **SQL Editor → New query → Run** ile çalıştır.
2. `supabase-config.js` içinde `mode: 'supabase'`, `url` ve `anonKey` değerlerini gir.
   Bu değerler herkese açıktır; `service_role` key **asla** repoya konmaz.
3. **Authentication → Providers → Email** → `Confirm email` = **OFF**.
   Kullanıcı adları arkada sentetik e-postaya çevrilir (`admin@iys.app`), gerçek e-posta gönderilmez.
4. **Authentication → URL Configuration → Site URL** = `https://selimhanc.github.io/iys/`
5. Uygulamadan `admin` kullanıcı adıyla üye ol, sonra SQL Editor'da çalıştır:
   ```sql
   update public.profiles set is_admin = true, status = 'active' where username = 'admin';
   ```
6. Yöneticiye "Şifre üret" özelliği için Edge Function gerekir.
   Dashboard → **Edge Functions → New Function** → `supabase/functions/admin-users/index.ts` içeriğini yapıştır → Deploy.
   Sonra `supabase-config.js` içindeki `adminFn` değerini
   `https://<proje-ref>.supabase.co/functions/v1/admin-users` yap.
   Onayla / reddet işlemleri RLS ile tarayıcıdan çalışır, fonksiyon yalnızca şifre işlemi içindir.

## Notlar

- Şifreler hiçbir koşulda düz metin tutulmaz; Supabase Auth `bcrypt` ile hash'ler.
- Kullanıcı kayıtları `pending` başlar, admin onayı olmadan giriş yapılamaz.
- RLS herkese açıktır: kullanıcı yalnızca kendi satırlarını, admin tüm kullanıcı
  satırlarını okur. Kampanya verisi yalnızca sahibine görünür.
- Üst bardaki `☁ Supabase · eşitlendi` göstergesi senkronizasyon durumunu bildirir.
- Geri dönmek için `supabase-config.js` içinde `mode: 'local'` yapmak yeterlidir.
