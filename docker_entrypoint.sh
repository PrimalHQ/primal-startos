#!/bin/sh

printf "\n\n [i] Starting Primal ...\n\n"

# 
CONF_FILE="/etc/nginx/conf.d/default.conf"
NGINX_CONF='server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
    listen 8080;
    listen 3443 ssl;
    http2 on;
    ssl_certificate /mnt/cert/main.cert.pem;
    ssl_certificate_key /mnt/cert/main.key.pem;

    server_name localhost;

    root /usr/share/nginx/html;
    index index.html index.htm;

    # Gzip settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
'
echo "$NGINX_CONF" > $CONF_FILE

cd /usr/share/nginx/html
cat <<EOF >service-worker.js
// Define the cache name for versioning
const CACHE_NAME = 'primal-pwa-cache-v1';

// Specify the assets to cache
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/$(ls assets/index-*.js)',
  '/$(ls assets/index-*.css)',
  '/$(ls assets/favicon-*.ico)',
  '/public/fonts.css',
  // Add all other assets like images, fonts from the public directory
  '/public/Nacelle/Nacelle-Regular.otf',
  '/public/RobotoCondensed/RobotoCondensed-Regular.ttf',
  // ... other font files and assets
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(ASSETS_TO_CACHE))
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cache => {
          if (cache !== CACHE_NAME) {
            return caches.delete(cache);
          }
        })
      );
    })
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Serve from cache if available, otherwise fetch from network
        return response || fetch(event.request);
      })
  );
});
EOF

cat << EOF >manifest.json
{
  "name": "Primal",
  "short_name": "Primal",
  "icons": [
    {
      "src": "public/primal-logo-large.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "start_url": ".",
  "display": "fullscreen",
  "orientation": "portrait"
}
EOF

HTML_FILE="/usr/share/nginx/html/index.html"

# Define the line to insert after
INSERT_AFTER='<\/title>'

# Define the manifest code to insert
INSERT_CODE='    <link rel="manifest" href="manifest.json">'

# Use sed to insert the code
sed -i "s|$INSERT_AFTER|$INSERT_AFTER\n$INSERT_CODE|" $HTML_FILE

# Define the worker code to be injected
CODE='    <script>\
    if ('"'"'serviceWorker'"'"' in navigator) {\
      window.addEventListener('"'"'load'"'"', function() {\
        navigator.serviceWorker.register('"'"'service-worker.js'"'"').then(function(registration) {\
          console.log('"'"'ServiceWorker registration successful with scope: '"'"', registration.scope);\
        }, function(err) {\
          console.log('"'"'ServiceWorker registration failed: '"'"', err);\
        });\
      });\
    }\
  </script>'

# Use awk to inject the worker code after the specified line
awk -v code="$CODE" '/lottie-player.js"><\/script>/ { print; print code; next }1' $HTML_FILE > temp.html && mv temp.html $HTML_FILE

_term() {
  echo "Caught SIGTERM signal!"
  kill -SIGTERM "$primal_process" 2>/dev/null
}

nginx -g 'daemon off;' &
primal_process=$!

trap _term SIGTERM

wait $primal_process
