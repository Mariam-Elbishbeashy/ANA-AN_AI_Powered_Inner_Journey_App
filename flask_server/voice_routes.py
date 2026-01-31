import os
import re
import base64
import traceback
from io import BytesIO
from flask import Blueprint, request, jsonify
from openai import OpenAI

voice_bp = Blueprint("voice_bp", __name__)

OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_TRANSCRIBE_MODEL = os.getenv("OPENAI_TRANSCRIBE_MODEL", "gpt-4o-mini-transcribe")
OPENAI_TTS_MODEL = os.getenv("OPENAI_TTS_MODEL", "gpt-4o-mini-tts")

DEFAULT_VOICE = os.getenv("OPENAI_VOICE", "alloy")

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# =========================
# Plan chooser + language detect (same as your desktop)
# =========================
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

B_TRIGGERS_EN = [
    "panic", "panicking", "can't breathe", "overwhelmed", "too much",
    "i can't", "i cannot", "i'm not ok", "help me", "scared", "terrified",
    "i feel like dying", "i want to disappear"
]
B_TRIGGERS_AR = [
    "مخنوق", "مش قادر", "مش قادره", "تايه", "مرعوب", "خايف",
    "قلقان قوي", "هلع", "بنهار", "مش تمام", "ساعدني", "كتير اوي", "غرقان"
]

def detect_lang(text: str) -> str:
    return "ar" if ARABIC_RE.search(text or "") else "en"

def choose_plan(user_text: str) -> str:
    t = (user_text or "").lower()
    if any(x in t for x in B_TRIGGERS_EN) or any(x in t for x in B_TRIGGERS_AR):
        return "B"
    return "A"


WC_REFERENCE_RULES = """
You are a warm, human-like voice companion.

You are supporting a user in a Wounded Child emotional state.
Do NOT mention IFS or "parts" unless the user does first.

Plan meaning:
- Plan A = gentle exploration.
- Plan B = safety & grounding first.

Micro-intervention rule:
- Most replies: 0 micro-interventions.
- If mild distress: at most 1 micro-intervention.
- If high distress: at most 2 short micro-interventions.

Language:
- If user speaks Arabic, respond in Egyptian Arabic.
- If user speaks English, respond in English.
""".strip()

SYSTEM_PROMPT = f"{WC_REFERENCE_RULES}".strip()

# ==========================================
# In-memory conversation store by sessionId
# (same behavior as desktop conversation list)
# ==========================================
CONVERSATIONS = {}  # sessionId -> messages list

def get_conversation(session_id: str):
    sid = session_id or "default"
    if sid not in CONVERSATIONS:
        CONVERSATIONS[sid] = [{"role": "system", "content": SYSTEM_PROMPT}]
    return CONVERSATIONS[sid]

def transcribe_bytes(audio_bytes: bytes, filename: str) -> str:
    if not audio_bytes or len(audio_bytes) < 4000:
        return ""
    bio = BytesIO(audio_bytes)
    bio.name = filename  # important for OpenAI SDK
    t = client.audio.transcriptions.create(
        model=OPENAI_TRANSCRIBE_MODEL,
        file=bio
    )
    return (t.text or "").strip()

def tts_bytes(text: str, voice: str) -> bytes:
    audio = client.audio.speech.create(
        model=OPENAI_TTS_MODEL,
        voice=voice,
        input=text,
        response_format="wav"
    )
    return audio.read()

@voice_bp.route("/voice/turn", methods=["POST"])
def voice_turn():
    """
    Flutter sends multipart/form-data:
      - file: audio file (wav)
      - sessionId: string (optional)  -> memory like desktop
      - voice: "alloy" (optional)

    Returns JSON:
      success, transcript, reply_text, reply_audio_wav_base64
    """
    try:
        if not os.getenv("OPENAI_API_KEY"):
            return jsonify({"success": False, "error": "OPENAI_API_KEY is not set"}), 500

        if "file" not in request.files:
            return jsonify({"success": False, "error": "Missing field 'file'"}), 400

        session_id = request.form.get("sessionId", "default")
        voice = request.form.get("voice", DEFAULT_VOICE)

        uploaded = request.files["file"]

        # Read bytes ONCE
        uploaded.stream.seek(0)
        audio_bytes = uploaded.read()

        # 1) Transcribe
        transcript = transcribe_bytes(audio_bytes, uploaded.filename or "user.wav")

        if not transcript:
            fallback = "I didn’t catch that. Can you say it again?"
            wav = tts_bytes(fallback, voice)
            return jsonify({
                "success": True,
                "transcript": "",
                "reply_text": fallback,
                "reply_audio_wav_base64": base64.b64encode(wav).decode("utf-8")
            })

        # 2) Plan + language (silent)
        lang = detect_lang(transcript)
        plan = choose_plan(transcript)

        # 3) Chat with memory (like desktop)
        convo = get_conversation(session_id)
        convo.append({"role": "user", "content": f"[lang={lang}][plan={plan}] {transcript}"})

        resp = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=convo,
            temperature=0.7
        )
        reply_text = (resp.choices[0].message.content or "").strip()
        if not reply_text:
            reply_text = "I’m here with you."

        convo.append({"role": "assistant", "content": reply_text})

        # 4) TTS -> base64 wav
        wav = tts_bytes(reply_text, voice)
        wav_b64 = base64.b64encode(wav).decode("utf-8")

        return jsonify({
            "success": True,
            "transcript": transcript,
            "reply_text": reply_text,
            "reply_audio_wav_base64": wav_b64
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500
