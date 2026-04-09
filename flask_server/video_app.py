from flask import Flask
from flask_cors import CORS

# Import both blueprints
from video_chat import video_bp
from video_chat_guider import guider_video_bp

app = Flask(__name__)
CORS(app)

# Register both blueprints with different prefixes
app.register_blueprint(video_bp, url_prefix="/video")           # Original video chat endpoints
app.register_blueprint(guider_video_bp, url_prefix="/guider")   # Guider video endpoints

if __name__ == "__main__":
    # Run both on the same port
    app.run(host="0.0.0.0", port=5003, debug=True)