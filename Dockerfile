# https://knightcinema.com/install-secure-muximux-ubuntu-16-04/
# Image de base
FROM debian

ARG email
ARG domain
# Installation de NGINX + PHP + LetsEncrypt + WGET + UNZIP avec apt-get
RUN apt-get update \
&& apt-get install -y wget unzip letsencrypt nginx php-fpm \
&& rm -rf /var/lib/apt/lists/*

# On partage un dossier de log
VOLUME /etc/nginx/sites-available

# On expose le port 80
EXPOSE 80
EXPOSE 443

# Installation de Muxumux à partir du site officiel
RUN mkdir -p /var/www/muximux \
&& cd /var/www/muximux \
&& wget -O muximux.zip https://github.com/mescon/Muximux/archive/master.zip \
&& unzip muximux.zip \
&& rm muximux.zip \
&& echo -e "server {\nlisten 80;\nlisten [::]:80;\nroot /var/www/muximux;\nindex index.html index.htm;\nserver_name $domain;\nlocation / {\ntry_files $uri $uri/ =404;\n}\nlocation ~ /.well-known {\nallow all;\n}\n}" >> /etc/nginx/sites-available/muximux.conf \
&& nginx -t \
&& letsencrypt certonly -a webroot --email $email --webroot-path=/var/www/muximux -d $domain --agree-tos \
&& openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048 \
&& echo -e "server {\nlisten 80;\nlisten [::]:80;\nserver_name $domain www.$domain;\nreturn 301 https://$server_name$request_uri;\n}\nserver {\n# SSL configuration\nlisten 443 ssl http2;\nlisten [::]:443 ssl http2;\nssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;\nssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;\nssl_protocols TLSv1 TLSv1.1 TLSv1.2;\nssl_prefer_server_ciphers on;\nssl_ciphers “EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH”;\nssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0\nssl_session_cache shared:SSL:10m;\nssl_session_tickets off; # Requires nginx >= 1.5.9\nssl_stapling on; # Requires nginx >= 1.3.7\nssl_stapling_verify on; # Requires nginx => 1.3.7\nresolver 8.8.8.8 8.8.4.4 valid=300s;\nresolver_timeout 5s;\nadd_header Strict-Transport-Security “max-age=63072000; includeSubDomains”;\nadd_header X-Frame-Options DENY;\nadd_header X-Content-Type-Options nosniff;\nssl_dhparam /etc/ssl/certs/dhparam.pem;\nlocation ~ \.php$ {\ninclude snippets/fastcgi-php.conf;\nfastcgi_pass unix:/run/php/php7.0-fpm.sock;\n}\nlocation ~ /\.ht {\ndeny all;\n}\nlocation ^~ /deluge/ {\nproxy_pass http://localhost:8112;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\nlocation ^~ /sonarr/ {\nproxy_pass http://localhost:8989/sonarr/;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\nlocation ^~ /radarr/ {\nproxy_pass http://localhost:7878/radarr/;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\nlocation ^~ /jackett/ {\nproxy_pass http://localhost:9117;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\nlocation ^~ /ombi/ {\nproxy_pass http://localhost:3579;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\nlocation ^~ /plex/ {\nproxy_pass http://localhost:32400/web/;\nproxy_set_header Host $host;\nproxy_set_header X-Real-IP $remote_addr;\nproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n}\n}" >> /etc/nginx/sites-available/muximux.conf \
&& nginx -t \
&& service nginx restart \
&& crontab -l > mycron \
&& echo -e "30 2 * * 1 /usr/bin/letsencrypt renew >> /var/log/le-renew.log\n35 2 * * 1 /bin/systemctl reload nginx" >> mycron \
&& crontab mycron \
&& rm mycron
