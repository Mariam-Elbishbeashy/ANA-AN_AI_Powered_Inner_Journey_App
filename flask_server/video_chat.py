from flask import Flask, request, jsonify, Blueprint
from flask_cors import CORS
import os
import json
from typing import Dict, List, Any
import traceback
from datetime import datetime, timezone
import tempfile
import time

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Initialize Firebase Admin SDK.
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

db = firestore.client()

# Create blueprint
video_bp = Blueprint("video_bp", __name__, url_prefix="/video")


# ============================================================================
# Helper Functions (EXACTLY like agents.py)
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


# ============================================================================
# Character Checklist Templates (EXACTLY like agents.py)
# ============================================================================

CHARACTER_CHECKLIST_TEMPLATES: Dict[str, List[Dict[str, str]]] = {
    "inner_critic": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the Inner Critic without fully becoming it; uses language like 'a part of me' rather than 'I am'."},
        {"id": "appreciation", "name": "Appreciation of protective intent", "definition": "User can acknowledge the Inner Critic is trying to help/protect (even if the method hurts)."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what activates the part and what it is afraid would happen if it stopped."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can soften intensity (breath/body grounding) and return to conversation."},
        {"id": "relationship_shift", "name": "Relationship shift", "definition": "User can relate with compassion/curiosity instead of fighting or obeying the part."},
    ],
    "people_pleaser": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the People Pleaser without merging; can observe urges to appease."},
        {"id": "needs_voice", "name": "Needs and boundaries voice", "definition": "User can name a personal need and experiment with a gentle boundary."},
        {"id": "fear_rejection", "name": "Fear clarity (rejection/conflict)", "definition": "User can articulate what they fear will happen if they disappoint others."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can regulate anxiety before/after boundary attempts."},
    ],
    "__default__": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the part without fully becoming it."},
        {"id": "protective_intent", "name": "Protective intent clarity", "definition": "User can understand what this part is trying to protect them from."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name triggers and underlying fears/beliefs."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can reduce intensity and keep the conversation safe and steady."},
    ],
}


def ensure_character_checklist(uid: str, character_id: str) -> None:
    """ensures a per-character plan doc exists - EXACTLY like agents.py"""
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

    print(json.dumps({
        "event": "character_plan_created",
        "ts": _now_iso(),
        "uid": uid,
        "characterId": character_id,
    }))


def _pick_focus_item_from_score(score: Dict[str, Any]) -> Dict[str, str]:
    """deterministic focus selection policy - EXACTLY like agents.py"""
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
    """Applies rules to update checklist item statuses - EXACTLY like agents.py"""
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
# Session Management (EXACTLY like agents.py)
# ============================================================================

def _ensure_session_doc(uid: str, session_id: str, character_id: str, character_profile: Dict) -> None:
    """Ensure session document exists - EXACTLY like agents.py"""
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            sref.set({
                "id": session_id,
                "characterId": character_id,
                "characterType": "inner_character",
                "status": "active",
                "type": "video",
                "title": f"Video call with {character_profile.get('displayName', character_id)}",
                "startedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "userTurnCount": 0,
                "intensity": {},
                "sessionSummary": {},
                "periodic": {},
            }, merge=True)
            print(f"[video_chat] Created session doc: {session_id}")
    except Exception as e:
        print(f"[video_chat] Error creating session doc: {e}")


