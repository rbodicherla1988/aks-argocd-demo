FROM python:3.12-alpine

WORKDIR /app

RUN apk add --no-cache ca-certificates \
  && adduser -D -u 10001 agent

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER agent
WORKDIR /app/src
ENTRYPOINT ["python", "main.py"]
