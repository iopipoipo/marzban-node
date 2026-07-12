#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Environment
# ==============================
export PORT="${PORT:-8080}"
export SERVICE_HOST="${SERVICE_HOST:-0.0.0.0}"
export SERVICE_PROTOCOL="${SERVICE_PROTOCOL:-rest}"
export SERVICE_TLS="${SERVICE_TLS:-true}"
export XRAY_EXECUTABLE_PATH="${XRAY_EXECUTABLE_PATH:-/usr/local/bin/xray}"
export XRAY_ASSETS_PATH="${XRAY_ASSETS_PATH:-/usr/local/share/xray}"

SSL_DIR="${SSL_DIR:-/var/lib/marzban-node}"
mkdir -p "$SSL_DIR"

export SSL_CERT_FILE="$SSL_DIR/ssl_cert.pem"
export SSL_KEY_FILE="$SSL_DIR/ssl_key.pem"
export SSL_CLIENT_CERT_FILE="$SSL_DIR/ssl_client_cert.pem"

# ==============================
# کپی گواهی کلاینت پنل (باید قبل از دیپلوی جایگزین شده باشد)
# ==============================
if [ -f "/code/ssl_client_cert.pem" ] && [ -s "/code/ssl_client_cert.pem" ]; then
    cp /code/ssl_client_cert.pem "$SSL_CLIENT_CERT_FILE"
    chmod 644 "$SSL_CLIENT_CERT_FILE"

    # چک ساده: آیا محتوا واقعاً شبیه یک گواهی PEM است یا همان placeholder خالی/نمونه؟
    if ! grep -q "BEGIN CERTIFICATE" "$SSL_CLIENT_CERT_FILE"; then
        echo "=================================================================="
        echo "❌ خطا: /code/ssl_client_cert.pem محتوای معتبر گواهی PEM ندارد."
        echo ""
        echo "این فایل باید قبل از push، با گواهی واقعی «کلاینت پنل مرزبان»"
        echo "جایگزین شود. مراحل:"
        echo "  1) در شل Railway (یا سرور) پنل مرزبان اجرا کن:"
        echo "     cat /var/lib/marzban/certs/ssl_client_cert.pem"
        echo "  2) خروجی کامل (شامل خطوط BEGIN/END CERTIFICATE) را کپی کن"
        echo "  3) در ریپوی این نود، فایل ssl_client_cert.pem را با همان محتوا"
        echo "     جایگزین کن و دوباره push/deploy کن"
        echo "=================================================================="
        exit 1
    fi
else
    echo "=================================================================="
    echo "❌ خطا: فایل /code/ssl_client_cert.pem وجود ندارد یا خالی است."
    echo ""
    echo "این نود بدون گواهی کلاینت واقعی پنل نمی‌تواند استارت شود."
    echo "همان ۳ مرحله بالا را انجام بده."
    echo "=================================================================="
    exit 1
fi

# ==============================
# ساخت گواهی TLS خود نود (برای رمزنگاری کانال REST بین پنل و نود)
# ==============================
if [ ! -f "$SSL_CERT_FILE" ] || [ ! -f "$SSL_KEY_FILE" ]; then
    echo "[marzban-node] generating TLS certificate..."
    # اگه دامنه TCP Proxy ریلوی رو از قبل می‌دونی، در NODE_PUBLIC_DOMAIN بذار
    # تا SAN گواهی درست ست بشه (مثلاً وقتی پنل هم SNI/hostname چک می‌کنه).
    CN="${NODE_PUBLIC_DOMAIN:-marzban-node}"
    openssl req \
        -x509 \
        -newkey rsa:2048 \
        -nodes \
        -days 3650 \
        -keyout "$SSL_KEY_FILE" \
        -out "$SSL_CERT_FILE" \
        -subj "/CN=${CN}" \
        -addext "subjectAltName = DNS:${CN},DNS:localhost,IP:127.0.0.1"
    chmod 644 "$SSL_CERT_FILE" "$SSL_KEY_FILE"
    echo "[marzban-node] TLS certificate created for CN=${CN}"
fi

echo "=================================================================="
echo "[marzban-node] starting with:"
echo "  SERVICE_PROTOCOL=$SERVICE_PROTOCOL"
echo "  SERVICE_TLS=$SERVICE_TLS"
echo "  listen=$SERVICE_HOST:$PORT"
echo "  SSL_CERT_FILE=$SSL_CERT_FILE"
echo "  SSL_KEY_FILE=$SSL_KEY_FILE"
echo "  SSL_CLIENT_CERT_FILE=$SSL_CLIENT_CERT_FILE"
echo ""
echo "  یادآوری: پورت $PORT فقط برای کانال کنترلی REST بین پنل و نوده."
echo "  برای ترافیک واقعی کاربران (اینباندهای Xray که در پنل تعریف می‌کنی)،"
echo "  باید جداگانه در Railway → Settings → Networking → TCP Proxy"
echo "  همون پورت اینباند رو باز کنی، وگرنه کلاینت‌ها به نود وصل نمی‌شن."
echo "=================================================================="

exec python main.py
