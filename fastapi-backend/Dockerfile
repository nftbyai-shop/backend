# Use an official base image
FROM python:3.12-slim

# Bring in curl and the CA bundle, then rebuild the trust store
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -sSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
      -o /usr/local/share/ca-certificates/aws-rds-g1.crt \
 && update-ca-certificates --fresh \
 && rm -rf /var/lib/apt/lists/*



# Set working directory
WORKDIR /app

# Copy dependency files first for better cache usage
COPY requirements.txt ./

# Install Python dependencies (no cache, fail on error)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Command to run your app (adjust if needed)
CMD ["uvicorn", "app.app:app", "--host", "0.0.0.0", "--port", "8080"]
