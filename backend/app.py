from flask import Flask, request, jsonify
from flask_cors import CORS
from toxic_checker import ToxicChecker

app = Flask(__name__)
CORS(app)

checker = ToxicChecker()

def get_tox_label(risk_score, bert_score, sim_score):
    if risk_score >= 85:
        return "toxic"
    elif risk_score >= 75:
        return "harassment"
    elif risk_score >= 70:
        return "suspicious"
    else:
        return "none"

@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "status": "running",
        "endpoints": ["/health", "/analyze"]
    })

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.get_json(force=True)
    text = data.get("text", "")
    sender = data.get("sender", "unknown")
    timestamp = data.get("timestamp", 0)

    result = checker.analyze(text)
    tox_label = get_tox_label(
        result["risk_score"],
        result["tox_score"],
        result["similarity_score"]
    )

    return jsonify({
        **result,
        "tox_label": tox_label,
        "sender": sender,
        "timestamp": timestamp
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)