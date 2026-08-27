# YANK (YouTube And Kut) - 컨테이너 이미지
# 시놀로지(Container Manager) / 클라우드 어디서든 동작
FROM python:3.12-slim

# ffmpeg + 클립보드(pyperclip)용 도구 설치 + deno(yt-dlp JS 런타임, 유튜브 403 방지)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        xclip \
        curl \
        unzip \
    && curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh \
    && apt-get purge -y curl unzip \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /app

# 의존성 먼저 설치 (레이어 캐시 활용)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 소스 복사
COPY app.py .
COPY .streamlit ./.streamlit

# yt-dlp는 유튜브 대응 패치가 잦아 빌드마다 최신으로 강제 갱신 (레이어 캐시로 구버전 고정 방지)
RUN pip install --no-cache-dir --upgrade yt-dlp

# 다운로드 결과가 저장될 위치 (docker volume으로 매핑)
ENV DOWNLOAD_DIR=/downloads
RUN mkdir -p /downloads

EXPOSE 8501

# 헬스체크: Streamlit 내장 health 엔드포인트
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8501/_stcore/health')" || exit 1

CMD ["streamlit", "run", "app.py", \
     "--server.address=0.0.0.0", \
     "--server.port=8501", \
     "--server.headless=true", \
     "--browser.gatherUsageStats=false"]
