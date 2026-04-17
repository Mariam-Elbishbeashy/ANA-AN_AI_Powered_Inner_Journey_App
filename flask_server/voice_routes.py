import os
import json
import base64
import re
import traceback
import requests
from datetime import datetime, timezone
import time
import uuid
from typing import Dict, List, Any, Optional

from flask import Blueprint, request, jsonify, send_file
from openai import OpenAI

# =============================
# Blueprint
# =============================
voice_bp = Blueprint("voice_bp", __name__, url_prefix="/voice")

# =============================
# Config
# =============================
OPENAI_TRANSCRIBE_MODEL = os.getenv("OPENAI_TRANSCRIBE_MODEL", "whisper-1")
OPENAI_TTS_MODEL = os.getenv("OPENAI_TTS_MODEL", "tts-1")
OPENAI_SUMMARY_MODEL = os.getenv("OPENAI_SUMMARY_MODEL", "gpt-4o-mini")
VOICE_NAME = os.getenv("OPENAI_VOICE", "nova")
GUIDER_VOICE = os.getenv("GUIDER_VOICE", "nova")

# Agents service URL (internal communication)
AGENTS_URL = os.getenv("AGENTS_URL", "http://localhost:5001")
# Emotion server URL
EMOTION_SERVER_URL = os.getenv("EMOTION_SERVER_URL", "http://localhost:5002")
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RECORDINGS_DIR = os.path.join(BASE_DIR, "recordings")
TTS_DIR = os.path.join(BASE_DIR, "tts_output")
os.makedirs(RECORDINGS_DIR, exist_ok=True)
os.makedirs(TTS_DIR, exist_ok=True)

# =============================
# Firebase Initialization
# =============================
db = None
try:
    import firebase_admin
    from firebase_admin import firestore

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app()

    db = firestore.client()
    print("✅ Firebase initialized using environment credentials")

except Exception as e:
    db = None
    print(f"⚠️ Firebase not initialized: {e}")

# =============================
# Language detection
# =============================
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

def detect_lang(text: str) -> str:
    if not text:
        return "en"

    arabic_chars = len(re.findall(r"[\u0600-\u06FF]", text))
    total_chars = len(text)

    if total_chars == 0:
        return "en"

    ratio = arabic_chars / total_chars

    return "ar" if ratio > 0.3 else "en"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def _now_dt():
    return datetime.now(timezone.utc)

def _json_default(obj):
    iso = getattr(obj, "isoformat", None)
    if callable(iso):
        try:
            return iso()
        except Exception:
            pass
    return str(obj)

def _user_ref(uid: str):
    return db.collection("users").document(uid)

def _sessions_ref(uid: str):
    return _user_ref(uid).collection("sessions")

def _session_ref(uid: str, session_id: str):
    return _sessions_ref(uid).document(session_id)

def _session_runs_ref(uid: str, session_id: str):
    return _session_ref(uid, session_id).collection("agent_runs")

def _threads_ref(uid: str):
    return _user_ref(uid).collection("chat_threads")

def _messages_ref(uid: str, thread_id: str):
    return _threads_ref(uid).document(thread_id).collection("messages")

def _ensure_session_doc(uid: str, session_id: str, character_id: str, thread_id: str, character_profile: Dict) -> None:
    if not db:
        return
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            sref.set({
                "id": session_id,
                "type": "voice",
                "characterId": character_id,
                "characterType": "inner_character",
                "threadId": thread_id,
                "status": "active",
                "title": f"Voice call with {character_profile.get('displayName', character_id)}",
                "startedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
                "userTurnCount": 0,
                "intensity": {},
                "sessionSummary": {},
                "periodic": {},
                # ✅ Add voice tone tracking (mirroring video session)
                "voiceTone": {
                    "dominant": None,
                    "averageConfidence": 0.0,
                    "startEmotion": None,
                    "startConfidence": 0.0,
                    "endEmotion": None,
                    "endConfidence": 0.0,
                    "allDetections": []
                }
            }, merge=True)
            print(f"[voice] Created session doc: {session_id}")
    except Exception as e:
        print(f"[voice] Error creating session doc: {e}")

