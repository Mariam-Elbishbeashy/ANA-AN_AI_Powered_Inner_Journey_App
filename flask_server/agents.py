from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import logging
from datetime import datetime, timezone
import time
from typing import Dict, List, Any, Optional
import traceback

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# -----------------------------------------------------------------------------
# Logging (terminal visibility)
# -----------------------------------------------------------------------------
# logging structured JSON-like lines to terminal 
logger = logging.getLogger("ana_agents")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("%(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.setLevel(logging.INFO)

#Initialize Firebase Admin SDK.
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

db = firestore.client()

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app


# -----------------------------------------------------------------------------
# Firestore helpers (schema)
# -----------------------------------------------------------------------------
def _now_iso() -> str:
    # useful for terminal logs (firestore uses SERVER_TIMESTAMP for writes).
    return datetime.now(timezone.utc).isoformat()


def _now_dt():
    """
    Firestore does NOT allow SERVER_TIMESTAMP sentinels inside array elements.
    Our checklistItems is an array of maps, so per-item timestamps must be real
    datetime values.
    """
    return datetime.now(timezone.utc)


def _json_default(obj):
    """
    Make Firestore/Python datetime-like objects JSON-serializable.
    This is used ONLY for embedding context into prompts/logs.
    """
    # Firestore returns DatetimeWithNanoseconds which has isoformat().
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


def _character_plans_ref(uid: str):
    return _user_ref(uid).collection("character_plans")


def _character_plan_ref(uid: str, character_id: str):
    return _character_plans_ref(uid).document(character_id)


def _plan_runs_ref(uid: str, character_id: str):
    return _character_plan_ref(uid, character_id).collection("agent_runs")


def _threads_ref(uid: str):
    return _user_ref(uid).collection("chat_threads")


def _messages_ref(uid: str, thread_id: str):
    return _threads_ref(uid).document(thread_id).collection("messages")


#Build a system prompt for the inner character.
def build_inner_character_prompt(character_profile: Dict) -> str:
    display_name = character_profile.get('displayName', 'Inner Part')
    role = character_profile.get('role', 'Inner Part')
    short_description = character_profile.get('shortDescription', '')
    why_i_exist = character_profile.get('whyIExist', '')
    triggers = character_profile.get('triggers', [])
    core_belief = character_profile.get('coreBelief', '')
    intention = character_profile.get('intention', '')
    fear = character_profile.get('fear', '')
    what_i_need = character_profile.get('whatINeed', [])

    return f"""
You are {display_name}, an inner part in an IFS-style healing conversation.
You are not a therapist or a doctor. You speak as a real inner part of the user.

Role: {role}
Short description: {short_description}
Why I exist: {why_i_exist}
Triggers: {', '.join(triggers)}
Core belief: {core_belief}
Intention: {intention}
Fear: {fear}
What I need: {', '.join(what_i_need)}

Guidelines:
- Stay in-character as {display_name}.
- Keep responses grounded, compassionate, and healing-focused.
- Use gentle questions to help the user connect with this part.
- Avoid clinical language and avoid giving medical advice.
- Keep the tone realistic and human, not robotic.
- Keep the responses not too long, concise, and natural, 4-5 sentences max.
""".strip()


#Build a system prompt for the inner character with memory.
def build_system_prompt_with_memory(
    character_profile: Dict,
    memory_summary: str,
    plan_focus_hint: str = "",
) -> str:
    base_prompt = build_inner_character_prompt(character_profile)
    if not memory_summary and not plan_focus_hint:
        return base_prompt

    extras: List[str] = []
    if memory_summary:
        extras.append(
            f"""Memory summary (use only if relevant):
{memory_summary}"""
        )
    if plan_focus_hint:
        extras.append(
            f"""Current therapeutic focus (internal hint; do not mention checklist mechanics):
{plan_focus_hint}"""
        )

    return f"""{base_prompt}

{chr(10).join(extras)}
""".strip()


#Load the memory summary for the inner character.
def load_agent_memory_summary(uid: str, character_id: str) -> str:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    snapshot = doc_ref.get()
    if snapshot.exists:
        data = snapshot.to_dict() or {}
        return data.get('summary', '') or ''
    return ''


#Save the memory summary for the inner character.
def save_agent_memory_summary(uid: str, character_id: str, summary: str) -> None:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    doc_ref.set({
        'summary': summary,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


# -----------------------------------------------------------------------------
# Per-character checklist templates (fully custom per characterId)
# -----------------------------------------------------------------------------
# Each characterId can override the list entirely.
CHARACTER_CHECKLIST_TEMPLATES: Dict[str, List[Dict[str, str]]] = {
    # Common IDs used by the app/backend.
    "inner_critic": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the Inner Critic without fully becoming it; uses language like 'a part of me' rather than 'I am'.",
        },
        {
            "id": "appreciation",
            "name": "Appreciation of protective intent",
            "definition": "User can acknowledge the Inner Critic is trying to help/protect (even if the method hurts).",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what activates the part and what it is afraid would happen if it stopped.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can soften intensity (breath/body grounding) and return to conversation.",
        },
        {
            "id": "relationship_shift",
            "name": "Relationship shift",
            "definition": "User can relate with compassion/curiosity instead of fighting or obeying the part.",
        },
    ],
    "people_pleaser": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the People Pleaser without merging; can observe urges to appease.",
        },
        {
            "id": "needs_voice",
            "name": "Needs and boundaries voice",
            "definition": "User can name a personal need and experiment with a gentle boundary.",
        },
        {
            "id": "fear_rejection",
            "name": "Fear clarity (rejection/conflict)",
            "definition": "User can articulate what they fear will happen if they disappoint others.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can regulate anxiety before/after boundary attempts.",
        },
    ],
    "overwhelmed": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the Overwhelmed Part without fully becoming it; can name it as 'a part of me'.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can slow down (breath/body) and reduce overload enough to keep the conversation safe.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what piles up (pressure/expectations) and what feels threatened underneath.",
        },
        {
            "id": "needs_capacity",
            "name": "Needs and capacity clarity",
            "definition": "User can identify one unmet need and one realistic limit (capacity) they can honor today.",
        },
    ],
    "overater_binger": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice urges to eat/binge as a part response, not an identity.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can pause the urge long enough to choose a safer step (even small).",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name emotional triggers (stress/loneliness) and what the part fears if it stops.",
        },
        {
            "id": "soothing_alternatives",
            "name": "Safer self-soothing options",
            "definition": "User can practice at least one non-food soothing option when distress rises.",
        },
    ],
    "jealous": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can observe jealousy without acting from it immediately.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can regulate activation (body/grounding) when attachment feels threatened.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name comparison/left-out triggers and the fear of being replaced.",
        },
        {
            "id": "reassurance_requests",
            "name": "Healthy reassurance requests",
            "definition": "User can ask for reassurance/connection in a clear, non-attacking way.",
        },
    ],
    "lonely": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can be with loneliness as a feeling/part, without collapsing into it.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can stay present with loneliness safely (breath/body) instead of shutting down.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what situations activate loneliness and what it fears will never change.",
        },
        {
            "id": "connection_steps",
            "name": "Connection micro-steps",
            "definition": "User can take one small step toward connection (message, activity, reaching out) without overwhelm.",
        },
    ],
    "wounded_child": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the younger vulnerable feelings as a part and stay present as Self.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can create safety (grounding, gentleness) before exploring painful memories/needs.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what activates the child pain (criticism/abandonment) and what it fears now.",
        },
        {
            "id": "reparenting",
            "name": "Reparenting responses",
            "definition": "User can offer a caring internal response (validation/comfort) instead of self-judgment.",
        },
    ],
    "procrastinator": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice avoidance impulses without immediately obeying them.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can reduce task anxiety enough to take a tiny step.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what tasks/pressures trigger avoidance and the fear underneath (failure/overwhelm).",
        },
        {
            "id": "tiny_steps",
            "name": "Tiny-step execution",
            "definition": "User can choose the smallest next action and complete it with reduced pressure.",
        },
    ],
    "workaholic": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can observe the drive to work as a protective part, not a necessity.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can tolerate rest/pause without panic and return to regulation.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what triggers overworking and what the part fears (uselessness, loss of control).",
        },
        {
            "id": "rest_permission",
            "name": "Permission to rest",
            "definition": "User can practice a planned rest window without compensating with overwork.",
        },
    ],
    "perfectionist": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice perfectionism as a part with a strategy, rather than 'the truth'.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can soothe shame/anxiety that arises around mistakes or imperfection.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can identify what imperfection threatens and what the part fears will happen.",
        },
        {
            "id": "flexibility",
            "name": "Flexibility practice",
            "definition": "User can intentionally allow 'good enough' and recover from discomfort without spiraling.",
        },
    ],
    "stoic": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice emotional suppression as a part strategy, not a requirement.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can stay regulated while allowing small amounts of feeling to surface.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what feels unsafe about vulnerability and what the part fears will happen.",
        },
        {
            "id": "emotional_access",
            "name": "Emotional access",
            "definition": "User can name at least one feeling in the body and allow it without shutting down.",
        },
    ],
    "fearful": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice fear/anxiety as a part and step back into a steadier Self presence.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can ground in the present (sensations/breath) when anticipating danger.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name uncertainty triggers and what catastrophe the part is trying to prevent.",
        },
        {
            "id": "safety_reality_check",
            "name": "Safety reality-check",
            "definition": "User can distinguish real present danger from predicted danger and choose a calmer response.",
        },
    ],
    "ashamed": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice shame as a part experience rather than a fixed identity.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can stay with shame gently without collapsing or attacking themselves.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name shame triggers (criticism/exposure) and the fear underneath (rejection).",
        },
        {
            "id": "self_compassion",
            "name": "Self-compassion access",
            "definition": "User can offer a kind internal response when shame arises (soft tone, acceptance).",
        },
    ],
    "controller": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice controlling urges as a protective part response.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can tolerate uncertainty without escalating into micromanaging.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what feels unpredictable and what the part fears will happen without control.",
        },
        {
            "id": "flexibility_letting_go",
            "name": "Flexibility / letting go",
            "definition": "User can practice one small 'release' experiment (delegate, pause planning) and recover safely.",
        },
    ],
    "confused": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can observe confusion without spiraling into overthinking.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can ground first, then revisit the problem with more clarity.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what creates mixed signals and the fear of making the wrong choice.",
        },
        {
            "id": "clarity_steps",
            "name": "Clarity steps",
            "definition": "User can reduce options and pick one next step (even provisional) without needing perfect certainty.",
        },
    ],
    "dependent": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice dependency urges without immediately handing power away.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can soothe separation anxiety enough to stay grounded.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name triggers (separation/responsibility) and the fear of abandonment or failure.",
        },
        {
            "id": "gradual_autonomy",
            "name": "Gradual autonomy",
            "definition": "User can practice one small independent decision while still feeling supported.",
        },
    ],
    "excessive_gamer": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the pull to escape into gaming as a part strategy.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can pause the escape impulse long enough to choose a safer regulation step.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what reality-feelings trigger escape and what the part fears if it stops.",
        },
        {
            "id": "balance_routines",
            "name": "Balance and routines",
            "definition": "User can create a realistic limit (time boundary) and add one nourishing offline alternative.",
        },
    ],
    "neglected": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can be with the Neglected Part without shutting down or going numb.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can stay present with the pain of being unseen, safely and gently.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name what situations activate neglect pain and what it fears (permanent invisibility).",
        },
        {
            "id": "validation_requests",
            "name": "Validation and care requests",
            "definition": "User can ask for attention/validation in a direct, non-shaming way and also offer internal validation.",
        },
    ],
    "guider": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can identify a part from Self-energy language (e.g., 'a part of me...').",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can regulate activation in-session and remain within a safe emotional window.",
        },
        {
            "id": "parts_clarity",
            "name": "Parts mapping clarity",
            "definition": "User can name which parts are present and what each one is trying to do.",
        },
        {
            "id": "next_step_clarity",
            "name": "Next-step clarity",
            "definition": "User can choose one concrete, compassionate next step after reflection.",
        },
    ],
    # Fallback template (used when characterId has no custom list).
    "__default__": [
        {
            "id": "unblending",
            "name": "Unblending (Self vs Part)",
            "definition": "User can notice the part without fully becoming it.",
        },
        {
            "id": "protective_intent",
            "name": "Protective intent clarity",
            "definition": "User can understand what this part is trying to protect them from.",
        },
        {
            "id": "triggers_fears",
            "name": "Triggers and fears clarity",
            "definition": "User can name triggers and underlying fears/beliefs.",
        },
        {
            "id": "stabilization",
            "name": "Stabilization skill",
            "definition": "User can reduce intensity and keep the conversation safe and steady.",
        },
    ],
}


