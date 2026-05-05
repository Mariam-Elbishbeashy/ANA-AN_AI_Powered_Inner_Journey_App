from flask import Flask, request, jsonify
from flask_cors import CORS
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
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
CHAT_CONTEXT_MAX_MESSAGES = max(4, int(os.getenv("CHAT_CONTEXT_MAX_MESSAGES", "6")))
CHAT_CONTEXT_MAX_CHARS_PER_MESSAGE = max(120, int(os.getenv("CHAT_CONTEXT_MAX_CHARS_PER_MESSAGE", "280")))
MEMORY_PROMPT_MAX_CHARS = max(200, int(os.getenv("MEMORY_PROMPT_MAX_CHARS", "1800")))
CHAT_REPLY_MAX_TOKENS = max(80, int(os.getenv("CHAT_REPLY_MAX_TOKENS", "120")))
MEMORY_CACHE_TTL_SEC = max(1, int(os.getenv("MEMORY_CACHE_TTL_SEC", "30")))
PLAN_FOCUS_CACHE_TTL_SEC = max(1, int(os.getenv("PLAN_FOCUS_CACHE_TTL_SEC", "20")))
AGENT_JSON_RESPONSE_MODE = str(os.getenv("AGENT_JSON_RESPONSE_MODE", "false")).strip().lower() in {"1", "true", "yes", "on"}
FAST_MODE_DETERMINISTIC_WRITES = str(os.getenv("FAST_MODE_DETERMINISTIC_WRITES", "true")).strip().lower() in {"1", "true", "yes", "on"}
FAST_MODE_PROGRESS_INTERVAL_SEC = max(30, int(os.getenv("FAST_MODE_PROGRESS_INTERVAL_SEC", "90")))
FAST_MODE_TIMELINE_INTERVAL_SEC = max(60, int(os.getenv("FAST_MODE_TIMELINE_INTERVAL_SEC", "300")))

_memory_cache_lock = Lock()
_memory_summary_cache: Dict[str, Dict[str, Any]] = {}
_plan_focus_cache: Dict[str, Dict[str, Any]] = {}
_write_throttle_lock = Lock()
_last_progress_update_ts: Dict[str, float] = {}
_last_timeline_event_ts: Dict[str, float] = {}

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

_BACKGROUND_WORKERS = max(2, int(os.getenv("AGENT_BACKGROUND_WORKERS", "6")))
_background_executor = ThreadPoolExecutor(max_workers=_BACKGROUND_WORKERS)


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


def _fallback_intervention_message(reason: str, suggested: str = "") -> str:
    if suggested:
        return suggested
    fallbacks = {
        "crisis_detected": "I sense this feels very heavy right now. The Guider is here to offer a calmer, steady space whenever you want it.",
        "emotional_intensity": "It sounds like a lot is moving inside. The Guider is available if you want a gentler moment to pause and process.",
        "stuck_loop": "You may be carrying this in circles. The Guider can help you widen the view when you are ready.",
        "session_length": "You have done deep work in this session. The Guider is here if you want to reflect and settle what came up.",
    }
    return fallbacks.get(reason, "The Guider is here whenever you want a gentle space to reflect.")


def _clip_text(value: Any, max_chars: int) -> str:
    text = str(value or "")
    if max_chars > 0 and len(text) > max_chars:
        return text[:max_chars].rstrip() + " ..."
    return text


