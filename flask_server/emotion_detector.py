import os
import numpy as np
import cv2
import base64
import tempfile
import time
import json
from collections import deque
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from keras.models import load_model
import librosa
import joblib
import warnings
warnings.filterwarnings('ignore')

app = Flask(__name__)
CORS(app)

# ======================= CONFIGURATION =======================
SAMPLE_RATE = 22050
DURATION = 3
N_MFCC = 13

# Model paths (update these to your actual model paths)
MODEL_PATHS = {
    'face': {
        'emotion_model': 'model_files/face/EmotionRecognition.h5'
    },
    'voice': {
        'knn': 'model_files/voice/knn2.pkl',
        'label_encoder': 'model_files/voice/label2_encoder.pkl',
        'pca': 'model_files/voice/pca2.pkl',
        'scaler': 'model_files/voice/scaler2.pkl'
    }
}

# Emotion mappings
FACE_EMOTIONS = {
    0: "Angry", 1: "Disgust", 2: "Fear", 3: "Happy",
    4: "Neutral", 5: "Sad", 6: "Surprise"
}

VOICE_EMOTIONS = ['angry', 'happy', 'sad', 'neutral', 'fear', 'surprise']

# ======================= SESSION MANAGER =======================
class EmotionSession:
    def __init__(self, session_id, user_name, character_id=None):
        self.session_id = session_id
        self.user_name = user_name
        self.character_id = character_id
        self.start_time = datetime.now()
        self.face_emotions = deque(maxlen=300)
        self.voice_emotions = deque(maxlen=100)
        self.combined_emotions = deque(maxlen=400)
        self.emotion_timeline = []

    def add_face_emotion(self, emotion, confidence, timestamp=None):
        if timestamp is None:
            timestamp = datetime.now().isoformat()
        self.face_emotions.append({'emotion': emotion, 'confidence': confidence, 'timestamp': timestamp})
        self.combined_emotions.append({'type': 'face', 'emotion': emotion, 'confidence': confidence, 'timestamp': timestamp})
        self.emotion_timeline.append({'time': timestamp, 'type': 'face', 'emotion': emotion, 'confidence': confidence})
        print(f"\n🎭 [FACE EMOTION] {emotion} ({confidence*100:.1f}%)")

    def add_voice_emotion(self, emotion, confidence, timestamp=None):
        if timestamp is None:
            timestamp = datetime.now().isoformat()
        self.voice_emotions.append({'emotion': emotion, 'confidence': confidence, 'timestamp': timestamp})
        self.combined_emotions.append({'type': 'voice', 'emotion': emotion, 'confidence': confidence, 'timestamp': timestamp})
        self.emotion_timeline.append({'time': timestamp, 'type': 'voice', 'emotion': emotion, 'confidence': confidence})
        print(f"\n🎭 [VOICE EMOTION] {emotion} ({confidence*100:.1f}%)")

    def get_dominant_emotion(self):
        if not self.combined_emotions:
            return "neutral", 0.0, {}
        emotion_scores = {}
        for entry in self.combined_emotions:
            weight = 0.6 if entry['type'] == 'face' else 0.4
            emotion = entry['emotion'].lower()
            confidence = entry['confidence']
            emotion_scores[emotion] = emotion_scores.get(emotion, 0) + (confidence * weight)
        total_score = sum(emotion_scores.values())
        if total_score > 0:
            for emotion in emotion_scores:
                emotion_scores[emotion] /= total_score
        dominant = max(emotion_scores.items(), key=lambda x: x[1])
        return dominant[0], dominant[1], emotion_scores

    def get_emotion_timeline(self, limit=50):
        return self.emotion_timeline[-limit:]

    def get_emotion_stats(self):
        if not self.combined_emotions:
            return {}
        face_emotions = [e['emotion'].lower() for e in self.face_emotions]
        voice_emotions = [e['emotion'].lower() for e in self.voice_emotions]
        from collections import Counter
        face_counts = Counter(face_emotions) if face_emotions else {}
        voice_counts = Counter(voice_emotions) if voice_emotions else {}
        total_face = len(face_emotions) or 1
        total_voice = len(voice_emotions) or 1
        return {
            'face': {'count': len(self.face_emotions), 'emotions': {k: v/total_face for k, v in face_counts.items()}, 'dominant': max(face_counts.items(), key=lambda x: x[1])[0] if face_counts else 'neutral'},
            'voice': {'count': len(self.voice_emotions), 'emotions': {k: v/total_voice for k, v in voice_counts.items()}, 'dominant': max(voice_counts.items(), key=lambda x: x[1])[0] if voice_counts else 'neutral'},
            'total_samples': len(self.combined_emotions),
            'duration_seconds': (datetime.now() - self.start_time).total_seconds()
        }

    def get_session_summary(self):
        dominant_emotion, confidence, scores = self.get_dominant_emotion()
        stats = self.get_emotion_stats()
        timeline = self.emotion_timeline[-20:]
        if len(timeline) > 1:
            changes = sum(1 for i in range(1, len(timeline)) if timeline[i]['emotion'] != timeline[i-1]['emotion'])
            volatility = changes / len(timeline)
        else:
            volatility = 0
        emotion_descriptions = {'angry': 'frustration or irritation', 'happy': 'happiness and positivity', 'sad': 'sadness or melancholy', 'fear': 'anxiety or concern', 'surprise': 'surprise or unexpected reactions', 'neutral': 'neutral emotions', 'disgust': 'discomfort or aversion'}
        emotion_desc = emotion_descriptions.get(dominant_emotion, 'mixed emotions')
        intensity = "high intensity" if confidence > 0.7 else ("moderate intensity" if confidence > 0.3 else "low intensity")
        stability = "significant emotional fluctuation" if volatility > 0.5 else "relatively stable emotions"
        summary = f"Throughout the conversation, the user predominantly expressed {emotion_desc} at {intensity} with {stability}."
        return {
            'session_id': self.session_id, 'user_name': self.user_name, 'character_id': self.character_id,
            'duration_seconds': stats['duration_seconds'], 'dominant_emotion': dominant_emotion,
            'dominant_confidence': confidence, 'emotion_scores': scores, 'emotional_stability': 1 - volatility,
            'volatility': volatility, 'statistics': stats, 'summary': summary, 'timeline': self.get_emotion_timeline(30)
        }

