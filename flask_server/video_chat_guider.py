from flask import Flask, request, jsonify, Blueprint
from flask_cors import CORS
import os
import json
import logging
from datetime import datetime, timezone
import time
from typing import Dict, List, Any, Optional
import traceback
import requests
from concurrent.futures import ThreadPoolExecutor

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI
from video_transcript_store import append_video_message_encrypted, get_video_messages_decrypted

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Emotion detector server URL
EMOTION_DETECTOR_URL = os.getenv('EMOTION_DETECTOR_URL', 'http://localhost:5002')

# -----------------------------------------------------------------------------
# Configuration (matching agents.py)
# -----------------------------------------------------------------------------
MEMORY_PROMPT_MAX_CHARS = max(200, int(os.getenv("MEMORY_PROMPT_MAX_CHARS", "1800")))
CHAT_REPLY_MAX_TOKENS = max(80, int(os.getenv("CHAT_REPLY_MAX_TOKENS", "120")))
AGENT_JSON_RESPONSE_MODE = str(os.getenv("AGENT_JSON_RESPONSE_MODE", "false")).strip().lower() in {"1", "true", "yes", "on"}
FAST_MODE_DETERMINISTIC_WRITES = str(os.getenv("FAST_MODE_DETERMINISTIC_WRITES", "true")).strip().lower() in {"1", "true", "yes", "on"}
FAST_MODE_PROGRESS_INTERVAL_SEC = max(30, int(os.getenv("FAST_MODE_PROGRESS_INTERVAL_SEC", "90")))
FAST_MODE_TIMELINE_INTERVAL_SEC = max(60, int(os.getenv("FAST_MODE_TIMELINE_INTERVAL_SEC", "300")))

_BACKGROUND_WORKERS = max(2, int(os.getenv("AGENT_BACKGROUND_WORKERS", "6")))
_background_executor = ThreadPoolExecutor(max_workers=_BACKGROUND_WORKERS)

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
# Helper Functions (matching agents.py)
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


def _clip_text(value: Any, max_chars: int) -> str:
    text = str(value or "")
    if max_chars > 0 and len(text) > max_chars:
        return text[:max_chars].rstrip() + " ..."
    return text


def _prepare_model_messages(
    messages: List[Dict[str, str]],
    max_messages: int = 6,
    max_chars_per_message: int = 280,
) -> List[Dict[str, str]]:
    tail = messages[-max_messages:] if len(messages) > max_messages else messages
    prepared: List[Dict[str, str]] = []
    for message in tail:
        role = message.get("role")
        content = message.get("content", "")
        if role in ["user", "assistant"] and content:
            prepared.append(
                {
                    "role": role,
                    "content": _clip_text(content, max_chars_per_message),
                }
            )
    return prepared


def _messages_payload_stats(messages: List[Dict[str, str]]) -> Dict[str, int]:
    chars = 0
    for message in messages:
        chars += len(str(message.get("content", "")))
    return {
        "count": len(messages),
        "chars": chars,
    }


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


def _run_background(task_name: str, fn, *args, **kwargs) -> None:
    try:
        fn(*args, **kwargs)
    except Exception as e:
        logger.info(
            json.dumps(
                {
                    "event": "background_task_failed",
                    "task": task_name,
                    "ts": _now_iso(),
                    "error": str(e),
                },
                ensure_ascii=False,
            )
        )


def _submit_background(task_name: str, fn, *args, **kwargs) -> None:
    _background_executor.submit(_run_background, task_name, fn, *args, **kwargs)


# ============================================================================
# Character Checklist Templates (matching agents.py)
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
    """Ensures a per-character plan doc exists - matching agents.py."""
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


def _get_character_plan_snapshot(uid: str, character_id: str) -> Dict[str, Any]:
    """Returns a compact snapshot of the per-character checklist + focus - matching agents.py."""
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


# ============================================================================
# Session Management
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
        else:
            # Update existing sessions to ensure fields exist
            sref.set({
                "characterType": "guider",
                "type": "video",
            }, merge=True)
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


