FROM python:3.14-slim@sha256:cae66f2ef0ec51a9891263eeee7f987dacf0a9879e8aa9353d5606e0530619a5

RUN useradd --create-home appuser
WORKDIR /home/appuser

COPY pyproject.toml uv.lock ./
RUN set -eux; \
    uv_version="$(python -c 'import tomllib; data = tomllib.load(open("pyproject.toml", "rb")); print(next(dep.removeprefix("uv==") for dep in data["dependency-groups"]["forge-github-app-register"] if dep.startswith("uv==")))')"; \
    pip install --no-cache-dir "uv==${uv_version}"; \
    uv export --locked --only-group forge-github-app-register --format requirements-txt --no-hashes > /tmp/forge-github-app-register-requirements.txt; \
    pip install --no-cache-dir -r /tmp/forge-github-app-register-requirements.txt; \
    rm /tmp/forge-github-app-register-requirements.txt

COPY --chown=appuser:appuser .docker/forge-github-app-register/deploy deploy
COPY --chown=appuser:appuser .docker/forge-github-app-register/app.py .

USER appuser

ENV HOST=0.0.0.0
ENV PORT=5000
EXPOSE 5000
CMD ["python", "app.py"]