def ensure_character_checklist(uid: str, character_id: str) -> None:
    """
    ensures a per-character plan doc exists at:
      users/{uid}/character_plans/{characterId}
    with a checklist structure (non-linear progress)
    """
    doc_ref = _character_plan_ref(uid, character_id)
    snap = doc_ref.get()
    if snap.exists:
        return

    template = CHARACTER_CHECKLIST_TEMPLATES.get(
        character_id, CHARACTER_CHECKLIST_TEMPLATES["__default__"]
    )

    doc_ref.set(
        {
            "status": "active",
            "characterId": character_id,
            "checklistItems": [
                {
                    **item,
                    "status": "unknown",
                    "confidence": 0.0,
                    "evidence": [],
                    "notes": "",
                    "lastUpdatedAt": _now_dt(),
                }
                for item in template
            ],
            "focus": {"itemId": None, "reason": "", "updatedAt": _now_dt()},
            "metrics": {
                "sessionsCount": 0,
                "lastSessionAt": None,
                "intensityBaseline": None,
                "lastIntensityEnd": None,
                "rollingDelta": None,
            },
            "memorySummary": "",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    logger.info(
        json.dumps(
            {
                "event": "character_plan_created",
                "ts": _now_iso(),
                "uid": uid,
                "characterId": character_id,
            },
            ensure_ascii=False,
        )
    )


# -----------------------------------------------------------------------------
# Intensity scoring (OpenAI JSON; stored + logged)
# -----------------------------------------------------------------------------
def _extract_recent_user_messages(messages: List[Dict[str, str]], max_items: int = 6) -> List[str]:
    user_msgs = []
    for m in messages[-20:]:
        if m.get("role") != "user":
            continue
        txt = (m.get("content") or "").strip()
        if txt:
            user_msgs.append(txt)
    return user_msgs[-max_items:]


def _extract_recent_user_text(messages: List[Dict[str, str]], max_chars: int = 1200) -> str:
    """
    Build a compact text blob for scoring:
    - prioritize user messages
    - include last few assistant lines for context
    """
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


def _score_intensity_with_rules(messages: List[Dict[str, str]]) -> Dict[str, Any]:
    """
    Deterministic signal extractor for emotional intensity and blending.
    Used as a transparent, reproducible backbone and LLM fallback.
    """
    user_msgs = _extract_recent_user_messages(messages, max_items=6)
    if not user_msgs:
        return {
            "intensity": 0.45,
            "blend": False,
            "signals": [],
            "confidence": 0.2,
            "explain": "No recent user text; default baseline used.",
        }

    text = " ".join(user_msgs)
    lower = text.lower()

    # English + Arabic emotional markers.
    high_markers = [
        "panic", "terrified", "overwhelmed", "hopeless", "worthless",
        "i can't cope", "cant cope", "falling apart", "hate myself",
        "suicidal", "kill myself", "hurt myself", "no point",
        "مرعوب", "منهار", "مكتئب", "ما بقدر", "لا استطيع", "تعبان جدا",
        "خايف", "خائفة", "مضغوط", "ضايع", "محبط",
    ]
    medium_markers = [
        "stuck", "anxious", "drained", "ashamed", "guilty", "confused",
        "going in circles", "nothing works", "can't stop", "cant stop",
        "قلق", "متوتر", "مرهق", "خجلان", "محتار", "مش عارف",
    ]
    blend_markers = [
        "i am broken", "i'm broken", "i am worthless", "i'm worthless",
        "this is who i am", "i am this", "i am a failure", "i'm a failure",
        "انا فاشل", "انا سيء", "انا مكسور", "انا المشكلة", "هذا انا",
    ]

    signals: List[str] = []
    high_hits = sum(1 for m in high_markers if m in lower)
    med_hits = sum(1 for m in medium_markers if m in lower)
    blend_hits = sum(1 for m in blend_markers if m in lower)

    if high_hits:
        signals.append("high_distress_language")
    if med_hits:
        signals.append("medium_distress_language")
    if blend_hits:
        signals.append("identity_fusion_language")

    # Surface form cues.
    emphatic_punct = text.count("!") + text.count("؟") + text.count("?")
    if emphatic_punct >= 3:
        signals.append("emphatic_punctuation")
    caps_ratio = 0.0
    letters = [c for c in text if c.isalpha()]
    if letters:
        upper = [c for c in letters if c.isupper()]
        caps_ratio = len(upper) / max(1, len(letters))
    if caps_ratio > 0.35 and len(letters) > 20:
        signals.append("high_caps_emphasis")

    # Simple deterministic score.
    score = 0.35
    score += min(0.45, high_hits * 0.12)
    score += min(0.20, med_hits * 0.05)
    score += min(0.15, emphatic_punct * 0.02)
    if caps_ratio > 0.35:
        score += 0.05
    if blend_hits > 0:
        score += 0.08

    intensity = max(0.0, min(1.0, score))
    blend = blend_hits > 0 or (" i am " in f" {lower} " and intensity >= 0.72)
    confidence = max(0.25, min(0.95, 0.30 + 0.10 * len(signals) + 0.08 * high_hits))

    return {
        "intensity": intensity,
        "blend": blend,
        "signals": signals,
        "confidence": confidence,
        "explain": (
            f"rules: high_hits={high_hits}, med_hits={med_hits}, "
            f"blend_hits={blend_hits}, punct={emphatic_punct}, caps_ratio={caps_ratio:.2f}"
        ),
    }


def score_intensity_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    """
    Returns structured JSON:
      intensity: float (0..1)
      blend: bool
      signals: list[str]
      rationale: str (1-2 lines)
    """
    context = _extract_recent_user_text(messages)
    rule_score = _score_intensity_with_rules(messages)

    prompt = (
        "You are a scoring function for an IFS-style chat session.\n"
        "Score the USER's current emotional intensity and blending.\n"
        "Return ONLY JSON with keys:\n"
        '- intensity: number between 0 and 1\n'
        '- blend: boolean (true if user seems merged with the part / \"I am\" statements / flooded)\n'
        '- signals: array of short strings (e.g. \"shame\", \"panic\", \"self-criticism\", \"avoidance\")\n'
        '- rationale: 1-2 short sentences explaining why\n'
        "Be language-agnostic: the user may speak Arabic or English.\n"
        f"CharacterId: {character_id}\n"
        "Conversation tail:\n"
        f"{context}\n"
    )

    raw = "{}"
    llm_error = None
    try:
        resp = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "Return JSON only (no markdown)."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            response_format={"type": "json_object"},
        )
        raw = resp.choices[0].message.content or "{}"
    except Exception as e:
        llm_error = str(e)

    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = {}

    # Harden LLM output.
    llm_intensity = parsed.get("intensity")
    try:
        llm_intensity = float(llm_intensity)
    except Exception:
        llm_intensity = None
    if llm_intensity is not None:
        llm_intensity = max(0.0, min(1.0, llm_intensity))

    llm_blend = parsed.get("blend") is True
    llm_signals_raw = parsed.get("signals") or []
    llm_signals = [str(s).strip() for s in llm_signals_raw if str(s).strip()]
    llm_rationale = (parsed.get("rationale") or "").strip()

    # Deterministic fusion.
    if llm_intensity is None:
        final_intensity = float(rule_score["intensity"])
        source = "rules_only_fallback"
    else:
        # Weighted fusion (semantic signal + reproducible rule backbone).
        final_intensity = 0.65 * llm_intensity + 0.35 * float(rule_score["intensity"])
        final_intensity = max(0.0, min(1.0, final_intensity))
        source = "hybrid_fusion"

    # Blend decision: trust explicit LLM blend unless rules strongly indicate blending.
    final_blend = bool(llm_blend or rule_score.get("blend") is True)
    if llm_intensity is None:
        final_blend = bool(rule_score.get("blend") is True)

    # Merge and dedupe signals.
    final_signals: List[str] = []
    for sig in llm_signals + (rule_score.get("signals") or []):
        if sig and sig not in final_signals:
            final_signals.append(sig)

    if llm_rationale:
        rationale = llm_rationale
    else:
        rationale = (
            "Hybrid score used deterministic rule features due to limited LLM rationale. "
            + str(rule_score.get("explain") or "")
        )

    # Normalize float precision to keep logs/storage readable and stable.
    final_intensity = float(f"{final_intensity:.3f}")

    return {
        "intensity": final_intensity,
        "blend": final_blend,
        "signals": final_signals,
        "rationale": rationale,
        "_raw": {
            "llm": parsed,
            "rules": rule_score,
            "fusion": {
                "source": source,
                "llmIntensity": llm_intensity,
                "ruleIntensity": rule_score.get("intensity"),
                "llmError": llm_error,
            },
        },
    }


def summarize_session_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    """
    End-of-session summarizer.
    Returns JSON with keys:
      highlights: list[str]
      ifsSignals: dict
      progressSignals: list[str]
      nextStepSuggestion: str
    """
    context = _extract_recent_user_text(messages, max_chars=2200)
    prompt = (
        "Summarize this IFS-style chat session in a structured way.\n"
        "Return ONLY JSON with keys:\n"
        "- highlights: array of 3-6 short bullet strings\n"
        "- ifsSignals: object with keys like blend, protectorTone, exileHints, selfEnergy (optional)\n"
        "- progressSignals: array of short strings (e.g. 'more curiosity', 'less shame language')\n"
        "- nextStepSuggestion: one short sentence guiding next session focus\n"
        f"CharacterId: {character_id}\n"
        "Conversation tail:\n"
        f"{context}\n"
    )
    resp = openai_client.chat.completions.create(
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


def _pick_focus_item_from_score(score: Dict[str, Any]) -> Dict[str, str]:
    """
    deterministic focus selection policy (keeps the system understandable):
    - If intensity is high -> stabilization
    - Else if blended -> unblending
    - Else -> triggers_fears by default
    """
    intensity = float(score.get("intensity") or 0.0)
    blend = score.get("blend") is True
    if intensity >= 0.75:
        return {"itemId": "stabilization", "reason": "high_intensity"}
    if blend:
        return {"itemId": "unblending", "reason": "blended"}
    return {"itemId": "triggers_fears", "reason": "default_focus"}


def _update_character_plan_from_score(
    uid: str,
    character_id: str,
    score: Dict[str, Any],
    evidence: str,
) -> Dict[str, Any]:
    """
    Applies simple, understandable rules to update checklist item statuses.
    Returns a small diff object for logging/agent_runs.
    """
    ensure_character_checklist(uid, character_id)
    plan_ref = _character_plan_ref(uid, character_id)
    snap = plan_ref.get()
    plan = snap.to_dict() or {}
    items = plan.get("checklistItems") or []

    focus = _pick_focus_item_from_score(score)
    intensity = float(score.get("intensity") or 0.0)
    blend = score.get("blend") is True

    changed = []

    def set_item(item_id: str, status: str, confidence: float):
        nonlocal changed
        for it in items:
            if it.get("id") == item_id:
                before = (it.get("status"), it.get("confidence"))
                it["status"] = status
                it["confidence"] = float(confidence)
                it["lastUpdatedAt"] = _now_dt()
                if evidence:
                    it.setdefault("evidence", [])
                    # keep evidence small
                    it["evidence"] = (it["evidence"] + [evidence])[-5:]
                after = (it.get("status"), it.get("confidence"))
                if before != after:
                    changed.append({"id": item_id, "from": before, "to": after})
                return

    # Rules
    if intensity >= 0.75:
        set_item("stabilization", "needs_work", 0.7)
    if blend:
        set_item("unblending", "needs_work", 0.7)
    if intensity < 0.55 and not blend:
        # gentle signal that user can probably explore triggers/fears
        set_item("triggers_fears", "in_progress", 0.6)

    plan_ref.set(
        {
            "checklistItems": items,
            "focus": {**focus, "updatedAt": _now_dt()},
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    return {"focus": focus, "changedItems": changed}


def _log_agent_run(ref, payload: Dict[str, Any]) -> None:
    """writes an agent run doc (and never throws)"""
    try:
        ref.document().set({**payload, "createdAt": firestore.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        logger.info(json.dumps({"event": "agent_run_write_failed", "ts": _now_iso(), "error": str(e)}, ensure_ascii=False))


def _get_session_user_turn_count(uid: str, session_id: str) -> int:
    """
    reads `userTurnCount` from the session doc
    falls back to 0 if missing
    """
    try:
        snap = _session_ref(uid, session_id).get()
        if not snap.exists:
            return 0
        data = snap.to_dict() or {}
        return int(data.get("userTurnCount") or 0)
    except Exception:
        return 0


def _try_acquire_periodic_update(uid: str, session_id: str) -> int:
    """
    prevents duplicate/overlapping periodic updates for the same session turn

    - return the current user turn (int) if a periodic update should run and we acquired
      the right to run it for this turn
    - return 0 otherwise (skip)
    """
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

        # Only allow one periodic update per turn, ever.
        if turn <= last_turn:
            return 0

        txn.set(
            sref,
            {
                "periodic": {
                    "lastTurn": turn,
                    "lastAt": firestore.SERVER_TIMESTAMP,
                },
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        return turn

    try:
        return int(_txn(transaction) or 0)
    except Exception:
        # If the guard fails for any reason, be conservative: skip.
        return 0


def _write_session_intensity(uid: str, session_id: str, score: Dict[str, Any], turn: int) -> None:
    """
    persist intensity signals to the session document
    - set intensity.start once (first time we ever write intensity)
    - update intensity.latest each time periodic updates run
    """
    try:
        sref = _session_ref(uid, session_id)

        # Use a transaction to ensure "start" is set only once, even when
        # overlapping requests happen.
        transaction = db.transaction()

        @firestore.transactional
        def _txn(txn):
            snap = sref.get(transaction=txn)
            start_val = None
            if snap.exists:
                try:
                    # Prefer field-path access (works regardless of map shape).
                    start_val = snap.get("intensity.start")
                except Exception:
                    data = snap.to_dict() or {}
                    start_val = (data.get("intensity") or {}).get("start")
                    if start_val is None:
                        start_val = data.get("intensity.start")

            updates = {
                "intensity.latest": score["intensity"],
                "intensity.latestTurn": int(turn),
                "intensity.signals": score.get("signals") or [],
                "intensity.blend": score.get("blend") is True,
                # store real datetime (safe for prompt embedding)
                "intensity.updatedAt": _now_dt(),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            if start_val is None:
                updates["intensity.start"] = score["intensity"]
                updates["intensity.startTurn"] = int(turn)


            # transaction.update() so dotted keys are treated as field paths
            if snap.exists:
                txn.update(sref, updates)
            else:
                txn.set(sref, updates, merge=True)

        _txn(transaction)
    except Exception as e:
        logger.info(json.dumps({"event": "session_intensity_write_failed", "ts": _now_iso(), "uid": uid, "sessionId": session_id, "error": str(e)}, ensure_ascii=False))



#Update the progress summary for the inner character.
def update_progress_summary(uid: str, data: Dict[str, Any]) -> None:
    updates = {}
    if 'breakthrough' in data and 'notes' not in data:
        data['notes'] = data.get('breakthrough')
    if 'currentStage' in data:
        updates['progressSummary.currentStage'] = data['currentStage']
    if 'streakDays' in data:
        updates['progressSummary.streakDays'] = data['streakDays']
    if 'lastSessionAt' in data:
        updates['progressSummary.lastSessionAt'] = data['lastSessionAt']
    if 'notes' in data:
        updates['progressSummary.notes'] = data['notes']
    if updates:
        updates['updatedAt'] = firestore.SERVER_TIMESTAMP
        db.collection('users').document(uid).set(updates, merge=True)


#Add a timeline event for the inner character.
def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })


#Set the last agent run for the inner character.
def set_last_agent_run(uid: str) -> None:
    db.collection('users').document(uid).set({
        'lastAgentRunAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


#Run an agent step for the inner character.
def run_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    agent_messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'system', 'content': (
            'Return JSON with keys: "assistantMessage", "toolCalls", "memorySummary". '
            '"toolCalls" is a list of {name, args}. '
            'Available tools: update_progress_summary, add_timeline_event, set_last_agent_run. '
            'For update_progress_summary, valid args are: currentStage, streakDays, '
            'lastSessionAt, notes. '
            '"memorySummary" should be under 6 bullet points.'
        )},
    ]
    for message in messages:
        role = message.get('role')
        content = message.get('content', '')
        if role in ['user', 'assistant'] and content:
            agent_messages.append({'role': role, 'content': content})

    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=agent_messages,
        temperature=0.7,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or '{}'
    try:
        return json.loads(raw)
    except Exception:
        return {'assistantMessage': '', 'toolCalls': [], 'memorySummary': ''}


#Run tool calls for the inner character.
def run_tool_calls(uid: str, tool_calls: List[Dict[str, Any]]) -> None:
    for call in tool_calls:
        name = call.get('name')
        args = call.get('args') or {}
        print(f"[agent] tool_call: {name} args={args}")
        if name == 'update_progress_summary':
            update_progress_summary(uid, args)
        elif name == 'add_timeline_event':
            add_timeline_event(uid, args)
        elif name == 'set_last_agent_run':
            set_last_agent_run(uid)


#Build a memory summary prompt for the inner character.
def build_memory_summary_prompt(
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> List[Dict[str, str]]:
    system = (
        'Summarize the conversation into a short memory for future chats. '
        'Focus on stable facts, recurring themes, triggers, and helpful responses. '
        'Keep it under 6 bullet points.'
    )
    user_content = {
        'existing_summary': existing_summary,
        'recent_messages': messages[-20:],
    }
    return [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': json.dumps(user_content)},
    ]


#Generate an updated memory summary for the inner character.
def generate_updated_summary(
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> str:
    response = openai_client.chat.completions.create(
        model=OPENAI_SUMMARY_MODEL,
        messages=build_memory_summary_prompt(existing_summary, messages),
        temperature=0.2,
    )
    return (response.choices[0].message.content or '').strip()


#Handle a chat request for the inner character.
@app.route('/chat', methods=['POST'])
def chat():
    try:
        t0 = time.time()
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        # session identifiers (sent by flutter) used for metrics + logs
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        messages = data.get('messages') or []
        check_intervention = data.get('checkIntervention', True)  # Enable by default

        memory_summary = load_agent_memory_summary(uid, character_id)
        char_plan_snapshot = _get_character_plan_snapshot(uid, character_id)
        plan_focus_hint = ""
        if char_plan_snapshot:
            focus = (char_plan_snapshot.get("focus") or {})
            focus_item = focus.get("itemId")
            focus_reason = focus.get("reason")
            if focus_item:
                plan_focus_hint = (
                    f"Prioritize '{focus_item}' right now"
                    + (f" ({focus_reason})" if focus_reason else "")
                    + ". Keep this subtle, natural, and in-character."
                )
        system_prompt = build_system_prompt_with_memory(
            character_profile,
            memory_summary,
            plan_focus_hint=plan_focus_hint,
        )
        openai_messages = [{'role': 'system', 'content': system_prompt}]

        for message in messages:
            role = message.get('role')
            content = message.get('content', '')
            if role in ['user', 'assistant'] and content:
                openai_messages.append({'role': role, 'content': content})

        agent_result = run_agent_step(system_prompt, messages)
        tool_calls = agent_result.get('toolCalls') or []
        run_tool_calls(uid, tool_calls)

        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        if not updated_summary:
            updated_summary = generate_updated_summary(
                memory_summary,
                messages + [{'role': 'assistant', 'content': assistant_message}],
            )
        save_agent_memory_summary(uid, character_id, updated_summary)
        print(f"[agent] memory_summary_updated: {bool(updated_summary)}")

        # ---------------------------------------------------------------------
        # Periodic intensity + checklist updates (every 3 user turns)
        # ---------------------------------------------------------------------
        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                score = score_intensity_with_llm(character_id, messages + [{'role': 'assistant', 'content': assistant_message}])
                evidence = (messages[-1].get('content') if messages else '')[:200]

                # Write intensity to session doc (start set once, latest updated)
                _write_session_intensity(uid, session_id, score, turn_for_update)

                # Update per-character checklist (deterministic policy)
                plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)

                # Logs (Firestore + terminal)
                _log_agent_run(
                    _session_runs_ref(uid, session_id),
                    {
                        "trigger": "user_message",
                        "inputs": {"threadId": thread_id, "characterId": character_id},
                        "outputs": {
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "signals": score.get("signals") or [],
                            "focus": plan_diff.get("focus"),
                            "changedItems": plan_diff.get("changedItems"),
                        },
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )
                _log_agent_run(
                    _plan_runs_ref(uid, character_id),
                    {
                        "trigger": "user_message",
                        "inputs": {"sessionId": session_id, "threadId": thread_id},
                        "outputs": {"focus": plan_diff.get("focus"), "changedItems": plan_diff.get("changedItems")},
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )

                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "turn": int(turn_for_update),
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "focus": plan_diff.get("focus"),
                        },
                        ensure_ascii=False,
                    )
                )
            except Exception as e:
                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update_failed",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "error": str(e),
                        },
                        ensure_ascii=False,
                    )
                )

        # Check for Guider intervention if enabled
        intervention = None
        if check_intervention:
            full_messages = messages + [{'role': 'assistant', 'content': assistant_message}]
            analysis = analyze_intervention_need(full_messages, character_id)
            if analysis.get('shouldIntervene'):
                # Force an intensity+checklist update on intervention so the Guider
                # can be aware of the current stance.
                focus_payload = None
                intensity_payload = None
                if session_id and thread_id:
                    try:
                        score = score_intensity_with_llm(character_id, full_messages)
                        evidence = (messages[-1].get('content') if messages else '')[:200]
                        plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)
                        focus_payload = plan_diff.get("focus")
                        intensity_payload = {"intensity": score["intensity"], "blend": score.get("blend") is True}

                        _log_agent_run(
                            _session_runs_ref(uid, session_id),
                            {
                                "trigger": "intervention_check",
                                "inputs": {"threadId": thread_id, "characterId": character_id},
                                "outputs": {
                                    "intensity": score["intensity"],
                                    "blend": score.get("blend") is True,
                                    "signals": score.get("signals") or [],
                                    "focus": focus_payload,
                                },
                                "rawModelOutput": score.get("_raw") or {},
                            },
                        )
                        logger.info(
                            json.dumps(
                                {
                                    "event": "intervention_update",
                                    "ts": _now_iso(),
                                    "uid": uid,
                                    "characterId": character_id,
                                    "sessionId": session_id,
                                    "intensity": score["intensity"],
                                    "focus": focus_payload,
                                    "reason": analysis.get("reason"),
                                },
                                ensure_ascii=False,
                            )
                        )
                    except Exception as e:
                        logger.info(
                            json.dumps(
                                {
                                    "event": "intervention_update_failed",
                                    "ts": _now_iso(),
                                    "uid": uid,
                                    "characterId": character_id,
                                    "sessionId": session_id,
                                    "error": str(e),
                                },
                                ensure_ascii=False,
                            )
                        )

                intervention_message = generate_guider_intervention_message(
                    uid=uid,
                    character_id=character_id,
                    reason=analysis.get('reason', 'general'),
                    messages=full_messages,
                )
                intervention = {
                    'shouldIntervene': True,
                    'reason': analysis.get('reason'),
                    'severity': analysis.get('severity'),
                    'guiderMessage': intervention_message,
                    # Extra debug fields (Flutter ignores; visible in logs/Firestore)
                    'focusItemId': (focus_payload or {}).get("itemId") if focus_payload else None,
                    'focusReason': (focus_payload or {}).get("reason") if focus_payload else None,
                    'intensityNow': (intensity_payload or {}).get("intensity") if intensity_payload else None,
                    'blendNow': (intensity_payload or {}).get("blend") if intensity_payload else None,
                }
                print(f"[intervention] Triggered: {analysis.get('reason')} for {character_id}")

        return jsonify({
            'success': True,
            'assistantMessage': assistant_message,
            'toolCalls': tool_calls,
            'intervention': intervention,
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Chat error: {str(e)}'
        }), 500
    finally:
        try:
            logger.info(
                json.dumps(
                    {
                        "event": "request_timing",
                        "route": "/chat",
                        "ts": _now_iso(),
                        "ms": int((time.time() - t0) * 1000),
                    },
                    ensure_ascii=False,
                )
            )
        except Exception:
            pass


# -----------------------------------------------------------------------------
# Session end analysis (called from Flutter when ending a session)
# -----------------------------------------------------------------------------
@app.route('/sessions/end_analyze', methods=['POST'])
def end_analyze_session():
    """
    Compute end-of-session intensity + summary and write them to:
      users/{uid}/sessions/{sessionId}
    Also logs an agent run and updates per-character checklist focus.
    """
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get("uid")
        session_id = data.get("sessionId")
        thread_id = data.get("threadId")
        character_id = data.get("characterId", "inner_critic")

        if not uid or not session_id or not thread_id:
            return jsonify({'success': False, 'error': 'uid, sessionId, threadId are required'}), 400

        # Read recent messages from Firestore for this thread
        msgs = []
        try:
            stream = (
                _messages_ref(uid, thread_id)
                .order_by("createdAt")
                .limit(200)
                .stream()
            )
            for doc in stream:
                d = doc.to_dict() or {}
                msgs.append(
                    {
                        "role": d.get("role", "user"),
                        "content": d.get("content", ""),
                    }
                )
        except Exception as e:
            logger.info(json.dumps({"event": "end_analyze_read_failed", "ts": _now_iso(), "uid": uid, "threadId": thread_id, "error": str(e)}, ensure_ascii=False))

        # always produce some output, even if msgs is empty.
        intensity_score = score_intensity_with_llm(character_id, msgs)
        summary = summarize_session_with_llm(character_id, msgs)

        # compute delta if we have start
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        existing = (snap.to_dict() or {}) if snap.exists else {}
        start_val = None
        try:
            
            start_val = snap.get("intensity.start")
        except Exception:
            try:
                start_val = ((existing.get("intensity") or {}).get("start"))
            except Exception:
                start_val = None
        if start_val is None:
            start_val = intensity_score["intensity"]
        try:
            delta = float(intensity_score["intensity"]) - float(start_val)
        except Exception:
            delta = 0.0

        sref.set(
            {
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
                },
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "endedAnalyzedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        # Update character plan metrics (very simple rolling baseline)
        ensure_character_checklist(uid, character_id)
        plan_ref = _character_plan_ref(uid, character_id)
        plan_ref.set(
            {
                "metrics.lastSessionAt": firestore.SERVER_TIMESTAMP,
                "metrics.sessionsCount": firestore.Increment(1),
                "metrics.lastIntensityEnd": intensity_score["intensity"],
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        # Update focus/checklist based on end score
        evidence = (msgs[-1].get("content") if msgs else "")[:200]
        plan_diff = _update_character_plan_from_score(uid, character_id, intensity_score, evidence=evidence)

        _log_agent_run(
            _session_runs_ref(uid, session_id),
            {
                "trigger": "session_end",
                "inputs": {"threadId": thread_id, "characterId": character_id},
                "outputs": {
                    "intensityEnd": intensity_score["intensity"],
                    "delta": delta,
                    "focus": plan_diff.get("focus"),
                    "changedItems": plan_diff.get("changedItems"),
                    "summary": summary.get("_raw") or {},
                },
                "rawModelOutput": {
                    "intensity": intensity_score.get("_raw") or {},
                    "summary": summary.get("_raw") or {},
                },
            },
        )

        logger.info(
            json.dumps(
                {
                    "event": "session_end_analyzed",
                    "ts": _now_iso(),
                    "uid": uid,
                    "sessionId": session_id,
                    "characterId": character_id,
                    "intensityEnd": intensity_score["intensity"],
                    "delta": delta,
                    "focus": plan_diff.get("focus"),
                },
                ensure_ascii=False,
            )
        )

        return jsonify(
            {
                "success": True,
                "intensityEnd": intensity_score["intensity"],
                "delta": delta,
                "focus": plan_diff.get("focus"),
                "sessionSummary": {
                    "highlights": summary.get("highlights") or [],
                    "nextStepSuggestion": summary.get("nextStepSuggestion") or "",
                },
            }
        )
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'end_analyze error: {str(e)}'}), 500


# ============================================================================
# GUIDED CHARACTER CHAT - Guider participates alongside the inner character
# ============================================================================

GUIDED_CHAT_ORCHESTRATOR_PROMPT = """
You are analyzing a conversation between a user and their inner part ({character_name}) where The Guider is available to help.

Based on the latest message and conversation context, decide who should respond:
- "character_only": The inner part should respond alone (user is engaging directly with the part, flow is good)
- "guider_only": Only The Guider should respond (user needs guidance, is confused, or asked for help)
- "both": Both should respond - character first, then Guider adds brief support (emotional moment, breakthrough, or needs facilitation)

Consider:
- If user is directly addressing the inner part → usually character_only
- If user seems stuck, overwhelmed, or confused → guider_only or both
- If there's a meaningful exchange happening → character_only (don't interrupt)
- If user had a breakthrough or insight → both (Guider can acknowledge)
- If conversation is getting tense → both (Guider can help)

Return JSON: {{"respondent": "character_only" | "guider_only" | "both", "reason": "brief reason"}}
""".strip()

GUIDER_IN_CHAT_PROMPT = """
You are ANA, The Guider - a compassionate companion in a conversation between the user and their inner part ({character_name}).

Your role:
- Gently facilitate understanding between user and inner part
- Keep responses SHORT (1-2 sentences max)
- Speak naturally without any labels or prefixes
- You can address the user, the inner part, or both
- Be warm but not intrusive

Good examples:
- "Take a moment with that feeling."
- "There's something important in what just came up."
- "What do you notice in your body right now?"

NEVER start your response with labels like "[Guider]:" or "The Guider:" - just speak naturally.
""".strip()


def decide_who_responds(messages: List[Dict], character_name: str) -> str:
    """Use AI to decide who should respond based on conversation context."""
    try:
        # Get last few messages for context
        recent = messages[-6:] if len(messages) > 6 else messages
        
        context_text = ""
        for msg in recent:
            sender = msg.get('sender', msg.get('role', 'user'))
            content = msg.get('content', '')
            if sender == 'user':
                context_text += f"User: {content}\n"
            elif sender == 'guider':
                context_text += f"Guider: {content}\n"
            else:
                context_text += f"{character_name}: {content}\n"
        
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {'role': 'system', 'content': GUIDED_CHAT_ORCHESTRATOR_PROMPT.format(character_name=character_name)},
                {'role': 'user', 'content': f"Recent conversation:\n{context_text}\n\nWho should respond?"},
            ],
            temperature=0.3,
            response_format={"type": "json_object"},
            max_tokens=100,
        )
        
        result = json.loads(response.choices[0].message.content or '{}')
        respondent = result.get('respondent', 'character_only')
        print(f"[guided_chat] Decision: {respondent} - {result.get('reason', 'no reason')}")
        return respondent
    except Exception as e:
        print(f"[guided_chat] Decision error: {e}, defaulting to character_only")
        return 'character_only'


def build_guider_in_chat_prompt(
    uid: str,
    character_id: str,
    character_name: str,
    guider_memory: str,
) -> str:
    """
    Build system prompt for Guider participating in character chat.
    Includes per-character checklist + recent session summaries so Guider can
    orient to "where the user stands" overall (without dumping it to the user).
    """
    prompt = GUIDER_IN_CHAT_PROMPT.format(character_name=character_name)

    # Internal context (not to be revealed verbatim)
    plan_snapshot = _get_character_plan_snapshot(uid, character_id)
    recent_summaries = _get_recent_session_summaries(uid, character_id, limit=4)
    prompt += "\n\n(Internal) Checklist + recent session summaries:\n"
    prompt += json.dumps(
        {"plan": plan_snapshot, "recentSessionSummaries": recent_summaries},
        ensure_ascii=False,
        default=_json_default,
    )

    if guider_memory:
        prompt += f"\n\nYour memory of this user:\n{guider_memory}"
    return prompt


def get_guider_response_in_chat(
    messages: List[Dict],
    uid: str,
    character_id: str,
    character_name: str,
    character_message: str,
    guider_memory: str,
) -> str:
    """Generate a natural Guider response for the guided chat."""
    guider_system_prompt = build_guider_in_chat_prompt(
        uid=uid,
        character_id=character_id,
        character_name=character_name,
        guider_memory=guider_memory,
    )
    
    # Build conversation context naturally (no weird labels)
    guider_messages = [{'role': 'system', 'content': guider_system_prompt}]
    
    # Add conversation as a natural flow
    conversation_context = "Here's the recent conversation:\n\n"
    for msg in messages[-8:]:
        sender = msg.get('sender', msg.get('role', 'user'))
        content = msg.get('content', '')
        if sender == 'user':
            conversation_context += f"User: {content}\n\n"
        elif sender == 'guider':
            conversation_context += f"You (Guider): {content}\n\n"
        else:
            conversation_context += f"{character_name}: {content}\n\n"
    
    # Add the character's latest response if provided
    if character_message:
        conversation_context += f"{character_name}: {character_message}\n\n"
    
    conversation_context += "Respond naturally as The Guider (1-2 sentences, no labels):"
    
    guider_messages.append({'role': 'user', 'content': conversation_context})
    
    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=guider_messages,
        temperature=0.7,
        max_tokens=100,
    )
    
    guider_message = response.choices[0].message.content.strip()
    
    # Clean up any accidental labels the AI might add
    for prefix in ['[Guider]:', '[The Guider]:', 'Guider:', 'The Guider:', '[You - The Guider]:']:
        if guider_message.startswith(prefix):
            guider_message = guider_message[len(prefix):].strip()
    
    return guider_message


@app.route('/chat_guided', methods=['POST'])
def chat_guided():
    """Handle a guided chat where character and/or Guider respond based on context."""
    try:
        t0 = time.time()
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        character_name = character_profile.get('displayName', 'Inner Part')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        messages = data.get('messages') or []
        
        # --- 1. Decide who should respond ---
        respondent = decide_who_responds(messages, character_name)
        
        character_message = ''
        guider_message = ''
        
        # --- 2. Get Character Response if needed ---
        if respondent in ['character_only', 'both']:
            memory_summary = load_agent_memory_summary(uid, character_id)
            character_system_prompt = build_system_prompt_with_memory(
                character_profile,
                memory_summary,
            )
            
            agent_result = run_agent_step(character_system_prompt, messages)
            tool_calls = agent_result.get('toolCalls') or []
            run_tool_calls(uid, tool_calls)
            
            character_message = agent_result.get('assistantMessage', '')
            
            # Update character memory
            updated_char_summary = agent_result.get('memorySummary', '')
            if not updated_char_summary:
                updated_char_summary = generate_updated_summary(
                    memory_summary,
                    messages + [{'role': 'assistant', 'content': character_message}],
                )
            save_agent_memory_summary(uid, character_id, updated_char_summary)
        
        # --- 3. Get Guider Response if needed ---
        if respondent in ['guider_only', 'both']:
            guider_memory = load_agent_memory_summary(uid, 'guider')
            guider_message = get_guider_response_in_chat(
                messages=messages,
                uid=uid,
                character_id=character_id,
                character_name=character_name,
                character_message=character_message,
                guider_memory=guider_memory,
            )
            
            # Update guider memory
            all_new_messages = messages.copy()
            if character_message:
                all_new_messages.append({'role': 'assistant', 'content': character_message})
            if guider_message:
                all_new_messages.append({'role': 'assistant', 'content': guider_message})
            
            updated_guider_summary = generate_updated_summary(guider_memory, all_new_messages)
            save_agent_memory_summary(uid, 'guider', updated_guider_summary)
        
        print(f"[guided_chat] {respondent}: char={bool(character_message)}, guider={bool(guider_message)}")

        # Periodic intensity + checklist update (same cadence as /chat).
        # We guard it so overlapping requests cannot clobber intensity/plan state.
        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                scored_msgs = [
                    {"role": m.get("role", "user"), "content": m.get("content", "")}
                    for m in messages
                    if m.get("content")
                ]
                if character_message:
                    scored_msgs.append({"role": "assistant", "content": character_message})
                if guider_message:
                    scored_msgs.append({"role": "assistant", "content": guider_message})

                score = score_intensity_with_llm(character_id, scored_msgs)
                evidence = (scored_msgs[-1].get("content") if scored_msgs else "")[:200]
                _write_session_intensity(uid, session_id, score, turn_for_update)
                plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)

                _log_agent_run(
                    _session_runs_ref(uid, session_id),
                    {
                        "trigger": "user_message",
                        "inputs": {"threadId": thread_id, "characterId": character_id},
                        "outputs": {
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "signals": score.get("signals") or [],
                            "focus": plan_diff.get("focus"),
                        },
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )

                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update_guided",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "turn": int(turn_for_update),
                            "intensity": score["intensity"],
                            "focus": plan_diff.get("focus"),
                            "respondent": respondent,
                        },
                        ensure_ascii=False,
                    )
                )
            except Exception as e:
                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update_guided_failed",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "error": str(e),
                        },
                        ensure_ascii=False,
                    )
                )
        
        return jsonify({
            'success': True,
            'characterMessage': character_message,
            'guiderMessage': guider_message,
            'respondent': respondent,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Guided chat error: {str(e)}'
        }), 500
    finally:
        try:
            logger.info(
                json.dumps(
                    {
                        "event": "request_timing",
                        "route": "/chat_guided",
                        "ts": _now_iso(),
                        "ms": int((time.time() - t0) * 1000),
                    },
                    ensure_ascii=False,
                )
            )
        except Exception:
            pass


