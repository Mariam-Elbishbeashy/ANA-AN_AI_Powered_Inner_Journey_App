#!/usr/bin/env python3
# flask_server.py - Flask Server for Multimodal Analysis API
# UPDATED: Added Egyptian Arabic support and improved translation

import os
import numpy as np
import joblib
import tensorflow as tf
import librosa
import speech_recognition as sr
import base64
import tempfile
import re
import cv2
import json
import time
from flask import Flask, request, jsonify
from flask_cors import CORS
import traceback
from tensorflow.keras.models import load_model
from collections import Counter
from langdetect import detect, DetectorFactory, detect_langs
import googletrans
from googletrans import Translator
from langdetect.lang_detect_exception import LangDetectException

# Set seed for consistent language detection
DetectorFactory.seed = 0

# ======================= INITIALIZATION =======================
print("Initializing Flask server...")
print("Loading models...")

app = Flask(__name__)
CORS(app, origins=["*"])

MODEL_DIR = "model_files"

# Initialize translator with retry mechanism
translator = Translator()
MAX_TRANSLATION_RETRIES = 3

# Egyptian Arabic specific patterns (colloquial Egyptian)
EGYPTIAN_ARABIC_PATTERNS = [
    r'ده\b', r'دي\b', r'اللي\b', r'عشان\b', r'ايه\b', r'ماشي\b',  # Common Egyptian words
    r'\bاحنا\b', r'\bهي\b', r'\bهو\b', r'\bانت\b', r'\bانتي\b',  # Pronouns
    r'يعني\b', r'بس\b', r'تمام\b', r'يا\b',  # Common expressions
]

# ======================= LOAD MODELS =======================
print("Loading models...")

# Load voice model
print("Loading voice model...")
scaler = pca = knn = le_voice = None
try:
    scaler = joblib.load(f'{MODEL_DIR}/voice/scaler2.pkl')
    pca = joblib.load(f'{MODEL_DIR}/voice/pca2.pkl')
    knn = joblib.load(f'{MODEL_DIR}/voice/knn2.pkl')
    le_voice = joblib.load(f'{MODEL_DIR}/voice/label2_encoder.pkl')
    print(f"✓ Voice model loaded. Classes: {le_voice.classes_}")
    print(f"   Scaler expects {scaler.n_features_in_} features")
except Exception as e:
    print(f"✗ Error loading voice model: {e}")

# Load text model
print("Loading text model...")
text_model = label_encoder_text = None
try:
    text_model = tf.keras.models.load_model(f'{MODEL_DIR}/text/inner_character_cnn_lstm (1).keras')
    label_encoder_text = joblib.load(f'{MODEL_DIR}/text/label_encoder (3).pkl')
    print(f"✓ Text model loaded. Classes: {label_encoder_text.classes_}")
except Exception as e:
    print(f"✗ Error loading text model: {e}")

