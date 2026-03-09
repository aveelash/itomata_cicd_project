from flask import Flask, jsonify
from flask_cors import CORS  # Import CORS

app = Flask(__name__)
CORS(app)  # This allows the frontend to communicate with this backend


@app.route('/')
def home():
    return jsonify({
        "message": "Hello from Itomata Flask Backend!",
        "platform": "AWS EKS",
        "status": "Healthy",
        "python_version": "3.8"
    })

# Add this route to match your frontend's fetch("/api/status")


@app.route('/api/status')
@app.route('/api/status/')
def status():
    return jsonify({
        "status": "Success",
        "message": "Backend is Connected Successfully!"
    })


@app.route('/health')
def health():
    return "OK", 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
