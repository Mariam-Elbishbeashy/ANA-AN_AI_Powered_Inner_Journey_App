import os
import json
import base64
import re
import traceback
import requests
from datetime import datetime
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
VOICE_NAME = os.getenv("OPENAI_VOICE", "nova")

# Agents service URL (internal communication)
AGENTS_URL = os.getenv("AGENTS_URL", "http://localhost:5001")

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RECORDINGS_DIR = os.path.join(BASE_DIR, "recordings")
TTS_DIR = os.path.join(BASE_DIR, "tts_output")
os.makedirs(RECORDINGS_DIR, exist_ok=True)
os.makedirs(TTS_DIR, exist_ok=True)

# =============================
# Optional Firebase (safe)
# =============================
db = None
try:
    import firebase_admin
    from firebase_admin import credentials, firestore

    key_path = os.getenv("FIREBASE_KEY_PATH", os.path.join(BASE_DIR, "firebase-key.json"))
    if os.path.exists(key_path):
        try:
            firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("✅ Firebase initialized (voice_routes)")
    else:
        print("⚠️ Firebase key not found - running without Firestore (voice_routes)")
except Exception:
    db = None
    print("⚠️ Firebase not initialized - running without Firestore (voice_routes)")

# =============================
# Language detection (still needed for TTS)
# =============================
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

def detect_lang(text: str) -> str:
    return "ar" if ARABIC_RE.search(text or "") else "en"

