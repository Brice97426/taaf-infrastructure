FROM python:3.9-slim

WORKDIR /app

# Installer requests
RUN pip install --no-cache-dir requests

# Copier le script
COPY gitlab-webhook.py .

# Rendre le script exécutable
RUN chmod +x gitlab-webhook.py

EXPOSE 8090

CMD ["python", "-u", "gitlab-webhook.py"]
