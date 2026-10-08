// Supabase Edge Function: admin-users
// Admin-only user management for the Content Management System.
// Deploy: Supabase Dashboard > Edge Functions > New Function > paste this file > Deploy.
// Or: supabase functions deploy admin-users
//
// After deploying, set supabase-config.js -> adminFn:
//   https://<project-ref>.supabase.co/functions/v1/admin-users

import { createClient } from 'jsr:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })

function password() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  const bytes = new Uint8Array(8)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, b => chars[b % chars.length]).join('')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Yetkisiz.' }, 401)

  const caller = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user) return json({ error: 'Oturum gecersiz.' }, 401)

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  const { data: profile } = await admin
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single()

  if (!profile?.is_admin) return json({ error: 'Bu islem icin yonetici yetkisi gerekir.' }, 403)

  let body = {}
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Gecersiz istek.' }, 400)
  }

  const { action, userId } = body

  if (action === 'list') {
    const { data, error } = await admin
      .from('profiles')
      .select('id,username,phone,status,is_admin,created_at,approved_at')
      .order('created_at', { ascending: false })
    if (error) return json({ error: error.message }, 500)
    return json({ users: data })
  }

  if (action === 'approve' || action === 'reject') {
    if (!userId) return json({ error: 'userId gerekli.' }, 400)
    if (userId === user.id) return json({ error: 'Kendi hesabinizi degistiremezsiniz.' }, 400)
    const status = action === 'approve' ? 'active' : 'rejected'
    const { error } = await admin
      .from('profiles')
      .update({ status, approved_at: status === 'active' ? new Date().toISOString() : null })
      .eq('id', userId)
    if (error) return json({ error: error.message }, 500)
    return json({ ok: true, status })
  }

  if (action === 'set-password') {
    if (!userId) return json({ error: 'userId gerekli.' }, 400)
    if (userId === user.id) return json({ error: 'Kendi sifrenizi degistiremezsiniz.' }, 400)
    const pass = typeof body.password === 'string' && body.password.length >= 8
      ? body.password
      : password()

    const { data: target } = await admin
      .from('profiles')
      .select('id,username')
      .eq('id', userId)
      .single()

    const { error } = await admin.auth.admin.updateUserById(userId, {
      password: pass,
      email_confirm: true,
    })
    if (error) return json({ error: error.message }, 500)

    await admin.from('profiles')
      .update({ status: 'active', approved_at: new Date().toISOString() })
      .eq('id', userId)

    return json({ ok: true, username: target?.username, password: pass })
  }

  if (action === 'delete') {
    if (!userId) return json({ error: 'userId gerekli.' }, 400)
    if (userId === user.id) return json({ error: 'Kendi hesabinizi silemezsiniz.' }, 400)
    const { error } = await admin.auth.admin.deleteUser(userId)
    if (error) return json({ error: error.message }, 500)
    return json({ ok: true })
  }

  return json({ error: 'Bilinmeyen islem.' }, 400)
})