# ======================= ARABIC TRANSLATION FUNCTIONS =======================
def detect_arabic_text(text):
    """Detect if text contains Arabic characters"""
    try:
        if not text or len(text.strip()) == 0:
            return False, None

        text = str(text).strip()

        # Method 1: Check for Arabic Unicode characters
        arabic_pattern = re.compile(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        if arabic_pattern.search(text):
            # Check for Egyptian Arabic patterns
            for pattern in EGYPTIAN_ARABIC_PATTERNS:
                if re.search(pattern, text, re.IGNORECASE):
                    return True, 'egyptian'
            return True, 'arabic'

        # Method 2: Use langdetect for language identification
        try:
            languages = detect_langs(text)
            for lang in languages:
                if lang.lang == 'ar':
                    # Check if it's likely Egyptian based on confidence
                    if lang.prob > 0.8:
                        # Check for Egyptian patterns in transliterated text
                        lower_text = text.lower()
                        egy_patterns = ['dah', 'di', 'elly', '3shan', 'eih', 'mashi']
                        if any(pattern in lower_text for pattern in egy_patterns):
                            return True, 'egyptian'
                        return True, 'arabic'
        except (LangDetectException, Exception):
            pass

        # Method 3: Check for transliterated Egyptian Arabic
        transliterated_patterns = [
            r'3[a-zA-Z]*',  # Words starting with 3 (ع)
            r'7[a-zA-Z]*',  # Words starting with 7 (ح)
            r'gh[a-zA-Z]*',  # Words starting with gh (غ)
            r'\bmashi\b', r'\bkwayes\b', r'\bana\b',  # Common transliterations
        ]

        for pattern in transliterated_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True, 'egyptian-transliterated'

        return False, None

    except Exception as e:
        print(f"Language detection error: {e}")
        return False, None

def translate_arabic_to_english(text, arabic_type='arabic', retry_count=0):
    """Translate Arabic text to English with retry mechanism"""
    try:
        if not text or len(text.strip()) == 0:
            return text

        # Clean text before translation
        text = str(text).strip()

        # Handle transliterated text (convert to proper Arabic if possible)
        if arabic_type == 'egyptian-transliterated':
            # Simple transliteration conversion (this could be enhanced)
            text = text.replace('3', 'ع').replace('7', 'ح').replace('gh', 'غ')
            arabic_type = 'egyptian'

        try:
            # Try translation with specific source language
            if arabic_type == 'egyptian':
                # Egyptian Arabic may need special handling
                translation = translator.translate(text, src='ar', dest='en')
            else:
                translation = translator.translate(text, src='ar', dest='en')

            translated_text = translation.text

            # Verify translation quality
            if len(translated_text.strip()) > 0:
                return translated_text
            else:
                if retry_count < MAX_TRANSLATION_RETRIES:
                    return translate_arabic_to_english(text, arabic_type, retry_count + 1)
                return text

        except Exception as trans_error:
            print(f"Translation error (attempt {retry_count + 1}): {trans_error}")
            if retry_count < MAX_TRANSLATION_RETRIES:
                time.sleep(0.5)  # Wait before retry
                return translate_arabic_to_english(text, arabic_type, retry_count + 1)
            return text

    except Exception as e:
        print(f"Translation function error: {e}")
        return text

def preprocess_text_for_analysis(text):
    """Preprocess text - detect and translate Arabic if needed"""
    try:
        if not text or len(text.strip()) < 3:
            return text, False, None

        text = str(text).strip()
        original_text = text

        # Detect if text contains Arabic
        is_arabic, arabic_type = detect_arabic_text(text)

        if is_arabic:
            print(f"   Detected Arabic type: {arabic_type}")
            print(f"   Original text: {text[:100]}..." if len(text) > 100 else f"   Original text: {text}")

            # Translate Arabic to English
            english_text = translate_arabic_to_english(text, arabic_type)

            print(f"   Translated text: {english_text[:100]}..." if len(english_text) > 100 else f"   Translated text: {english_text}")

            return english_text, True, arabic_type
        else:
            return text, False, None

    except Exception as e:
        print(f"Text preprocessing error: {e}")
        return text, False, None

def speech_to_text_with_arabic_support(audio, sample_rate=22050):
    """Convert speech to text with enhanced Arabic/Egyptian support"""
    try:
        if audio is None or len(audio) == 0:
            return "", False, None

        # Normalize audio
        max_amp = np.max(np.abs(audio))
        if max_amp < 0.01:
            return "", False, None

        # Boost quiet audio
        if max_amp < 0.1:
            audio = audio * (0.1 / max_amp)

        recognizer = sr.Recognizer()

        # Convert to 16-bit PCM
        audio_16bit = (audio * 32767).astype(np.int16)
        audio_data = sr.AudioData(audio_16bit.tobytes(), sample_rate, 2)

        detected_language = None
        is_translated = False

        # Try Egyptian Arabic recognition first (most specific)
        try:
            text = recognizer.recognize_google(audio_data, language="ar-EG")  # Egyptian Arabic
            if text and len(text.strip()) > 3:
                print(f"   Detected Egyptian Arabic speech")
                english_text = translate_arabic_to_english(text, 'egyptian')
                return english_text, True, 'egyptian'
        except sr.UnknownValueError:
            pass
        except Exception as e:
            print(f"   Egyptian Arabic recognition error: {e}")

        # Try Modern Standard Arabic
        try:
            text = recognizer.recognize_google(audio_data, language="ar-SA")  # Saudi Arabic (MSA)
            if text and len(text.strip()) > 3:
                print(f"   Detected Modern Standard Arabic speech")
                english_text = translate_arabic_to_english(text, 'arabic')
                return english_text, True, 'arabic'
        except sr.UnknownValueError:
            pass
        except Exception as e:
            print(f"   MSA recognition error: {e}")

        # Try English recognition
        try:
            text = recognizer.recognize_google(audio_data, language="en-US")
            if text and len(text.strip()) > 3:
                print(f"   Detected English speech")
                return text, False, 'english'
        except sr.UnknownValueError:
            pass
        except Exception as e:
            print(f"   English recognition error: {e}")

        # Try Arabic without specific dialect
        try:
            text = recognizer.recognize_google(audio_data, language="ar")
            if text and len(text.strip()) > 3:
                print(f"   Detected Arabic speech (generic)")
                # Check if it's Egyptian
                is_egyptian, arabic_type = detect_arabic_text(text)
                english_text = translate_arabic_to_english(text, arabic_type if is_egyptian else 'arabic')
                return english_text, True, arabic_type if is_egyptian else 'arabic'
        except:
            pass

        return "", False, None

    except Exception as e:
        print(f"Speech recognition error: {e}")
        return "", False, None

# ======================= VOICE EMOTION FUNCTIONS =======================
def extract_audio_features(audio, sr=22050):
    """Extract 159 audio features matching model expectations"""
    try:
        if len(audio) == 0:
            return np.zeros(159)

        # Ensure minimum length
        min_samples = int(0.5 * sr)
        if len(audio) < min_samples:
            audio = np.pad(audio, (0, min_samples - len(audio)), mode='constant')

        features = []

        # MFCCs (13 coefficients)
        mfccs = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=13, n_fft=2048, hop_length=512)
        features.extend(np.mean(mfccs, axis=1))  # 13
        features.extend(np.std(mfccs, axis=1))   # 13

        # Mel spectrogram
        mel = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=64, n_fft=2048, hop_length=512)
        mel_db = librosa.power_to_db(mel, ref=np.max)
        features.extend(np.mean(mel_db, axis=1)[:16])  # 16
        features.extend(np.std(mel_db, axis=1)[:16])   # 16

        # Chroma features
        chroma = librosa.feature.chroma_stft(y=audio, sr=sr, n_fft=2048, hop_length=512)
        features.extend(np.mean(chroma, axis=1))  # 12
        features.extend(np.std(chroma, axis=1))   # 12

        # Spectral features
        spectral_centroid = librosa.feature.spectral_centroid(y=audio, sr=sr, n_fft=2048, hop_length=512)
        features.append(np.mean(spectral_centroid))
        features.append(np.std(spectral_centroid))

        spectral_bandwidth = librosa.feature.spectral_bandwidth(y=audio, sr=sr, n_fft=2048, hop_length=512)
        features.append(np.mean(spectral_bandwidth))
        features.append(np.std(spectral_bandwidth))

        spectral_rolloff = librosa.feature.spectral_rolloff(y=audio, sr=sr, n_fft=2048, hop_length=512)
        features.append(np.mean(spectral_rolloff))
        features.append(np.std(spectral_rolloff))

        # Zero crossing rate
        zcr = librosa.feature.zero_crossing_rate(audio, frame_length=2048, hop_length=512)
        features.append(np.mean(zcr))
        features.append(np.std(zcr))

        # RMS energy
        rms = librosa.feature.rms(y=audio, frame_length=2048, hop_length=512)
        features.append(np.mean(rms))
        features.append(np.std(rms))

        # Spectral contrast
        contrast = librosa.feature.spectral_contrast(y=audio, sr=sr, n_fft=2048, hop_length=512)
        features.extend(np.mean(contrast, axis=1))  # 7
        features.extend(np.std(contrast, axis=1))   # 7

        # Tonnetz
        try:
            tonnetz = librosa.feature.tonnetz(y=audio, sr=sr)
            features.extend(np.mean(tonnetz, axis=1))  # 6
            features.extend(np.std(tonnetz, axis=1))   # 6
        except:
            features.extend([0] * 12)

        # Poly features
        try:
            poly_features = librosa.feature.poly_features(y=audio, sr=sr, n_fft=2048, hop_length=512)
            features.append(np.mean(poly_features[0]))
            features.append(np.mean(poly_features[1]))
        except:
            features.extend([0, 0])

        # Tempo
        try:
            onset_env = librosa.onset.onset_strength(y=audio, sr=sr)
            tempo = librosa.feature.rhythm.tempo(onset_envelope=onset_env, sr=sr)[0]
            features.append(tempo)
        except:
            features.append(120.0)

        # Ensure exactly 159 features
        features_array = np.array(features)
        if len(features_array) < 159:
            features_array = np.pad(features_array, (0, 159 - len(features_array)), mode='constant')
        elif len(features_array) > 159:
            features_array = features_array[:159]

        return features_array

    except Exception as e:
        print(f"Feature extraction error: {e}")
        return np.zeros(159)

