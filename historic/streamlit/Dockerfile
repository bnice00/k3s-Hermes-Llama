FROM python:3.12-slim AS base


ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/home/appuser/.local/bin:$PATH"

 
WORKDIR /app

 
RUN useradd --create-home appuser && chown -R appuser:appuser /app

 
COPY --chown=appuser:appuser requirements.txt .

 
USER appuser

 
RUN pip install --no-cache-dir --user -r requirements.txt

 
COPY --chown=appuser:appuser . .

 
EXPOSE 8501


CMD ["streamlit", "run", "agent.py", "--server.address=0.0.0.0", "--server.port=8501", "--server.headless=true"]