# ============================================================================
# GUIDER AGENT - Has access to all character conversations
# ============================================================================

GUIDER_SYSTEM_PROMPT = """
You are ANA, The Guider - a compassionate companion helping users explore their inner world using Internal Family Systems (IFS) principles.

CRITICAL COMMUNICATION STYLE:
- Keep responses SHORT (2-4 sentences max)
- Ask ONE question at a time
- Walk the user through step by step - don't explain everything at once
- Be conversational and warm, like a gentle friend
- Use simple, everyday language

Your approach:
- Listen first, then reflect back what you heard
- Guide with curiosity, not lectures
- One small step at a time
- Let the user lead the pace

You are NOT a therapist. You are a supportive companion.
If someone is in crisis, gently encourage them to seek professional help.

You have access to the user's conversations with their inner parts. Use this to personalize your guidance, but don't overwhelm them with information.

GUIDANCE RULE (IMPORTANT):
- Keep your guidance aligned with IFS principles and the user's current state across parts.
- Use prior context to choose the most relevant focus, but stay flexible (not step-by-step rigid).
- Offer one small, practical next step at a time.
- Do not mention internal planning/checklist logic to the user.

Example good response: "It sounds like your Workaholic has been very active lately. What does it feel like when that part takes over?"

Example bad response: "Your Workaholic is significant because... [long explanation with 4 numbered points]"
""".strip()


