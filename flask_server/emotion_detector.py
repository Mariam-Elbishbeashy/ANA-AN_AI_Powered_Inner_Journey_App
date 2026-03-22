import os
import numpy as np
import cv2
import pickle
import joblib
import tensorflow as tf
from tensorflow.keras.models import load_model
from typing import Dict, List, Any, Optional, Tuple
import librosa
import base64
from io import BytesIO
from PIL import Image
import traceback
from datetime import datetime, timedelta

# ============================================================================
# FACE EMOTION DETECTION
# ============================================================================

class FaceEmotionDetector:
    """Detect emotions from facial expressions using CNN model."""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.emotion_labels = ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral']
        self.face_cascade = None
        self.load_model()

    def load_model(self):
        """Load the emotion recognition model and face cascade."""
        try:
            if os.path.exists(self.model_path):
                # Suppress TensorFlow warnings
                import logging
                logging.getLogger('tensorflow').setLevel(logging.ERROR)

                self.model = load_model(self.model_path, compile=False)
                print(f"✅ Face emotion model loaded from {self.model_path}")
            else:
                print(f"⚠️ Face emotion model not found at {self.model_path}")

            # Load face cascade for face detection
            cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            self.face_cascade = cv2.CascadeClassifier(cascade_path)
            if self.face_cascade.empty():
                print("⚠️ Face cascade not loaded properly, using fallback method")
                self.face_cascade = None
        except Exception as e:
            print(f"❌ Error loading face emotion model: {e}")
            traceback.print_exc()

    def preprocess_face(self, face_img: np.ndarray) -> np.ndarray:
        """Preprocess face image for model input."""
        try:
            # Resize to 48x48 (common for emotion recognition)
            face_img = cv2.resize(face_img, (48, 48))
            # Convert to grayscale if needed
            if len(face_img.shape) == 3:
                face_img = cv2.cvtColor(face_img, cv2.COLOR_BGR2GRAY)
            # Normalize
            face_img = face_img.astype('float32') / 255.0
            # Add dimensions for model input
            face_img = np.expand_dims(face_img, axis=0)
            face_img = np.expand_dims(face_img, axis=-1)
            return face_img
        except Exception as e:
            print(f"❌ Error preprocessing face: {e}")
            return None

    def detect_emotion_from_frame(self, frame: np.ndarray) -> Dict[str, Any]:
        """Detect emotion from a single frame."""
        if self.model is None:
            return {'emotion': 'unknown', 'confidence': 0.0, 'face_detected': False}

        try:
            # Convert to grayscale for face detection
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            # Detect faces
            faces = []
            if self.face_cascade is not None:
                faces = self.face_cascade.detectMultiScale(
                    gray,
                    scaleFactor=1.1,
                    minNeighbors=5,
                    minSize=(30, 30)
                )

            if len(faces) == 0:
                return {'emotion': 'unknown', 'confidence': 0.0, 'face_detected': False}

            # Process the largest face
            (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])
            face_roi = gray[y:y+h, x:x+w]

            # Preprocess and predict
            processed_face = self.preprocess_face(face_roi)
            if processed_face is None:
                return {'emotion': 'unknown', 'confidence': 0.0, 'face_detected': True}

            predictions = self.model.predict(processed_face, verbose=0)[0]

            # Get top emotion
            emotion_idx = np.argmax(predictions)
            confidence = float(predictions[emotion_idx])
            emotion = self.emotion_labels[emotion_idx]

            return {
                'emotion': emotion.lower(),
                'confidence': confidence,
                'face_detected': True,
                'bbox': [int(x), int(y), int(w), int(h)]
            }
        except Exception as e:
            print(f"❌ Error detecting face emotion: {e}")
            return {'emotion': 'unknown', 'confidence': 0.0, 'face_detected': False}

    def detect_emotion_from_base64(self, base64_image: str) -> Dict[str, Any]:
        """Detect emotion from base64 encoded image."""
        try:
            # Decode base64 image
            if 'base64,' in base64_image:
                base64_image = base64_image.split('base64,')[1]

            img_bytes = base64.b64decode(base64_image)
            img_array = np.frombuffer(img_bytes, dtype=np.uint8)
            frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

            return self.detect_emotion_from_frame(frame)
        except Exception as e:
            print(f"❌ Error processing base64 image: {e}")
            return {'emotion': 'unknown', 'confidence': 0.0, 'face_detected': False}


