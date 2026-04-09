from flask import Flask, request, jsonify, Blueprint
from flask_cors import CORS
import os
import json
import logging
from datetime import datetime, timezone
import time
from typing import Dict, List, Any
import traceback
import requests

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Emotion detector server URL
EMOTION_DETECTOR_URL = os.getenv('EMOTION_DETECTOR_URL', 'http://localhost:5002')

# -----------------------------------------------------------------------------
# Logging (terminal visibility)
# -----------------------------------------------------------------------------
logger = logging.getLogger("guider_video")
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("%(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Initialize Firebase Admin SDK.
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

db = firestore.client()

# Create blueprint
guider_video_bp = Blueprint("guider_video_bp", __name__, url_prefix="/guider")


# ============================================================================
# Helper Functions (mirroring agent.py)
# ============================================================================

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


def _character_plans_ref(uid: str):
    return _user_ref(uid).collection("character_plans")


def _character_plan_ref(uid: str, character_id: str):
    return _character_plans_ref(uid).document(character_id)


def _plan_runs_ref(uid: str, character_id: str):
    return _character_plan_ref(uid, character_id).collection("agent_runs")


# ============================================================================
# Character Checklist Templates (mirroring agent.py)
# ============================================================================

CHARACTER_CHECKLIST_TEMPLATES: Dict[str, List[Dict[str, str]]] = {
    "guider": [
        {
            "id": "presence",
            "name": "Therapeutic presence",
            "definition": "User can stay present with difficult emotions without shutting down.",
        },
        {
            "id": "self_awareness",
            "name": "Self-awareness",
            "definition": "User can notice their own reactions and patterns.",
        },
        {
            "id": "emotional_regulation",
            "name": "Emotional regulation",
            "definition": "User can use grounding techniques when intensity rises.",
        },
        {
            "id": "curiosity",
            "name": "Curiosity about parts",
            "definition": "User can approach inner parts with curiosity instead of judgment.",
        },
        {
            "id": "compassion",
            "name": "Self-compassion",
            "definition": "User can offer kindness to themselves when struggling.",
        },
    ],
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
    """Ensures a per-character plan doc exists."""
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


# ============================================================================
# Session Management (mirroring agent.py patterns)
# ============================================================================

def _ensure_session_doc(uid: str, session_id: str, character_id: str = 'guider') -> None:
    """Ensure session document exists."""
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            sref.set({
                "id": session_id,
                "characterId": character_id,
                "characterType": "guider",
                "status": "active",
                "type": "video",
                "title": "Video call with The Guider",
                "startedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "userTurnCount": 0,
                "intensity": {},
                "sessionSummary": {},
                "periodic": {},
                "faceEmotion": {
                    "dominant": None,
                    "averageConfidence": 0.0,
                    "startEmotion": None,
                    "startConfidence": 0.0,
                    "endEmotion": None,
                    "endConfidence": 0.0,
                    "allDetections": []
                },
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
            logger.info(json.dumps({
                "event": "session_created",
                "ts": _now_iso(),
                "uid": uid,
                "sessionId": session_id
            }, ensure_ascii=False))
    except Exception as e:
        logger.info(json.dumps({
            "event": "session_creation_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _ensure_thread_doc(uid: str, thread_id: str, session_id: str) -> None:
    """Ensure thread document exists."""
    try:
        tref = _threads_ref(uid).document(thread_id)
        snap = tref.get()
        if not snap.exists:
            tref.set({
                "id": thread_id,
                "sessionId": session_id,
                "characterId": "guider",
                "characterType": "guider",
                "title": "Video call with The Guider",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
    except Exception as e:
        logger.info(json.dumps({
            "event": "thread_creation_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _save_message(uid: str, thread_id: str, role: str, content: str, sender: str = None) -> None:
    """Save a message to Firestore."""
    try:
        msg_ref = _messages_ref(uid, thread_id).document()
        msg_data = {
            "role": role,
            "content": content,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
        if sender:
            msg_data["sender"] = sender

        msg_ref.set(msg_data)

        _threads_ref(uid).document(thread_id).set({
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        thread_doc = _threads_ref(uid).document(thread_id).get()
        if thread_doc.exists:
            session_id = thread_doc.to_dict().get('sessionId')
            if session_id:
                _session_ref(uid, session_id).set({
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                    "lastMessageAt": firestore.SERVER_TIMESTAMP,
                }, merge=True)

                if role == 'user':
                    _session_ref(uid, session_id).set({
                        "userTurnCount": firestore.Increment(1),
                    }, merge=True)
    except Exception as e:
        logger.info(json.dumps({
            "event": "save_message_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _update_face_emotion(uid: str, session_id: str, emotion: str, confidence: float) -> None:
    """Update face emotion data in Firestore."""
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            return

        current_data = snap.to_dict() or {}
        face_data = current_data.get('faceEmotion', {})
        all_detections = face_data.get('allDetections', [])

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
            'faceEmotion': {
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

        logger.info(json.dumps({
            "event": "face_emotion_updated",
            "ts": _now_iso(),
            "uid": uid,
            "sessionId": session_id,
            "emotion": emotion,
            "confidence": confidence,
            "dominant": dominant
        }, ensure_ascii=False))

    except Exception as e:
        logger.info(json.dumps({
            "event": "face_emotion_update_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _update_voice_emotion(uid: str, session_id: str, emotion: str, confidence: float) -> None:
    """Update voice emotion data in Firestore."""
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

        logger.info(json.dumps({
            "event": "voice_emotion_updated",
            "ts": _now_iso(),
            "uid": uid,
            "sessionId": session_id,
            "emotion": emotion,
            "confidence": confidence,
            "dominant": dominant
        }, ensure_ascii=False))

    except Exception as e:
        logger.info(json.dumps({
            "event": "voice_emotion_update_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _log_agent_run(ref, payload: Dict[str, Any]) -> None:
    """Writes an agent run doc (and never throws)."""
    try:
        ref.document().set({**payload, "createdAt": firestore.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        logger.info(json.dumps({
            "event": "agent_run_write_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


def _get_session_user_turn_count(uid: str, session_id: str) -> int:
    try:
        snap = _session_ref(uid, session_id).get()
        if not snap.exists:
            return 0
        data = snap.to_dict() or {}
        return int(data.get("userTurnCount") or 0)
    except Exception:
        return 0


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
        logger.info(json.dumps({
            "event": "session_intensity_write_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


# ============================================================================
# Intensity Scoring (mirroring agent.py)
# ============================================================================

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


def score_intensity_with_llm(character_id: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    context = _extract_recent_user_text(messages)

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


def _pick_focus_item_from_score(score: Dict[str, Any]) -> Dict[str, str]:
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
                    it["evidence"] = (it["evidence"] + [evidence])[-5:]
                after = (it.get("status"), it.get("confidence"))
                if before != after:
                    changed.append({"id": item_id, "from": before, "to": after})
                return

    if intensity >= 0.75:
        set_item("stabilization", "needs_work", 0.7)
    if blend:
        set_item("unblending", "needs_work", 0.7)
    if intensity < 0.55 and not blend:
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


# ============================================================================
# Memory Functions (mirroring agent.py)
# ============================================================================

def load_agent_memory_summary(uid: str, character_id: str) -> str:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    snapshot = doc_ref.get()
    if snapshot.exists:
        data = snapshot.to_dict() or {}
        return data.get('summary', '') or ''
    return ''


def save_agent_memory_summary(uid: str, character_id: str, summary: str) -> None:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    doc_ref.set({
        'summary': summary,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


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


def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })


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


def set_last_agent_run(uid: str) -> None:
    db.collection('users').document(uid).set({
        'lastAgentRunAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


# ============================================================================
# Guider Agent (mirroring agent.py's run_agent_step pattern)
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

PLAN MANAGEMENT RULES (IMPORTANT):
- Create ONE plan after 3-4 exchanges when you understand the user's focus - then STOP creating new plans
- After a plan exists, ONLY use update_plan_step to track progress - DO NOT create new plans
- Only create a NEW plan if: (1) user explicitly shifts to a completely different inner part, OR (2) all steps are completed
- When user makes progress or has insight: use update_plan_step with status="completed"
- When user needs more work on a step: use update_plan_step with status="in_progress" and notes
- CRITICAL: Do NOT create a plan on every message - maximum ONE plan per conversation topic
- NEVER say the whole plan at once to the user, just walk the user through it step by step

Example good response: "It sounds like your Workaholic has been very active lately. What does it feel like when that part takes over?"

Example bad response: "Your Workaholic is significant because... [long explanation with 4 numbered points]"
""".strip()


def run_guider_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    agent_messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'system', 'content': (
            'Return JSON with keys: "assistantMessage", "toolCalls", "memorySummary". '
            '"toolCalls" is a list of {name, args}. '
            '\n\nAvailable tools:'
            '\n- create_healing_plan: args={title, targetCharacterId (optional), steps (list of step descriptions)}. '
            'Use ONCE after 3-4 exchanges. DO NOT use again unless topic completely changes or plan is done.'
            '\n- update_plan_step: args={stepId, status ("completed"/"in_progress"), notes (optional)}. '
            'Use this to track progress on EXISTING plan steps. This is your main tool after plan is created.'
            '\n- suggest_character_focus: args={characterId, reason}. '
            'Use when you identify which inner part needs attention.'
            '\n- add_timeline_event: args={type, title, summary}. '
            'Use to record breakthroughs or important moments.'
            '\n- update_progress_summary: args={currentStage, streakDays, notes}. '
            'Use to track overall progress.'
            '\n- set_last_agent_run: args={}. '
            'Use to mark when you last interacted with the user.'
            '\n\nIMPORTANT: After creating ONE plan, prefer update_plan_step over create_healing_plan.'
            '\n\n"memorySummary" should be under 6 bullet points about the user\'s journey.'
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


def has_active_plan(uid: str) -> bool:
    try:
        plans_ref = db.collection('users').document(uid).collection('plans')
        active_plans = plans_ref.where('status', '==', 'active').limit(1).stream()
        for _ in active_plans:
            return True
    except Exception:
        pass
    return False


def run_guider_tool_calls(uid: str, tool_calls: List[Dict[str, Any]]) -> None:
    for call in tool_calls:
        name = call.get('name')
        args = call.get('args') or {}
        logger.info(json.dumps({
            "event": "guider_tool_call",
            "ts": _now_iso(),
            "uid": uid,
            "tool": name
        }, ensure_ascii=False))

        if name == 'create_healing_plan':
            if has_active_plan(uid):
                logger.info(json.dumps({
                    "event": "create_plan_skipped",
                    "ts": _now_iso(),
                    "uid": uid,
                    "reason": "active_plan_exists"
                }, ensure_ascii=False))
            else:
                create_healing_plan(uid, args)
        elif name == 'update_plan_step':
            update_plan_step(uid, args)
        elif name == 'suggest_character_focus':
            logger.info(json.dumps({
                "event": "suggest_character_focus",
                "ts": _now_iso(),
                "uid": uid,
                "characterId": args.get('characterId')
            }, ensure_ascii=False))
        elif name == 'add_timeline_event':
            add_timeline_event(uid, args)
        elif name == 'update_progress_summary':
            update_progress_summary(uid, args)
        elif name == 'set_last_agent_run':
            set_last_agent_run(uid)


def create_healing_plan(uid: str, args: Dict[str, Any]) -> str:
    plans_ref = db.collection('users').document(uid).collection('plans')

    active_plans = plans_ref.where('status', '==', 'active').stream()
    for plan in active_plans:
        plans_ref.document(plan.id).update({'status': 'paused'})

    steps = args.get('steps', [])
    plan_steps = [
        {'id': f'step_{i}', 'description': step, 'status': 'pending'}
        for i, step in enumerate(steps)
    ]

    new_plan = {
        'title': args.get('title', 'Healing Plan'),
        'targetCharacterId': args.get('targetCharacterId'),
        'status': 'active',
        'steps': plan_steps,
        'currentStepIndex': 0,
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }

    doc_ref = plans_ref.add(new_plan)
    logger.info(json.dumps({
        "event": "healing_plan_created",
        "ts": _now_iso(),
        "uid": uid,
        "planId": doc_ref[1].id,
        "title": args.get('title', 'Healing Plan')
    }, ensure_ascii=False))
    return doc_ref[1].id


def update_plan_step(uid: str, args: Dict[str, Any]) -> None:
    plans_ref = db.collection('users').document(uid).collection('plans')
    active_plans = plans_ref.where('status', '==', 'active').limit(1).stream()

    for plan in active_plans:
        plan_data = plan.to_dict() or {}
        steps = plan_data.get('steps', [])
        step_id = args.get('stepId')
        new_status = args.get('status', 'completed')
        notes = args.get('notes', '')

        for step in steps:
            if step.get('id') == step_id:
                step['status'] = new_status
                if notes:
                    step['notes'] = notes
                break

        current_index = plan_data.get('currentStepIndex', 0)
        if new_status == 'completed' and current_index < len(steps) - 1:
            current_index += 1

        plans_ref.document(plan.id).update({
            'steps': steps,
            'currentStepIndex': current_index,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })

        logger.info(json.dumps({
            "event": "plan_step_updated",
            "ts": _now_iso(),
            "uid": uid,
            "planId": plan.id,
            "stepId": step_id,
            "status": new_status
        }, ensure_ascii=False))
        break


def get_all_character_summaries(uid: str) -> Dict[str, str]:
    summaries = {}
    try:
        memory_ref = db.collection('users').document(uid).collection('agent_memory')
        docs = memory_ref.stream()
        for doc in docs:
            data = doc.to_dict() or {}
            summary = data.get('summary', '')
            if summary and doc.id != 'guider':
                summaries[doc.id] = summary
    except Exception as e:
        logger.info(json.dumps({
            "event": "fetch_summaries_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))
    return summaries


def build_guider_context(uid: str) -> str:
    summaries = get_all_character_summaries(uid)
    if not summaries:
        return ""
    context_parts = []
    for character_id, summary in summaries.items():
        display_name = character_id.replace('_', ' ').title()
        context_parts.append(f"**{display_name}:**\n{summary}\n")
    return "\n".join(context_parts)


# ============================================================================
# GUIDER VIDEO CALL ENDPOINTS
# ============================================================================

@guider_video_bp.route('/start_session', methods=['POST'])
def start_video_session():
    """Start a video session and also start emotion tracking."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        user_name = data.get('userName', 'User')
        character_id = data.get('characterId')

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        _ensure_session_doc(uid, session_id, 'guider')
        if thread_id:
            _ensure_thread_doc(uid, thread_id, session_id)

        emotion_tracking = False
        try:
            requests.post(
                f"{EMOTION_DETECTOR_URL}/emotion/start_session",
                json={
                    "session_id": session_id,
                    "user_name": user_name,
                    "character_id": character_id
                },
                timeout=5
            )
            emotion_tracking = True
        except Exception as e:
            logger.info(json.dumps({
                "event": "emotion_start_failed",
                "ts": _now_iso(),
                "error": str(e)
            }, ensure_ascii=False))

        return jsonify({
            'success': True,
            'message': 'Video session started',
            'emotion_tracking': emotion_tracking,
            'emotion_server': EMOTION_DETECTOR_URL
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@guider_video_bp.route('/update_emotions', methods=['POST'])
def update_emotions():
    """Endpoint for Flutter to send emotion data from the emotion detector."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        face_emotion = data.get('faceEmotion')
        face_confidence = data.get('faceConfidence', 0.0)
        voice_emotion = data.get('voiceEmotion')
        voice_confidence = data.get('voiceConfidence', 0.0)

        if face_emotion:
            _update_face_emotion(uid, session_id, face_emotion, face_confidence)
        if voice_emotion:
            _update_voice_emotion(uid, session_id, voice_emotion, voice_confidence)

        return jsonify({'success': True})

    except Exception as e:
        logger.info(json.dumps({
            "event": "update_emotions_error",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))
        return jsonify({'success': False, 'error': str(e)}), 500


@guider_video_bp.route('/respond', methods=['POST'])
def guider_video_respond():
    """Guider video call endpoint - receives user message and returns Guider response."""
    t0 = time.time()
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({'success': False, 'error': 'uid is required'}), 400

        user_message = data.get('userMessage', '')
        character_id = data.get('characterId')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        conversation_history = data.get('conversationHistory', [])
        force_plan_creation = data.get('forcePlanCreation', False)

        if session_id:
            _ensure_session_doc(uid, session_id, 'guider')
        if thread_id:
            _ensure_thread_doc(uid, thread_id, session_id)

        if thread_id and user_message:
            _save_message(uid, thread_id, 'user', user_message, 'user')

        guider_memory = load_agent_memory_summary(uid, 'guider')
        character_context = build_guider_context(uid)

        if character_id:
            character_memory = load_agent_memory_summary(uid, character_id)
            if character_memory:
                character_context += f"\n\nRecent work with {character_id}:\n{character_memory[:300]}"

        system_prompt = GUIDER_SYSTEM_PROMPT
        if character_context:
            system_prompt += f"\n\n--- USER'S INNER PARTS CONTEXT ---\n{character_context}"
        if guider_memory:
            system_prompt += f"\n\n--- YOUR MEMORY OF THIS USER ---\n{guider_memory}"

        messages = []
        for msg in conversation_history:
            if msg.get('role') == 'user':
                messages.append({'role': 'user', 'content': msg.get('content', '')})
            elif msg.get('role') == 'assistant' and msg.get('sender') == 'guider':
                messages.append({'role': 'assistant', 'content': msg.get('content', '')})

        messages.append({'role': 'user', 'content': user_message})

        agent_result = run_guider_agent_step(system_prompt, messages)

        assistant_message = agent_result.get('assistantMessage', '')
        tool_calls = agent_result.get('toolCalls') or []
        updated_summary = agent_result.get('memorySummary', '')

        run_guider_tool_calls(uid, tool_calls)

        if force_plan_creation and not has_active_plan(uid):
            create_healing_plan(uid, {
                'title': f'Healing plan from video call',
                'targetCharacterId': character_id,
                'steps': [
                    'Notice emotional patterns as they arise',
                    'Practice grounding techniques when intensity rises',
                    'Connect with the inner part that needs attention',
                    'Track progress and celebrate small wins'
                ]
            })

        if thread_id and assistant_message:
            _save_message(uid, thread_id, 'assistant', assistant_message, 'guider')

        if not updated_summary:
            all_messages = conversation_history + [
                {'role': 'user', 'content': user_message},
                {'role': 'assistant', 'content': assistant_message, 'sender': 'guider'}
            ]
            updated_summary = generate_updated_summary(guider_memory, all_messages)
        save_agent_memory_summary(uid, 'guider', updated_summary)

        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                scored_msgs = []
                for msg in conversation_history:
                    if msg.get('content'):
                        scored_msgs.append({
                            "role": msg.get('role', 'user'),
                            "content": msg.get('content', '')
                        })
                scored_msgs.append({"role": "user", "content": user_message})
                if assistant_message:
                    scored_msgs.append({"role": "assistant", "content": assistant_message})

                score = score_intensity_with_llm('guider', scored_msgs)

                _write_session_intensity(uid, session_id, score, turn_for_update)

                if character_id:
                    plan_diff = _update_character_plan_from_score(
                        uid, character_id, score,
                        evidence=user_message[:200]
                    )

                    _log_agent_run(
                        _plan_runs_ref(uid, character_id),
                        {
                            "trigger": "video_call_update",
                            "inputs": {"sessionId": session_id, "characterId": character_id},
                            "outputs": {
                                "intensity": score["intensity"],
                                "focus": plan_diff.get("focus"),
                                "changedItems": plan_diff.get("changedItems"),
                            },
                            "rawModelOutput": score.get("_raw") or {},
                        },
                    )

                _log_agent_run(
                    _session_runs_ref(uid, session_id),
                    {
                        "trigger": "user_message",
                        "inputs": {"threadId": thread_id, "characterId": "guider"},
                        "outputs": {
                            "intensity": score["intensity"],
                            "blend": score.get("blend") is True,
                            "signals": score.get("signals") or [],
                        },
                        "rawModelOutput": score.get("_raw") or {},
                    },
                )
            except Exception as e:
                logger.info(json.dumps({
                    "event": "periodic_update_failed",
                    "ts": _now_iso(),
                    "error": str(e)
                }, ensure_ascii=False))

        if len(assistant_message.split('.')) > 4:
            sentences = assistant_message.split('.')
            assistant_message = '.'.join(sentences[:4]) + '.'

        return jsonify({
            'success': True,
            'guiderMessage': assistant_message,
            'toolCalls': tool_calls,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Guider video error: {str(e)}'}), 500
    finally:
        try:
            logger.info(json.dumps({
                "event": "request_timing",
                "route": "/guider/respond",
                "ts": _now_iso(),
                "ms": int((time.time() - t0) * 1000),
            }, ensure_ascii=False))
        except Exception:
            pass


@guider_video_bp.route('/session_summary', methods=['POST'])
def guider_video_session_summary():
    """Generate a summary of a video call session and save to timeline."""
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId')
        session_id = data.get('sessionId')
        duration = data.get('duration', 0)
        messages = data.get('messages', [])

        if not uid:
            return jsonify({'success': False, 'error': 'uid is required'}), 400

        try:
            requests.post(
                f"{EMOTION_DETECTOR_URL}/emotion/end_session",
                json={"session_id": session_id},
                timeout=5
            )
        except Exception as e:
            logger.info(json.dumps({
                "event": "emotion_end_failed",
                "ts": _now_iso(),
                "error": str(e)
            }, ensure_ascii=False))

        sref = _session_ref(uid, session_id) if session_id else None
        snap = sref.get() if sref else None
        existing = (snap.to_dict() or {}) if snap and snap.exists else {}

        intensity_score = score_intensity_with_llm('guider', messages)

        start_val = None
        if snap and snap.exists:
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

        user_messages = [m for m in messages if m.get('role') == 'user']

        if not user_messages:
            summary_text = "The session was brief. The Guider was present."
        else:
            user_texts = [m.get('content', '')[:100] for m in user_messages[-5:]]

            prompt = f"""
Summarize this IFS video call session in 2-3 short sentences.

Duration: {duration // 60000} minutes
User shared about: {', '.join(user_texts)}

Return a warm, brief summary that captures:
- The emotional themes
- Any key moments
- A gentle suggestion
"""

            response = openai_client.chat.completions.create(
                model=OPENAI_SUMMARY_MODEL,
                messages=[
                    {'role': 'system', 'content': 'You are a compassionate IFS guide. Return a short, warm summary.'},
                    {'role': 'user', 'content': prompt},
                ],
                temperature=0.5,
                max_tokens=120,
            )
            summary_text = response.choices[0].message.content.strip()

        session_summary = {
            "highlights": [summary_text[:200]],
            "duration": duration // 1000,
            "endedAt": firestore.SERVER_TIMESTAMP,
        }

        if session_id:
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
                "sessionSummary": session_summary,
                "endedAt": firestore.SERVER_TIMESTAMP,
                "status": "ended",
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "endedAnalyzedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            _log_agent_run(
                _session_runs_ref(uid, session_id),
                {
                    "trigger": "session_end",
                    "inputs": {"characterId": "guider"},
                    "outputs": {
                        "intensityEnd": intensity_score["intensity"],
                        "delta": delta,
                    },
                    "rawModelOutput": intensity_score.get("_raw") or {},
                },
            )

        title = "Video call with The Guider"
        if character_id:
            title = f"Video call about {character_id.replace('_', ' ').title()}"

        add_timeline_event(uid, {
            'type': 'video_session',
            'title': title,
            'summary': summary_text[:200],
        })

        final_face_emotion = existing.get('faceEmotion', {})
        final_voice_tone = existing.get('voiceTone', {})

        return jsonify({
            'success': True,
            'summary': summary_text,
            'intensityEnd': intensity_score["intensity"],
            'delta': delta,
            'faceEmotion': {
                'dominant': final_face_emotion.get('dominant'),
                'averageConfidence': final_face_emotion.get('averageConfidence', 0),
                'startEmotion': final_face_emotion.get('startEmotion'),
                'endEmotion': final_face_emotion.get('endEmotion'),
                'totalDetections': len(final_face_emotion.get('allDetections', []))
            },
            'voiceTone': {
                'dominant': final_voice_tone.get('dominant'),
                'averageConfidence': final_voice_tone.get('averageConfidence', 0),
                'startEmotion': final_voice_tone.get('startEmotion'),
                'endEmotion': final_voice_tone.get('endEmotion'),
                'totalDetections': len(final_voice_tone.get('allDetections', []))
            }
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Summary error: {str(e)}'}), 500


@guider_video_bp.route('/health', methods=['GET'])
def health():
    emotion_detector_ok = False
    try:
        resp = requests.get(f"{EMOTION_DETECTOR_URL}/emotion/health", timeout=2)
        emotion_detector_ok = resp.status_code == 200
    except:
        pass

    return jsonify({
        "success": True,
        "message": "Guider Video server is running",
        "openai_ready": bool(os.getenv("OPENAI_API_KEY")),
        "firebase_ready": db is not None,
        "emotion_detector_connected": emotion_detector_ok,
        "emotion_detector_url": EMOTION_DETECTOR_URL,
        "endpoints": [
            "/guider/start_session",
            "/guider/update_emotions",
            "/guider/respond",
            "/guider/session_summary",
            "/guider/health"
        ]
    })


# For direct execution
if __name__ == '__main__':
    app = Flask(__name__)
    CORS(app)
    app.register_blueprint(guider_video_bp)
    app.run(host='0.0.0.0', port=5004, debug=True)