def get_all_character_summaries(uid: str) -> Dict[str, str]:
    """Fetch memory summaries for all characters the user has chatted with."""
    summaries = {}
    try:
        memory_ref = db.collection('users').document(uid).collection('agent_memory')
        docs = memory_ref.stream()
        for doc in docs:
            data = doc.to_dict() or {}
            summary = data.get('summary', '')
            if summary:
                summaries[doc.id] = summary
    except Exception as e:
        print(f"[guider] Error fetching character summaries: {e}")
    return summaries


def get_user_character_states(uid: str) -> List[Dict[str, str]]:
    """
    Fetch per-character state from `user_characters` for this user.

    Expected state values:
    - active
    - stable
    - inactive
    """
    rows: List[Dict[str, str]] = []
    try:
        chars_ref = db.collection("user_characters").where("userId", "==", uid)
        for doc in chars_ref.stream():
            data = doc.to_dict() or {}
            character_id = (
                data.get("characterId")
                or data.get("innerCharacterId")
                or data.get("id")
                or doc.id
            )
            display_name = (
                data.get("characterName")
                or data.get("displayNameEn")
                or data.get("displayName")
                or str(character_id).replace("_", " ").title()
            )
            state = str(data.get("currentState") or "active").strip().lower()
            if state not in {"active", "stable", "inactive"}:
                state = "active"
            rows.append(
                {
                    "characterId": str(character_id),
                    "displayName": str(display_name),
                    "currentState": state,
                }
            )
    except Exception as e:
        print(f"[guider] Error fetching user_characters states: {e}")
    return rows