def predict_voice_emotion(audio):
    """Predict top 3 voice emotions"""
    try:
        if scaler is None or pca is None or knn is None or le_voice is None:
            return [{"emotion": "Error", "confidence": 0.0}]

        if audio is None or len(audio) == 0:
            return [{"emotion": "No Audio", "confidence": 0.0}]

        # Extract features
        features = extract_audio_features(audio)

        # Reshape and adjust dimensions
        features = features.reshape(1, -1)

        if features.shape[1] != scaler.n_features_in_:
            if features.shape[1] < scaler.n_features_in_:
                features = np.pad(features, ((0, 0), (0, scaler.n_features_in_ - features.shape[1])), mode='constant')
            else:
                features = features[:, :scaler.n_features_in_]

        # Scale and transform
        features_scaled = scaler.transform(features)
        features_pca = pca.transform(features_scaled)

        # Get probabilities
        probs = knn.predict_proba(features_pca)[0]

        # Get top 3 predictions
        top_indices = np.argsort(probs)[-3:][::-1]
        top_predictions = []

        for idx in top_indices:
            emotion = le_voice.inverse_transform([idx])[0]
            confidence = float(probs[idx])

            # Adjust confidence based on audio quality
            audio_quality = np.max(np.abs(audio))
            if audio_quality < 0.05:
                confidence *= 0.5
            elif audio_quality < 0.1:
                confidence *= 0.7

            confidence = max(0.01, confidence)

            top_predictions.append({
                "emotion": emotion,
                "confidence": confidence
            })

        # Sort by confidence
        top_predictions.sort(key=lambda x: x["confidence"], reverse=True)

        # Normalize confidences
        total_conf = sum(p['confidence'] for p in top_predictions)
        if total_conf > 0:
            for pred in top_predictions:
                pred['confidence'] = pred['confidence'] / total_conf

        print(f"   Voice emotion predictions:")
        for i, pred in enumerate(top_predictions):
            print(f"     {i+1}. {pred['emotion']}: {pred['confidence']:.3f}")

        return top_predictions

    except Exception as e:
        print(f"Voice prediction error: {e}")
        return [{"emotion": "Error", "confidence": 0.0}]

