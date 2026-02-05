FROM python:3.14-slim@sha256:fa0acdcd760f0bf265bc2c1ee6120776c4d92a9c3a37289e17b9642ad2e5b83b

RUN useradd --create-home appuser
WORKDIR /home/appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser deploy deploy
COPY --chown=appuser:appuser app.py .

USER appuser

ENV HOST=0.0.0.0
ENV PORT=5000
EXPOSE 5000
CMD ["python", "app.py"]