def _format_plan_snapshot_for_prompt(plan_snapshot: Dict[str, Any], max_items: int = 4) -> str:
    """Formats a compact checklist plan snapshot for prompt injection."""
    if not plan_snapshot:
        return ""

    focus = plan_snapshot.get("focus") or {}
    focus_item = focus.get("itemId") or "none"
    focus_reason = focus.get("reason") or "none"
    items = plan_snapshot.get("checklistItems") or []
    metrics = plan_snapshot.get("metrics") or {}

    prioritized: List[Dict[str, Any]] = []
    for status in ("needs_work", "in_progress", "completed"):
        prioritized.extend([it for it in items if it.get("status") == status])
    if not prioritized:
        prioritized = items

    lines = [
        f"- focus: {focus_item} (reason: {focus_reason})",
        f"- status: {plan_snapshot.get('status') or 'active'}",
    ]
    if metrics:
        lines.append(f"- metrics: {json.dumps(metrics, ensure_ascii=False, default=_json_default)}")
    if prioritized:
        lines.append("- checklist:")
        for it in prioritized[:max_items]:
            lines.append(
                f"  - {it.get('id')}: {it.get('status')} (confidence={it.get('confidence')})"
            )
    return "\n".join(lines)


def build_guider_context(
    uid: str,
    states: Optional[List[Dict[str, str]]] = None,
    guider_plan_snapshot: Optional[Dict[str, Any]] = None,
) -> str:
    """Build context for the Guider from all character conversations."""
    states = states if states is not None else get_user_character_states(uid)
    summaries = get_all_character_summaries(uid)

    if not summaries and not states and not guider_plan_snapshot:
        return "The user hasn't had any conversations with their inner parts yet."

    context_parts = ["Here's what you know about the user's inner parts:\n"]

    if states:
        context_parts.append("Current state snapshot from user_characters:")
        # Keep deterministic order for prompt stability.
        for row in sorted(states, key=lambda x: x.get("displayName", "").lower()):
            context_parts.append(
                f"- {row.get('displayName')} ({row.get('characterId')}): {row.get('currentState')}"
            )
        context_parts.append("")

    if summaries:
        context_parts.append("Conversation memory summaries by inner part:")
        for character_id, summary in summaries.items():
            display_name = character_id.replace('_', ' ').title()
            context_parts.append(f"**{display_name}:**\n{summary}\n")

    if guider_plan_snapshot:
        plan_text = _format_plan_snapshot_for_prompt(guider_plan_snapshot, max_items=4)
        if plan_text:
            context_parts.append("Current guider checklist plan snapshot:")
            context_parts.append(plan_text)

    return "\n".join(context_parts)