def _prepare_model_messages(
    messages: List[Dict[str, str]],
    max_messages: int = CHAT_CONTEXT_MAX_MESSAGES,
    max_chars_per_message: int = CHAT_CONTEXT_MAX_CHARS_PER_MESSAGE,
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
    # for terminal logs (firestore uses SERVER_TIMESTAMP for writes).
    return datetime.now(timezone.utc).isoformat()


def _now_dt():
    """
    firestore doesn't allow SERVER_TIMESTAMP inside array elements.
    the checklistItems is an array of maps, so per-item timestamps must be real
    datetime values
    """
    return datetime.now(timezone.utc)


def _json_default(obj):
    """
    make firestore/python datetime-like objects JSON-serializable.
    used only for embedding context into prompts/logs
    """
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


_SEVERITY_RANK = {"none": 0, "low": 1, "medium": 2, "high": 3}
_CORE_TRACKED_CHECKLIST_ITEMS = {"stabilization", "unblending", "triggers_fears"}


def _normalize_character_key(value: Any) -> str:
    return str(value or "").strip().lower().replace(" ", "_")


def _get_session_time_key(session: Dict[str, Any]) -> str:
    return str(
        session.get("endedAt")
        or session.get("updatedAt")
        or session.get("startedAt")
        or ""
    )


def _extract_session_intensity_end(session: Dict[str, Any]) -> Optional[float]:
    try:
        intensity = session.get("intensity") or {}
        val = intensity.get("end")
        if val is None:
            return None
        return float(val)
    except Exception:
        return None


def _extract_session_intensity_delta(session: Dict[str, Any]) -> Optional[float]:
    try:
        intensity = session.get("intensity") or {}
        val = intensity.get("delta")
        if val is None:
            return None
        return float(val)
    except Exception:
        return None


def _extract_session_intervention_severity(session: Dict[str, Any]) -> str:
    # canonical location (new): session.intervention.maxSeverity
    intervention = session.get("intervention") or {}
    sev = str(intervention.get("maxSeverity") or intervention.get("lastSeverity") or "").strip().lower()
    if sev in _SEVERITY_RANK:
        return sev

    # legacy fallback: some payloads may store intervention directly
    sev = str(session.get("severity") or "").strip().lower()
    if sev in _SEVERITY_RANK:
        return sev

    return "none"


def _plan_completion_ratio(plan_snapshot: Dict[str, Any]) -> float:
    items = plan_snapshot.get("checklistItems") or []
    if not items:
        return 0.0
    # Stability uses only the checklist items that are actively auto-updated by
    # backend policy, so the threshold can be reached without manual edits.
    scoped = [it for it in items if str(it.get("id") or "").strip() in _CORE_TRACKED_CHECKLIST_ITEMS]
    target_items = scoped if scoped else items
    completed = sum(
        1 for it in target_items if str(it.get("status") or "").strip().lower() == "completed"
    )
    return completed / max(1, len(target_items))


def _find_user_character_doc(uid: str, character_id: str):
    target = _normalize_character_key(character_id)
    try:
        chars_ref = db.collection("user_characters").where("userId", "==", uid)
        for doc in chars_ref.stream():
            data = doc.to_dict() or {}
            candidates = {
                _normalize_character_key(doc.id),
                _normalize_character_key(data.get("id")),
                _normalize_character_key(data.get("characterId")),
                _normalize_character_key(data.get("innerCharacterId")),
                _normalize_character_key(data.get("characterName")),
                _normalize_character_key(data.get("displayName")),
                _normalize_character_key(data.get("displayNameEn")),
            }
            if target in candidates:
                return doc.reference, data
    except Exception:
        pass
    return None, None


def _record_session_intervention(uid: str, session_id: str, reason: str, severity: str) -> None:
    """
    keeps intervention severity into the session doc so stabilization rules can
    evaluate recent ended sessions
    """
    sev = str(severity or "low").strip().lower()
    if sev not in _SEVERITY_RANK:
        sev = "low"

    sref = _session_ref(uid, session_id)
    prev_max = "none"
    try:
        snap = sref.get()
        if snap.exists:
            d = snap.to_dict() or {}
            prev_max = _extract_session_intervention_severity(d)
    except Exception:
        prev_max = "none"

    max_sev = sev if _SEVERITY_RANK[sev] >= _SEVERITY_RANK.get(prev_max, 0) else prev_max
    sref.set(
        {
            "intervention": {
                "count": firestore.Increment(1),
                "lastSeverity": sev,
                "maxSeverity": max_sev,
                "lastReason": str(reason or ""),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def _evaluate_character_stability(uid: str, character_id: str) -> Dict[str, Any]:
    """
    stability rules (thresholds):
      - minEndedSessions >= 5
      - totalUserTurns >= 20
      - last 3 ended sessions: intensity.end <= 0.35 for all 3
      - no high/medium intervention in last 3 ended sessions
      - plan completion >= 70%
      - focus.itemId != stabilization
    """
    try:
        snaps = _sessions_ref(uid).where("characterId", "==", character_id).limit(200).stream()
        ended_sessions: List[Dict[str, Any]] = []
        for s in snaps:
            d = s.to_dict() or {}
            if str(d.get("status") or "").strip().lower() == "ended":
                ended_sessions.append({**d, "_id": s.id})

        ended_sessions.sort(key=_get_session_time_key, reverse=True)
        min_ended_ok = len(ended_sessions) >= 5
        total_user_turns = sum(int(s.get("userTurnCount") or 0) for s in ended_sessions)
        turns_ok = total_user_turns >= 20

        last3 = ended_sessions[:3]
        low_end_ok = (
            len(last3) == 3
            and all((_extract_session_intensity_end(s) is not None and _extract_session_intensity_end(s) <= 0.35) for s in last3)
        )
        no_mid_high_intervention_ok = (
            len(last3) == 3
            and all(_extract_session_intervention_severity(s) not in {"medium", "high"} for s in last3)
        )

        plan_snapshot = _get_character_plan_snapshot(uid, character_id)
        completion_ratio = _plan_completion_ratio(plan_snapshot)
        plan_completion_ok = completion_ratio >= 0.70
        focus_item = str((plan_snapshot.get("focus") or {}).get("itemId") or "").strip().lower()
        focus_ok = focus_item != "stabilization"

        is_stable = all(
            [
                min_ended_ok,
                turns_ok,
                low_end_ok,
                no_mid_high_intervention_ok,
                plan_completion_ok,
                focus_ok,
            ]
        )
        return {
            "isStable": is_stable,
            "checks": {
                "minEndedSessions": min_ended_ok,
                "totalUserTurns": turns_ok,
                "last3IntensityEnd": low_end_ok,
                "last3NoMidHighIntervention": no_mid_high_intervention_ok,
                "planCompletion": plan_completion_ok,
                "focusNotStabilization": focus_ok,
            },
            "metrics": {
                "endedSessionsCount": len(ended_sessions),
                "totalUserTurns": total_user_turns,
                "planCompletionRatio": round(completion_ratio, 3),
                "focusItemId": focus_item or None,
            },
        }
    except Exception as e:
        return {
            "isStable": False,
            "checks": {},
            "metrics": {},
            "error": str(e),
        }


def _apply_stable_state_if_eligible(uid: str, character_id: str) -> Dict[str, Any]:
    """
    evaluate requested stability thresholds and set user_character.currentState to
    'stable' if all checks pass
    """
    evaluation = _evaluate_character_stability(uid, character_id)
    if not evaluation.get("isStable"):
        return {"changed": False, "evaluation": evaluation}

    ref, data = _find_user_character_doc(uid, character_id)
    if ref is None:
        return {"changed": False, "evaluation": evaluation, "error": "user_character_not_found"}

    current_state = str((data or {}).get("currentState") or "active").strip().lower()
    if current_state == "inactive":
        # keeping inactive semantics (separate from stability progression)
        return {"changed": False, "evaluation": evaluation, "reason": "character_inactive"}

    if current_state == "stable":
        return {"changed": False, "evaluation": evaluation, "reason": "already_stable"}

    now_iso = _now_dt().isoformat()
    ref.set(
        {
            "previousState": current_state or "active",
            "currentState": "stable",
            "stableAt": now_iso,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return {"changed": True, "evaluation": evaluation}


#build a system prompt for the inner character
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


#build a system prompt for the inner character with memory
def build_system_prompt_with_memory(
    character_profile: Dict,
    memory_summary: str,
    plan_focus_hint: str = "",
) -> str:
    base_prompt = build_inner_character_prompt(character_profile)
    clipped_summary = _clip_text(memory_summary, MEMORY_PROMPT_MAX_CHARS)
    if not clipped_summary and not plan_focus_hint:
        return base_prompt

    extras: List[str] = []
    if clipped_summary:
        extras.append(
            f"""Memory summary (use only if relevant):
{clipped_summary}"""
        ) # feeding it a hint of the plan focus item
    if plan_focus_hint:
        extras.append(
            f"""Current therapeutic focus (internal hint; do not mention checklist mechanics):
{plan_focus_hint}"""
        )

    return f"""{base_prompt}

{chr(10).join(extras)}
""".strip()


#load the memory summary for the inner character
def load_agent_memory_summary(uid: str, character_id: str) -> str:
    cache_key = f"{uid}:{character_id}"
    now = time.time()
    with _memory_cache_lock:
        cached = _memory_summary_cache.get(cache_key)
        if cached:
            summary = str(cached.get("summary", ""))
            is_stale = (now - float(cached.get("ts", 0))) > MEMORY_CACHE_TTL_SEC
            is_refreshing = cached.get("refreshing") is True
            if is_stale and not is_refreshing:
                cached["refreshing"] = True
                _submit_background("refresh_memory_summary_cache", _refresh_memory_summary_cache, uid, character_id)
            return summary

        # cold start: return quickly and fetch in background
        _memory_summary_cache[cache_key] = {"summary": "", "ts": 0, "refreshing": True}
    _submit_background("refresh_memory_summary_cache", _refresh_memory_summary_cache, uid, character_id)
    return ""


#save the memory summary for the inner character
def save_agent_memory_summary(uid: str, character_id: str, summary: str) -> None:
    cache_key = f"{uid}:{character_id}"
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    doc_ref.set({
        'summary': summary,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)
    with _memory_cache_lock:
        _memory_summary_cache[cache_key] = {"summary": summary, "ts": time.time(), "refreshing": False}


def _refresh_memory_summary_cache(uid: str, character_id: str) -> None:
    cache_key = f"{uid}:{character_id}"
    summary = ""
    try:
        doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
        snapshot = doc_ref.get()
        if snapshot.exists:
            data = snapshot.to_dict() or {}
            summary = data.get('summary', '') or ''
    finally:
        with _memory_cache_lock:
            _memory_summary_cache[cache_key] = {"summary": summary, "ts": time.time(), "refreshing": False}


def _get_plan_focus_hint(uid: str, character_id: str) -> str:
    cache_key = f"{uid}:{character_id}"
    now = time.time()
    with _memory_cache_lock:
        cached = _plan_focus_cache.get(cache_key)
        if cached:
            hint = str(cached.get("hint", ""))
            is_stale = (now - float(cached.get("ts", 0))) > PLAN_FOCUS_CACHE_TTL_SEC
            is_refreshing = cached.get("refreshing") is True
            if is_stale and not is_refreshing:
                cached["refreshing"] = True
                _submit_background("refresh_plan_focus_cache", _refresh_plan_focus_cache, uid, character_id)
            return hint

        _plan_focus_cache[cache_key] = {"hint": "", "ts": 0, "refreshing": True}
    _submit_background("refresh_plan_focus_cache", _refresh_plan_focus_cache, uid, character_id)
    return ""


def _refresh_plan_focus_cache(uid: str, character_id: str) -> None:
    cache_key = f"{uid}:{character_id}"
    hint = ""
    try:
        snap = _character_plan_ref(uid, character_id).get()
        if snap.exists:
            focus = (snap.to_dict() or {}).get("focus") or {}
            focus_item = focus.get("itemId")
            focus_reason = focus.get("reason")
            if focus_item:
                hint = (
                    f"Prioritize '{focus_item}' right now"
                    + (f" ({focus_reason})" if focus_reason else "")
                    + ". Keep this subtle, natural, and in-character."
                )
        else:
            _submit_background("ensure_character_checklist", ensure_character_checklist, uid, character_id)
    except Exception:
        hint = ""
    finally:
        with _memory_cache_lock:
            _plan_focus_cache[cache_key] = {"hint": hint, "ts": time.time(), "refreshing": False}


# -----------------------------------------------------------------------------
# Per-character checklist templates (fully custom per characterId)
# -----------------------------------------------------------------------------
# each characterId can override the list entirely
CHARACTER_CHECKLIST_TEMPLATES: Dict[str, List[Dict[str, str]]] = {
    # IDs used by the app/backend.
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
# Intensity scoring
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
    builds a compact text blob for scoring:
    - prioritizing user messages
    - including last few assistant lines for context
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
    deterministic signal extractor for emotional intensity and blending
    used as a backbone and LLM fallback
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

    # English + Arabic emotional markers
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
        "انا فاشل", "انا سيء", "انا مكسور", "انا المشكلة", "دا انا",
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

    # surface form cues
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

    # simple deterministic score
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
    returns structured JSON:
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

    # harden LLM output
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

    # deterministic fusion
    if llm_intensity is None:
        final_intensity = float(rule_score["intensity"])
        source = "rules_only_fallback"
    else:
        # weighted fusion (semantic signal + reproducible rule backbone).
        final_intensity = 0.65 * llm_intensity + 0.35 * float(rule_score["intensity"])
        final_intensity = max(0.0, min(1.0, final_intensity))
        source = "hybrid_fusion"

    # blend decision: trust explicit LLM blend unless rules strongly indicate blending
    final_blend = bool(llm_blend or rule_score.get("blend") is True)
    if llm_intensity is None:
        final_blend = bool(rule_score.get("blend") is True)

    # merge and dedupe signals
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

    # normalize float precision
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
    end-of-session summarizer
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
    rules to update checklist item statuses
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

    by_id = {str(it.get("id") or "").strip(): it for it in items}

    # Rules
    if intensity >= 0.75:
        set_item("stabilization", "needs_work", 0.7)
    if blend:
        set_item("unblending", "needs_work", 0.7)
    if intensity < 0.55 and not blend:
        # gentle signal that user can probably explore triggers/fears
        set_item("triggers_fears", "in_progress", 0.6)

    # completion promotion rules:
    # - keep deterministic/simple
    # - only promote when the immediate score suggests steadier regulation
    # - never promote while blended
    if not blend and intensity <= 0.45:
        set_item("unblending", "completed", 0.85)
    if intensity <= 0.35:
        set_item("stabilization", "completed", 0.85)

    triggers_item = by_id.get("triggers_fears") or {}
    if (
        not blend
        and intensity <= 0.50
        and str(triggers_item.get("status") or "").strip().lower() == "in_progress"
        and float(triggers_item.get("confidence") or 0.0) >= 0.6
    ):
        set_item("triggers_fears", "completed", 0.8)

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
    """writes an agent run doc"""
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

    - return the current user turn (int) if a periodic update should run and holding
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

        # only allow one periodic update per turn, everrr
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
        # if the guard fails, skip
        return 0


def _write_session_intensity(uid: str, session_id: str, score: Dict[str, Any], turn: int) -> None:
    """
    persist intensity signals to the session document
    - set intensity.start once (first time ever writing intensity)
    - update intensity.latest each time periodic updates runs
    """
    try:
        sref = _session_ref(uid, session_id)

        # use a transaction to ensure "start" is set only once, even when (decorator)
        # overlapping requests happen
        transaction = db.transaction()

        # runs as one atomic read-> decide->write block
        # if another request updates this doc mid-process, firestore retries
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



            if snap.exists:
                txn.update(sref, updates)
            else:
                txn.set(sref, updates, merge=True)

        _txn(transaction)
    except Exception as e:
        logger.info(json.dumps({"event": "session_intensity_write_failed", "ts": _now_iso(), "uid": uid, "sessionId": session_id, "error": str(e)}, ensure_ascii=False))



#update the progress summary for the inner character
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


#adding a timeline event for the inner character
def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })


#setting the last agent run for the inner character
def set_last_agent_run(uid: str) -> None:
    db.collection('users').document(uid).set({
        'lastAgentRunAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


#running an agent step for the inner character
def run_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
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
        agent_messages.extend(_prepare_model_messages(messages))
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


#run tool calls for the inner character
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


def _should_throttle(map_obj: Dict[str, float], key: str, interval_sec: int) -> bool:
    now = time.time()
    with _write_throttle_lock:
        last = float(map_obj.get(key, 0.0))
        if now - last < interval_sec:
            return True
        map_obj[key] = now
        return False


def _deterministic_fast_mode_writes(
    uid: str,
    character_id: str,
    session_id: Optional[str],
    thread_id: Optional[str],
    assistant_message: str,
    user_message: str,
) -> None:
    if not FAST_MODE_DETERMINISTIC_WRITES:
        return
    try:
        set_last_agent_run(uid)
    except Exception as e:
        logger.info(json.dumps({"event": "fast_mode_last_agent_run_failed", "ts": _now_iso(), "uid": uid, "error": str(e)}, ensure_ascii=False))

    if user_message and not _should_throttle(_last_progress_update_ts, uid, FAST_MODE_PROGRESS_INTERVAL_SEC):
        try:
            update_progress_summary(
                uid,
                {
                    "lastSessionAt": _now_iso(),
                    "notes": _clip_text(f"user={user_message} | agent={assistant_message}", 420),
                },
            )
        except Exception as e:
            logger.info(json.dumps({"event": "fast_mode_progress_update_failed", "ts": _now_iso(), "uid": uid, "error": str(e)}, ensure_ascii=False))

    if assistant_message and not _should_throttle(_last_timeline_event_ts, uid, FAST_MODE_TIMELINE_INTERVAL_SEC):
        try:
            add_timeline_event(
                uid,
                {
                    "type": "agent_reply",
                    "title": f"{character_id} response",
                    "summary": _clip_text(assistant_message, 220),
                    "refPath": f"sessions/{session_id}" if session_id else (f"threads/{thread_id}" if thread_id else None),
                },
            )
        except Exception as e:
            logger.info(json.dumps({"event": "fast_mode_timeline_event_failed", "ts": _now_iso(), "uid": uid, "error": str(e)}, ensure_ascii=False))


#building a memory summary prompt for the inner character
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


#generating an updated memory summary for the inner character
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


#handle a chat request for the inner character
@app.route('/chat', methods=['POST'])
def chat():
    try:
        t0 = time.time()
        t_before_llm = t0
        pre_llm_ms = 0
        llm_ms = 0
        post_llm_ms = 0
        payload_messages = 0
        payload_chars = 0
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
        plan_focus_hint = _get_plan_focus_hint(uid, character_id)
        system_prompt = build_system_prompt_with_memory(
            character_profile,
            memory_summary,
            plan_focus_hint=plan_focus_hint,
        )
        pre_llm_ms = int((time.time() - t0) * 1000)
        t_before_llm = time.time()
        agent_result = run_agent_step(system_prompt, messages)
        llm_meta = (agent_result.get("_meta") or {}) if isinstance(agent_result, dict) else {}
        llm_ms = int(llm_meta.get("llmMs") or 0)
        payload_messages = int(llm_meta.get("payloadMessages") or 0)
        payload_chars = int(llm_meta.get("payloadChars") or 0)
        if isinstance(agent_result, dict):
            agent_result.pop("_meta", None)
        tool_calls = agent_result.get('toolCalls') or []
        if tool_calls:
            _submit_background("run_tool_calls_chat", run_tool_calls, uid, tool_calls)

        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        full_messages = messages + [{'role': 'assistant', 'content': assistant_message}]
        if not AGENT_JSON_RESPONSE_MODE:
            last_user_message = ""
            for msg in reversed(messages):
                if msg.get("role") == "user":
                    last_user_message = str(msg.get("content", "") or "")
                    break
            _submit_background(
                "deterministic_writes_chat",
                _deterministic_fast_mode_writes,
                uid,
                character_id,
                session_id,
                thread_id,
                assistant_message,
                last_user_message,
            )
        _submit_background(
            "persist_character_memory_chat",
            _persist_agent_memory_summary,
            uid,
            character_id,
            updated_summary,
            memory_summary,
            full_messages,
        )

        # ---------------------------------------------------------------------
        # Periodic intensity + checklist updates (every 3 user turns)
        # ---------------------------------------------------------------------
        if session_id and thread_id:
            def _periodic_update_task() -> None:
                turn_for_update = _try_acquire_periodic_update(uid, session_id)
                if not turn_for_update:
                    return
                try:
                    score = score_intensity_with_llm(character_id, full_messages)
                    evidence = (messages[-1].get('content') if messages else '')[:200]

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

            _submit_background("periodic_update_chat", _periodic_update_task)

        # check for guider intervention if enabled
        intervention = None
        if check_intervention:
            analysis = analyze_intervention_need(full_messages, character_id)
            if analysis.get('shouldIntervene'):
                if session_id and thread_id:
                    def _intervention_update_task() -> None:
                        try:
                            score = score_intensity_with_llm(character_id, full_messages)
                            evidence = (messages[-1].get('content') if messages else '')[:200]
                            plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)

                            _log_agent_run(
                                _session_runs_ref(uid, session_id),
                                {
                                    "trigger": "intervention_check",
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
                                        "event": "intervention_update",
                                        "ts": _now_iso(),
                                        "uid": uid,
                                        "characterId": character_id,
                                        "sessionId": session_id,
                                        "intensity": score["intensity"],
                                        "focus": plan_diff.get("focus"),
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

                    _submit_background("intervention_update_chat", _intervention_update_task)

                intervention_message = _fallback_intervention_message(
                    analysis.get('reason', 'general'),
                    analysis.get('message', ''),
                )
                intervention = {
                    'shouldIntervene': True,
                    'reason': analysis.get('reason'),
                    'severity': analysis.get('severity'),
                    'guiderMessage': intervention_message,
                    # extra debug fields (Flutter ignores; in logs/firestore)
                    'focusItemId': None,
                    'focusReason': None,
                    'intensityNow': None,
                    'blendNow': None,
                }
                if session_id:
                    _submit_background(
                        "record_intervention_chat",
                        _record_session_intervention,
                        uid,
                        session_id,
                        analysis.get("reason", ""),
                        analysis.get("severity", "low"),
                    )
                print(f"[intervention] Triggered: {analysis.get('reason')} for {character_id}")
        post_llm_ms = int((time.time() - t_before_llm) * 1000) - llm_ms
        if post_llm_ms < 0:
            post_llm_ms = 0

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
                        "preLlmMs": pre_llm_ms,
                        "llmMs": llm_ms,
                        "postLlmMs": post_llm_ms,
                        "payloadMessages": payload_messages,
                        "payloadChars": payload_chars,
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
    compute end-of-session intensity + summary and write them to:
      users/{uid}/sessions/{sessionId}
    also logs an agent run and updates per-character checklist focus item
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

        # always produce some output, even if msgs is empty
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

        # update character plan metrics
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

        # update focus/checklist based on end score
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

        # evaluate whether this character now qualifies for "stable" state
        stability_result = _apply_stable_state_if_eligible(uid, character_id)
        if stability_result.get("changed"):
            logger.info(
                json.dumps(
                    {
                        "event": "character_marked_stable",
                        "ts": _now_iso(),
                        "uid": uid,
                        "characterId": character_id,
                        "evaluation": stability_result.get("evaluation") or {},
                    },
                    ensure_ascii=False,
                )
            )
        else:
            logger.info(
                json.dumps(
                    {
                        "event": "character_stability_check",
                        "ts": _now_iso(),
                        "uid": uid,
                        "characterId": character_id,
                        "changed": False,
                        "evaluation": stability_result.get("evaluation") or {},
                        "reason": stability_result.get("reason"),
                        "error": stability_result.get("error"),
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
                "stabilityChanged": stability_result.get("changed") is True,
                "stabilityChecks": (stability_result.get("evaluation") or {}).get("checks") or {},
                "stabilityMetrics": (stability_result.get("evaluation") or {}).get("metrics") or {},
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
    """using AI to decide who should respond based on conversation context"""
    try:
        # get last few messages for context
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
    building system prompt for Guider participating in character chat
    Includes per-character checklist + recent session summaries so Guider can
    orient to "where the user stands" overall (without dumping it to the user)
    """
    prompt = GUIDER_IN_CHAT_PROMPT.format(character_name=character_name)

    # internal context (not to be revealed verbatim)
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
    """generating a natural Guider response for the guided chat"""
    guider_system_prompt = build_guider_in_chat_prompt(
        uid=uid,
        character_id=character_id,
        character_name=character_name,
        guider_memory=guider_memory,
    )
    

    guider_messages = [{'role': 'system', 'content': guider_system_prompt}]
    
    # add conversation as a natural flow
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
    
    # add the character's latest response if provided
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
    
    # cleaning up any accidental labels the AI might add
    for prefix in ['[Guider]:', '[The Guider]:', 'Guider:', 'The Guider:', '[You - The Guider]:']:
        if guider_message.startswith(prefix):
            guider_message = guider_message[len(prefix):].strip()
    
    return guider_message


@app.route('/chat_guided', methods=['POST'])
def chat_guided():
    """handling a guided chat where character and/or Guider respond based on context"""
    try:
        t0 = time.time()
        orchestrator_ms = 0
        character_llm_ms = 0
        character_payload_messages = 0
        character_payload_chars = 0
        guider_in_chat_ms = 0
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
        
        # 1. decide who should respond
        t_orchestrator = time.time()
        respondent = decide_who_responds(messages, character_name)
        orchestrator_ms = int((time.time() - t_orchestrator) * 1000)
        
        character_message = ''
        guider_message = ''
        
        # 2. get character response if needed
        if respondent in ['character_only', 'both']:
            memory_summary = load_agent_memory_summary(uid, character_id)
            character_system_prompt = build_system_prompt_with_memory(
                character_profile,
                memory_summary,
            )
            
            agent_result = run_agent_step(character_system_prompt, messages)
            llm_meta = (agent_result.get("_meta") or {}) if isinstance(agent_result, dict) else {}
            character_llm_ms = int(llm_meta.get("llmMs") or 0)
            character_payload_messages = int(llm_meta.get("payloadMessages") or 0)
            character_payload_chars = int(llm_meta.get("payloadChars") or 0)
            if isinstance(agent_result, dict):
                agent_result.pop("_meta", None)
            tool_calls = agent_result.get('toolCalls') or []
            if tool_calls:
                _submit_background("run_tool_calls_guided_character", run_tool_calls, uid, tool_calls)
            
            character_message = agent_result.get('assistantMessage', '')
            
            # update character memory
            updated_char_summary = agent_result.get('memorySummary', '')
            _submit_background(
                "persist_character_memory_guided",
                _persist_agent_memory_summary,
                uid,
                character_id,
                updated_char_summary,
                memory_summary,
                messages + [{'role': 'assistant', 'content': character_message}],
            )
        
        # 3. get guider response if needed
        if respondent in ['guider_only', 'both']:
            guider_memory = load_agent_memory_summary(uid, 'guider')
            t_guider_in_chat = time.time()
            guider_message = get_guider_response_in_chat(
                messages=messages,
                uid=uid,
                character_id=character_id,
                character_name=character_name,
                character_message=character_message,
                guider_memory=guider_memory,
            )
            guider_in_chat_ms = int((time.time() - t_guider_in_chat) * 1000)
            
            # update guider memory
            all_new_messages = messages.copy()
            if character_message:
                all_new_messages.append({'role': 'assistant', 'content': character_message})
            if guider_message:
                all_new_messages.append({'role': 'assistant', 'content': guider_message})
            
            _submit_background(
                "persist_guider_memory_guided",
                _persist_agent_memory_summary,
                uid,
                'guider',
                '',
                guider_memory,
                all_new_messages,
            )
        
        print(f"[guided_chat] {respondent}: char={bool(character_message)}, guider={bool(guider_message)}")

        # periodic intensity + checklist update (same as /chat)
        if session_id and thread_id:
            def _periodic_update_guided_task() -> None:
                turn_for_update = _try_acquire_periodic_update(uid, session_id)
                if not turn_for_update:
                    return
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

            _submit_background("periodic_update_guided", _periodic_update_guided_task)
        
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
                        "orchestratorMs": orchestrator_ms,
                        "characterLlmMs": character_llm_ms,
                        "characterPayloadMessages": character_payload_messages,
                        "characterPayloadChars": character_payload_chars,
                        "guiderInChatMs": guider_in_chat_ms,
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
    """fetching memory summaries for all characters the user has chatted with"""
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
    fetch per-character state from `user_characters` for this user

    expected state values:
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
    """formats a compact checklist plan snapshot for prompt injection"""
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
    """building context for the Guider from all character conversations"""
    states = states if states is not None else get_user_character_states(uid)
    summaries = get_all_character_summaries(uid)

    if not summaries and not states and not guider_plan_snapshot:
        return "The user hasn't had any conversations with their inner parts yet."

    context_parts = ["Here's what you know about the user's inner parts:\n"]

    if states:
        context_parts.append("Current state snapshot from user_characters:")

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
    """building the full system prompt for the Guider with user context"""
    character_context = build_guider_context(
        uid,
        states=states,
        guider_plan_snapshot=guider_plan_snapshot,
    )
    character_context = _clip_text(character_context, 2600)
    guider_memory = _clip_text(guider_memory, MEMORY_PROMPT_MAX_CHARS)
    
    prompt = GUIDER_SYSTEM_PROMPT
    
    if character_context:
        prompt += f"\n\n--- USER'S INNER PARTS CONTEXT ---\n{character_context}"
    
    if guider_memory:
        prompt += f"\n\n--- YOUR MEMORY OF THIS USER ---\n{guider_memory}"
    
    return prompt


def run_guider_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    """running an agent step for the Guider"""
    llm_started_at = time.time()
    if AGENT_JSON_RESPONSE_MODE:
        agent_messages = [
            {'role': 'system', 'content': system_prompt},
            {'role': 'system', 'content': (
                'Return JSON with keys: "assistantMessage", "memorySummary". '
                '"assistantMessage" should be warm, concise, and practical. '
                '"memorySummary" should be under 6 bullet points about the user\'s journey.'
            )},
        ]
    else:
        agent_messages = [
            {'role': 'system', 'content': _clip_text(system_prompt, 1200)},
            {'role': 'system', 'content': (
                'Reply as The Guider in 1-2 warm, practical sentences. '
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
                parsed = {'assistantMessage': '', 'memorySummary': ''}
        except Exception:
            parsed = {'assistantMessage': '', 'memorySummary': ''}
    else:
        parsed = {
            "assistantMessage": raw.strip(),
            "memorySummary": "",
        }
    parsed["_meta"] = {
        "llmMs": llm_ms,
        "payloadMessages": payload_stats["count"],
        "payloadChars": payload_stats["chars"],
    }
    return parsed


@app.route('/chat_guider', methods=['POST'])
def chat_guider():
    """handle a chat request for The Guider agent"""
    try:
        t0 = time.time()
        context_ms = 0
        llm_ms = 0
        payload_messages = 0
        payload_chars = 0
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
        
        # keep guider-only chat inside session tracking as well
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        messages = data.get('messages') or []
        character_id = 'guider'

        # loading per-character state snapshot so Guider can ground decisions in
        # current stabilization status across all parts
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
        
        # loading guider's memory of this user
        guider_memory = load_agent_memory_summary(uid, 'guider')
        guider_plan_snapshot = _get_character_plan_snapshot(uid, 'guider')
        
        # building system prompt with all character context
        system_prompt = build_guider_system_prompt_with_context(
            uid,
            guider_memory,
            states=character_states,
            guider_plan_snapshot=guider_plan_snapshot,
        )
        context_ms = int((time.time() - t0) * 1000)
        
        # running the guider agent
        agent_result = run_guider_agent_step(system_prompt, messages)
        llm_meta = (agent_result.get("_meta") or {}) if isinstance(agent_result, dict) else {}
        llm_ms = int(llm_meta.get("llmMs") or 0)
        payload_messages = int(llm_meta.get("payloadMessages") or 0)
        payload_chars = int(llm_meta.get("payloadChars") or 0)
        if isinstance(agent_result, dict):
            agent_result.pop("_meta", None)
        
        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        
        # updating guider's memory
        _submit_background(
            "persist_guider_memory_chat",
            _persist_agent_memory_summary,
            uid,
            'guider',
            updated_summary,
            guider_memory,
            messages + [{'role': 'assistant', 'content': assistant_message}],
        )

        # ---------------------------------------------------------------------
        # Periodic intensity + checklist updates for guider-only sessions.
        # every 3 user turns of this guider session.
        # writes:
        # - users/{uid}/sessions/{sessionId}.intensity.*
        # - users/{uid}/character_plans/guider
        # - agent_runs under session + character_plan
        # ---------------------------------------------------------------------
        if session_id and thread_id:
            def _periodic_update_guider_task() -> None:
                turn_for_update = _try_acquire_periodic_update(uid, session_id)
                if not turn_for_update:
                    return
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

            _submit_background("periodic_update_guider", _periodic_update_guider_task)
        
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


@app.route('/character_plans/active', methods=['GET'])
def get_active_character_plan():
    """
    getting the per-character checklist plan for a specific characterId
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

# markers that suggest the user may need Guider support
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
    
    # getting recent user messages (last 6)
    recent_user_messages = [
        m['content'].lower() for m in messages[-6:] 
        if m.get('role') == 'user'
    ]
    
    if not recent_user_messages:
        return {'shouldIntervene': False}
    
    combined_text = ' '.join(recent_user_messages)
    
    # checking for crisis keywords (highest priority)
    for keyword in CRISIS_KEYWORDS:
        if keyword in combined_text:
            return {
                'shouldIntervene': True,
                'reason': 'crisis_detected',
                'severity': 'high',
                'message': 'I sense you may be going through something very difficult. Would you like to talk to The Guider? They can help you find support.',
            }
    
    # counting emotional intensity markers
    intensity_count = sum(1 for marker in EMOTIONAL_INTENSITY_MARKERS if marker in combined_text)
    
    # checking for stuck loop patterns
    stuck_count = sum(1 for phrase in STUCK_LOOP_PHRASES if phrase in combined_text)
    
    # checking for repetitive themes (same phrases appearing multiple times)
    repetition_detected = False
    if len(recent_user_messages) >= 3:
        # checking if user is repeating similar messages
        for i in range(len(recent_user_messages) - 1):
            for j in range(i + 1, len(recent_user_messages)):
                # simple similarity check
                words_i = set(recent_user_messages[i].split())
                words_j = set(recent_user_messages[j].split())
                if len(words_i) > 3 and len(words_j) > 3:
                    overlap = len(words_i & words_j)
                    if overlap / max(len(words_i), len(words_j)) > 0.6:
                        repetition_detected = True
                        break
    
    # determine intervention level
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
    
    # check message count - suggest guider after extended sessions
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

    # character display name
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
    
    # context-aware message using AI
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
        # fallback messages based on reason
        fallbacks = {
            'crisis_detected': 'I\'m here if you need a calm space. You don\'t have to go through this alone.',
            'emotional_intensity': 'It sounds like a lot is coming up. I\'m here when you need a moment to breathe.',
            'stuck_loop': 'Sometimes stepping back helps us see more clearly. I\'m here if you want to reflect.',
            'session_length': 'You\'ve been exploring deeply. I\'m here if you want to process what you\'ve discovered.',
        }
        return fallbacks.get(reason, 'I\'m here if you want to talk.')


@app.route('/check_intervention', methods=['POST'])
def check_intervention():
    """check if Guider intervention is recommended for a character chat"""
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
        
        # analyze if intervention is needed
        analysis = analyze_intervention_need(messages, character_id)
        
        if not analysis.get('shouldIntervene'):
            return jsonify({
                'success': True,
                'shouldIntervene': False,
            })
        
        # generate personalized intervention message
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