# ======================= MODEL LOADER =======================
class EmotionModelLoader:
    def __init__(self):
        self.face_model = None
        self.voice_knn = None
        self.voice_label_encoder = None
        self.voice_pca = None
        self.voice_scaler = None
        self.expected_features = None
        self.load_models()

    def load_models(self):
        print("\n" + "="*50)
        print("🔧 LOADING EMOTION MODELS")
        print("="*50)
        try:
            self.face_model = load_model(MODEL_PATHS['face']['emotion_model'])
            print("✓ Face emotion model loaded")
        except Exception as e:
            print(f"✗ Face model error: {e}")
        try:
            self.voice_knn = joblib.load(MODEL_PATHS['voice']['knn'])
            self.voice_label_encoder = joblib.load(MODEL_PATHS['voice']['label_encoder'])
            self.voice_pca = joblib.load(MODEL_PATHS['voice']['pca'])
            self.voice_scaler = joblib.load(MODEL_PATHS['voice']['scaler'])

            # Check expected feature count from scaler
            if hasattr(self.voice_scaler, 'mean_'):
                self.expected_features = self.voice_scaler.mean_.shape[0]
                print(f"✓ Voice emotion models loaded (expects {self.expected_features} features)")
            else:
                self.expected_features = 159  # Default based on training script
                print(f"✓ Voice emotion models loaded (unknown feature count, using {self.expected_features})")

        except Exception as e:
            print(f"✗ Voice models error: {e}")
            self.expected_features = 159
        print("="*50 + "\n")

    def extract_voice_features(self, audio_data, sr=SAMPLE_RATE):
        """
        Extract features that MATCH THE TRAINING SCRIPT exactly.
        Training script uses: mfcc(13) + chroma(12) + mel(128) + zcr(1) + rms(1)
        + spectral_centroid(1) + spectral_bandwidth(1) + spectral_rolloff(1) + spectral_flatness(1)
        Total: 13+12+128+1+1+1+1+1+1 = 159 features
        """
        try:
            if len(audio_data) < sr * 0.5:
                print(f"   ⚠️ Audio too short: {len(audio_data)} samples")
                return None

            if len(audio_data.shape) > 1:
                audio_data = audio_data.flatten()

            # Extract MFCC (13 features)
            mfccs = librosa.feature.mfcc(y=audio_data, sr=sr, n_mfcc=N_MFCC)
            mfccs_mean = np.mean(mfccs.T, axis=0)  # 13 features

            # Extract Chroma (12 features)
            chroma = librosa.feature.chroma_stft(y=audio_data, sr=sr)
            chroma_mean = np.mean(chroma.T, axis=0)  # 12 features

            # Extract Mel spectrogram (128 features)
            mel = librosa.feature.melspectrogram(y=audio_data, sr=sr, n_mels=128)
            mel_mean = np.mean(mel.T, axis=0)  # 128 features

            # Extract Zero Crossing Rate (1 feature)
            zcr = librosa.feature.zero_crossing_rate(audio_data)
            zcr_mean = np.mean(zcr.T, axis=0)[0]  # 1 feature

            # Extract RMS (1 feature)
            rms = librosa.feature.rms(y=audio_data)
            rms_mean = np.mean(rms.T, axis=0)[0]  # 1 feature

            # Extract Spectral Centroid (1 feature)
            spectral_centroids = librosa.feature.spectral_centroid(y=audio_data, sr=sr)
            spectral_centroids_mean = np.mean(spectral_centroids.T, axis=0)[0]  # 1 feature

            # Extract Spectral Bandwidth (1 feature) - ADD THIS!
            spectral_bandwidth = librosa.feature.spectral_bandwidth(y=audio_data, sr=sr)
            spectral_bandwidth_mean = np.mean(spectral_bandwidth.T, axis=0)[0]  # 1 feature

            # Extract Spectral Rolloff (1 feature)
            spectral_rolloff = librosa.feature.spectral_rolloff(y=audio_data, sr=sr)
            spectral_rolloff_mean = np.mean(spectral_rolloff.T, axis=0)[0]  # 1 feature

            # Extract Spectral Flatness (1 feature) - ADD THIS!
            spectral_flatness = librosa.feature.spectral_flatness(y=audio_data)
            spectral_flatness_mean = np.mean(spectral_flatness.T, axis=0)[0]  # 1 feature

            # Concatenate all features in the SAME ORDER as training
            all_features = np.concatenate([
                mfccs_mean,              # 13
                chroma_mean,             # 12
                mel_mean,                # 128
                [zcr_mean],              # 1
                [rms_mean],              # 1
                [spectral_centroids_mean],  # 1
                [spectral_bandwidth_mean],  # 1
                [spectral_rolloff_mean],    # 1
                [spectral_flatness_mean]    # 1
            ])  # Total: 13+12+128+1+1+1+1+1+1 = 159 features

            feature_count = len(all_features)
            print(f"   🔍 Extracted {feature_count} features")

            # Ensure correct feature count
            if self.expected_features and feature_count != self.expected_features:
                print(f"   ⚠️ Feature count mismatch: {feature_count} vs expected {self.expected_features}")
                if feature_count < self.expected_features:
                    padding = np.zeros(self.expected_features - feature_count)
                    all_features = np.concatenate([all_features, padding])
                    print(f"   🔧 Padded to {len(all_features)} features")
                else:
                    all_features = all_features[:self.expected_features]
                    print(f"   🔧 Truncated to {len(all_features)} features")

            return all_features.reshape(1, -1)

        except Exception as e:
            print(f"Feature extraction error: {e}")
            return None

    def predict_face_emotion(self, face_image):
        if self.face_model is None:
            return None, 0.0
        try:
            if isinstance(face_image, np.ndarray):
                if len(face_image.shape) == 3:
                    gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
                else:
                    gray = face_image
            else:
                return None, 0.0
            resized = cv2.resize(gray, (48, 48))
            normalized = resized / 255.0
            input_data = np.reshape(normalized, (1, 48, 48, 1))
            predictions = self.face_model.predict(input_data, verbose=0)
            emotion_idx = np.argmax(predictions[0])
            confidence = float(np.max(predictions[0]))
            emotion = FACE_EMOTIONS.get(emotion_idx, "Neutral")
            return emotion, confidence
        except Exception as e:
            print(f"Face prediction error: {e}")
            return None, 0.0

    def predict_voice_emotion(self, audio_data):
        if any(model is None for model in [self.voice_knn, self.voice_scaler, self.voice_pca, self.voice_label_encoder]):
            print("   ⚠️ Voice models not loaded properly")
            return None, 0.0

        try:
            features = self.extract_voice_features(audio_data)
            if features is None:
                return None, 0.0

            print(f"   🔍 Feature shape: {features.shape}")

            # Scale features
            features_scaled = self.voice_scaler.transform(features)

            # Apply PCA
            features_pca = self.voice_pca.transform(features_scaled)

            # Predict
            prediction = self.voice_knn.predict(features_pca)
            emotion = self.voice_label_encoder.inverse_transform(prediction)[0]

            # Get confidence using distance-based method
            distances, indices = self.voice_knn.kneighbors(features_pca)
            # Convert distance to confidence (closer distance = higher confidence)
            confidence = 1.0 / (1.0 + np.mean(distances[0]))

            # Ensure confidence is reasonable (0-1)
            confidence = max(0.0, min(1.0, confidence))

            return emotion, confidence

        except Exception as e:
            print(f"Voice prediction error: {e}")
            return None, 0.0