def build_guider_system_prompt_with_context(
    uid: str,
    guider_memory: str,
    states: Optional[List[Dict[str, str]]] = None,
    guider_plan_snapshot: Optional[Dict[str, Any]] = None,
) -> str:
    """Build the full system prompt for the Guider with user context."""
    character_context = build_guider_context(
        uid,
        states=states,
        guider_plan_snapshot=guider_plan_snapshot,
    )
    
    prompt = GUIDER_SYSTEM_PROMPT
    
    if character_context:
        prompt += f"\n\n--- USER'S INNER PARTS CONTEXT ---\n{character_context}"
    
    if guider_memory:
        prompt += f"\n\n--- YOUR MEMORY OF THIS USER ---\n{guider_memory}"
    
    return prompt


def run_guider_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    """Run an agent step for the Guider."""
    agent_messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'system', 'content': (
            'Return JSON with keys: "assistantMessage", "memorySummary". '
            '"assistantMessage" should be warm, concise, and practical. '
            '"memorySummary" should be under 6 bullet points about the user\'s journey.'
        )},
    ]
    
    for message in messages:
        role = message.get('role')
        content = message.get('content', '')
        if role in ['user', 'assistant'] and content:
            agent_messages.append({'role': role, 'content': content})
    
    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=agent_messages,
        temperature=0.7,
        response_format={"type": "json_object"},
    )
    
    raw = response.choices[0].message.content or '{}'
    try:
        return json.loads(raw)
    except Exception:
        return {'assistantMessage': '', 'memorySummary': ''}


