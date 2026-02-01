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
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
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

    # Put firebase-key.json next to app.py or set FIREBASE_KEY_PATH env var
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

def build_system_prompt_with_memory(uid_key: str) -> str:
    memory = MEMORY_SUMMARIES.get(uid_key, "")
    mem_block = f"\n\n[PRIVATE MEMORY SUMMARY]\n{memory}\n[/PRIVATE MEMORY SUMMARY]\n" if memory else ""
    system_prompt = f"""
You are a warm, human-like voice companion, but you must speak AS the Inner Critic part.

Top priority: sound natural and human.
- If user says "hello", reply normally (in-character as Inner Critic).
- Do NOT use clinical language.
- Do NOT give medical advice.

{INNER_CRITIC_RULES}

{PLAN_GUIDANCE}
""".strip()
    return system_prompt + mem_block

# =============================
# Helpers - OpenAI
# =============================
def transcribe_audio(wav_path: str) -> str:
    def _try(language: Optional[str]) -> str:
        with open(wav_path, "rb") as f:
            kwargs = {"model": OPENAI_TRANSCRIBE_MODEL, "file": f}
            if language:
                kwargs["language"] = language
            t = client.audio.transcriptions.create(**kwargs)
            return (getattr(t, "text", "") or "").strip()

    txt = _try(None)
    if txt:
        return txt
    txt = _try("ar")
    if txt:
        return txt
    return _try("en")

def chat_reply(uid_key: str, user_text: str) -> Dict[str, str]:
    lang = detect_lang(user_text)
    plan = choose_plan(user_text)

    if uid_key not in CONVERSATIONS:
        CONVERSATIONS[uid_key] = [{"role": "system", "content": build_system_prompt_with_memory(uid_key)}]

    convo = CONVERSATIONS[uid_key]
    update_memory_summary_if_needed(uid_key, convo, every_n_user_turns=3)
    convo[0]["content"] = build_system_prompt_with_memory(uid_key)

    convo.append({"role": "user", "content": f"[lang={lang}][plan={plan}] {user_text}"})

    resp = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=convo,
        temperature=0.7,
    )
    ai = (resp.choices[0].message.content or "").strip()
    convo.append({"role": "assistant", "content": ai})

    return {"assistant": ai, "lang": lang, "plan": plan}

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
    audio_bytes = audio.read()
    return base64.b64encode(audio_bytes).decode("utf-8")

def make_public_audio_url(req, filename: str) -> str:
    host = req.host_url.rstrip("/")
    return f"{host}/voice/audio/{filename}"

def _save_chat_to_firestore(uid: str, character_id: str, user_text: str, ai_text: str, uid_key: str):
    if not db:
        return
    try:
        db.collection("users").document(uid).collection("chats").add({
            "characterId": character_id,
            "uidKey": uid_key,
            "userMessage": user_text,
            "aiResponse": ai_text,
            "timestamp": datetime.utcnow().isoformat(),
        })
    except Exception as e:
        print(f"Firebase save error: {e}")

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
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

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
    """Multipart: file=<audio wav>  -> transcript"""
    try:
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

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
    """JSON: {text, voice?} -> wav_base64"""
    try:
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

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
    Multipart:
      - uid
      - characterId
      - file: audio
    Returns:
      transcript, assistantText, wav_base64
    """
    try:
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

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
    """
    ✅ This is the endpoint your Flutter screen uses.
    Multipart form-data:
      - uid: string (required)
      - characterId: string (optional)
      - audio: file (required)

    Returns (Flutter expects):
      transcript, assistantText, audioUrl   (+ optional audioBase64)
    """
    try:
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

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

        size = os.path.getsize(in_path)
        if size < 4000:
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

        # IMPORTANT: keep keys stable for Flutter screen
        return jsonify({
            "success": True,
            "lang": chat_res["lang"],
            "plan": chat_res["plan"],
            "transcript": transcript,
            "assistantText": assistant_text,
            "audioUrl": audio_url,
            # keep this optional; Flutter fallback uses it if URL fails
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
