/* Supabase baglantisi.
   Bu dosya herkese aciktir; icine sadece Project URL ve anon (publishable) key yazilir.
   service_role key ASLA buraya veya GitHub'a konulmaz. */
window.SB_CONFIG = {
  mode: 'local',
  url: '',
  anonKey: '',
  emailDomain: 'iys.app',
  adminFn: ''
};

/* GitHub Pages + Supabase'a gecmek icin:
   1) mode: 'supabase' yap
   2) url ve anonKey'i Supabase Dashboard > Project Settings > API Keys > Project URL / anon (publishable) key
   3) email confirmations'i Authentication > Providers > Email > Confirm email = OFF yap
   4) Authentication > URL Configuration > Site URL = https://selimhanc.github.io/iys/
   'local' moda donerek cihazda kalan localStorage kullanimi geri alinir. */