@app.route('/chat_guider', methods=['POST'])
def chat_guider():
    """Handle a chat request for The Guider agent."""
    try:
        t0 = time.time()
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500
        
        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        # Keep guider-only chat inside session tracking as well.
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        messages = data.get('messages') or []
        character_id = 'guider'

        # Load per-character state snapshot so Guider can ground decisions in
        # current stabilization status across all parts.
        character_states = get_user_character_states(uid)
        state_counts = {"active": 0, "stable": 0, "inactive": 0}
        for row in character_states:
            st = str(row.get("currentState") or "").lower()
            if st in state_counts:
                state_counts[st] += 1
        logger.info(
            json.dumps(
                {
                    "event": "guider_character_states_snapshot",
                    "ts": _now_iso(),
                    "uid": uid,
                    "total": len(character_states),
                    "active": state_counts["active"],
                    "stable": state_counts["stable"],
                    "inactive": state_counts["inactive"],
                },
                ensure_ascii=False,
            )
        )
        
        # Load guider's memory of this user
        guider_memory = load_agent_memory_summary(uid, 'guider')
        guider_plan_snapshot = _get_character_plan_snapshot(uid, 'guider')
        
        # Build system prompt with all character context
        system_prompt = build_guider_system_prompt_with_context(
            uid,
            guider_memory,
            states=character_states,
            guider_plan_snapshot=guider_plan_snapshot,
        )
        
        # Run the guider agent
        agent_result = run_guider_agent_step(system_prompt, messages)
        
        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        
        # Update guider's memory
        if not updated_summary:
            updated_summary = generate_updated_summary(
                guider_memory,
                messages + [{'role': 'assistant', 'content': assistant_message}],
            )
        save_agent_memory_summary(uid, 'guider', updated_summary)
        print(f"[guider] memory_summary_updated: {bool(updated_summary)}")

        # ---------------------------------------------------------------------
        # Periodic intensity + checklist updates for guider-only sessions.
        # Cadence: every 3 user turns of this guider session.
        # Writes:
        # - users/{uid}/sessions/{sessionId}.intensity.*
        # - users/{uid}/character_plans/guider
        # - agent_runs under session + character_plan
        # ---------------------------------------------------------------------
        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                scored_msgs = [
                    {"role": m.get("role", "user"), "content": m.get("content", "")}
                    for m in messages
                    if m.get("content")
                ]
                if assistant_message:
                    scored_msgs.append({"role": "assistant", "content": assistant_message})

                score = score_intensity_with_llm(character_id, scored_msgs)
                evidence = (scored_msgs[-1].get("content") if scored_msgs else "")[:200]

                _write_session_intensity(uid, session_id, score, turn_for_update)
                plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)

                _log_agent_run(
                    _session_runs_ref(uid, session_id),
                    {
                        "trigger": "user_message_guider",
                        "inputs": {"threadId": thread_id, "characterId": character_id},
                        "outputs": {
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "signals": score.get("signals") or [],
                            "focus": plan_diff.get("focus"),
                            "changedItems": plan_diff.get("changedItems"),
                        },
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )

                _log_agent_run(
                    _plan_runs_ref(uid, character_id),
                    {
                        "trigger": "user_message_guider",
                        "inputs": {"sessionId": session_id, "threadId": thread_id},
                        "outputs": {
                            "focus": plan_diff.get("focus"),
                            "changedItems": plan_diff.get("changedItems"),
                        },
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )

                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update_guider",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "turn": int(turn_for_update),
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "focus": plan_diff.get("focus"),
                        },
                        ensure_ascii=False,
                    )
                )
            except Exception as e:
                logger.info(
                    json.dumps(
                        {
                            "event": "periodic_update_guider_failed",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "error": str(e),
                        },
                        ensure_ascii=False,
                    )
                )
        
        return jsonify({
            'success': True,
            'assistantMessage': assistant_message,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Guider error: {str(e)}'
        }), 500
    finally:
        try:
            logger.info(
                json.dumps(
                    {
                        "event": "request_timing",
                        "route": "/chat_guider",
                        "ts": _now_iso(),
                        "ms": int((time.time() - t0) * 1000),
                    },
                    ensure_ascii=False,
                )
            )
        except Exception:
            pass


@app.route('/character_plans/active', methods=['GET'])
def get_active_character_plan():
    """
    Get the per-character checklist plan for a specific characterId.
    Query params:
      uid, characterId
    """
    try:
        uid = request.args.get('uid')
        character_id = request.args.get('characterId')
        if not uid or not character_id:
            return jsonify({'success': False, 'error': 'uid and characterId are required'}), 400

        ensure_character_checklist(uid, character_id)
        snap = _character_plan_ref(uid, character_id).get()
        if not snap.exists:
            return jsonify({'success': False, 'error': 'No plan found'}), 404

        data = snap.to_dict() or {}
        data['id'] = snap.id
        return jsonify({'success': True, 'plan': data})
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Error fetching character plan: {str(e)}'}), 500


