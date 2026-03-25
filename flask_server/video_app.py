from flask import Flask
from flask_cors import CORS

# ✅ video_chat.py is in the same folder (flask_server)
from video_chat import video_bp

app = Flask(__name__)
CORS(app)

# ✅ register the blueprint (/video/*)
app.register_blueprint(video_bp)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5003, debug=True)