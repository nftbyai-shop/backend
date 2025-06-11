# Use an official base image
FROM python:3.12-slim
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