# =============================
# Helpers - OpenAI (only transcription and TTS)
# =============================
def transcribe_audio(wav_path: str) -> str:
    with open(wav_path, "rb") as f:
        t = client.audio.transcriptions.create(
            model=OPENAI_TRANSCRIBE_MODEL,
            file=f,
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

    # Android emulator fix
    if host in ["127.0.0.1", "localhost"]:
        host = "10.0.2.2"

    return f"http://{host}:5003/voice/audio/{filename}"

def _save_chat_to_firestore(uid: str, character_id: str, user_text: str, ai_text: str):
    """
    Save voice messages exactly like the Flutter text chat:
    users/{uid}/chat_threads/{threadId}/messages
    """

    if not db:
        print("⚠️ Firestore not initialized")
        return

    try:
        user_ref = db.collection("users").document(uid)
        threads_ref = user_ref.collection("chat_threads")

        # 1️⃣ find active thread for this character
        query = (
            threads_ref
            .where("characterId", "==", character_id)
            .where("status", "==", "active")
            .limit(1)
            .stream()
        )

        thread_doc = None
        for doc in query:
            thread_doc = doc
            break

        # 2️⃣ create thread if none exists
        if thread_doc is None:
            new_thread_ref = threads_ref.document()

            new_thread_ref.set({
                "characterId": character_id,
                "characterType": "inner_character",
                "title": character_id,
                "status": "active",
                "createdAt": datetime.utcnow(),
                "updatedAt": datetime.utcnow(),
                "lastMessageAt": datetime.utcnow()
            })

            thread_id = new_thread_ref.id
        else:
            thread_id = thread_doc.id

        # 3️⃣ messages path
        messages_ref = (
            user_ref
            .collection("chat_threads")
            .document(thread_id)
            .collection("messages")
        )

        # 4️⃣ save user message
        messages_ref.add({
            "role": "user",
            "content": user_text,
            "createdAt": datetime.utcnow(),
            "metadata": {
                "source": "voice",
                "characterId": character_id
            }
        })

        # 5️⃣ save assistant message
        messages_ref.add({
            "role": "assistant",
            "content": ai_text,
            "createdAt": datetime.utcnow(),
            "metadata": {
                "source": "voice",
                "characterId": character_id
            }
        })

        # 6️⃣ update thread timestamps
        threads_ref.document(thread_id).update({
            "updatedAt": datetime.utcnow(),
            "lastMessageAt": datetime.utcnow()
        })

        print(f"✅ Voice messages saved to thread {thread_id}")

    except Exception as e:
        print("❌ FIRESTORE SAVE ERROR")
        traceback.print_exc()

# =============================
# Agents API Helpers
# =============================
def get_character_response(uid: str, character_id: str, character_profile: Dict, messages: List[Dict]) -> Dict:
    """Call the agents service to get a character response."""
    try:
        response = requests.post(
            f"{AGENTS_URL}/chat",
            json={
                "uid": uid,
                "characterId": character_id,
                "characterProfile": character_profile,
                "messages": messages,
                "checkIntervention": True  # Enable Guider intervention
            },
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling agents service: {e}")
        # Fallback response if agents service fails
        return {
            "success": False,
            "assistantMessage": "I'm having trouble connecting right now. Please try again in a moment.",
            "toolCalls": [],
            "intervention": None
        }

def get_guided_response(uid: str, character_id: str, character_profile: Dict, messages: List[Dict]) -> Dict:
    """Call the agents service for guided chat (character + guider)."""
    try:
        response = requests.post(
            f"{AGENTS_URL}/chat_guided",
            json={
                "uid": uid,
                "characterId": character_id,
                "characterProfile": character_profile,
                "messages": messages
            },
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling guided agents service: {e}")
        return {
            "success": False,
            "characterMessage": "",
            "guiderMessage": "",
            "respondent": "character_only"
        }

# =============================
# Routes
# =============================
@voice_bp.get("/health")
def voice_health():
    # Check if agents service is reachable
    agents_ok = False
    try:
        agents_response = requests.get(f"{AGENTS_URL}/health", timeout=5)
        agents_ok = agents_response.status_code == 200
    except:
        pass

    return jsonify({
        "ok": True,
        "openai_ready": bool(os.getenv("OPENAI_API_KEY")),
        "firebase_ready": db is not None,
        "agents_ready": agents_ok
    })

@voice_bp.get("/audio/<filename>")
def get_audio(filename: str):
    p = os.path.join(TTS_DIR, filename)
    if not os.path.exists(p):
        return jsonify({"success": False, "error": "Audio not found"}), 404
    return send_file(p, mimetype="audio/wav", as_attachment=False)

@voice_bp.post("/tts_test")
def tts_test():
    try:
        data = request.get_json(silent=True) or {}
        uid = (data.get("uid") or "test_user").strip()
        voice = (data.get("voice") or VOICE_NAME).strip()
        text = (data.get("text") or "I’m listening… and you’re safe.").strip()

        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
        out_name = f"{uid}_tts_test_{ts}.wav"
        out_path = os.path.join(TTS_DIR, out_name)

        tts_to_file(text, out_path, voice=voice)
        audio_url = make_public_audio_url(request, out_name)

        return jsonify({"success": True, "voice": voice, "text": text, "audioUrl": audio_url})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

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

@voice_bp.post("/tts")
def tts_route():
    try:
        data = request.get_json(silent=True) or {}
        text = (data.get("text") or "").strip()
        voice = (data.get("voice") or VOICE_NAME).strip()
        if not text:
            return jsonify({"success": False, "error": "No text provided"}), 400

        audio_b64 = tts_to_base64(text, voice=voice)
        return jsonify({"success": True, "wav_base64": audio_b64, "voice": voice, "text_length": len(text)})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@voice_bp.post("/complete")
def voice_complete():
    """
    Legacy endpoint - kept for backward compatibility.
    Uses agents service for AI responses.
    """
    try:
        file = request.files.get("file")
        if not file:
            return jsonify({"success": False, "error": "Missing form file 'file'"}), 400

        uid = (request.form.get("uid") or "anonymous").strip()
        character_id = (request.form.get("characterId") or "inner_critic").strip()

        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
        in_path = os.path.join(RECORDINGS_DIR, f"{uid}_{character_id}_{ts}_complete_user.wav")
        file.save(in_path)

        transcript = transcribe_audio(in_path)
        if not transcript:
            return jsonify({"success": False, "error": "Transcription returned empty"}), 400

        # Get character profile (simplified - in production, fetch from Firebase)
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

        # Get response from agents service
        messages = [{"role": "user", "content": transcript}]
        agent_response = get_character_response(uid, character_id, character_profile, messages)

        assistant_text = agent_response.get("assistantMessage", "I'm here listening.")

        # Check for Guider intervention
        intervention = agent_response.get("intervention")
        if intervention and intervention.get("shouldIntervene"):
            # If Guider intervened, use their message instead
            assistant_text = intervention.get("guiderMessage", assistant_text)

        audio_b64 = tts_to_base64(assistant_text, voice=VOICE_NAME)

        _save_chat_to_firestore(uid, character_id, transcript, assistant_text)

        return jsonify({
            "success": True,
            "transcript": transcript,
            "assistantText": assistant_text,
            "wav_base64": audio_b64,
            "lang": detect_lang(assistant_text),
            "intervention": intervention
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@voice_bp.post("/chat")
def voice_chat():
    """
    Main voice chat endpoint.
    Uses agents service for AI responses with full guided chat support.
    """
    try:
        uid = (request.form.get("uid") or "").strip()
        if not uid:
            return jsonify({"success": False, "error": "uid is required"}), 400

        character_id = (request.form.get("characterId") or "inner_critic").strip()
        use_guided = request.form.get("guided", "true").lower() == "true"

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

        # Get character profile (simplified - in production, fetch from Firebase)
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

        messages = [{"role": "user", "content": transcript}]

        if use_guided:
            # Use guided chat (character + guider)
            agent_response = get_guided_response(uid, character_id, character_profile, messages)
            character_message = agent_response.get("characterMessage", "")
            guider_message = agent_response.get("guiderMessage", "")
            respondent = agent_response.get("respondent", "character_only")

            # Combine messages for TTS
            if guider_message and respondent == "both":
                # When both respond, character speaks first, then guider
                assistant_text = f"{character_message} {guider_message}"
            elif guider_message and respondent == "guider_only":
                assistant_text = guider_message
            else:
                assistant_text = character_message
        else:
            # Use regular character chat with intervention
            agent_response = get_character_response(uid, character_id, character_profile, messages)
            assistant_text = agent_response.get("assistantMessage", "")

            # Check for Guider intervention
            intervention = agent_response.get("intervention")
            if intervention and intervention.get("shouldIntervene"):
                assistant_text = intervention.get("guiderMessage", assistant_text)

        if not assistant_text:
            assistant_text = "I'm here listening. Please continue."

        out_name = f"{uid}_{character_id}_{ts}_ai.wav"
        out_path = os.path.join(TTS_DIR, out_name)
        tts_to_file(assistant_text, out_path, voice=VOICE_NAME)
        audio_url = make_public_audio_url(request, out_name)

        _save_chat_to_firestore(uid, character_id, transcript, assistant_text)

        response_data = {
            "success": True,
            "lang": detect_lang(assistant_text),
            "transcript": transcript,
            "assistantText": assistant_text,
            "audioUrl": audio_url,
            "audioBase64": "",
            "savedUserAudioPath": in_path,
            "savedAiAudioPath": out_path,
        }

        # Add guided chat metadata if applicable
        if use_guided:
            response_data["respondent"] = respondent
            if 'character_message' in locals() and character_message:
                response_data["characterMessage"] = character_message
            if 'guider_message' in locals() and guider_message:
                response_data["guiderMessage"] = guider_message
        else:
            # Add intervention data if any
            intervention = agent_response.get("intervention")
            if intervention:
                response_data["intervention"] = intervention

        return jsonify(response_data)

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": f"Voice chat error: {str(e)}"}), 500

# =============================
# Conversation history endpoints (now proxy to agents)
# =============================
@voice_bp.get("/conversations/<uid>/<character_id>")
def get_conversation(uid: str, character_id: str):
    """Get conversation history - proxies to Firebase directly"""
    if not db:
        return jsonify({"success": False, "error": "Firebase not available"}), 503

    try:
        # Fetch from Firestore
        user_ref = db.collection("users").document(uid)
        threads_ref = user_ref.collection("chat_threads")

        # Find thread for this character
        query = threads_ref.where("characterId", "==", character_id).limit(1).stream()
        thread_doc = None
        for doc in query:
            thread_doc = doc
            break

        if not thread_doc:
            return jsonify({
                "success": True,
                "uidKey": f"{uid}:{character_id}",
                "summary": "",
                "messages": []
            })

        # Get messages
        messages_ref = threads_ref.document(thread_doc.id).collection("messages")
        messages = messages_ref.order_by("createdAt").stream()

        message_list = []
        for msg in messages:
            data = msg.to_dict()
            message_list.append({
                "role": data.get("role", "user"),
                "content": data.get("content", ""),
                "createdAt": str(data.get("createdAt", ""))
            })

        # Get memory summary from agent_memory collection
        memory_ref = user_ref.collection("agent_memory").document(character_id)
        memory_doc = memory_ref.get()
        summary = memory_doc.to_dict().get("summary", "") if memory_doc.exists else ""

        return jsonify({
            "success": True,
            "uidKey": f"{uid}:{character_id}",
            "summary": summary,
            "messages": message_list
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@voice_bp.post("/conversations/<uid>/<character_id>/clear")
def clear_conversation(uid: str, character_id: str):
    """Clear conversation - can't really delete from Firestore, so just return success"""
    # In a real implementation, you might want to archive or delete messages
    return jsonify({
        "success": True,
        "message": "Conversation clear requested",
        "uidKey": f"{uid}:{character_id}"
    })