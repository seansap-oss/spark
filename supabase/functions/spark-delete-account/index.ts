import { createClient } from 'npm:@supabase/supabase-js@2.119.2'

const allowedOrigins = new Set([
  'https://spark-plum-beta.vercel.app',
  'http://localhost:5173',
])

function response(origin: string | null, status: number, data: Record<string, unknown>) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...(origin && allowedOrigins.has(origin) ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : {}),
    },
  })
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get('Origin')
  if (origin && !allowedOrigins.has(origin)) return response(null, 403, { error: 'Origin not allowed' })
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': origin || 'https://spark-plum-beta.vercel.app',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
        'Access-Control-Max-Age': '3600',
        Vary: 'Origin',
      },
    })
  }
  if (request.method !== 'POST') return response(origin, 405, { error: 'POST required' })

  const authorization = request.headers.get('Authorization') || ''
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7) : ''
  if (!token) return response(origin, 401, { error: 'Sign in before deleting your account' })

  let confirmation: unknown
  try { confirmation = (await request.json()).confirmation } catch { return response(origin, 400, { error: 'Invalid request' }) }
  if (confirmation !== 'DELETE MY ACCOUNT') return response(origin, 400, { error: 'Confirmation phrase required' })

  const url = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY') ||
    JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}').default
  const secretKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ||
    JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}').default
  if (!url || !publishableKey || !secretKey) return response(origin, 503, { error: 'Account deletion is not configured' })

  const auth = createClient(url, publishableKey, { auth: { persistSession: false } })
  const { data: { user }, error: authError } = await auth.auth.getUser(token)
  if (authError || !user) return response(origin, 401, { error: 'Session expired. Sign in again.' })

  const admin = createClient(url, secretKey, { auth: { persistSession: false } })
  const bucket = admin.storage.from('spark-profile-photos')
  const chatBucket = admin.storage.from('spark-chat-media')
  try {
    // Removing an Auth user cascades their matches and messages. Remove the
    // private objects for both participants first so neither side is orphaned.
    const { data: matches, error: matchError } = await admin.from('spark_connections')
      .select('id,requester_id,recipient_id')
      .or(`requester_id.eq.${user.id},recipient_id.eq.${user.id}`)
      .limit(1000)
    if (matchError) throw matchError
    if ((matches || []).length === 1000) throw new Error('Too many matches for automatic media cleanup')
    const removeMediaFolder = async (folder: string) => {
      for (let page = 0; page < 100; page++) {
        const { data: files, error } = await chatBucket.list(folder, { limit: 100, offset: 0 })
        if (error) throw error
        const paths = (files || []).filter(file => file.id && file.name).map(file => `${folder}/${file.name}`)
        if (!paths.length) return
        const { error: removeError } = await chatBucket.remove(paths)
        if (removeError) throw removeError
      }
      throw new Error('Too many chat files for automatic cleanup')
    }
    for (const match of matches || []) {
      await removeMediaFolder(`${match.requester_id}/${match.id}`)
      await removeMediaFolder(`${match.recipient_id}/${match.id}`)
    }
    // Also remove any upload that failed before its message was posted.
    const { data: ownFolders, error: folderError } = await chatBucket.list(user.id, { limit: 1000 })
    if (folderError) throw folderError
    if ((ownFolders || []).length === 1000) throw new Error('Too many chat folders for automatic cleanup')
    for (const folder of ownFolders || []) {
      if (!folder.id && folder.name) await removeMediaFolder(`${user.id}/${folder.name}`)
    }
    // Storage objects must be removed through Storage before Auth user deletion.
    // Each member's photos are directly inside the folder named by their Auth ID.
    for (let page = 0; page < 20; page++) {
      const { data: files, error: listError } = await bucket.list(user.id, { limit: 100, offset: 0 })
      if (listError) throw listError
      const paths = (files || []).filter(file => file.id && file.name).map(file => `${user.id}/${file.name}`)
      if (!paths.length) break
      const { error: removeError } = await bucket.remove(paths)
      if (removeError) throw removeError
      if (page === 19) throw new Error('Too many photo files to remove in one request')
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
    if (deleteError) throw deleteError
    return response(origin, 200, { deleted: true })
  } catch (error) {
    console.error('Spark account deletion failed:', error)
    return response(origin, 500, { error: 'Deletion could not be completed. Please try again or contact Spark support.' })
  }
})