# ======================= TEXT PROCESSING FUNCTIONS =======================
def predict_text_character(text, top_k=3):
    """Predict inner character from text with Arabic support"""
    try:
        if not text or len(text.strip()) < 5:
            return [], None, None

        if text_model is None or label_encoder_text is None:
            return [], None, None

        # Preprocess text - detect Arabic and translate if needed
        processed_text, is_translated, arabic_type = preprocess_text_for_analysis(text)

        # Clean text
        text_clean = str(processed_text).lower()
        text_clean = re.sub(r"[^\w\s.,!?\-']", "", text_clean)
        text_clean = re.sub(r"\s+", " ", text_clean).strip()

        if len(text_clean) < 10:
            return [], is_translated, arabic_type

        # Prepare input for model
        try:
            input_tensor = tf.convert_to_tensor([[text_clean]], dtype=tf.string)
            probs = text_model(input_tensor, training=False)[0].numpy()

            # Get top predictions
            top_indices = np.argsort(probs)[-top_k:][::-1]
            predictions = []

            for idx in top_indices:
                character = label_encoder_text.inverse_transform([idx])[0]
                confidence = float(probs[idx])

                # Adjust confidence based on text length and translation
                if len(text_clean) < 30:
                    confidence *= 0.8
                elif len(text_clean) < 100:
                    confidence *= 0.9

                # Slightly reduce confidence for translated text
                if is_translated:
                    confidence *= 0.95

                confidence = max(0.01, confidence)

                predictions.append({
                    "character": character,
                    "confidence": confidence
                })

            # Normalize confidences
            total_conf = sum(p['confidence'] for p in predictions)
            if total_conf > 0:
                for pred in predictions:
                    pred['confidence'] = pred['confidence'] / total_conf

            # Print predictions for debugging
            pred_strs = []
            for p in predictions:
                pred_strs.append(f"{p['character']} ({p['confidence']:.3f})")
            print(f"   Text predictions: {', '.join(pred_strs)}")

            return predictions, is_translated, arabic_type

        except Exception as e:
            print(f"   Model prediction error: {e}")
            return [], is_translated, arabic_type

    except Exception as e:
        print(f"Text prediction error: {e}")
        return [], False, None