# ======================= SESSION STORAGE =======================
active_sessions = {}
model_loader = EmotionModelLoader()

# ======================= API ENDPOINTS =======================

@app.route('/emotion/start_session', methods=['POST'])
def start_session():
    try:
        data = request.json
        session_id = data.get('session_id')
        user_name = data.get('user_name', 'User')
        character_id = data.get('character_id')
        if not session_id:
            session_id = str(int(time.time() * 1000))
        session = EmotionSession(session_id, user_name, character_id)
        active_sessions[session_id] = session
        print(f"\n{'='*60}")
        print(f"🎭 NEW EMOTION SESSION STARTED")
        print(f"{'='*60}")
        print(f"   Session ID: {session_id}")
        print(f"   User: {user_name}")
        print(f"   Character: {character_id}")
        if model_loader.expected_features:
            print(f"   Voice model expects: {model_loader.expected_features} features")
        print(f"{'='*60}\n")
        return jsonify({'success': True, 'session_id': session_id, 'message': 'Emotion tracking session started', 'models_available': {'face': model_loader.face_model is not None, 'voice': model_loader.voice_knn is not None}})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/emotion/analyze_face', methods=['POST'])
def analyze_face():
    try:
        data = request.json
        session_id = data.get('session_id')
        frame_data = data.get('frame')
        if not session_id or session_id not in active_sessions:
            return jsonify({'success': False, 'error': 'Invalid session'}), 400
        if not frame_data:
            return jsonify({'success': False, 'error': 'No frame data'}), 400
        if ',' in frame_data:
            frame_data = frame_data.split(',')[1]
        frame_bytes = base64.b64decode(frame_data)
        np_arr = np.frombuffer(frame_bytes, np.uint8)
        frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if frame is None:
            return jsonify({'success': False, 'error': 'Invalid frame'}), 400
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)
        emotions = []
        for (x, y, w, h) in faces:
            face_roi = gray[y:y+h, x:x+w]
            emotion, confidence = model_loader.predict_face_emotion(face_roi)
            if emotion:
                active_sessions[session_id].add_face_emotion(emotion, confidence)
                emotions.append({'emotion': emotion, 'confidence': confidence, 'bbox': [int(x), int(y), int(w), int(h)]})
        dominant_emotion, dominant_conf, _ = active_sessions[session_id].get_dominant_emotion()
        return jsonify({'success': True, 'emotions': emotions, 'dominant_emotion': dominant_emotion, 'dominant_confidence': dominant_conf, 'face_count': len(faces)})
    except Exception as e:
        print(f"Face analysis error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/emotion/analyze_audio', methods=['POST'])
def analyze_audio():
    try:
        data = request.json
        session_id = data.get('session_id')
        audio_data = data.get('audio')
        if not session_id or session_id not in active_sessions:
            return jsonify({'success': False, 'error': 'Invalid session'}), 400
        if not audio_data:
            return jsonify({'success': False, 'error': 'No audio data'}), 400
        if ',' in audio_data:
            audio_data = audio_data.split(',')[1]
        audio_bytes = base64.b64decode(audio_data)

        print(f"\n🎵 Processing voice audio...")

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
                tmp_file.write(audio_bytes)
                tmp_file.flush()
                tmp_path = tmp_file.name

            # Load audio
            audio, sr = librosa.load(tmp_path, sr=SAMPLE_RATE, duration=DURATION)
            print(f"   📊 Audio loaded: {len(audio)} samples, {sr} Hz")

            # Predict emotion
            emotion, confidence = model_loader.predict_voice_emotion(audio)

            if emotion:
                active_sessions[session_id].add_voice_emotion(emotion, confidence)
                result = {'emotion': emotion, 'confidence': confidence}
                print(f"   ✅ Voice analysis complete: {emotion} ({confidence*100:.1f}%)")
            else:
                result = None
                print(f"   ⚠️ No voice emotion detected")

        except Exception as e:
            print(f"Audio processing error: {e}")
            result = None
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except:
                    pass

        dominant_emotion, dominant_conf, _ = active_sessions[session_id].get_dominant_emotion()

        return jsonify({'success': True, 'voice_emotion': result, 'dominant_emotion': dominant_emotion, 'dominant_confidence': dominant_conf})
    except Exception as e:
        print(f"Audio analysis error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/emotion/get_session_emotion', methods=['POST'])
def get_session_emotion():
    try:
        data = request.json
        session_id = data.get('session_id')
        if not session_id or session_id not in active_sessions:
            return jsonify({'success': False, 'error': 'Invalid session'}), 400
        session = active_sessions[session_id]
        dominant_emotion, confidence, scores = session.get_dominant_emotion()
        stats = session.get_emotion_stats()
        return jsonify({'success': True, 'session_id': session_id, 'dominant_emotion': dominant_emotion, 'confidence': confidence, 'emotion_scores': scores, 'statistics': stats, 'timeline': session.get_emotion_timeline(10)})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/emotion/end_session', methods=['POST'])
def end_session():
    try:
        data = request.json
        session_id = data.get('session_id')
        if not session_id or session_id not in active_sessions:
            return jsonify({'success': False, 'error': 'Invalid session'}), 400
        session = active_sessions[session_id]
        final_analysis = session.get_session_summary()

        print("\n" + "="*60)
        print("🎭 FINAL EMOTION ANALYSIS REPORT")
        print("="*60)
        print(f"\n📊 SESSION INFORMATION:")
        print(f"   User: {final_analysis['user_name']}")
        print(f"   Session ID: {final_analysis['session_id']}")
        print(f"   Duration: {final_analysis['duration_seconds']:.1f} seconds ({final_analysis['duration_seconds']/60:.1f} minutes)")
        print(f"\n🎯 DOMINANT EMOTION:")
        print(f"   {final_analysis['dominant_emotion'].upper()} ({final_analysis['dominant_confidence']*100:.1f}%)")
        print(f"\n📈 EMOTIONAL STABILITY:")
        print(f"   Stability Score: {final_analysis['emotional_stability']*100:.1f}%")
        print(f"   Volatility: {final_analysis['volatility']*100:.1f}%")
        print(f"\n📊 EMOTION DISTRIBUTION:")
        scores = final_analysis['emotion_scores']
        sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        for emotion, score in sorted_scores:
            bar_length = int(score * 30)
            bar = "█" * bar_length
            print(f"   {emotion.capitalize():10} {bar} {score*100:.1f}%")
        print(f"\n📝 SUMMARY:")
        print(f"   {final_analysis['summary']}")
        print(f"\n📊 STATISTICS:")
        stats = final_analysis['statistics']
        if 'face' in stats:
            print(f"   Face detections: {stats['face']['count']}")
            print(f"   Face dominant: {stats['face']['dominant']}")
        if 'voice' in stats:
            print(f"   Voice detections: {stats['voice']['count']}")
            print(f"   Voice dominant: {stats['voice']['dominant']}")
        else:
            print(f"   Voice detections: 0")
        print(f"   Total samples: {stats['total_samples']}")
        print("\n" + "="*60)
        print("✅ EMOTION ANALYSIS COMPLETE")
        print("="*60 + "\n")

        del active_sessions[session_id]
        return jsonify({'success': True, 'final_analysis': final_analysis})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/emotion/health', methods=['GET'])
def health_check():
    return jsonify({'success': True, 'status': 'running', 'active_sessions': len(active_sessions), 'models_loaded': {'face': model_loader.face_model is not None, 'voice': model_loader.voice_knn is not None}})

if __name__ == '__main__':
    print("\n" + "="*60)
    print("🎭 EMOTION ANALYSIS SERVER")
    print("="*60)
    print("\n📡 Endpoints:")
    print("  POST /emotion/start_session     - Start tracking session")
    print("  POST /emotion/analyze_face      - Analyze face frame")
    print("  POST /emotion/analyze_audio     - Analyze audio")
    print("  POST /emotion/get_session_emotion - Get current emotion")
    print("  POST /emotion/end_session       - End session & get analysis")
    print("  GET  /emotion/health            - Health check")
    print("\n🚀 Starting server on port 5002...")
    print("\n💡 Waiting for emotion data from Flutter app...")
    print("="*60 + "\n")
    app.run(host='0.0.0.0', port=5002, debug=False, threaded=True)