def _save_message_encrypted(uid: str, thread_id: str, role: str, content: str,
                            session_id: str = None, sender: str = None, character_id: str = None) -> None:
    """Save an encrypted message to Firestore."""
    if not thread_id:
        return
    if not content or content.strip() == '':
        return
    try:
        result = append_video_message_encrypted(
            uid=uid,
            thread_id=thread_id,
            role=role,
            content=content,
            session_id=session_id,
            sender=sender,
            character_id=character_id,
        )
    except Exception as e:
        logger.info(json.dumps({
            "event": "save_message_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


# ============================================================================
# Emotion Tracking (Video-specific)
# ============================================================================

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

    except Exception as e:
        logger.info(json.dumps({
            "event": "voice_emotion_update_failed",
            "ts": _now_iso(),
            "error": str(e)
        }, ensure_ascii=False))


# ============================================================================
# Intensity Scoring (matching agents.py)
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


# ============================================================================
# Memory Functions (matching agents.py)
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


def _persist_agent_memory_summary(
    uid: str,
    character_id: str,
    candidate_summary: str,
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> None:
    if isinstance(candidate_summary, str):
        summary = candidate_summary.strip()
    elif isinstance(candidate_summary, list):
        summary = "\n".join(str(item).strip() for item in candidate_summary if str(item).strip())
    elif isinstance(candidate_summary, dict):
        summary = json.dumps(candidate_summary, ensure_ascii=False)
    else:
        summary = str(candidate_summary or "").strip()
    if not summary:
        summary = (generate_updated_summary(existing_summary, messages) or "").strip()
    if summary:
        save_agent_memory_summary(uid, character_id, summary)


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
# Guider Agent (matching agents.py pattern)
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

Example good response: "It sounds like your Workaholic has been very active lately. What does it feel like when that part takes over?"

Example bad response: "Your Workaholic is significant because... [long explanation with 4 numbered points]"
""".strip()


def run_guider_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    llm_started_at = time.time()
    if AGENT_JSON_RESPONSE_MODE:
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
    else:
        agent_messages = [
            {'role': 'system', 'content': _clip_text(system_prompt, 1200)},
            {'role': 'system', 'content': (
                'Reply naturally and briefly in-character (2-4 sentences max). '
                'Do not output JSON, labels, or metadata.'
            )},
        ]
    agent_messages.extend(_prepare_model_messages(messages))
    payload_stats = _messages_payload_stats(agent_messages)

    if AGENT_JSON_RESPONSE_MODE:
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=agent_messages,
            temperature=0.7,
            response_format={"type": "json_object"},
            max_tokens=CHAT_REPLY_MAX_TOKENS,
        )
    else:
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=agent_messages,
            temperature=0.7,
            max_tokens=CHAT_REPLY_MAX_TOKENS,
        )
    llm_ms = int((time.time() - llm_started_at) * 1000)

    raw = response.choices[0].message.content or '{}'
    if AGENT_JSON_RESPONSE_MODE:
        try:
            parsed = json.loads(raw)
            if not isinstance(parsed, dict):
                parsed = {'assistantMessage': '', 'toolCalls': [], 'memorySummary': ''}
        except Exception:
            parsed = {'assistantMessage': '', 'toolCalls': [], 'memorySummary': ''}
    else:
        parsed = {
            "assistantMessage": raw.strip(),
            "toolCalls": [],
            "memorySummary": "",
        }
    parsed["_meta"] = {
        "llmMs": llm_ms,
        "payloadMessages": payload_stats["count"],
        "payloadChars": payload_stats["chars"],
    }
    return parsed


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

        if name == 'update_progress_summary':
            update_progress_summary(uid, args)
        elif name == 'add_timeline_event':
            add_timeline_event(uid, args)
        elif name == 'set_last_agent_run':
            set_last_agent_run(uid)


# ============================================================================
# GUIDER VIDEO CALL ENDPOINTS
# ============================================================================

@guider_video_bp.route('/start_session', methods=['POST'])
def start_video_session():
    """Start a video session with proper thread_id for encryption"""
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        user_name = data.get('userName', 'User')
        character_id = data.get('characterId')

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        # Ensure guider character plan exists
        try:
            ensure_character_checklist(uid, 'guider')
            logger.info(json.dumps({
                "event": "guider_character_plan_ensured",
                "ts": _now_iso(),
                "uid": uid,
                "characterId": "guider"
            }, ensure_ascii=False))
        except Exception as e:
            logger.info(json.dumps({
                "event": "guider_character_plan_failed",
                "ts": _now_iso(),
                "error": str(e)
            }, ensure_ascii=False))

        # Create session document with thread_id
        _ensure_session_doc(uid, session_id, 'guider')

        if thread_id:
            _ensure_thread_doc(uid, thread_id, session_id)
            _session_ref(uid, session_id).set({
                'threadId': thread_id
            }, merge=True)

        # Start emotion tracking
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
    context_ms = 0
    llm_ms = 0
    payload_messages = 0
    payload_chars = 0

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

        # Ensure guider character plan exists
        ensure_character_checklist(uid, 'guider')

        if session_id:
            _ensure_session_doc(uid, session_id, 'guider')
        if thread_id:
            _ensure_thread_doc(uid, thread_id, session_id)

        # Save user message with encryption
        if thread_id and user_message:
            _save_message_encrypted(uid, thread_id, 'user', user_message, session_id, 'user', 'guider')

        # Load Guider memory and character context
        guider_memory = load_agent_memory_summary(uid, 'guider')
        character_context = build_guider_context(uid)

        if character_id:
            character_memory = load_agent_memory_summary(uid, character_id)
            if character_memory:
                character_context += f"\n\nRecent work with {character_id}:\n{character_memory[:300]}"

        # Build system prompt
        system_prompt = GUIDER_SYSTEM_PROMPT
        if character_context:
            system_prompt += f"\n\n--- USER'S INNER PARTS CONTEXT ---\n{character_context}"
        if guider_memory:
            system_prompt += f"\n\n--- YOUR MEMORY OF THIS USER ---\n{guider_memory}"

        context_ms = int((time.time() - t0) * 1000)

        # Build messages for AI
        messages = []
        for msg in conversation_history:
            if msg.get('role') == 'user':
                messages.append({'role': 'user', 'content': msg.get('content', '')})
            elif msg.get('role') == 'assistant' and msg.get('sender') == 'guider':
                messages.append({'role': 'assistant', 'content': msg.get('content', '')})

        messages.append({'role': 'user', 'content': user_message})

        # Get Guider response
        agent_result = run_guider_agent_step(system_prompt, messages)
        llm_meta = (agent_result.get("_meta") or {}) if isinstance(agent_result, dict) else {}
        llm_ms = int(llm_meta.get("llmMs") or 0)
        payload_messages = int(llm_meta.get("payloadMessages") or 0)
        payload_chars = int(llm_meta.get("payloadChars") or 0)
        if isinstance(agent_result, dict):
            agent_result.pop("_meta", None)

        assistant_message = agent_result.get('assistantMessage', '')
        tool_calls = agent_result.get('toolCalls') or []
        updated_summary = agent_result.get('memorySummary', '')

        # Run tool calls
        if tool_calls:
            _submit_background("run_tool_calls_video", run_guider_tool_calls, uid, tool_calls)

        # Save assistant message with encryption
        if thread_id and assistant_message:
            _save_message_encrypted(uid, thread_id, 'assistant', assistant_message, session_id, 'guider', 'guider')

        # Update memory summary in background
        all_messages = conversation_history + [
            {'role': 'user', 'content': user_message},
            {'role': 'assistant', 'content': assistant_message, 'sender': 'guider'}
        ]

        _submit_background(
            "persist_guider_memory_video",
            _persist_agent_memory_summary,
            uid,
            'guider',
            updated_summary,
            guider_memory,
            all_messages,
        )

        # Periodic updates
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
            logger.info(
                json.dumps(
                    {
                        "event": "request_timing",
                        "route": "/guider/respond",
                        "ts": _now_iso(),
                        "ms": int((time.time() - t0) * 1000),
                        "contextMs": context_ms,
                        "llmMs": llm_ms,
                        "payloadMessages": payload_messages,
                        "payloadChars": payload_chars,
                    },
                    ensure_ascii=False,
                )
            )
        except Exception:
            pass


@guider_video_bp.route('/get_messages', methods=['POST'])
def get_guider_messages():
    """Get decrypted messages for a Guider video session."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')
        limit = data.get('limit', 100)

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        snap = _session_ref(uid, session_id).get()
        if not snap.exists:
            return jsonify({'success': False, 'error': 'Session not found'}), 404

        session_data = snap.to_dict() or {}
        thread_id = session_data.get('threadId')

        if not thread_id:
            return jsonify({'success': False, 'error': 'No threadId found for session'}), 404

        messages = get_video_messages_decrypted(uid=uid, thread_id=thread_id, limit=limit)

        return jsonify({
            'success': True,
            'messages': messages,
            'sessionId': session_id,
            'threadId': thread_id,
            'messageCount': len(messages),
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


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


@guider_video_bp.route('/decrypt_message', methods=['POST'])
def decrypt_message():
    """Decrypt a single message"""
    try:
        data = request.json or {}
        uid = data.get('uid')
        message_data = data.get('messageData', {})

        if not uid or not message_data:
            return jsonify({'success': False, 'error': 'uid and messageData required'}), 400

        from video_crypto import decrypt_video_message
        content = decrypt_video_message(uid, message_data)

        return jsonify({
            'success': True,
            'content': content,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


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


@guider_video_bp.route('/migrate_sessions', methods=['POST'])
def migrate_sessions():
    """Migrate old sessions to have proper characterType field."""
    try:
        data = request.json or {}
        uid = data.get('uid')

        if not uid:
            return jsonify({'success': False, 'error': 'uid required'}), 400

        sessions_ref = db.collection('users').document(uid).collection('sessions')
        sessions = sessions_ref.where('type', '==', 'video').stream()

        updated_count = 0
        for session in sessions:
            session_data = session.to_dict() or {}
            if session_data.get('characterType') != 'guider':
                session.reference.update({
                    'characterType': 'guider',
                    'updatedAt': firestore.SERVER_TIMESTAMP
                })
                updated_count += 1

        return jsonify({
            'success': True,
            'updated_count': updated_count,
            'message': f'Migrated {updated_count} sessions'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# For direct execution
if __name__ == '__main__':
    app = Flask(__name__)
    CORS(app)
    app.register_blueprint(guider_video_bp)
    app.run(host='0.0.0.0', port=5004, debug=True)