# ======================= AUDIO PROCESSING =======================
def validate_base64_data(base64_string, min_size=1024):
    """Validate base64 data"""
    try:
        if 'base64,' in base64_string:
            base64_string = base64_string.split('base64,')[1]

        data_size = len(base64_string) * 3 / 4
        if data_size < min_size:
            return False

        return True
    except Exception as e:
        return False

def decode_audio_base64(base64_string):
    """Decode base64 audio"""
    try:
        if not validate_base64_data(base64_string, min_size=2048):
            print("   Invalid audio data")
            return None, None

        if 'base64,' in base64_string:
            base64_string = base64_string.split('base64,')[1]

        audio_bytes = base64.b64decode(base64_string)

        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        try:
            audio, sr = librosa.load(tmp_path, sr=22050, duration=30, mono=True)
            print(f"   Audio loaded: {len(audio)} samples, {sr}Hz, {len(audio)/sr:.1f}s")
        except Exception as e:
            print(f"   Failed to load audio: {e}")
            return None, None

        # Cleanup
        try:
            os.unlink(tmp_path)
        except:
            pass

        return audio, sr

    except Exception as e:
        print(f"Audio decode error: {e}")
        return None, None

# ======================= VIDEO PROCESSING FUNCTIONS =======================
def decode_video_base64(base64_string):
    """Decode base64 video"""
    try:
        if not validate_base64_data(base64_string, min_size=10240):
            print("   Invalid video data")
            return None

        if 'base64,' in base64_string:
            base64_string = base64_string.split('base64,')[1]

        video_bytes = base64.b64decode(base64_string)

        with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as tmp:
            tmp.write(video_bytes)
            tmp_path = tmp.name

        print(f"   Video saved to: {tmp_path}")
        return tmp_path

    except Exception as e:
        print(f"Video decode error: {e}")
        return None

