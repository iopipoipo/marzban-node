# ---------------- BUILD ----------------
FROM python:3.12-slim AS build
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /code

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        unzip \
        ca-certificates \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# به‌جای پین‌کردن دستی نسخه‌ی قدیمی Xray (که باعث ناسازگاری با کانفیگ‌های
# جدید پنل و کرش خاموش می‌شد)، از همون اسکریپت رسمی Marzban-scripts استفاده
# می‌کنیم که همیشه آخرین نسخه سازگار را نصب می‌کند — دقیقاً همون اسکریپتی
# که خود پنل هم برای نصب Xray استفاده می‌کند.
RUN curl -L https://github.com/Gozargah/Marzban-scripts/raw/master/install_latest_xray.sh | bash \
    && /usr/local/bin/xray version

COPY requirements.txt /code/
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# ---------------- RUNTIME ----------------
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    SERVICE_HOST=0.0.0.0 \
    SERVICE_PROTOCOL=rest \
    SERVICE_TLS=true \
    XRAY_EXECUTABLE_PATH=/usr/local/bin/xray \
    XRAY_ASSETS_PATH=/usr/local/share/xray \
    SSL_DIR=/var/lib/marzban-node

WORKDIR /code

COPY --from=build \
    /usr/local/lib/python3.12/site-packages \
    /usr/local/lib/python3.12/site-packages
COPY --from=build \
    /usr/local/bin/xray \
    /usr/local/bin/xray
COPY --from=build \
    /usr/local/share/xray \
    /usr/local/share/xray

# app files (شامل ssl_client_cert.pem که باید قبل از build جایگزین شده باشد -- به README مراجعه کن)
COPY . /code

RUN groupadd --system --gid 1001 app \
    && useradd --system --uid 1001 --gid app app \
    && mkdir -p /var/lib/marzban-node \
    && chown -R app:app /code /var/lib/marzban-node \
    && chmod +x /code/start.sh
USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,ssl,os; urllib.request.urlopen('https://127.0.0.1:'+os.getenv('PORT','8080')+'/health',context=ssl._create_unverified_context())"

ENTRYPOINT ["bash","/code/start.sh"]
