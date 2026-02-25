from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "Hello from Itomata Flask Backend!",
        "platform": "AWS EKS",
        "status": "Healthy",
        "python_version": "3.8"
    })

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)