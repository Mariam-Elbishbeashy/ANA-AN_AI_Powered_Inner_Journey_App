from flask import Flask
from flask_cors import CORS

# ✅ voice_routes.py is in the same folder (flask_server)
from voice_routes import voice_bp

app = Flask(__name__)
CORS(app)

# ✅ register the blueprint (/voice/*)
app.register_blueprint(voice_bp)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5004, debug=True)
