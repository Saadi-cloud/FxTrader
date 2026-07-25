

self.addEventListener('install', (event) => {
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
    // Minimal pass-through — required for installability, can expand later for offline caching
});
//{
//    "name": "OLX Trade",
//        "short_name": "OLX Trade",
//            "icons": [
//                { "src": "/images/brand/logoicon.png", "sizes": "192x192", "type": "image/png" },
//                { "src": "/images/brand/logoicon.png", "sizes": "512x512", "type": "image/png" }
//            ],
//                "start_url": "/",
//                    "display": "standalone",
//                        "background_color": "#0B0E11",
//                            "theme_color": "#0B0E11"
//}