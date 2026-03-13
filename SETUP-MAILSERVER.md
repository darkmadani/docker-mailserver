# Setup Mailserver dengan SSL (DNS Challenge)

## Arsitektur

```
┌─────────────────────────────────────────┐
│  Acme.sh Container                      │
│  - Generate SSL via Cloudflare DNS      │
│  - Auto-renew setiap 60 hari            │
│  - Share cert via volume                │
└─────────────────────────────────────────┘
              ↓ (shared volume)
┌─────────────────────────────────────────┐
│  Mailserver Container                   │
│  - Postfix (SMTP: 25, 465, 587)        │
│  - Dovecot (IMAP: 143, 993)            │
│  - Baca cert dari /etc/letsencrypt     │
└─────────────────────────────────────────┘
```

## Langkah Setup

### 1. Pastikan DNS Sudah Benar

Cek di Cloudflare:
- ✅ A record: `mail.madev.cloud` → IP server
- ✅ MX record: `madev.cloud` → `mail.madev.cloud`

Verifikasi:
```bash
dig mail.madev.cloud +short
dig madev.cloud MX +short
```

### 2. Deploy Container

```bash
# Di Dokploy, commit & push perubahan
git add .
git commit -m "Setup mailserver dengan acme.sh"
git push

# Atau manual:
docker compose up -d
```

### 3. Generate SSL Certificate

Setelah container running:

```bash
# Jalankan script setup SSL
chmod +x setup-ssl.sh
./setup-ssl.sh
```

Script akan:
1. Request certificate dari Let's Encrypt via Cloudflare DNS
2. Install certificate ke `/etc/letsencrypt/live/mail.madev.cloud/`
3. Restart mailserver untuk apply certificate

### 4. Buat Email Account

```bash
# Buat email pertama
docker exec -it mailserver setup email add admin@madev.cloud YourPassword123

# List email accounts
docker exec -it mailserver setup email list

# Update password
docker exec -it mailserver setup email update admin@madev.cloud NewPassword456

# Hapus email
docker exec -it mailserver setup email del user@madev.cloud
```

### 5. Setup DKIM

```bash
# Generate DKIM key
docker exec -it mailserver setup config dkim

# Lihat DKIM record untuk ditambahkan ke DNS
docker exec -it mailserver cat /tmp/docker-mailserver/opendkim/keys/madev.cloud/mail.txt
```

Copy output dan tambahkan sebagai TXT record di Cloudflare:
- Name: `mail._domainkey.madev.cloud`
- Type: TXT
- Value: (dari output di atas)

### 6. Setup SPF & DMARC

Tambahkan di Cloudflare DNS:

**SPF Record:**
- Name: `madev.cloud`
- Type: TXT
- Value: `v=spf1 mx ~all`

**DMARC Record:**
- Name: `_dmarc.madev.cloud`
- Type: TXT
- Value: `v=DMARC1; p=quarantine; rua=mailto:postmaster@madev.cloud`

## Troubleshooting

### Certificate Tidak Ter-generate

```bash
# Cek logs acme container
docker logs acme-mailserver

# Manual generate
docker exec -it acme-mailserver acme.sh --issue --dns dns_cf -d mail.madev.cloud
```

### Mailserver Tidak Start

```bash
# Cek logs
docker logs mailserver -f

# Cek certificate ada
docker exec mailserver ls -la /etc/letsencrypt/live/mail.madev.cloud/
```

### Test Koneksi

```bash
# Test SMTP
telnet mail.madev.cloud 25

# Test IMAP
openssl s_client -connect mail.madev.cloud:993

# Test SMTP TLS
openssl s_client -connect mail.madev.cloud:465
```

## Auto-Renewal

Acme.sh akan otomatis renew certificate setiap 60 hari. Untuk manual renew:

```bash
docker exec acme-mailserver acme.sh --renew -d mail.madev.cloud --force
docker restart mailserver
```

## Backup & Restore

### Backup

```bash
# Backup volumes
docker run --rm \
  -v madev_mailserver-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/mailserver-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore

```bash
# Restore volumes
docker run --rm \
  -v madev_mailserver-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/mailserver-backup-YYYYMMDD.tar.gz -C /
```

## Monitoring

```bash
# Cek status services
docker exec mailserver supervisorctl status

# Cek mail queue
docker exec mailserver postqueue -p

# Cek logs
docker exec mailserver tail -f /var/log/mail/mail.log
```
