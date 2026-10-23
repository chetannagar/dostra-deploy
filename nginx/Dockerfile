# Reverse proxy image for the Dostra CRM stack (production).
#
# Same as nginx:alpine, plus the Filament admin panel's static assets copied
# from the freshly built api image, so Nginx can serve them directly while
# everything dynamic goes to PHP-FPM. Rebuilt on every deploy, so the assets
# always match the deployed api version.
#
# "api" is an additional build context pointing at the api service
# (see docker-compose.prod.yml). The Nginx config itself is bind-mounted.
FROM nginx:1.27-alpine

COPY --from=api /var/www/html/public/css/filament /var/www/html/public/css/filament
COPY --from=api /var/www/html/public/js/filament /var/www/html/public/js/filament
COPY --from=api /var/www/html/public/fonts/filament /var/www/html/public/fonts/filament