def _ensure_thread_doc(uid: str, thread_id: str, session_id: str, character_id: str, character_profile: Dict) -> None:
    if not db:
        return
    try:
        tref = _threads_ref(uid).document(thread_id)
        snap = tref.get()
        if not snap.exists:
            tref.set({
                "id": thread_id,
                "sessionId": session_id,
                "characterId": character_id,
                "characterType": "inner_character",
                "title": f"Voice call with {character_profile.get('displayName', character_id)}",
                "status": "active",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            print(f"[voice] Created thread doc: {thread_id}")
    except Exception as e:
        print(f"[voice] Error creating thread doc: {e}")

def _save_message(uid: str, thread_id: str, role: str, content: str, sender: str = None, character_id: str = None, session_id: str = None) -> None:
    if not db or not thread_id:
        return
    try:
        msg_ref = _messages_ref(uid, thread_id).document()
        msg_data = {
            "id": msg_ref.id,
            "role": role,
            "content": content,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
        if sender:
            msg_data["sender"] = sender
        if character_id:
            msg_data["characterId"] = character_id
        if session_id:
            msg_data["sessionId"] = session_id

        msg_ref.set(msg_data)
        print(f"[voice] Saved message: role={role}, thread={thread_id}")

        _threads_ref(uid).document(thread_id).set({
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        if session_id:
            sref = _session_ref(uid, session_id)
            sref.set({
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            if role == 'user':
                sref.set({"userTurnCount": firestore.Increment(1)}, merge=True)
    except Exception as e:
        print(f"[voice] Error saving message: {e}")

def _get_session_user_turn_count(uid: str, session_id: str) -> int:
    try:
        snap = _session_ref(uid, session_id).get()
        if not snap.exists:
            return 0
        data = snap.to_dict() or {}
        return int(data.get("userTurnCount") or 0)
    except Exception:
        return 0

def _increment_session_turn(uid: str, session_id: str) -> None:
    """Increment the user turn count for a session."""
    if not db:
        return
    try:
        _session_ref(uid, session_id).set({
            "userTurnCount": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)
    except Exception as e:
        print(f"[voice] Error incrementing turn count: {e}")
def _try_acquire_periodic_update(uid: str, session_id: str) -> int:
    turn = _get_session_user_turn_count(uid, session_id)
    if turn <= 0 or (turn % 3) != 0:
        return 0

    sref = _session_ref(uid, session_id)
    transaction = db.transaction()

    @firestore.transactional
    def _txn(txn):
        snap = sref.get(transaction=txn)
        data = (snap.to_dict() or {}) if snap.exists else {}
        periodic = data.get("periodic") or {}
        last_turn = int(periodic.get("lastTurn") or 0)
        if turn <= last_turn:
            return 0
        txn.set(sref, {
            "periodic": {"lastTurn": turn, "lastAt": firestore.SERVER_TIMESTAMP},
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)
        return turn

    try:
        return int(_txn(transaction) or 0)
    except Exception:
        return 0

def _write_session_intensity(uid: str, session_id: str, score: Dict[str, Any], turn: int) -> None:
    try:
        sref = _session_ref(uid, session_id)
        transaction = db.transaction()

        @firestore.transactional
        def _txn(txn):
            snap = sref.get(transaction=txn)
            start_val = None
            if snap.exists:
                try:
                    start_val = snap.get("intensity.start")
                except Exception:
                    data = snap.to_dict() or {}
                    start_val = (data.get("intensity") or {}).get("start")

            updates = {
                "intensity.latest": score["intensity"],
                "intensity.latestTurn": int(turn),
                "intensity.signals": score.get("signals") or [],
                "intensity.blend": score.get("blend") is True,
                "intensity.updatedAt": _now_dt(),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            if start_val is None:
                updates["intensity.start"] = score["intensity"]
                updates["intensity.startTurn"] = int(turn)

            if snap.exists:
                txn.update(sref, updates)
            else:
                txn.set(sref, updates, merge=True)

        _txn(transaction)
    except Exception as e:
        print(f"[voice] session_intensity_write_failed: {e}")

def _log_agent_run(ref, payload: Dict[str, Any]) -> None:
    try:
        ref.document().set({**payload, "createdAt": firestore.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        print(f"[voice] agent_run_write_failed: {e}")

def _extract_recent_user_text(messages: List[Dict[str, str]], max_chars: int = 1200) -> str:
    if not messages:
        return ""
    tail = messages[-12:]
    lines = []
    for m in tail:
        role = m.get("role", "")
        content = (m.get("content") or "").strip()
        if not content:
            continue
        if role == "user":
            lines.append(f"USER: {content}")
        elif role == "assistant":
            lines.append(f"ASSISTANT: {content}")
    text = "\n".join(lines)
    return text[-max_chars:]

def score_intensity_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    context = _extract_recent_user_text(messages)

    prompt = (
        "You are a scoring function for an IFS-style chat session.\n"
        "Score the USER's current emotional intensity and blending.\n"
        "Return ONLY JSON with keys:\n"
        '- intensity: number between 0 and 1\n'
        '- blend: boolean (true if user seems merged with the part / "I am" statements / flooded)\n'
        '- signals: array of short strings (e.g. "shame", "panic", "self-criticism", "avoidance")\n'
        '- rationale: 1-2 short sentences explaining why\n'
        "Be language-agnostic: the user may speak Arabic or English.\n"
        f"CharacterId: {character_id}\n"
        "Conversation tail:\n"
        f"{context}\n"
    )

    resp = client.chat.completions.create(
        model=OPENAI_SUMMARY_MODEL,
        messages=[
            {"role": "system", "content": "Return JSON only (no markdown)."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
        response_format={"type": "json_object"},
    )

    raw = resp.choices[0].message.content or "{}"
    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = {}

    intensity = parsed.get("intensity")
    try:
        intensity = float(intensity)
    except Exception:
        intensity = 0.5
    intensity = max(0.0, min(1.0, intensity))

    return {
        "intensity": intensity,
        "blend": parsed.get("blend") is True,
        "signals": parsed.get("signals") or [],
        "rationale": (parsed.get("rationale") or "").strip(),
        "_raw": parsed,
    }

def summarize_session_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    context = _extract_recent_user_text(messages[-2200:]) if len(messages) > 2200 else _extract_recent_user_text(messages)

    prompt = (
        "Summarize this IFS-style voice chat session in a structured way.\n"
        "Return ONLY JSON with keys:\n"
        "- highlights: array of 3-6 short bullet strings\n"
        "- ifsSignals: object with keys like blend, protectorTone, exileHints, selfEnergy (optional)\n"
        "- progressSignals: array of short strings (e.g. 'more curiosity', 'less shame language')\n"
        "- nextStepSuggestion: one short sentence guiding next session focus\n"
        f"CharacterId: {character_id}\n"
        "Conversation:\n"
        f"{context}\n"
    )

    resp = client.chat.completions.create(
        model=OPENAI_SUMMARY_MODEL,
        messages=[
            {"role": "system", "content": "Return JSON only (no markdown)."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
        response_format={"type": "json_object"},
    )

    raw = resp.choices[0].message.content or "{}"
    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = {}

    return {
        "highlights": parsed.get("highlights") or [],
        "ifsSignals": parsed.get("ifsSignals") or {},
        "progressSignals": parsed.get("progressSignals") or [],
        "nextStepSuggestion": (parsed.get("nextStepSuggestion") or "").strip(),
        "_raw": parsed,
    }

def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    """Add an event to user's timeline."""
    if not db:
        return
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })

def ensure_character_checklist(uid: str, character_id: str) -> None:
    """Ensures a per-character plan doc exists - simplified for voice"""
    if not db:
        return
    doc_ref = db.collection('users').document(uid).collection('character_plans').document(character_id)
    snap = doc_ref.get()
    if snap.exists:
        return

    doc_ref.set({
        "status": "active",
        "characterId": character_id,
        "checklistItems": [],
        "focus": {"itemId": None, "reason": ""},
        "metrics": {
            "sessionsCount": 0,
            "lastSessionAt": None,
            "lastIntensityEnd": None,
        },
        "memorySummary": "",
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)
    print(f"✅ Created character plan for {character_id}")

# =============================
# Emotion Integration Helpers
# =============================

def start_emotion_session(uid: str, session_id: str, character_id: str) -> str:
    """Start an emotion tracking session for voice call"""
    try:
        emotion_session_id = f"voice_emotion_{session_id}"

        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/start_session",
            json={
                'session_id': emotion_session_id,
                'user_name': character_id,
                'character_id': character_id
            },
            timeout=5
        )

        if response.status_code == 200:
            print(f"✅ Emotion session started: {emotion_session_id}")
            return emotion_session_id
        else:
            print(f"⚠️ Failed to start emotion session: {response.status_code}")
            return None
    except Exception as e:
        print(f"⚠️ Emotion server not available: {e}")
        return None

def analyze_audio_emotion(emotion_session_id: str, audio_base64: str) -> Dict[str, Any]:
    """Analyze voice emotion from audio data"""
    try:
        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/analyze_audio",
            json={
                'session_id': emotion_session_id,
                'audio': audio_base64
            },
            timeout=10
        )

        if response.status_code == 200:
            return response.json()
        else:
            return {'success': False, 'error': f'HTTP {response.status_code}'}
    except Exception as e:
        print(f"⚠️ Voice emotion analysis error: {e}")
        return {'success': False, 'error': str(e)}

def end_emotion_session(emotion_session_id: str) -> Dict[str, Any]:
    """End an emotion tracking session and get final analysis"""
    try:
        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/end_session",
            json={'session_id': emotion_session_id},
            timeout=10
        )

        if response.status_code == 200:
            return response.json()
        else:
            return {'success': False, 'error': f'HTTP {response.status_code}'}
    except Exception as e:
        print(f"⚠️ Error ending emotion session: {e}")
        return {'success': False, 'error': str(e)}
# =============================
# OpenAI Helpers
# =============================
def transcribe_audio(wav_path: str) -> str:
    with open(wav_path, "rb") as f:
        t = client.audio.transcriptions.create(
            model=OPENAI_TRANSCRIBE_MODEL,
            file=f,
            language="en"
        )
        return (getattr(t, "text", "") or "").strip()

def tts_to_file(text: str, out_path: str, voice: str = VOICE_NAME):
    audio = client.audio.speech.create(
        model=OPENAI_TTS_MODEL,
        voice=voice,
        input=text,
        response_format="wav",
    )
    with open(out_path, "wb") as f:
        f.write(audio.read())

def tts_to_base64(text: str, voice: str = VOICE_NAME) -> str:
    audio = client.audio.speech.create(
        model=OPENAI_TTS_MODEL,
        voice=voice,
        input=text,
        response_format="wav",
    )
    return base64.b64encode(audio.read()).decode("utf-8")

def make_public_audio_url(req, filename: str) -> str:
    host = req.host.split(":")[0]
    if host in ["127.0.0.1", "localhost"]:
        host = "10.0.2.2"
    return f"http://{host}:5004/voice/audio/{filename}"

# =============================
# Agents API Helpers
# =============================
def get_character_response(uid: str, character_id: str, character_profile: Dict, messages: List[Dict]) -> Dict:
    try:
        response = requests.post(
            f"{AGENTS_URL}/chat",
            json={
                "uid": uid,
                "characterId": character_id,
                "characterProfile": character_profile,
                "messages": messages,
                "checkIntervention": True,
                "language": "en"
            },
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling agents service: {e}")
        return {"success": False, "assistantMessage": "I'm having trouble connecting.", "intervention": None}

# Add these functions after the existing helper functions in voice_routes.py

def _update_voice_emotion(uid: str, session_id: str, emotion: str, confidence: float) -> None:
    """Update voice emotion data in Firestore (mirroring video session structure)."""
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            return

        current_data = snap.to_dict() or {}
        voice_data = current_data.get('voiceTone', {})
        all_detections = voice_data.get('allDetections', [])

        all_detections.append({
            'emotion': emotion,
            'confidence': confidence,
            'timestamp': datetime.now(timezone.utc).isoformat()
        })

        from collections import Counter
        emotion_counts = Counter([d['emotion'] for d in all_detections])
        dominant = emotion_counts.most_common(1)[0][0] if emotion_counts else None
        avg_confidence = sum([d['confidence'] for d in all_detections]) / len(all_detections) if all_detections else 0
        start_emotion = all_detections[0]['emotion'] if all_detections else None
        start_confidence = all_detections[0]['confidence'] if all_detections else 0
        end_emotion = all_detections[-1]['emotion'] if all_detections else None
        end_confidence = all_detections[-1]['confidence'] if all_detections else 0

        sref.set({
            'voiceTone': {
                'dominant': dominant,
                'averageConfidence': avg_confidence,
                'startEmotion': start_emotion,
                'startConfidence': start_confidence,
                'endEmotion': end_emotion,
                'endConfidence': end_confidence,
                'allDetections': all_detections,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
        }, merge=True)

        print(f"🎭 Voice emotion updated: {emotion} ({confidence:.2f}), dominant: {dominant}")

    except Exception as e:
        print(f"Error updating voice emotion: {e}")

def get_guided_response(uid: str, character_id: str, character_profile: Dict, messages: List[Dict]) -> Dict:
    try:
        response = requests.post(
            f"{AGENTS_URL}/chat_guided",
            json={
                "uid": uid,
                "characterId": character_id,
                "characterProfile": character_profile,
                "messages": messages,
                 "language": "en"
            },
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling guided agents service: {e}")
        return {"success": False, "characterMessage": "", "guiderMessage": "", "respondent": "character_only"}

def get_guider_response(uid: str, messages: List[Dict]) -> Dict:
    try:
        response = requests.post(
            f"{AGENTS_URL}/chat_guider",
            json={"uid": uid, "messages": messages},
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling guider service: {e}")
        return {"success": False, "assistantMessage": "I'm here to support you."}

# =============================
# Routes
# =============================

@voice_bp.route('/create_session', methods=['POST'])
def create_session():
    """Create a new voice session and thread - called by Flutter"""
    try:
        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId')
        character_type = data.get('characterType', 'inner_character')
        title = data.get('title', 'Voice Session')

        if not uid or not character_id:
            return jsonify({'success': False, 'error': 'uid and characterId required'}), 400

        session_id = f"voice_{int(time.time() * 1000)}_{character_id}"
        thread_id = str(uuid.uuid4())

        session_ref = _session_ref(uid, session_id)
        session_ref.set({
            "id": session_id,
            "type": "voice",
            "characterId": character_id,
            "characterType": character_type,
            "threadId": thread_id,
            "status": "active",
            "title": title,
            "startedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "userTurnCount": 0,
            "intensity": {},
            "sessionSummary": {},
            "periodic": {},
        }, merge=True)

        thread_ref = _threads_ref(uid).document(thread_id)
        thread_ref.set({
            "id": thread_id,
            "sessionId": session_id,
            "characterId": character_id,
            "characterType": character_type,
            "title": title,
            "status": "active",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        print(f"✅ Created voice session: {session_id}, thread: {thread_id}")
        return jsonify({'success': True, 'sessionId': session_id, 'threadId': thread_id})

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500

@voice_bp.route('/get_active_session', methods=['GET'])
def get_active_session():
    """Get the active session for a character - called by Flutter"""
    try:
        uid = request.args.get('uid')
        character_id = request.args.get('characterId')

        if not uid or not character_id:
            return jsonify({'success': False, 'error': 'uid and characterId required'}), 400

        sessions_ref = _sessions_ref(uid)
        query = sessions_ref.where('characterId', '==', character_id).where('status', '==', 'active').limit(1)
        docs = query.stream()

        for doc in docs:
            data = doc.to_dict()
            thread_id = data.get('threadId')
            if not thread_id:
                threads_ref = _threads_ref(uid)
                thread_query = threads_ref.where('sessionId', '==', doc.id).limit(1)
                thread_docs = thread_query.stream()
                for tdoc in thread_docs:
                    thread_id = tdoc.id
                    doc.reference.set({'threadId': thread_id}, merge=True)
                    break

            return jsonify({
                'success': True,
                'session': {
                    'id': doc.id,
                    'threadId': thread_id,
                    'characterId': data.get('characterId'),
                    'status': data.get('status'),
                    'startedAt': data.get('startedAt'),
                }
            })

        return jsonify({'success': True, 'session': None})

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500

@voice_bp.get("/health")
def voice_health():
    agents_ok = False
    try:
        agents_response = requests.get(f"{AGENTS_URL}/health", timeout=5)
        agents_ok = agents_response.status_code == 200
    except:
        pass
    return jsonify({"ok": True, "openai_ready": bool(os.getenv("OPENAI_API_KEY")), "firebase_ready": db is not None, "agents_ready": agents_ok})

@voice_bp.get("/audio/<filename>")
def get_audio(filename: str):
    p = os.path.join(TTS_DIR, filename)
    if not os.path.exists(p):
        return jsonify({"success": False, "error": "Audio not found"}), 404
    return send_file(p, mimetype="audio/wav", as_attachment=False)

@voice_bp.post("/transcribe")
def transcribe_route():
    try:
        file = request.files.get("file")
        if not file:
            return jsonify({"success": False, "error": "Missing form file 'file'"}), 400
        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
        in_path = os.path.join(RECORDINGS_DIR, f"transcribe_{ts}.wav")
        file.save(in_path)
        transcript = transcribe_audio(in_path)
        return jsonify({"success": True, "transcript": transcript, "language": detect_lang(transcript)})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@voice_bp.post("/chat")
def voice_chat():
    """
    Main voice chat endpoint with full Guider support - accepts audio file upload.
    """
    try:
        uid = (request.form.get("uid") or "").strip()
        if not uid:
            return jsonify({"success": False, "error": "uid is required"}), 400

        character_id = (request.form.get("characterId") or "inner_critic").strip()
        use_guided = request.form.get("guided", "true").lower() == "true"
        session_id = request.form.get("sessionId", "").strip()
        thread_id = request.form.get("threadId", "").strip()
        guider_active = request.form.get("guiderActive", "false").lower() == "true"

        file = request.files.get("audio")
        if file is None:
            return jsonify({"success": False, "error": "Missing audio file. Use form field name 'audio'."}), 400

        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
        in_name = f"{uid}_{character_id}_{ts}_user.wav"
        in_path = os.path.join(RECORDINGS_DIR, in_name)
        file.save(in_path)

        if os.path.getsize(in_path) < 4000:
            return jsonify({"success": False, "error": "Audio too short or empty. Try a longer recording."}), 400

        transcript = transcribe_audio(in_path)
        if not transcript:
            return jsonify({"success": False, "error": "Transcription returned empty. Try again."}), 400

        # Get or create session/thread (MOVED UP)
        if not session_id or not thread_id:
            sessions_ref = _sessions_ref(uid)
            query = sessions_ref.where('characterId', '==', character_id).where('status', '==', 'active').limit(1)
            docs = query.stream()
            for doc in docs:
                data_dict = doc.to_dict()
                session_id = doc.id
                thread_id = data_dict.get('threadId')
                if thread_id:
                    break

            if not session_id or not thread_id:
                session_id = f"voice_{int(time.time() * 1000)}_{character_id}"
                thread_id = str(uuid.uuid4())
                character_profile = {
                    "displayName": character_id.replace("_", " ").title(),
                }
                _session_ref(uid, session_id).set({
                    "id": session_id, "type": "voice", "characterId": character_id,
                    "characterType": "inner_character", "threadId": thread_id, "status": "active",
                    "title": f"Voice call with {character_profile.get('displayName', character_id)}",
                    "startedAt": firestore.SERVER_TIMESTAMP, "updatedAt": firestore.SERVER_TIMESTAMP,
                    "lastMessageAt": firestore.SERVER_TIMESTAMP, "userTurnCount": 0,
                }, merge=True)
                _threads_ref(uid).document(thread_id).set({
                    "id": thread_id, "sessionId": session_id, "characterId": character_id,
                    "characterType": "inner_character",
                    "title": f"Voice call with {character_profile.get('displayName', character_id)}",
                    "status": "active", "createdAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP, "lastMessageAt": firestore.SERVER_TIMESTAMP,
                }, merge=True)

        # Ensure session and thread documents exist
        character_profile = {
            "displayName": character_id.replace("_", " ").title(),
            "role": "Inner Part",
            "shortDescription": "",
            "whyIExist": "",
            "triggers": [],
            "coreBelief": "",
            "intention": "",
            "fear": "",
            "whatINeed": []
        }
        emotion_session_id = None
        if db:
            _ensure_session_doc(uid, session_id, character_id, thread_id, character_profile)
            _ensure_thread_doc(uid, thread_id, session_id, character_id, character_profile)
            _increment_session_turn(uid, session_id)
            current_turn = _get_session_user_turn_count(uid, session_id)
            print(f"[voice] Session {session_id} - Turn: {current_turn}")

            # Start emotion session (NOW DEFINED HERE)
            emotion_session_id = start_emotion_session(uid, session_id, character_id)

        # NOW analyze voice emotion (AFTER emotion_session_id is defined)
        if emotion_session_id:
            with open(in_path, "rb") as audio_file:
                audio_base64 = base64.b64encode(audio_file.read()).decode('utf-8')

            emotion_result = analyze_audio_emotion(emotion_session_id, audio_base64)
            if emotion_result.get('success'):
                voice_emotion = emotion_result.get('voice_emotion', {})
                if voice_emotion:
                    emotion = voice_emotion.get('emotion', 'neutral')
                    confidence = voice_emotion.get('confidence', 0.0)
                    print(f"🎭 Voice emotion detected: {emotion} ({confidence*100:.1f}%)")

                    if db and session_id:
                                    _update_voice_emotion(uid, session_id, emotion, confidence)
                    if db and session_id:
                        _session_ref(uid, session_id).set({
                            f"emotions.voice_{datetime.utcnow().isoformat()}": {
                                'emotion': emotion,
                                'confidence': confidence,
                                'timestamp': firestore.SERVER_TIMESTAMP
                            }
                        }, merge=True)

        # Save user message
        if thread_id and transcript:
            _save_message(uid, thread_id, 'user', transcript, 'user', character_id, session_id)
        messages = [{"role": "user", "content": transcript}]

        assistant_text = ""
        is_guider_message = False
        respondent = "character_only"
        character_message = ""
        guider_message = ""

        if guider_active:
            # Guider is active - use /chat_guider endpoint
            guider_messages = [{"role": "user", "content": transcript}]
            guider_response = get_guider_response(uid, guider_messages)
            assistant_text = guider_response.get("assistantMessage", "I'm here with you.")
            is_guider_message = True
            respondent = "guider_only"

        elif use_guided:
            # Use guided chat (character + guider)
            agent_response = get_guided_response(uid, character_id, character_profile, messages)
            character_message = agent_response.get("characterMessage", "")
            guider_message = agent_response.get("guiderMessage", "")
            respondent = agent_response.get("respondent", "character_only")

            if guider_message and respondent == "both":
                assistant_text = f"{character_message} {guider_message}"
                is_guider_message = False
            elif guider_message and respondent == "guider_only":
                assistant_text = guider_message
                is_guider_message = True
            else:
                assistant_text = character_message
                is_guider_message = False
        else:
            # Use regular character chat with intervention detection
            agent_response = get_character_response(uid, character_id, character_profile, messages)
            assistant_text = agent_response.get("assistantMessage", "")
            is_guider_message = False

            # Check for Guider intervention
            intervention = agent_response.get("intervention")
            if intervention and intervention.get("shouldIntervene"):
                return jsonify({
                    "success": True,
                    "transcript": transcript,
                    "needsIntervention": True,
                    "interventionMessage": intervention.get("guiderMessage", ""),
                    "interventionReason": intervention.get("reason", ""),
                    "interventionSeverity": intervention.get("severity", "medium")
                })

        if not assistant_text:
            assistant_text = "I'm here listening. Please continue."
            is_guider_message = False

        # Save assistant message
        if thread_id and assistant_text:
            _save_message(uid, thread_id, 'assistant', assistant_text, character_id, character_id, session_id)

        # Periodic intensity update (every 3 turns)
        if db and not guider_active and session_id:
            turn_for_update = _try_acquire_periodic_update(uid, session_id)
            if turn_for_update:
                try:
                    intensity_score = 0.3
                    if any(keyword in transcript.lower() for keyword in ['hate', 'angry', 'furious', 'depressed', 'hopeless']):
                        intensity_score = 0.7
                    if any(keyword in transcript.lower() for keyword in ['suicidal', 'hurt myself', 'kill myself']):
                        intensity_score = 0.95

                    score = {
                        "intensity": intensity_score,
                        "blend": intensity_score > 0.6,
                        "signals": ["voice_detected"]
                    }

                    _write_session_intensity(uid, session_id, score, turn_for_update)

                    _log_agent_run(
                        _session_runs_ref(uid, session_id),
                        {
                            "trigger": "voice_user_message",
                            "inputs": {"characterId": character_id},
                            "outputs": {
                                "intensity": score["intensity"],
                                "blend": score.get("blend") is True,
                                "transcript": transcript[:200],
                            },
                        },
                    )

                    print(f"[voice] Periodic update - turn: {turn_for_update}, intensity: {score['intensity']}")
                except Exception as e:
                    print(f"[voice] Periodic update failed: {e}")

        # Generate TTS with appropriate voice
        voice_to_use = GUIDER_VOICE if is_guider_message else VOICE_NAME

        out_name = f"{uid}_{character_id}_{ts}_ai.wav"
        out_path = os.path.join(TTS_DIR, out_name)
        # FORCE FINAL OUTPUT LANGUAGE SAFETY
        if detect_lang(assistant_text) == "ar":
            print("⚠️ Arabic output detected, forcing English fallback")
            assistant_text = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "Rewrite in natural, simple English. Keep meaning unchanged. No extra text."},
                    {"role": "user", "content": assistant_text}
                ],
                temperature=0.2
            ).choices[0].message.content
        tts_to_file(assistant_text, out_path, voice=voice_to_use)
        audio_url = make_public_audio_url(request, out_name)

        response_data = {
            "success": True,
            "lang": detect_lang(assistant_text),
            "transcript": transcript,
            "assistantText": assistant_text,
            "audioUrl": audio_url,
            "audioBase64": "",
            "savedUserAudioPath": in_path,
            "savedAiAudioPath": out_path,
            "isGuider": is_guider_message,
            "respondent": respondent
        }

        if character_message:
            response_data["characterMessage"] = character_message
        if guider_message:
            response_data["guiderMessage"] = guider_message

        return jsonify(response_data)

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": f"Voice chat error: {str(e)}"}), 500
@voice_bp.route('/session_summary', methods=['POST'])
def session_summary():
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        duration = data.get('duration', 0)
        messages = data.get('messages', [])

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        sref = _session_ref(uid, session_id)
        snap = sref.get()
        existing = (snap.to_dict() or {}) if snap.exists else {}

        # Get intensity score using LLM
        intensity_score = score_intensity_with_llm(character_id, messages)

        # Get start intensity
        start_val = None
        if snap.exists:
            try:
                start_val = snap.get("intensity.start")
            except Exception:
                start_val = (existing.get("intensity") or {}).get("start")

        if start_val is None:
            start_val = intensity_score["intensity"]

        try:
            delta = float(intensity_score["intensity"]) - float(start_val)
        except Exception:
            delta = 0.0

        # Generate summary using LLM
        summary = summarize_session_with_llm(character_id, messages)
        voice_tone = existing.get('voiceTone', {})

        # ✅ Get any face emotion data (though voice sessions typically don't have this)
        face_emotion = existing.get('faceEmotion', {})

        # Update character plan metrics
        if db:
            ensure_character_checklist(uid, character_id)
            plan_ref = db.collection('users').document(uid).collection('character_plans').document(character_id)
            plan_ref.set({
                "metrics.lastSessionAt": firestore.SERVER_TIMESTAMP,
                "metrics.sessionsCount": firestore.Increment(1),
                "metrics.lastIntensityEnd": intensity_score["intensity"],
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

        sref.set({
            "intensity": {
                "start": start_val,
                "end": intensity_score["intensity"],
                "delta": delta,
                "latest": intensity_score["intensity"],
                "signals": intensity_score.get("signals") or [],
                "blend": intensity_score.get("blend") is True,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            "sessionSummary": {
                "highlights": summary.get("highlights") or [],
                "ifsSignals": summary.get("ifsSignals") or {},
                "progressSignals": summary.get("progressSignals") or [],
                "nextStepSuggestion": summary.get("nextStepSuggestion") or "",
                "duration": duration,
            },
            "duration": duration,
            "endedAt": firestore.SERVER_TIMESTAMP,
            "status": "ended",
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "endedAnalyzedAt": firestore.SERVER_TIMESTAMP,
            "voiceTone": voice_tone,
        }, merge=True)

        # Log agent run
        if db:
            _log_agent_run(
                _session_runs_ref(uid, session_id),
                {
                    "trigger": "session_end",
                    "inputs": {"threadId": thread_id, "characterId": character_id},
                    "outputs": {
                        "intensityEnd": intensity_score["intensity"],
                        "delta": delta,
                        "summary": summary.get("_raw") or {},
                    },
                    "rawModelOutput": {
                        "intensity": intensity_score.get("_raw") or {},
                        "summary": summary.get("_raw") or {},
                    },
                },
            )

        # Add timeline event
        character_names = {
            'inner_critic': 'Inner Critic',
            'perfectionist': 'Perfectionist',
            'people_pleaser': 'People Pleaser',
            'lonely': 'Lonely Part',
            'workaholic': 'Workaholic',
            'procrastinator': 'Procrastinator',
            'wounded_child': 'Wounded Child',
        }
        display_name = character_names.get(character_id, character_id.replace('_', ' ').title())

        add_timeline_event(uid, {
            'type': 'voice_session',
            'title': f'Voice call with {display_name}',
            'summary': (summary.get('highlights') or ['Session completed'])[0][:200],
        })

        return jsonify({
            'success': True,
            'intensityEnd': intensity_score["intensity"],
            'delta': delta,
            'sessionSummary': {
                'highlights': summary.get("highlights") or [],
                'nextStepSuggestion': summary.get("nextStepSuggestion") or "",
            },
            # ✅ Return voice emotion data to Flutter
            'voiceTone': {
                'dominant': voice_tone.get('dominant'),
                'averageConfidence': voice_tone.get('averageConfidence', 0),
                'startEmotion': voice_tone.get('startEmotion'),
                'endEmotion': voice_tone.get('endEmotion'),
                'totalDetections': len(voice_tone.get('allDetections', []))
                }
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Summary error: {str(e)}'}), 500
@voice_bp.route('/end_session', methods=['POST'])
def end_session():
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')
        emotion_session_id = data.get('emotionSessionId')

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400


        _session_ref(uid, session_id).set({
            "status": "ended",
            "endedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        # End emotion session if exists
        if emotion_session_id:
            final_analysis = end_emotion_session(emotion_session_id)
            if final_analysis.get('success'):
                print(f"🎭 Final emotion analysis saved for session {session_id}")
                _session_ref(uid, session_id).set({
                    'final_emotion_analysis': final_analysis.get('final_analysis', {})
                }, merge=True)

        return jsonify({'success': True})
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500

@voice_bp.route('/debug_messages', methods=['GET'])
def debug_messages():
    """Debug endpoint to check messages in a thread"""
    try:
        uid = request.args.get('uid')
        thread_id = request.args.get('threadId')
        if not uid or not thread_id:
            return jsonify({'success': False, 'error': 'uid and threadId required'}), 400
        messages = []
        docs = _messages_ref(uid, thread_id).order_by("createdAt").stream()
        for doc in docs:
            data = doc.to_dict()
            messages.append({'id': doc.id, 'role': data.get('role'), 'content': data.get('content', '')[:100]})
        return jsonify({'success': True, 'threadId': thread_id, 'messageCount': len(messages), 'messages': messages})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# =============================
# EMOTION INTEGRATION ENDPOINTS (for voice call)
# =============================

@voice_bp.route('/emotion/start_session', methods=['POST'])
def voice_emotion_start_session():
    """Start an emotion tracking session for voice call"""
    try:
        data = request.json or {}
        session_id = data.get('session_id')
        user_name = data.get('user_name', 'User')
        character_id = data.get('character_id')

        if not session_id:
            session_id = f"voice_emotion_{int(time.time() * 1000)}"

        print(f"🎭 Voice emotion session started: {session_id}")
        return jsonify({'success': True, 'session_id': session_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@voice_bp.route('/emotion/analyze_audio', methods=['POST'])
def voice_analyze_emotion():
    """Analyze voice emotion from audio data - calls emotion_detector.py"""
    try:
        data = request.json or {}
        session_id = data.get('session_id')
        audio_data = data.get('audio')

        if not session_id or not audio_data:
            return jsonify({'success': False, 'error': 'Missing session_id or audio data'}), 400

        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/analyze_audio",
            json={
                'session_id': session_id,
                'audio': audio_data
            },
            timeout=10
        )

        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'success': False, 'error': 'Emotion analysis failed'}), 500

    except Exception as e:
        print(f"Voice emotion analysis error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@voice_bp.route('/emotion/end_session', methods=['POST'])
def voice_emotion_end_session():
    """End an emotion tracking session"""
    try:
        data = request.json or {}
        session_id = data.get('session_id')

        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/end_session",
            json={'session_id': session_id},
            timeout=10
        )

        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'success': True, 'message': 'Session ended'})

    except Exception as e:
        print(f"Error ending emotion session: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@voice_bp.route('/emotion/get_session_emotion', methods=['POST'])
def voice_get_session_emotion():
    """Get current emotion analysis for a session"""
    try:
        data = request.json or {}
        session_id = data.get('session_id')

        response = requests.post(
            f"{EMOTION_SERVER_URL}/emotion/get_session_emotion",
            json={'session_id': session_id},
            timeout=10
        )

        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'success': False, 'error': 'Failed to get emotion data'}), 500

    except Exception as e:
        print(f"Error getting emotion data: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@voice_bp.route('/emotion/health', methods=['GET'])
def voice_emotion_health():
    """Health check for emotion service"""
    try:
        response = requests.get(f"{EMOTION_SERVER_URL}/emotion/health", timeout=5)
        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'success': False, 'error': 'Emotion service not available'}), 503
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 503