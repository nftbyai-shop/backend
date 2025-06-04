# Use an official base image
FROM python:3.12-alpine

# Set working directory
WORKDIR .

# Copy dependency files first for better cache usage
COPY requirements.txt ./

# Install Python dependencies (no cache, fail on error)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Command to run your app (adjust if needed)
CMD ["python", "produce_nft.py"]