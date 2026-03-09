# Using Python 3.8 as per your preference
FROM public.ecr.aws/docker/library/python:3.8-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Flask runs on 5000 by default
EXPOSE 5000

CMD ["python", "app.py"]