def _ensure_thread_doc(uid: str, thread_id: str, session_id: str, character_id: str, character_profile: Dict) -> None:
    """Ensure thread document exists - EXACTLY like agents.py"""
    try:
        tref = _threads_ref(uid).document(thread_id)
        snap = tref.get()
        if not snap.exists:
            tref.set({
                "id": thread_id,
                "sessionId": session_id,
                "characterId": character_id,
                "characterType": "inner_character",
                "title": f"Video call with {character_profile.get('displayName', character_id)}",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            print(f"[video_chat] Created thread doc: {thread_id}")
    except Exception as e:
        print(f"[video_chat] Error creating thread doc: {e}")


def _save_message(uid: str, thread_id: str, role: str, content: str, sender: str = None) -> None:
    """Save a message to Firestore - EXACTLY like agents.py"""
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
        print(f"[video_chat] Saved {role} message: {content[:50] if content else 'empty'}...")

        # Update thread's lastMessageAt
        _threads_ref(uid).document(thread_id).set({
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        # Update session's updatedAt and userTurnCount
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
        print(f"[video_chat] Error saving message: {e}")


def _log_agent_run(ref, payload: Dict[str, Any]) -> None:
    """writes an agent run doc - EXACTLY like agents.py"""
    try:
        ref.document().set({**payload, "createdAt": firestore.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        print(f"[video_chat] agent_run_write_failed: {e}")


def _get_session_user_turn_count(uid: str, session_id: str) -> int:
    """reads `userTurnCount` from the session doc - EXACTLY like agents.py"""
    try:
        snap = _session_ref(uid, session_id).get()
        if not snap.exists:
            return 0
        data = snap.to_dict() or {}
        return int(data.get("userTurnCount") or 0)
    except Exception:
        return 0


def _try_acquire_periodic_update(uid: str, session_id: str) -> int:
    """prevents duplicate periodic updates - EXACTLY like agents.py"""
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
    """persist intensity signals - EXACTLY like agents.py"""
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
                    if start_val is None:
                        start_val = data.get("intensity.start")

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
        print(f"[video_chat] session_intensity_write_failed: {e}")


def score_intensity_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    """Returns structured JSON - EXACTLY like agents.py"""
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


def summarize_session_with_llm(
    character_id: str,
    messages: List[Dict[str, str]],
) -> Dict[str, Any]:
    """End-of-session summarizer - EXACTLY like agents.py"""
    def _extract_recent_user_text(messages: List[Dict[str, str]], max_chars: int = 2200) -> str:
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

    context = _extract_recent_user_text(messages)

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


# ============================================================================
# Character Functions (EXACTLY like agents.py)
# ============================================================================

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
""".strip()


def build_system_prompt_with_memory(
    character_profile: Dict,
    memory_summary: str,
) -> str:
    base_prompt = build_inner_character_prompt(character_profile)
    if not memory_summary:
        return base_prompt
    return f"""{base_prompt}

Memory summary (use only if relevant):
{memory_summary}
""".strip()


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


def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })


def set_last_agent_run(uid: str) -> None:
    db.collection('users').document(uid).set({
        'lastAgentRunAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


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


def generate_updated_summary(
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> str:
    system = (
        'Summarize the conversation into a short memory for future chats. '
        'Focus on stable facts, recurring themes, triggers, and helpful responses. '
        'Keep it under 6 bullet points.'
    )
    user_content = {
        'existing_summary': existing_summary,
        'recent_messages': messages[-20:],
    }

    response = openai_client.chat.completions.create(
        model=OPENAI_SUMMARY_MODEL,
        messages=[
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': json.dumps(user_content)},
        ],
        temperature=0.2,
    )
    return (response.choices[0].message.content or '').strip()


# ============================================================================
# CHARACTER VIDEO CALL ENDPOINTS (FULL agents.py database saving)
# ============================================================================

@video_bp.route('/chat', methods=['POST'])
def chat():
    """Character video call endpoint using EXACT SAME logic as agents.py /chat."""
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

        user_message = data.get('userMessage', '')
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        conversation_history = data.get('conversationHistory', [])
        check_intervention = data.get('checkIntervention', True)

        print(f"[video_chat] Session: {session_id}, Thread: {thread_id}")
        print(f"[video_chat] Character: {character_id}")
        print(f"[video_chat] User message: {user_message[:50] if user_message else 'empty'}...")

        # Ensure character checklist exists
        ensure_character_checklist(uid, character_id)

        # Ensure session and thread documents exist
        if session_id:
            _ensure_session_doc(uid, session_id, character_id, character_profile)
        if thread_id:
            _ensure_thread_doc(uid, thread_id, session_id, character_id, character_profile)

        # Save user message to Firestore
        if thread_id and user_message:
            _save_message(uid, thread_id, 'user', user_message, 'user')

        # Load character's memory
        memory_summary = load_agent_memory_summary(uid, character_id)
        system_prompt = build_system_prompt_with_memory(character_profile, memory_summary)

        # Build conversation messages
        messages = []
        for msg in conversation_history:
            if msg.get('role') == 'user':
                messages.append({'role': 'user', 'content': msg.get('content', '')})
            elif msg.get('role') == 'assistant' and msg.get('sender') == character_id:
                messages.append({'role': 'assistant', 'content': msg.get('content', '')})

        # Add current user message
        if user_message:
            messages.append({'role': 'user', 'content': user_message})

        # Run character agent step
        agent_result = run_agent_step(system_prompt, messages)
        tool_calls = agent_result.get('toolCalls') or []
        run_tool_calls(uid, tool_calls)

        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')

        # Update character memory
        if not updated_summary:
            updated_summary = generate_updated_summary(
                memory_summary,
                messages + [{'role': 'assistant', 'content': assistant_message}],
            )
        save_agent_memory_summary(uid, character_id, updated_summary)
        print(f"[video_chat] memory_summary_updated: {bool(updated_summary)}")

        # Save character response to Firestore
        if thread_id and assistant_message:
            _save_message(uid, thread_id, 'assistant', assistant_message, character_id)

        # Periodic intensity update (every 3 user turns) - EXACTLY like agents.py
        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                # Build messages for intensity scoring
                scored_msgs = []
                for msg in conversation_history:
                    if msg.get('content'):
                        scored_msgs.append({
                            "role": msg.get('role', 'user'),
                            "content": msg.get('content', '')
                        })
                if user_message:
                    scored_msgs.append({"role": "user", "content": user_message})
                if assistant_message:
                    scored_msgs.append({"role": "assistant", "content": assistant_message})

                score = score_intensity_with_llm(character_id, scored_msgs)
                evidence = user_message[:200]

                # Write intensity to session doc
                _write_session_intensity(uid, session_id, score, turn_for_update)

                # Update per-character checklist
                plan_diff = _update_character_plan_from_score(uid, character_id, score, evidence=evidence)

                # Log agent run
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

                print(json.dumps({
                    "event": "periodic_update_video_chat",
                    "ts": _now_iso(),
                    "uid": uid,
                    "characterId": character_id,
                    "sessionId": session_id,
                    "turn": int(turn_for_update),
                    "intensity": score["intensity"],
                    "focus": plan_diff.get("focus"),
                }))
            except Exception as e:
                print(f"[video_chat] Periodic update failed: {e}")

        # Check for Guider intervention if enabled
        intervention = None
        if check_intervention:
            full_messages = messages + [{'role': 'assistant', 'content': assistant_message}]
            analysis = analyze_intervention_need(full_messages, character_id)
            if analysis.get('shouldIntervene'):
                focus_payload = None
                intensity_payload = None
                if session_id and thread_id:
                    try:
                        score = score_intensity_with_llm(character_id, full_messages)
                        evidence = user_message[:200]
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
                        print(json.dumps({
                            "event": "intervention_update",
                            "ts": _now_iso(),
                            "uid": uid,
                            "characterId": character_id,
                            "sessionId": session_id,
                            "intensity": score["intensity"],
                            "focus": focus_payload,
                            "reason": analysis.get("reason"),
                        }))
                    except Exception as e:
                        print(f"[video_chat] Intervention update failed: {e}")

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
                    'focusItemId': (focus_payload or {}).get("itemId") if focus_payload else None,
                    'focusReason': (focus_payload or {}).get("reason") if focus_payload else None,
                    'intensityNow': (intensity_payload or {}).get("intensity") if intensity_payload else None,
                    'blendNow': (intensity_payload or {}).get("blend") if intensity_payload else None,
                }
                print(f"[intervention] Triggered: {analysis.get('reason')} for {character_id}")

        # Log request timing
        print(json.dumps({
            "event": "request_timing",
            "route": "/video/chat",
            "ts": _now_iso(),
            "ms": int((time.time() - t0) * 1000),
        }))

        return jsonify({
            'success': True,
            'characterMessage': assistant_message,
            'toolCalls': tool_calls,
            'intervention': intervention,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Character video error: {str(e)}'
        }), 500


@video_bp.route('/transcribe', methods=['POST'])
def transcribe_route():
    """Transcribe audio for video calls."""
    try:
        file = None
        if 'file' in request.files:
            file = request.files['file']
        elif 'audio' in request.files:
            file = request.files['audio']

        if not file:
            return jsonify({
                'success': False,
                'error': 'No audio file provided'
            }), 400

        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"temp_audio_{datetime.now().timestamp()}.wav")
        file.save(temp_path)

        file_size = os.path.getsize(temp_path)
        if file_size < 1000:
            return jsonify({
                'success': False,
                'error': 'Audio file too small'
            }), 400

        with open(temp_path, "rb") as audio_file:
            transcript_response = openai_client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
            )

        transcript = transcript_response.text.strip()

        try:
            os.remove(temp_path)
        except:
            pass

        print(f"📝 Transcription result: '{transcript}'")

        if not transcript:
            return jsonify({
                'success': False,
                'error': 'Empty transcription'
            }), 400

        return jsonify({
            'success': True,
            'transcript': transcript,
            'language': 'en'
        })

    except Exception as e:
        print(f"❌ Transcription error: {e}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@video_bp.route('/session_summary', methods=['POST'])
def session_summary():
    """Generate a summary of a video call session - EXACTLY like agents.py end_analyze."""
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500

        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        duration = data.get('duration', 0)
        messages = data.get('messages', [])

        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400

        if not session_id:
            return jsonify({
                'success': False,
                'error': 'sessionId is required'
            }), 400

        # Get the current session to read intensity.start
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        existing = (snap.to_dict() or {}) if snap.exists else {}

        # Compute end-of-session intensity score
        intensity_score = score_intensity_with_llm(character_id, messages)

        # Get start intensity if it exists
        start_val = None
        if snap.exists:
            try:
                start_val = snap.get("intensity.start")
            except Exception:
                start_val = (existing.get("intensity") or {}).get("start")

        if start_val is None:
            start_val = intensity_score["intensity"]

        # Calculate delta
        try:
            delta = float(intensity_score["intensity"]) - float(start_val)
        except Exception:
            delta = 0.0

        # Generate session summary using summarize_session_with_llm
        summary = summarize_session_with_llm(character_id, messages)

        # Update character plan metrics
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
        evidence = (messages[-1].get("content") if messages else "")[:200]
        plan_diff = _update_character_plan_from_score(uid, character_id, intensity_score, evidence=evidence)

        # End the session and save full data
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
            "endedAt": firestore.SERVER_TIMESTAMP,
            "status": "ended",
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "endedAnalyzedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        # Log agent run for session end
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

        # Add timeline event
        character_names = {
            'inner_critic': 'Inner Critic',
            'perfectionist': 'Perfectionist',
            'people_pleaser': 'People Pleaser',
            'workaholic': 'Workaholic',
            'procrastinator': 'Procrastinator',
        }
        display_name = character_names.get(character_id, character_id.replace('_', ' ').title())

        add_timeline_event(uid, {
            'type': 'video_session',
            'title': f'Video call with {display_name}',
            'summary': (summary.get('highlights') or ['Session completed'])[0][:200],
        })

        print(json.dumps({
            "event": "session_end_analyzed",
            "ts": _now_iso(),
            "uid": uid,
            "sessionId": session_id,
            "characterId": character_id,
            "intensityEnd": intensity_score["intensity"],
            "delta": delta,
            "focus": plan_diff.get("focus"),
        }))

        return jsonify({
            'success': True,
            'intensityEnd': intensity_score["intensity"],
            'delta': delta,
            'focus': plan_diff.get("focus"),
            'sessionSummary': {
                'highlights': summary.get("highlights") or [],
                'nextStepSuggestion': summary.get("nextStepSuggestion") or "",
            },
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Summary error: {str(e)}'
        }), 500


@video_bp.route('/end_session', methods=['POST'])
def end_session():
    """Simple endpoint to mark a session as ended without summary generation."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        session_id = data.get('sessionId')

        if not uid or not session_id:
            return jsonify({'success': False, 'error': 'uid and sessionId are required'}), 400

        _session_ref(uid, session_id).set({
            "status": "ended",
            "endedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@video_bp.route('/health', methods=['GET'])
def health():
    return jsonify({
        "success": True,
        "message": "Character Video server is running",
        "openai_ready": bool(os.getenv("OPENAI_API_KEY")),
        "firebase_ready": db is not None,
        "endpoints": [
            "/video/chat",
            "/video/transcribe",
            "/video/session_summary",
            "/video/end_session",
            "/video/health"
        ]
    })


# ============================================================================
# GUIDER INTERVENTION IN CHARACTER CHATS (EXACTLY like agents.py)
# ============================================================================

EMOTIONAL_INTENSITY_MARKERS = [
    'i can\'t', 'i cant', 'too much', 'overwhelming', 'scared', 'terrified',
    'hate myself', 'hate my', 'worthless', 'hopeless', 'give up', 'giving up',
    'can\'t cope', 'cant cope', 'falling apart', 'breaking down', 'panic',
    'anxiety', 'depressed', 'suicidal', 'hurt myself', 'end it', 'no point',
]

STUCK_LOOP_PHRASES = [
    'i don\'t know', 'i dont know', 'not sure', 'confused', 'same thing',
    'going in circles', 'nothing works', 'tried everything', 'always the same',
]

CRISIS_KEYWORDS = [
    'suicidal', 'suicide', 'kill myself', 'hurt myself', 'self-harm',
    'end my life', 'don\'t want to live',
]


def analyze_intervention_need(messages: List[Dict[str, str]], character_id: str) -> Dict[str, Any]:
    """Analyze conversation to determine if Guider intervention would be helpful - EXACTLY like agents.py"""
    if len(messages) < 3:
        return {'shouldIntervene': False}

    recent_user_messages = [
        m['content'].lower() for m in messages[-6:]
        if m.get('role') == 'user'
    ]

    if not recent_user_messages:
        return {'shouldIntervene': False}

    combined_text = ' '.join(recent_user_messages)

    for keyword in CRISIS_KEYWORDS:
        if keyword in combined_text:
            return {
                'shouldIntervene': True,
                'reason': 'crisis_detected',
                'severity': 'high',
            }

    intensity_count = sum(1 for marker in EMOTIONAL_INTENSITY_MARKERS if marker in combined_text)
    stuck_count = sum(1 for phrase in STUCK_LOOP_PHRASES if phrase in combined_text)

    if intensity_count >= 3 or (intensity_count >= 2 and stuck_count >= 2):
        return {
            'shouldIntervene': True,
            'reason': 'emotional_intensity',
            'severity': 'medium',
        }

    if stuck_count >= 3:
        return {
            'shouldIntervene': True,
            'reason': 'stuck_loop',
            'severity': 'low',
        }

    total_user_messages = sum(1 for m in messages if m.get('role') == 'user')
    if total_user_messages >= 15 and total_user_messages % 5 == 0:
        return {
            'shouldIntervene': True,
            'reason': 'session_length',
            'severity': 'low',
        }

    return {'shouldIntervene': False}


def generate_guider_intervention_message(
    uid: str,
    character_id: str,
    reason: str,
    messages: List[Dict[str, str]],
) -> str:
    """Generate a personalized intervention message - EXACTLY like agents.py"""
    character_names = {
        'inner_critic': 'The Inner Critic',
        'perfectionist': 'The Perfectionist',
        'people_pleaser': 'The People Pleaser',
    }
    character_name = character_names.get(character_id, 'this inner part')

    try:
        intervention_prompt = f"""You are The Guider, a compassionate companion.

The user has been chatting with {character_name}.
Reason for intervention: {reason}

Generate a SHORT (1-2 sentences) caring message that:
- Acknowledges their feelings
- Gently offers yourself as a space for reflection

Keep it warm and brief."""

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
    except Exception:
        fallbacks = {
            'crisis_detected': "I'm here if you need a calm space. You don't have to go through this alone.",
            'emotional_intensity': "It sounds like a lot is coming up. I'm here when you need a moment.",
            'stuck_loop': "Sometimes stepping back helps. I'm here if you want to reflect.",
            'session_length': "You've been exploring deeply. I'm here if you want to process.",
        }
        return fallbacks.get(reason, "I'm here if you want to talk.")


# For direct execution
if __name__ == '__main__':
    app = Flask(__name__)
    CORS(app)
    app.register_blueprint(video_bp)
    app.run(host='0.0.0.0', port=5002, debug=True)