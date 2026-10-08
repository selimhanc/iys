const CACHE='icerik-yonetim-sistemi-v4';
const ASSETS=['./','./index.html','./manifest.json','./supabase-config.js','./icon.svg','./icon-192.png','./icon-512.png'];

self.addEventListener('install',e=>{
  e.waitUntil(caches.open(CACHE).then(c=>Promise.allSettled(ASSETS.map(a=>c.add(a)))).then(()=>self.skipWaiting()));
});

self.addEventListener('activate',e=>{
  e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});

self.addEventListener('message',e=>{if(e.data==='skipWaiting')self.skipWaiting()});

self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET')return;
  const url=new URL(req.url);
  if(url.origin!==self.location.origin)return;

  if(req.mode==='navigate'){
    e.respondWith(
      fetch(req)
        .then(r=>{const copy=r.clone();caches.open(CACHE).then(c=>c.put(req,copy));return r})
        .catch(()=>caches.match('./index.html').then(c=>c||caches.match('./')))
    );
    return;
  }

  // network-first: always fresh when online, still works offline from cache
  e.respondWith(
    fetch(req)
      .then(r=>{
        if(r&&r.ok){const copy=r.clone();caches.open(CACHE).then(c=>c.put(req,copy))}
        return r;
      })
      .catch(()=>caches.match(req))
  );
});