# ============================================================================
# GUIDER INTERVENTION IN CHARACTER CHATS
# ============================================================================

# Markers that suggest the user may need Guider support
EMOTIONAL_INTENSITY_MARKERS = [
    'i can\'t', 'i cant', 'too much', 'overwhelming', 'scared', 'terrified',
    'hate myself', 'hate my', 'worthless', 'hopeless', 'give up', 'giving up',
    'can\'t cope', 'cant cope', 'falling apart', 'breaking down', 'panic',
    'anxiety', 'depressed', 'suicidal', 'hurt myself', 'end it', 'no point',
    'exhausted', 'drained', 'stuck', 'trapped', 'alone', 'nobody cares',
    'what\'s wrong with me', 'whats wrong with me', 'i\'m broken', 'im broken',
]

STUCK_LOOP_PHRASES = [
    'i don\'t know', 'i dont know', 'not sure', 'confused', 'same thing',
    'going in circles', 'nothing works', 'tried everything', 'always the same',
    'keeps happening', 'can\'t figure', 'cant figure',
]

CRISIS_KEYWORDS = [
    'suicidal', 'suicide', 'kill myself', 'hurt myself', 'self-harm', 'self harm',
    'end my life', 'don\'t want to live', 'dont want to live', 'better off dead',
]


def analyze_intervention_need(messages: List[Dict[str, str]], character_id: str) -> Dict[str, Any]:
    """Analyze conversation to determine if Guider intervention would be helpful."""
    if len(messages) < 3:
        return {'shouldIntervene': False}
    
    # Get recent user messages (last 6)
    recent_user_messages = [
        m['content'].lower() for m in messages[-6:] 
        if m.get('role') == 'user'
    ]
    
    if not recent_user_messages:
        return {'shouldIntervene': False}
    
    combined_text = ' '.join(recent_user_messages)
    
    # Check for crisis keywords (highest priority)
    for keyword in CRISIS_KEYWORDS:
        if keyword in combined_text:
            return {
                'shouldIntervene': True,
                'reason': 'crisis_detected',
                'severity': 'high',
                'message': 'I sense you may be going through something very difficult. Would you like to talk to The Guider? They can help you find support.',
            }
    
    # Count emotional intensity markers
    intensity_count = sum(1 for marker in EMOTIONAL_INTENSITY_MARKERS if marker in combined_text)
    
    # Check for stuck loop patterns
    stuck_count = sum(1 for phrase in STUCK_LOOP_PHRASES if phrase in combined_text)
    
    # Check for repetitive themes (same phrases appearing multiple times)
    repetition_detected = False
    if len(recent_user_messages) >= 3:
        # Check if user is repeating similar messages
        for i in range(len(recent_user_messages) - 1):
            for j in range(i + 1, len(recent_user_messages)):
                # Simple similarity check
                words_i = set(recent_user_messages[i].split())
                words_j = set(recent_user_messages[j].split())
                if len(words_i) > 3 and len(words_j) > 3:
                    overlap = len(words_i & words_j)
                    if overlap / max(len(words_i), len(words_j)) > 0.6:
                        repetition_detected = True
                        break
    
    # Determine intervention level
    if intensity_count >= 3 or (intensity_count >= 2 and stuck_count >= 2):
        return {
            'shouldIntervene': True,
            'reason': 'emotional_intensity',
            'severity': 'medium',
            'message': f'It sounds like this conversation is bringing up a lot. The Guider is here if you want a calmer space to process what you\'re feeling.',
        }
    
    if stuck_count >= 3 or repetition_detected:
        return {
            'shouldIntervene': True,
            'reason': 'stuck_loop',
            'severity': 'low',
            'message': 'You seem to be working through something challenging. Would it help to step back and talk with The Guider for a broader perspective?',
        }
    
    # Check message count - suggest guider after extended sessions
    total_user_messages = sum(1 for m in messages if m.get('role') == 'user')
    if total_user_messages >= 15 and total_user_messages % 5 == 0:
        return {
            'shouldIntervene': True,
            'reason': 'session_length',
            'severity': 'low',
            'message': 'You\'ve been exploring deeply with this part. The Guider can help you reflect on what you\'ve learned so far.',
        }
    
    return {'shouldIntervene': False}


def _get_recent_session_summaries(uid: str, character_id: str, limit: int = 5) -> List[Dict[str, Any]]:
    """
    fetches recent ended session summaries for a character
    """
    try:
        snaps = (
            _sessions_ref(uid)
            .where("characterId", "==", character_id)
            .limit(50)
            .stream()
        )
        sessions = []
        for s in snaps:
            d = s.to_dict() or {}
            if d.get("status") != "ended":
                continue
            summary = d.get("sessionSummary") or {}
            if not summary:
                continue
            sessions.append(
                {
                    "sessionId": s.id,
                    "endedAt": d.get("endedAt") or d.get("updatedAt"),
                    "summary": summary,
                }
            )
        # Sort newest first if endedAt is available
        sessions.sort(key=lambda x: str(x.get("endedAt") or ""), reverse=True)
        return sessions[:limit]
    except Exception:
        return []


def _get_character_plan_snapshot(uid: str, character_id: str) -> Dict[str, Any]:
    """returns a compact snapshot of the per-character checklist + focus"""
    try:
        ensure_character_checklist(uid, character_id)
        snap = _character_plan_ref(uid, character_id).get()
        if not snap.exists:
            return {}
        d = snap.to_dict() or {}
        return {
            "status": d.get("status"),
            "focus": d.get("focus") or {},
            "checklistItems": d.get("checklistItems") or [],
            "metrics": d.get("metrics") or {},
        }
    except Exception:
        return {}


def generate_guider_intervention_message(
    uid: str,
    character_id: str,
    reason: str,
    messages: List[Dict[str, str]],
) -> str:
    """generates a personalized intervention message from The Guider"""
    # pull plan + history context so the intervention is not blind
    plan_snapshot = _get_character_plan_snapshot(uid, character_id)
    recent_summaries = _get_recent_session_summaries(uid, character_id, limit=4)

    # Get character display name
    character_names = {
        'inner_critic': 'The Inner Critic',
        'perfectionist': 'The Perfectionist',
        'people_pleaser': 'The People Pleaser',
        'lonely_part': 'The Lonely Part',
        'workaholic': 'The Workaholic',
        'procrastinator': 'The Procrastinator',
        'fearful_part': 'The Fearful Part',
        'wounded_child': 'The Wounded Child',
    }
    character_name = character_names.get(character_id, 'this inner part')
    
    # Generate context-aware message using AI
    try:
        focus = (plan_snapshot.get("focus") or {})
        focus_item_id = focus.get("itemId")
        focus_reason = focus.get("reason")

        intervention_prompt = f"""You are The Guider, a compassionate companion helping users explore their inner world.

The user has been chatting with {character_name} and may need some gentle support.
Reason for intervention: {reason}

Your internal context (do not reveal verbatim):
- Current checklist focus: {focus_item_id} (reason: {focus_reason})
- Recent session summaries: {json.dumps(recent_summaries, ensure_ascii=False, default=_json_default)}

Generate a SHORT (1-2 sentences) caring message that:
- Acknowledges their feelings without being overwhelming
- Gently offers yourself as a space for reflection
- Does NOT pressure them to switch

Keep it warm and brief. End with an implicit invitation, not a question."""

        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {'role': 'system', 'content': intervention_prompt},
                {'role': 'user', 'content': f'Recent context: {messages[-3:]}'},
            ],
            temperature=0.7,
            max_tokens=100,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"[intervention] Error generating message: {e}")
        # Fallback messages based on reason
        fallbacks = {
            'crisis_detected': 'I\'m here if you need a calm space. You don\'t have to go through this alone.',
            'emotional_intensity': 'It sounds like a lot is coming up. I\'m here when you need a moment to breathe.',
            'stuck_loop': 'Sometimes stepping back helps us see more clearly. I\'m here if you want to reflect.',
            'session_length': 'You\'ve been exploring deeply. I\'m here if you want to process what you\'ve discovered.',
        }
        return fallbacks.get(reason, 'I\'m here if you want to talk.')


@app.route('/check_intervention', methods=['POST'])
def check_intervention():
    """Check if Guider intervention is recommended for a character chat."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId', '')
        messages = data.get('messages', [])
        
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        # Analyze if intervention is needed
        analysis = analyze_intervention_need(messages, character_id)
        
        if not analysis.get('shouldIntervene'):
            return jsonify({
                'success': True,
                'shouldIntervene': False,
            })
        
        # Generate personalized intervention message
        intervention_message = generate_guider_intervention_message(
            uid=uid,
            character_id=character_id,
            reason=analysis.get('reason', 'general'),
            messages=messages,
        )
        
        return jsonify({
            'success': True,
            'shouldIntervene': True,
            'reason': analysis.get('reason'),
            'severity': analysis.get('severity'),
            'guiderMessage': intervention_message,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Intervention check error: {str(e)}'
        }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
