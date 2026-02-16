FROM python:3.11-slim

WORKDIR /workspace

# Install dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy conversion scripts
COPY *.py .

CMD ["python", "convert_embedding.py"]
