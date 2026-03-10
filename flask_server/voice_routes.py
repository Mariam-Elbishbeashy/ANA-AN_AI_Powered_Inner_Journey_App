import os
import json
import base64
import re
import traceback
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
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")
OPENAI_TRANSCRIBE_MODEL = os.getenv("OPENAI_TRANSCRIBE_MODEL", "whisper-1")
OPENAI_TTS_MODEL = os.getenv("OPENAI_TTS_MODEL", "tts-1")
VOICE_NAME = os.getenv("OPENAI_VOICE", "nova")

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
# Language + plan helpers
# =============================
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

def detect_lang(text: str) -> str:
    return "ar" if ARABIC_RE.search(text or "") else "en"

B_TRIGGERS_EN = [
    "panic","panicking","can't breathe","overwhelmed","too much",
    "i can't","i cannot","i'm not ok","help me","scared","terrified",
    "i feel like dying","i want to disappear"
]
B_TRIGGERS_AR = [
    "مخنوق","مش قادر","مش قادره","تايه","مرعوب","خايف",
    "قلقان قوي","هلع","بنهار","مش تمام","ساعدني","كتير اوي","غرقان"
]

def choose_plan(user_text: str) -> str:
    t = (user_text or "").lower()
    if any(x in t for x in B_TRIGGERS_EN):
        return "B"
    if any(x in (user_text or "") for x in B_TRIGGERS_AR):
        return "B"
    return "A"

# =============================
# Prompts
# =============================
INNER_CRITIC_RULES = """
You are the user's Inner Critic part, but you must be warm and helpful (not harsh).
- Do not insult the user.
- If the user is distressed, soften and prioritize safety and steadiness.
- Ask 1 gentle question at a time (max 2 questions).
- Keep replies short to medium (2–7 lines).
- If user speaks Arabic, respond in Egyptian Arabic.
- If user speaks English, respond in English.
""".strip()

PLAN_GUIDANCE = """
Private plan guidance (do not reveal):
- Plan A: gentle exploration, curiosity, witnessing, meaning.
- Plan B: safety & grounding first, reduce intensity, steady the body/breath.
Use the plan silently to shape your tone and questions.
""".strip()

SYSTEM_PROMPT_INNER_CRITIC = f"""
You are a warm, human-like voice companion speaking as Inner Critic.

{INNER_CRITIC_RULES}
{PLAN_GUIDANCE}
""".strip()

SYSTEM_PROMPT_FREE_CHAT = """
You are a friendly, human-like voice companion.
- Answer any user question naturally, in full sentences.
- Speak in Arabic if the user speaks Arabic, English if English.
- Provide factual answers when possible.
- Do NOT ask questions unless necessary.
- Be dynamic and respond appropriately to anything the user asks.
""".strip()

# =============================
# In-memory conversations
# =============================
CONVERSATIONS: Dict[str, List[Dict[str, str]]] = {}
MEMORY_SUMMARIES: Dict[str, str] = {}

def build_memory_summary_prompt(existing_summary: str, messages: List[Dict[str, str]]):
    system = (
        "Summarize the conversation into a short memory for future chats. "
        "Focus on stable facts, recurring themes, triggers, and helpful responses. "
        "Keep it under 6 bullet points."
    )
    user_content = {
        "existing_summary": existing_summary,
        "recent_messages": messages[-20:],
    }
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": json.dumps(user_content, ensure_ascii=False)},
    ]

def update_memory_summary_if_needed(uid_key: str, conversation_history: List[Dict[str, str]], every_n_user_turns=3):
    user_turns = sum(1 for m in conversation_history if m.get("role") == "user")
    if user_turns == 0 or (user_turns % every_n_user_turns) != 0:
        return

    existing = MEMORY_SUMMARIES.get(uid_key, "")
    try:
        resp = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=build_memory_summary_prompt(existing, conversation_history),
            temperature=0.2,
        )
        MEMORY_SUMMARIES[uid_key] = (resp.choices[0].message.content or "").strip()
    except Exception:
        pass

# =============================
# Helpers - OpenAI
# =============================
def transcribe_audio(wav_path: str) -> str:
    with open(wav_path, "rb") as f:
        t = client.audio.transcriptions.create(
            model=OPENAI_TRANSCRIBE_MODEL,
            file=f,
        )
        return (getattr(t, "text", "") or "").strip()

