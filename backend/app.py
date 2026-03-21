from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


@app.route('/')
def home():
    return jsonify({
        "message": "Hello from Itomata Flask Backend!",
        "platform": "AWS EKS",
        "status": "Healthy",
        "python_version": "3.8"
    })


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
