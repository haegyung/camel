# Dockerfile for camel-ai based on pyproject.toml

# --- 빌드 단계 (Builder Stage) ---
# 1. 베이스 이미지 선택 (Python 3.10, 3.11, or 3.12)
FROM python:3.11-slim AS builder

# 2. 환경 변수 설정
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    WORKDIR=/app \
    VENV_PATH=/opt/venv

# 가상 환경 생성
RUN python -m venv $VENV_PATH
ENV PATH="$VENV_PATH/bin:$PATH" # Activate venv

# 3. 시스템 의존성 설치 (필요한 경우)
# camel-ai의 특정 기능(RAG, 미디어 처리 등)을 사용하려면 시스템 라이브러리가 필요할 수 있습니다.
# 필요에 따라 아래 주석을 해제하고 관련 패키지를 추가하세요. (예: libpq-dev, ffmpeg, libmupdf-dev 등)
# RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
#    build-essential \
#    # 예시: libpq-dev \
#    # 예시: ffmpeg \
#    && rm -rf /var/lib/apt/lists/*

# 4. Python 의존성 설치
# pyproject.toml만 먼저 복사하여 Docker 빌드 캐시 활용
COPY pyproject.toml ./

# pip 및 기본 빌드 도구(wheel, setuptools) 업그레이드
RUN pip install --no-cache-dir --upgrade pip wheel setuptools

# pyproject.toml에서 핵심 의존성([project].dependencies) 설치
# hatchling 빌드 백엔드를 사용하며, 오직 핵심 의존성만 설치됩니다.
RUN pip install --no-cache-dir --use-pep517 "."

# (선택 사항) 만약 'rag', 'web_tools' 같은 추가 기능 그룹 설치가 필요하다면:
# 아래 명령어의 주석을 풀고 필요한 그룹 이름을 대괄호 안에 나열하세요.
# RUN pip install --no-cache-dir --use-pep517 ".[rag, web_tools]"

# --- 실행 단계 (Runtime Stage) ---
FROM python:3.11-slim AS runtime

# 환경 변수 설정
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    WORKDIR=/app \
    VENV_PATH=/opt/venv \
    # 애플리케이션이 사용할 포트 번호 (컨테이너 내부 기준)
    # !!! 중요: 실제 애플리케이션 실행 스크립트가 사용하는 포트로 변경해야 합니다 !!!
    PORT=8000

ENV PATH="$VENV_PATH/bin:$PATH"

# 빌드 단계에서 생성된 가상 환경 복사
COPY --from=builder $VENV_PATH $VENV_PATH

# (선택 사항, 보안 강화) non-root 사용자 생성 및 사용
# RUN groupadd --system app && useradd --system --group app app
# USER app

# 5. 애플리케이션 코드 복사
# 나머지 소스 코드를 복사합니다. (.dockerignore 파일 사용 권장)
COPY . .

# 6. 포트 노출
# 위에서 설정한 PORT 환경 변수와 동일한 포트를 노출합니다.
EXPOSE ${PORT}

# 7. 애플리케이션 실행 명령어
# !!! 중요: 이 부분은 사용자가 'camel-ai' 라이브러리를 어떻게 사용하는지에 따라 완전히 달라집니다 !!!
#    - 'camel-ai'는 라이브러리입니다. 이 라이브러리를 사용하는 실행 스크립트(예: main.py, app.py)를 실행해야 합니다.
#    - 웹 API 서버(FastAPI 등)를 실행하는 경우 Gunicorn/Uvicorn 등을 사용합니다.
#    - 아래는 예시이며, 실제 실행 명령어로 반드시 교체해야 합니다.

# 예시 1: 만약 'main.py' 가 실행 파일이라면
CMD ["python", "main.py"] # 'main.py' 를 실제 실행 파일 이름으로 변경하세요.

# 예시 2: 만약 FastAPI 앱('app.main:app')을 Uvicorn으로 실행한다면 (FastAPI는 web_tools 의존성에 포함됨)
# CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "${PORT}"]