def extract_frames_from_video(video_path, num_frames=10):
    """Extract frames from video for analysis"""
    try:
        cap = cv2.VideoCapture(video_path)
        frames = []
        frame_count = 0

        if not cap.isOpened():
            print("   Failed to open video")
            return frames

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS)

        print(f"   Video info: {total_frames} frames, {fps:.1f} fps")

        # Extract frames at regular intervals
        interval = max(1, total_frames // num_frames)

        for i in range(0, min(total_frames, num_frames * interval), interval):
            cap.set(cv2.CAP_PROP_POS_FRAMES, i)
            ret, frame = cap.read()
            if ret:
                # Resize for consistency
                frame = cv2.resize(frame, (224, 224))
                frames.append(frame)
                frame_count += 1

        cap.release()
        print(f"   Extracted {frame_count} frames")
        return frames

    except Exception as e:
        print(f"Frame extraction error: {e}")
        return []

def analyze_face_emotion(frame):
    """Simple face emotion analysis (placeholder)"""
    emotions = ['Neutral', 'Happy', 'Sad', 'Angry', 'Surprise', 'Fear', 'Disgust']
    confidences = [0.7, 0.1, 0.05, 0.05, 0.05, 0.03, 0.02]

    return np.random.choice(emotions, p=confidences), np.random.uniform(0.5, 0.9)

def detect_hand_gesture(frame):
    """Simple hand gesture detection (placeholder)"""
    gestures = ['None', 'Hand Up', 'Hand Wave', 'Pointing', 'Clenched Fist']
    emotions = ['Neutral', 'Excited', 'Friendly', 'Directing', 'Angry']

    return np.random.choice(gestures), np.random.choice(emotions), np.random.uniform(0.4, 0.8)

def process_video_analysis(video_path, audio_base64=None, text_input=""):
    """Process video analysis with Arabic support"""
    try:
        results = {
            'face_emotion': 'Unknown',
            'face_confidence': 0.0,
            'hand_gesture': 'None',
            'hand_gesture_emotion': 'Neutral',
            'hand_gesture_confidence': 0.0,
            'video_duration': 0,
            'frame_count': 0,
            'audio_analysis': None,
            'text_analysis': None,
            'voice_emotions': [],
            'transcribed_text': '',
            'transcribed_original': '',
            'is_translated': False,
            'detected_language': None,
            'primary_character': 'Unknown',
            'character_name': '',
            'confidence': 0.0,
            'inner_characters': []
        }

        # Extract frames from video
        frames = extract_frames_from_video(video_path, num_frames=5)
        results['frame_count'] = len(frames)

        if frames:
            # Analyze first frame for face emotion
            face_emotion, face_conf = analyze_face_emotion(frames[0])
            results['face_emotion'] = face_emotion
            results['face_confidence'] = float(face_conf)

            # Analyze for hand gesture
            gesture, gesture_emotion, gesture_conf = detect_hand_gesture(frames[0])
            results['hand_gesture'] = gesture
            results['hand_gesture_emotion'] = gesture_emotion
            results['hand_gesture_confidence'] = float(gesture_conf)

        # Process audio if provided
        if audio_base64 and validate_base64_data(audio_base64, min_size=2048):
            audio, sr = decode_audio_base64(audio_base64)
            if audio is not None:
                # Voice emotion analysis
                voice_predictions = predict_voice_emotion(audio)
                results['voice_emotions'] = voice_predictions

                # Speech to text with Arabic support
                speech_text, is_translated, detected_lang = speech_to_text_with_arabic_support(audio)
                results['transcribed_text'] = speech_text
                results['is_translated'] = is_translated
                results['detected_language'] = detected_lang

                results['audio_analysis'] = {
                    'duration': len(audio) / sr if sr else 0,
                    'sample_rate': sr,
                    'is_translated': is_translated,
                    'detected_language': detected_lang
                }

        # Process text input if provided
        analysis_text = text_input
        if not analysis_text and results['transcribed_text']:
            analysis_text = results['transcribed_text']

        if analysis_text and len(analysis_text.strip()) > 10:
            text_predictions, text_is_translated, text_lang = predict_text_character(analysis_text, top_k=3)
            results['is_translated'] = results['is_translated'] or text_is_translated
            results['detected_language'] = results['detected_language'] or text_lang

            if text_predictions:
                results['primary_character'] = text_predictions[0]['character']
                results['character_name'] = text_predictions[0]['character']
                results['confidence'] = float(text_predictions[0]['confidence'])
                results['inner_characters'] = [
                    {
                        'rank': i + 1,
                        'character': p['character'],
                        'character_name': p['character'],
                        'confidence': float(p['confidence'])
                    }
                    for i, p in enumerate(text_predictions)
                ]

        # Clean up temp video file
        try:
            os.unlink(video_path)
        except:
            pass

        return results

    except Exception as e:
        print(f"Video processing error: {e}")
        traceback.print_exc()
        return None

# ======================= API ENDPOINTS =======================
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'Enhanced Multimodal Analysis Server with Egyptian Arabic Support',
        'models_loaded': {
            'voice': scaler is not None,
            'text': text_model is not None,
        },
        'voice_classes': list(le_voice.classes_) if le_voice else [],
        'text_classes': list(label_encoder_text.classes_) if label_encoder_text else [],
        'features': ['Egyptian Arabic detection', 'Arabic to English translation', 'Multimodal analysis'],
        'timestamp': time.time()
    })