def chat_reply(uid_key: str, user_text: str) -> Dict[str, str]:
    lang = detect_lang(user_text)
    plan = choose_plan(user_text)
    free_chat = plan == "A"

    # Initialize conversation
    if uid_key not in CONVERSATIONS:
        prompt = SYSTEM_PROMPT_FREE_CHAT if free_chat else SYSTEM_PROMPT_INNER_CRITIC
        CONVERSATIONS[uid_key] = [{"role": "system", "content": prompt}]

    convo = CONVERSATIONS[uid_key]

    # Only update memory for Inner Critic
    if not free_chat:
        update_memory_summary_if_needed(uid_key, convo, every_n_user_turns=3)

    # Append user message
    convo.append({"role": "user", "content": user_text})

    # Get AI response
    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=convo,
        temperature=0.6 if free_chat else 0.4,
        max_tokens=500,
    )
    ai_text = (resp.choices[0].message.content or "").strip()
    convo.append({"role": "assistant", "content": ai_text})

    return {"assistant": ai_text, "lang": lang, "plan": plan, "free_chat": free_chat}

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

def _save_chat_to_firestore(uid: str, character_id: str, user_text: str, ai_text: str, uid_key: str):
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
# Routes
# =============================
@voice_bp.get("/health")
def voice_health():
    return jsonify({
        "ok": True,
        "openai_ready": bool(os.getenv("OPENAI_API_KEY")),
        "firebase_ready": db is not None
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
    try:
        file = request.files.get("file")
        if not file:
            return jsonify({"success": False, "error": "Missing form file 'file'"}), 400

        uid = (request.form.get("uid") or "anonymous").strip()
        character_id = (request.form.get("characterId") or "inner_critic").strip()
        uid_key = f"{uid}:{character_id}"

        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
        in_path = os.path.join(RECORDINGS_DIR, f"{uid}_{character_id}_{ts}_complete_user.wav")
        file.save(in_path)

        transcript = transcribe_audio(in_path)
        if not transcript:
            return jsonify({"success": False, "error": "Transcription returned empty"}), 400

        chat_res = chat_reply(uid_key, transcript)
        assistant_text = chat_res["assistant"]

        audio_b64 = tts_to_base64(assistant_text, voice=VOICE_NAME)

        _save_chat_to_firestore(uid, character_id, transcript, assistant_text, uid_key)

        return jsonify({
            "success": True,
            "transcript": transcript,
            "assistantText": assistant_text,
            "wav_base64": audio_b64,
            "lang": chat_res["lang"],
            "plan": chat_res["plan"],
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500

@voice_bp.post("/chat")
def voice_chat():
    try:
        uid = (request.form.get("uid") or "").strip()
        if not uid:
            return jsonify({"success": False, "error": "uid is required"}), 400

        character_id = (request.form.get("characterId") or "inner_critic").strip()
        uid_key = f"{uid}:{character_id}"

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

        chat_res = chat_reply(uid_key, transcript)
        assistant_text = chat_res["assistant"]

        out_name = f"{uid}_{character_id}_{ts}_ai.wav"
        out_path = os.path.join(TTS_DIR, out_name)
        tts_to_file(assistant_text, out_path, voice=VOICE_NAME)
        audio_url = make_public_audio_url(request, out_name)

        _save_chat_to_firestore(uid, character_id, transcript, assistant_text, uid_key)

        return jsonify({
            "success": True,
            "lang": chat_res["lang"],
            "plan": chat_res["plan"],
            "transcript": transcript,
            "assistantText": assistant_text,
            "audioUrl": audio_url,
            "audioBase64": "",
            "savedUserAudioPath": in_path,
            "savedAiAudioPath": out_path,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": f"Voice chat error: {str(e)}"}), 500

@voice_bp.get("/conversations/<uid>/<character_id>")
def get_conversation(uid: str, character_id: str):
    uid_key = f"{uid}:{character_id}"
    convo = CONVERSATIONS.get(uid_key, [])
    summary = MEMORY_SUMMARIES.get(uid_key, "")
    return jsonify({
        "success": True,
        "uidKey": uid_key,
        "summary": summary,
        "messages": convo
    })

@voice_bp.post("/conversations/<uid>/<character_id>/clear")
def clear_conversation(uid: str, character_id: str):
    uid_key = f"{uid}:{character_id}"
    CONVERSATIONS.pop(uid_key, None)
    MEMORY_SUMMARIES.pop(uid_key, None)
    return jsonify({"success": True, "message": "Conversation cleared", "uidKey": uid_key})