# ============================================================================
# VOICE TONE EMOTION DETECTION - SIMPLIFIED VERSION
# ============================================================================

class VoiceToneDetector:
    """Detect emotions from voice tone using audio features and simple classifier."""

    def __init__(self, model_dir: str):
        self.model_dir = model_dir
        self.knn_model = None
        self.label_encoder = None
        self.pca = None
        self.scaler = None
        self.emotion_labels = ['neutral', 'calm', 'happy', 'sad', 'angry', 'fearful', 'disgust', 'surprised']
        self.use_simple_detection = False
        self.load_models()

    def load_models(self):
        """Load all voice emotion models with better error handling."""
        try:
            # Paths to model files
            knn_path = os.path.join(self.model_dir, 'knn2.pkl')
            encoder_path = os.path.join(self.model_dir, 'label2_encoder.pkl')
            pca_path = os.path.join(self.model_dir, 'pca2.pkl')
            scaler_path = os.path.join(self.model_dir, 'scaler2.pkl')

            # Try to load models with different methods
            if os.path.exists(knn_path):
                try:
                    # Try different pickle protocols
                    with open(knn_path, 'rb') as f:
                        self.knn_model = pickle.load(f)
                    print(f"✅ KNN model loaded from {knn_path}")
                except Exception as e:
                    print(f"⚠️ Could not load KNN model with pickle: {e}")
                    try:
                        # Try joblib
                        self.knn_model = joblib.load(knn_path)
                        print(f"✅ KNN model loaded with joblib from {knn_path}")
                    except:
                        self.use_simple_detection = True
                        print("⚠️ Using simplified voice emotion detection")
            else:
                print(f"⚠️ KNN model not found at {knn_path}")
                self.use_simple_detection = True

            # Load other models if they exist
            if os.path.exists(encoder_path):
                try:
                    with open(encoder_path, 'rb') as f:
                        self.label_encoder = pickle.load(f)
                    print(f"✅ Label encoder loaded from {encoder_path}")
                except:
                    pass

            if os.path.exists(pca_path):
                try:
                    with open(pca_path, 'rb') as f:
                        self.pca = pickle.load(f)
                    print(f"✅ PCA model loaded from {pca_path}")
                except:
                    pass

            if os.path.exists(scaler_path):
                try:
                    self.scaler = joblib.load(scaler_path)
                    print(f"✅ Scaler loaded from {scaler_path}")
                except:
                    pass

        except Exception as e:
            print(f"❌ Error loading voice emotion models: {e}")
            traceback.print_exc()
            self.use_simple_detection = True

    def extract_features(self, audio_path: str) -> Optional[np.ndarray]:
        """Extract MFCC features from audio file."""
        try:
            # Load audio file
            y, sr = librosa.load(audio_path, sr=16000)

            # Extract MFCCs
            mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, n_fft=512, hop_length=256)

            # Get mean and std for each MFCC coefficient
            mfccs_mean = np.mean(mfccs.T, axis=0)
            mfccs_std = np.std(mfccs.T, axis=0)

            # Extract additional features
            features_list = [mfccs_mean, mfccs_std]

            try:
                # Chroma features
                chroma = librosa.feature.chroma_stft(y=y, sr=sr)
                chroma_mean = np.mean(chroma.T, axis=0)
                features_list.append(chroma_mean)
            except:
                pass

            try:
                # Spectral contrast
                spectral_contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
                spectral_mean = np.mean(spectral_contrast.T, axis=0)
                features_list.append(spectral_mean)
            except:
                pass

            try:
                # Tonnetz
                tonnetz = librosa.feature.tonnetz(y=y, sr=sr)
                tonnetz_mean = np.mean(tonnetz.T, axis=0)
                features_list.append(tonnetz_mean)
            except:
                pass

            # Combine all features
            features = np.concatenate(features_list)

            return features
        except Exception as e:
            print(f"❌ Error extracting audio features: {e}")
            return None

    def simple_emotion_detection(self, audio_path: str) -> Dict[str, Any]:
        """Simplified emotion detection based on audio characteristics."""
        try:
            y, sr = librosa.load(audio_path, sr=16000)

            # Calculate basic audio features
            # Energy (volume)
            energy = np.mean(np.abs(y))

            # Pitch (fundamental frequency)
            pitches, magnitudes = librosa.piptrack(y=y, sr=sr)
            pitch_values = pitches[magnitudes > np.median(magnitudes)]
            mean_pitch = np.mean(pitch_values) if len(pitch_values) > 0 else 0

            # Zero crossing rate (indicator of noisiness)
            zcr = np.mean(librosa.feature.zero_crossing_rate(y))

            # Spectral rolloff
            rolloff = np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr))

            # Simple rule-based classification
            if energy < 0.01:
                emotion = 'neutral'
            elif mean_pitch > 200 and zcr > 0.1:
                emotion = 'happy'
            elif mean_pitch < 150 and energy < 0.05:
                emotion = 'sad'
            elif mean_pitch > 180 and energy > 0.1:
                emotion = 'angry'
            elif zcr > 0.15 and energy > 0.08:
                emotion = 'fearful'
            else:
                emotion = 'neutral'

            return {
                'emotion': emotion,
                'confidence': 0.6,
                'method': 'simple'
            }
        except Exception as e:
            print(f"❌ Error in simple emotion detection: {e}")
            return {'emotion': 'unknown', 'confidence': 0.0, 'method': 'simple'}

    def detect_emotion_from_audio(self, audio_path: str) -> Dict[str, Any]:
        """Detect emotion from audio file."""
        if self.use_simple_detection:
            return self.simple_emotion_detection(audio_path)

        try:
            # Extract features
            features = self.extract_features(audio_path)
            if features is None:
                return self.simple_emotion_detection(audio_path)

            # Reshape for sklearn
            features = features.reshape(1, -1)

            # Apply scaler if available
            if self.scaler is not None:
                features = self.scaler.transform(features)

            # Apply PCA if available
            if self.pca is not None:
                features = self.pca.transform(features)

            # Predict emotion
            if self.knn_model is not None:
                if hasattr(self.knn_model, 'predict_proba'):
                    probabilities = self.knn_model.predict_proba(features)[0]
                    emotion_idx = np.argmax(probabilities)
                    confidence = float(probabilities[emotion_idx])
                else:
                    emotion_idx = self.knn_model.predict(features)[0]
                    confidence = 0.7

                # Get emotion label
                if self.label_encoder is not None:
                    emotion = self.label_encoder.inverse_transform([emotion_idx])[0]
                else:
                    emotion = self.emotion_labels[emotion_idx % len(self.emotion_labels)]

                return {
                    'emotion': emotion.lower(),
                    'confidence': confidence,
                    'method': 'ml'
                }
            else:
                return self.simple_emotion_detection(audio_path)

        except Exception as e:
            print(f"❌ Error detecting voice emotion: {e}")
            traceback.print_exc()
            return self.simple_emotion_detection(audio_path)