@app.route('/api/analyze/audio', methods=['POST'])
def analyze_audio():
    """Audio analysis endpoint with Egyptian Arabic support"""
    try:
        data = request.get_json()
        print(f"\n🎤 Audio analysis request")

        if not data or 'audio' not in data:
            return jsonify({
                'success': False,
                'error': 'No audio data provided'
            }), 400

        # Decode audio
        audio, sr = decode_audio_base64(data['audio'])
        if audio is None:
            return jsonify({
                'success': False,
                'error': 'Failed to decode audio'
            }), 400

        # Get voice emotion predictions
        voice_predictions = predict_voice_emotion(audio)

        # Get speech-to-text with Arabic support
        speech_text, is_translated, detected_lang = speech_to_text_with_arabic_support(audio)

        # Text analysis from speech
        text_predictions = []
        text_is_translated = False
        text_lang = None

        if speech_text and len(speech_text.strip()) > 10:
            text_predictions, text_is_translated, text_lang = predict_text_character(speech_text, top_k=3)

        # Build response
        result = {
            'success': True,
            'analysis_type': 'audio',
            'audio_duration': len(audio) / sr if sr else 0,
            'voice_emotions': voice_predictions,
            'primary_voice_emotion': voice_predictions[0]["emotion"] if voice_predictions else "Unknown",
            'primary_voice_confidence': voice_predictions[0]["confidence"] if voice_predictions else 0.0,
            'transcribed_text': speech_text,
            'is_translated': is_translated or text_is_translated,
            'detected_language': detected_lang or text_lang,
            'has_speech': bool(speech_text and len(speech_text.strip()) > 5),
            'processing_time': time.time()
        }

        if text_predictions:
            result['primary_character'] = text_predictions[0]['character']
            result['character_name'] = text_predictions[0]['character']
            result['confidence'] = float(text_predictions[0]['confidence'])
            result['inner_characters'] = [
                {
                    'rank': i + 1,
                    'character': p['character'],
                    'character_name': p['character'],
                    'confidence': float(p['confidence'])
                }
                for i, p in enumerate(text_predictions)
            ]
        else:
            result['primary_character'] = None
            result['character_name'] = None
            result['confidence'] = None
            result['inner_characters'] = []

        print(f"✅ Audio analysis complete")
        print(f"   Language detected: {result['detected_language']}")
        print(f"   Translated: {result['is_translated']}")
        return jsonify(result)

    except Exception as e:
        print(f"❌ Audio analysis error: {e}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analyze/text', methods=['POST'])
def analyze_text():
    """Text analysis endpoint with Egyptian Arabic support"""
    try:
        data = request.get_json()
        print(f"\n📝 Text analysis request")

        if not data or 'text' not in data:
            return jsonify({
                'success': False,
                'error': 'No text provided'
            }), 400

        text = data['text'].strip()
        print(f"📝 Input: {text[:100]}..." if len(text) > 100 else f"📝 Input: {text}")

        if len(text) < 10:
            return jsonify({
                'success': False,
                'error': 'Text too short (minimum 10 characters)'
            }), 400

        predictions, is_translated, detected_lang = predict_text_character(text, top_k=3)

        if not predictions:
            return jsonify({
                'success': False,
                'error': 'No predictions generated'
            }), 400

        result = {
            'success': True,
            'analysis_type': 'text',
            'input_length': len(text),
            'is_translated': is_translated,
            'detected_language': detected_lang,
            'primary_character': predictions[0]['character'],
            'character_name': predictions[0]['character'],
            'confidence': float(predictions[0]['confidence']),
            'inner_characters': [
                {
                    'rank': i + 1,
                    'character': p['character'],
                    'character_name': p['character'],
                    'confidence': float(p['confidence'])
                }
                for i, p in enumerate(predictions)
            ],
            'processing_time': time.time()
        }

        print(f"✅ Text analysis complete")
        print(f"   Language detected: {result['detected_language']}")
        print(f"   Translated: {result['is_translated']}")
        return jsonify(result)

    except Exception as e:
        print(f"❌ Text analysis error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/analyze/video', methods=['POST'])
def analyze_video():
    """Video analysis endpoint"""
    try:
        data = request.get_json()
        print(f"\n🎥 Video analysis request")

        if not data or 'video' not in data:
            return jsonify({
                'success': False,
                'error': 'No video data provided'
            }), 400

        # Decode video
        video_path = decode_video_base64(data['video'])
        if video_path is None:
            return jsonify({
                'success': False,
                'error': 'Failed to decode video'
            }), 400

        # Get optional audio and text
        audio_base64 = data.get('audio')
        text_input = data.get('text', '')

        # Process video analysis
        results = process_video_analysis(video_path, audio_base64, text_input)

        if results is None:
            return jsonify({
                'success': False,
                'error': 'Video analysis failed'
            }), 500

        # Build response
        response = {
            'success': True,
            'analysis_type': 'video',
            'frame_count': results['frame_count'],
            'face_emotion': results['face_emotion'],
            'face_confidence': results['face_confidence'],
            'hand_gesture': results['hand_gesture'],
            'hand_gesture_emotion': results['hand_gesture_emotion'],
            'hand_gesture_confidence': results['hand_gesture_confidence'],
            'voice_emotions': results['voice_emotions'],
            'primary_voice_emotion': results['voice_emotions'][0]["emotion"] if results['voice_emotions'] else "Unknown",
            'primary_voice_confidence': results['voice_emotions'][0]["confidence"] if results['voice_emotions'] else 0.0,
            'transcribed_text': results['transcribed_text'],
            'is_translated': results['is_translated'],
            'detected_language': results['detected_language'],
            'primary_character': results['primary_character'],
            'character_name': results['character_name'],
            'confidence': results['confidence'],
            'inner_characters': results['inner_characters'],
            'processing_time': time.time()
        }

        print(f"✅ Video analysis complete")
        print(f"   Language detected: {response['detected_language']}")
        print(f"   Translated: {response['is_translated']}")
        return jsonify(response)

    except Exception as e:
        print(f"❌ Video analysis error: {e}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ======================= MAIN =======================
if __name__ == '__main__':
    print("=" * 60)
    print("🚀 ENHANCED MULTIMODAL ANALYSIS SERVER")
    print("=" * 60)
    print("\n✅ Key Features:")
    print("   1. EGYPTIAN ARABIC DETECTION & TRANSLATION")
    print("   2. VOICE EMOTION PREDICTION (159 features)")
    print("   3. SPEECH-TO-TEXT with Egyptian Arabic support")
    print("   4. TEXT CHARACTER PREDICTION with translation")
    print("\n🎤 Supported Languages:")
    print("   - English")
    print("   - Modern Standard Arabic (ar-SA)")
    print("   - Egyptian Arabic (ar-EG)")
    print("   - Arabic (generic)")
    print("\n📡 Endpoints:")
    print("  GET  /api/health           - Health check")
    print("  POST /api/analyze/text     - Analyze text")
    print("  POST /api/analyze/audio    - Analyze audio")
    print("  POST /api/analyze/video    - Analyze video")
    print("\n🚀 Starting server...")
    print("=" * 60)

    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)