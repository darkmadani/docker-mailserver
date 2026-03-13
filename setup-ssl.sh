#!/bin/bash

# Script untuk generate SSL certificate menggunakan acme.sh dengan Cloudflare DNS

echo "=== Setup SSL Certificate untuk mail.madev.cloud ==="

# Tunggu acme container ready
echo "Menunggu acme container siap..."
sleep 5

# Generate certificate
echo "Generating certificate dengan Cloudflare DNS challenge..."
docker exec acme-mailserver acme.sh --issue \
  --dns dns_cf \
  -d mail.madev.cloud \
  --server letsencrypt \
  --keylength 4096

# Install certificate ke folder yang benar
echo "Installing certificate..."
docker exec acme-mailserver acme.sh --install-cert \
  -d mail.madev.cloud \
  --cert-file /etc/letsencrypt/live/mail.madev.cloud/cert.pem \
  --key-file /etc/letsencrypt/live/mail.madev.cloud/privkey.pem \
  --fullchain-file /etc/letsencrypt/live/mail.madev.cloud/fullchain.pem \
  --ca-file /etc/letsencrypt/live/mail.madev.cloud/chain.pem

# Set permissions
echo "Setting permissions..."
docker exec acme-mailserver chmod -R 755 /etc/letsencrypt/live/mail.madev.cloud/

# Restart mailserver untuk apply certificate
echo "Restarting mailserver..."
docker restart mailserver

echo "=== SSL Setup Complete! ==="
echo ""
echo "Certificate location:"
echo "  - Cert: /etc/letsencrypt/live/mail.madev.cloud/fullchain.pem"
echo "  - Key:  /etc/letsencrypt/live/mail.madev.cloud/privkey.pem"
echo ""
echo "Certificate akan auto-renew setiap 60 hari."