# ============================================================================
# EMOTION TRACKER - Tracks emotions throughout the call
# ============================================================================

class EmotionTracker:
    """Tracks face and voice emotions throughout a call session."""

    def __init__(self, face_detector: FaceEmotionDetector, voice_detector: VoiceToneDetector):
        self.face_detector = face_detector
        self.voice_detector = voice_detector
        self.face_history = []  # List of (timestamp, emotion, confidence)
        self.voice_history = []  # List of (timestamp, emotion, confidence)
        self.current_face_emotion = 'unknown'
        self.current_voice_emotion = 'unknown'
        self.session_start = None
        self.last_face_update = None
        self.last_voice_update = None

    def start_session(self):
        """Start a new emotion tracking session."""
        self.session_start = datetime.now()
        self.face_history = []
        self.voice_history = []
        self.current_face_emotion = 'unknown'
        self.current_voice_emotion = 'unknown'
        print(f"✅ Emotion tracking session started at {self.session_start}")

    def update_face_emotion(self, emotion_result: Dict[str, Any]):
        """Update face emotion with timestamp."""
        timestamp = datetime.now()
        self.current_face_emotion = emotion_result.get('emotion', 'unknown')
        confidence = emotion_result.get('confidence', 0.0)

        self.face_history.append({
            'timestamp': timestamp.isoformat(),
            'emotion': self.current_face_emotion,
            'confidence': confidence,
            'face_detected': emotion_result.get('face_detected', False)
        })

        # Keep only last 100 entries
        if len(self.face_history) > 100:
            self.face_history = self.face_history[-100:]

        self.last_face_update = timestamp

    def update_voice_emotion(self, emotion_result: Dict[str, Any]):
        """Update voice emotion with timestamp."""
        timestamp = datetime.now()
        self.current_voice_emotion = emotion_result.get('emotion', 'unknown')
        confidence = emotion_result.get('confidence', 0.0)

        self.voice_history.append({
            'timestamp': timestamp.isoformat(),
            'emotion': self.current_voice_emotion,
            'confidence': confidence
        })

        # Keep only last 20 entries (voice updates are less frequent)
        if len(self.voice_history) > 20:
            self.voice_history = self.voice_history[-20:]

        self.last_voice_update = timestamp

    def get_dominant_face_emotion(self, window_seconds: int = 30) -> Dict[str, Any]:
        """Get the dominant face emotion in the last window_seconds."""
        if not self.face_history:
            return {'emotion': 'unknown', 'count': 0, 'confidence': 0.0}

        cutoff = (datetime.now() - timedelta(seconds=window_seconds)).isoformat()
        recent = [h for h in self.face_history if h['timestamp'] >= cutoff]

        if not recent:
            return {'emotion': 'unknown', 'count': 0, 'confidence': 0.0}

        # Count emotions
        emotion_counts = {}
        for entry in recent:
            emotion = entry['emotion']
            emotion_counts[emotion] = emotion_counts.get(emotion, 0) + 1

        dominant = max(emotion_counts.items(), key=lambda x: x[1])
        avg_confidence = np.mean([e['confidence'] for e in recent if e['emotion'] == dominant[0]])

        return {
            'emotion': dominant[0],
            'count': dominant[1],
            'confidence': float(avg_confidence),
            'total_samples': len(recent)
        }

    def get_dominant_voice_emotion(self, window_seconds: int = 60) -> Dict[str, Any]:
        """Get the dominant voice emotion in the last window_seconds."""
        if not self.voice_history:
            return {'emotion': 'unknown', 'count': 0, 'confidence': 0.0}

        cutoff = (datetime.now() - timedelta(seconds=window_seconds)).isoformat()
        recent = [h for h in self.voice_history if h['timestamp'] >= cutoff]

        if not recent:
            return {'emotion': 'unknown', 'count': 0, 'confidence': 0.0}

        # Count emotions
        emotion_counts = {}
        for entry in recent:
            emotion = entry['emotion']
            emotion_counts[emotion] = emotion_counts.get(emotion, 0) + 1

        dominant = max(emotion_counts.items(), key=lambda x: x[1])
        avg_confidence = np.mean([e['confidence'] for e in recent if e['emotion'] == dominant[0]])

        return {
            'emotion': dominant[0],
            'count': dominant[1],
            'confidence': float(avg_confidence),
            'total_samples': len(recent)
        }

    def get_emotion_summary(self) -> Dict[str, Any]:
        """Get a summary of emotions throughout the session."""
        if not self.session_start:
            return {'error': 'No active session'}

        session_duration = (datetime.now() - self.session_start).total_seconds()

        return {
            'session_start': self.session_start.isoformat(),
            'session_duration_seconds': session_duration,
            'current_face_emotion': self.current_face_emotion,
            'current_voice_emotion': self.current_voice_emotion,
            'dominant_face_emotion_30s': self.get_dominant_face_emotion(30),
            'dominant_voice_emotion_60s': self.get_dominant_voice_emotion(60),
            'face_samples': len(self.face_history),
            'voice_samples': len(self.voice_history),
            'last_face_update': self.last_face_update.isoformat() if self.last_face_update else None,
            'last_voice_update': self.last_voice_update.isoformat() if self.last_voice_update else None
        }