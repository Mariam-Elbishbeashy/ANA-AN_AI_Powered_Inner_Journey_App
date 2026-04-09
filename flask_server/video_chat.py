from flask import Blueprint, request, jsonify
from flask_cors import CORS
import os
import json
import tempfile
import time
import traceback
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Any

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI

# ============================================================================
# INITIALIZATION
# ============================================================================

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Initialize Firebase Admin SDK
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

db = firestore.client()

# Create blueprint
video_bp = Blueprint("video_bp", __name__, url_prefix="/video")

# ============================================================================
# HELPER FUNCTIONS (EXACTLY like agents.py)
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
# CHARACTER CHECKLIST TEMPLATES (COMPLETE - matching agents.py)
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
    "overwhelmed": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the Overwhelmed Part without fully becoming it; can name it as 'a part of me'."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can slow down (breath/body) and reduce overload enough to keep the conversation safe."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what piles up (pressure/expectations) and what feels threatened underneath."},
        {"id": "needs_capacity", "name": "Needs and capacity clarity", "definition": "User can identify one unmet need and one realistic limit (capacity) they can honor today."},
    ],
    "overater_binger": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice urges to eat/binge as a part response, not an identity."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can pause the urge long enough to choose a safer step (even small)."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name emotional triggers (stress/loneliness) and what the part fears if it stops."},
        {"id": "soothing_alternatives", "name": "Safer self-soothing options", "definition": "User can practice at least one non-food soothing option when distress rises."},
    ],
    "jealous": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can observe jealousy without acting from it immediately."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can regulate activation (body/grounding) when attachment feels threatened."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name comparison/left-out triggers and the fear of being replaced."},
        {"id": "reassurance_requests", "name": "Healthy reassurance requests", "definition": "User can ask for reassurance/connection in a clear, non-attacking way."},
    ],
    "lonely": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can be with loneliness as a feeling/part, without collapsing into it."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can stay present with loneliness safely (breath/body) instead of shutting down."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what situations activate loneliness and what it fears will never change."},
        {"id": "connection_steps", "name": "Connection micro-steps", "definition": "User can take one small step toward connection (message, activity, reaching out) without overwhelm."},
    ],
    "wounded_child": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the younger vulnerable feelings as a part and stay present as Self."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can create safety (grounding, gentleness) before exploring painful memories/needs."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what activates the child pain (criticism/abandonment) and what it fears now."},
        {"id": "reparenting", "name": "Reparenting responses", "definition": "User can offer a caring internal response (validation/comfort) instead of self-judgment."},
    ],
    "procrastinator": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice avoidance impulses without immediately obeying them."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can reduce task anxiety enough to take a tiny step."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what tasks/pressures trigger avoidance and the fear underneath (failure/overwhelm)."},
        {"id": "tiny_steps", "name": "Tiny-step execution", "definition": "User can choose the smallest next action and complete it with reduced pressure."},
    ],
    "workaholic": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can observe the drive to work as a protective part, not a necessity."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can tolerate rest/pause without panic and return to regulation."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what triggers overworking and what the part fears (uselessness, loss of control)."},
        {"id": "rest_permission", "name": "Permission to rest", "definition": "User can practice a planned rest window without compensating with overwork."},
    ],
    "perfectionist": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice perfectionism as a part with a strategy, rather than 'the truth'."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can soothe shame/anxiety that arises around mistakes or imperfection."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can identify what imperfection threatens and what the part fears will happen."},
        {"id": "flexibility", "name": "Flexibility practice", "definition": "User can intentionally allow 'good enough' and recover from discomfort without spiraling."},
    ],
    "stoic": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice emotional suppression as a part strategy, not a requirement."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can stay regulated while allowing small amounts of feeling to surface."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what feels unsafe about vulnerability and what the part fears will happen."},
        {"id": "emotional_access", "name": "Emotional access", "definition": "User can name at least one feeling in the body and allow it without shutting down."},
    ],
    "fearful": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice fear/anxiety as a part and step back into a steadier Self presence."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can ground in the present (sensations/breath) when anticipating danger."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name uncertainty triggers and what catastrophe the part is trying to prevent."},
        {"id": "safety_reality_check", "name": "Safety reality-check", "definition": "User can distinguish real present danger from predicted danger and choose a calmer response."},
    ],
    "ashamed": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice shame as a part experience rather than a fixed identity."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can stay with shame gently without collapsing or attacking themselves."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name shame triggers (criticism/exposure) and the fear underneath (rejection)."},
        {"id": "self_compassion", "name": "Self-compassion access", "definition": "User can offer a kind internal response when shame arises (soft tone, acceptance)."},
    ],
    "controller": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice controlling urges as a protective part response."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can tolerate uncertainty without escalating into micromanaging."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what feels unpredictable and what the part fears will happen without control."},
        {"id": "flexibility_letting_go", "name": "Flexibility / letting go", "definition": "User can practice one small 'release' experiment (delegate, pause planning) and recover safely."},
    ],
    "confused": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can observe confusion without spiraling into overthinking."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can ground first, then revisit the problem with more clarity."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what creates mixed signals and the fear of making the wrong choice."},
        {"id": "clarity_steps", "name": "Clarity steps", "definition": "User can reduce options and pick one next step (even provisional) without needing perfect certainty."},
    ],
    "dependent": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice dependency urges without immediately handing power away."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can soothe separation anxiety enough to stay grounded."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name triggers (separation/responsibility) and the fear of abandonment or failure."},
        {"id": "gradual_autonomy", "name": "Gradual autonomy", "definition": "User can practice one small independent decision while still feeling supported."},
    ],
    "excessive_gamer": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the pull to escape into gaming as a part strategy."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can pause the escape impulse long enough to choose a safer regulation step."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what reality-feelings trigger escape and what the part fears if it stops."},
        {"id": "balance_routines", "name": "Balance and routines", "definition": "User can create a realistic limit (time boundary) and add one nourishing offline alternative."},
    ],
    "neglected": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can be with the Neglected Part without shutting down or going numb."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can stay present with the pain of being unseen, safely and gently."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name what situations activate neglect pain and what it fears (permanent invisibility)."},
        {"id": "validation_requests", "name": "Validation and care requests", "definition": "User can ask for attention/validation in a direct, non-shaming way and also offer internal validation."},
    ],
    "__default__": [
        {"id": "unblending", "name": "Unblending (Self vs Part)", "definition": "User can notice the part without fully becoming it."},
        {"id": "protective_intent", "name": "Protective intent clarity", "definition": "User can understand what this part is trying to protect them from."},
        {"id": "triggers_fears", "name": "Triggers and fears clarity", "definition": "User can name triggers and underlying fears/beliefs."},
        {"id": "stabilization", "name": "Stabilization skill", "definition": "User can reduce intensity and keep the conversation safe and steady."},
    ],
}

def ensure_character_checklist(uid: str, character_id: str) -> None:
    """Ensures a per-character plan doc exists at users/{uid}/character_plans/{characterId}"""
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

    print(f"✅ Created character plan for {character_id}")

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
# SESSION MANAGEMENT (EXACTLY like agents.py)
# ============================================================================

def _ensure_session_doc(uid: str, session_id: str, character_id: str, thread_id: str, character_profile: Dict) -> None:
    """Ensure session document exists with proper structure matching ChatSession entity"""
    try:
        sref = _session_ref(uid, session_id)
        snap = sref.get()
        if not snap.exists:
            sref.set({
                "id": session_id,
                "type": "video",
                "characterId": character_id,
                "characterType": "inner_character",
                "threadId": thread_id,
                "status": "active",
                "title": f"Video call with {character_profile.get('displayName', character_id)}",
                "startedAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
                "userTurnCount": 0,
                "intensity": {},
                "sessionSummary": {},
                "periodic": {},
            }, merge=True)
            print(f"✅ Created session doc: {session_id} with threadId: {thread_id}")
    except Exception as e:
        print(f"[video_chat] Error creating session doc: {e}")

def _ensure_thread_doc(uid: str, thread_id: str, session_id: str, character_id: str, character_profile: Dict) -> None:
    """Ensure thread document exists with proper structure matching ChatThread entity"""
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
                "status": "active",
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)
            print(f"✅ Created thread doc: {thread_id}")
    except Exception as e:
        print(f"[video_chat] Error creating thread doc: {e}")

def _save_message(uid: str, thread_id: str, role: str, content: str, sender: str = None, character_id: str = None, session_id: str = None) -> None:
    """Save a message to Firestore matching ChatMessage structure"""
    try:
        if not thread_id:
            print(f"[video_chat] ERROR: Cannot save message - thread_id is None")
            return

        if not content or content.strip() == '':
            print(f"[video_chat] WARNING: Empty content, skipping save")
            return

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
        print(f"[video_chat] ✅ Saved message: id={msg_ref.id}, role={role}, thread={thread_id}")

        # Update thread's lastMessageAt
        _threads_ref(uid).document(thread_id).set({
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

        # Update session's lastMessageAt and userTurnCount
        if session_id:
            sref = _session_ref(uid, session_id)
            sref.set({
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            if role == 'user':
                sref.set({
                    "userTurnCount": firestore.Increment(1),
                }, merge=True)

    except Exception as e:
        print(f"[video_chat] ❌ Error saving message: {e}")

def _log_agent_run(ref, payload: Dict[str, Any]) -> None:
    try:
        ref.document().set({**payload, "createdAt": firestore.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        print(f"[video_chat] agent_run_write_failed: {e}")

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

# ============================================================================
# INTENSITY SCORING (EXACTLY like agents.py)
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
    context = _extract_recent_user_text(messages[-2200:]) if len(messages) > 2200 else _extract_recent_user_text(messages)

    prompt = (
        "Summarize this IFS-style chat session in a structured way.\n"
        "Return ONLY JSON with keys:\n"
        "- highlights: array of 3-6 short bullet strings\n"
        "- ifsSignals: object with keys like blend, protectorTone, exileHints, selfEnergy (optional)\n"
        "- progressSignals: array of short strings (e.g. 'more curiosity', 'less shame language')\n"
        "- nextStepSuggestion: one short sentence guiding next session focus\n"
        f"CharacterId: {character_id}\n"
        "Conversation:\n"
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
# CHARACTER FUNCTIONS (EXACTLY like agents.py)
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
# GUIDER INTERVENTION (EXACTLY like agents.py)
# ============================================================================

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

def _get_recent_session_summaries(uid: str, character_id: str, limit: int = 5) -> List[Dict[str, Any]]:
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
    plan_snapshot = _get_character_plan_snapshot(uid, character_id)
    recent_summaries = _get_recent_session_summaries(uid, character_id, limit=4)

    character_names = {
        'inner_critic': 'The Inner Critic',
        'perfectionist': 'The Perfectionist',
        'people_pleaser': 'The People Pleaser',
        'lonely': 'The Lonely Part',
        'workaholic': 'The Workaholic',
        'procrastinator': 'The Procrastinator',
        'fearful': 'The Fearful Part',
        'wounded_child': 'The Wounded Child',
        'ashamed': 'The Ashamed Part',
    }
    character_name = character_names.get(character_id, 'this inner part')

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
        fallbacks = {
            'crisis_detected': "I'm here if you need a calm space. You don't have to go through this alone.",
            'emotional_intensity': "It sounds like a lot is coming up. I'm here when you need a moment to breathe.",
            'stuck_loop': "Sometimes stepping back helps us see more clearly. I'm here if you want to reflect.",
            'session_length': "You've been exploring deeply. I'm here if you want to process what you've discovered.",
        }
        return fallbacks.get(reason, "I'm here if you want to talk.")

# ============================================================================
# GUIDED VIDEO CHAT (with Guider participation)
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
    try:
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
        print(f"[guided_video] Decision: {respondent} - {result.get('reason', 'no reason')}")
        return respondent
    except Exception as e:
        print(f"[guided_video] Decision error: {e}, defaulting to character_only")
        return 'character_only'

def get_guider_response_in_chat(
    messages: List[Dict],
    uid: str,
    character_id: str,
    character_name: str,
    character_message: str,
    guider_memory: str,
) -> str:
    plan_snapshot = _get_character_plan_snapshot(uid, character_id)
    recent_summaries = _get_recent_session_summaries(uid, character_id, limit=4)

    guider_system_prompt = GUIDER_IN_CHAT_PROMPT.format(character_name=character_name)
    guider_system_prompt += "\n\n(Internal) Checklist + recent session summaries:\n"
    guider_system_prompt += json.dumps(
        {"plan": plan_snapshot, "recentSessionSummaries": recent_summaries},
        ensure_ascii=False,
        default=_json_default,
    )

    if guider_memory:
        guider_system_prompt += f"\n\nYour memory of this user:\n{guider_memory}"

    guider_messages = [{'role': 'system', 'content': guider_system_prompt}]

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

    for prefix in ['[Guider]:', '[The Guider]:', 'Guider:', 'The Guider:', '[You - The Guider]:']:
        if guider_message.startswith(prefix):
            guider_message = guider_message[len(prefix):].strip()

    return guider_message

# ============================================================================
# API ENDPOINTS
# ============================================================================

@video_bp.route('/create_session', methods=['POST'])
def create_session():
    """Create a new video session and thread - called by Flutter"""
    try:
        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId')
        character_type = data.get('characterType', 'inner_character')
        title = data.get('title', 'Video Session')

        if not uid or not character_id:
            return jsonify({'success': False, 'error': 'uid and characterId required'}), 400

        session_id = f"video_{int(time.time() * 1000)}_{character_id}"
        thread_id = str(uuid.uuid4())

        ensure_character_checklist(uid, character_id)

        # Create session document
        session_ref = _session_ref(uid, session_id)
        session_ref.set({
            "id": session_id,
            "type": "video",
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

        # Create thread document
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

        print(f"✅ Created session: {session_id}, thread: {thread_id}")

        return jsonify({
            'success': True,
            'sessionId': session_id,
            'threadId': thread_id,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500

@video_bp.route('/get_active_session', methods=['GET'])
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

@video_bp.route('/chat', methods=['POST'])
def chat():
    try:
        t0 = time.time()

        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({'success': False, 'error': 'uid is required'}), 400

        user_message = data.get('userMessage', '')
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        conversation_history = data.get('conversationHistory', [])
        check_intervention = data.get('checkIntervention', True)

        # Get or create session/thread
        if not session_id or not thread_id:
            sessions_ref = _sessions_ref(uid)
            query = sessions_ref.where('characterId', '==', character_id).where('status', '==', 'active').limit(1)
            docs = query.stream()

            for doc in docs:
                data = doc.to_dict()
                session_id = doc.id
                thread_id = data.get('threadId')
                if thread_id:
                    break

            if not session_id or not thread_id:
                session_id = f"video_{int(time.time() * 1000)}_{character_id}"
                thread_id = str(uuid.uuid4())

                _session_ref(uid, session_id).set({
                    "id": session_id,
                    "type": "video",
                    "characterId": character_id,
                    "characterType": "inner_character",
                    "threadId": thread_id,
                    "status": "active",
                    "title": f"Video call with {character_profile.get('displayName', character_id)}",
                    "startedAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                    "lastMessageAt": firestore.SERVER_TIMESTAMP,
                    "userTurnCount": 0,
                }, merge=True)

                _threads_ref(uid).document(thread_id).set({
                    "id": thread_id,
                    "sessionId": session_id,
                    "characterId": character_id,
                    "characterType": "inner_character",
                    "title": f"Video call with {character_profile.get('displayName', character_id)}",
                    "status": "active",
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                    "lastMessageAt": firestore.SERVER_TIMESTAMP,
                }, merge=True)

        # Ensure documents exist
        ensure_character_checklist(uid, character_id)
        _ensure_session_doc(uid, session_id, character_id, thread_id, character_profile)
        _ensure_thread_doc(uid, thread_id, session_id, character_id, character_profile)

        # Save user message
        if thread_id and user_message:
            _save_message(uid, thread_id, 'user', user_message, 'user', character_id, session_id)

        # Build messages for AI
        messages = []
        for msg in conversation_history:
            if msg.get('role') == 'user':
                messages.append({'role': 'user', 'content': msg.get('content', '')})
            elif msg.get('role') == 'assistant':
                messages.append({'role': 'assistant', 'content': msg.get('content', '')})

        if user_message:
            messages.append({'role': 'user', 'content': user_message})

        memory_summary = load_agent_memory_summary(uid, character_id)
        system_prompt = build_system_prompt_with_memory(character_profile, memory_summary)

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

        # Save assistant message
        if thread_id and assistant_message:
            _save_message(uid, thread_id, 'assistant', assistant_message, character_id, character_id, session_id)

        # Periodic updates
        turn_for_update = _try_acquire_periodic_update(uid, session_id) if session_id else 0
        if session_id and thread_id and turn_for_update:
            try:
                scored_msgs = messages + [{'role': 'assistant', 'content': assistant_message}]
                score = score_intensity_with_llm(character_id, scored_msgs)
                evidence = user_message[:200]

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
            except Exception as e:
                print(f"[video_chat] Periodic update failed: {e}")

        # Guider intervention check
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

        return jsonify({
            'success': True,
            'assistantMessage': assistant_message,
            'toolCalls': tool_calls,
            'intervention': intervention,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Character video error: {str(e)}'}), 500

@video_bp.route('/chat_guided', methods=['POST'])
def chat_guided():
    try:
        t0 = time.time()

        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({'success': False, 'error': 'OPENAI_API_KEY is not set'}), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({'success': False, 'error': 'uid is required'}), 400

        user_message = data.get('userMessage', '')
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        character_name = character_profile.get('displayName', 'Inner Part')
        session_id = data.get('sessionId')
        thread_id = data.get('threadId')
        conversation_history = data.get('conversationHistory', [])

        print(f"[guided_video] Session: {session_id}, Thread: {thread_id}")
        print(f"[guided_video] User message: {user_message[:100] if user_message else 'empty'}")

        ensure_character_checklist(uid, character_id)

        if session_id and thread_id:
            _ensure_session_doc(uid, session_id, character_id, thread_id, character_profile)
            _ensure_thread_doc(uid, thread_id, session_id, character_id, character_profile)

        if thread_id and user_message:
            _save_message(uid, thread_id, 'user', user_message, 'user', character_id, session_id)

        # Build guided messages
        guided_messages = []
        for msg in conversation_history:
            sender = msg.get('sender', msg.get('role', 'user'))
            if sender == 'user' or msg.get('role') == 'user':
                guided_messages.append({'sender': 'user', 'content': msg.get('content', '')})
            elif msg.get('sender') == 'guider':
                guided_messages.append({'sender': 'guider', 'content': msg.get('content', '')})
            else:
                guided_messages.append({'sender': character_name, 'content': msg.get('content', '')})

        guided_messages.append({'sender': 'user', 'content': user_message})

        respondent = decide_who_responds(guided_messages, character_name)
        print(f"[guided_video] Respondent: {respondent}")

        character_message = ''
        guider_message = ''

        # Get Character Response
        if respondent in ['character_only', 'both']:
            messages = []
            for msg in conversation_history:
                if msg.get('role') == 'user':
                    messages.append({'role': 'user', 'content': msg.get('content', '')})
                elif msg.get('role') == 'assistant' and msg.get('sender') != 'guider':
                    messages.append({'role': 'assistant', 'content': msg.get('content', '')})

            if user_message:
                messages.append({'role': 'user', 'content': user_message})

            memory_summary = load_agent_memory_summary(uid, character_id)
            system_prompt = build_system_prompt_with_memory(character_profile, memory_summary)

            agent_result = run_agent_step(system_prompt, messages)
            tool_calls = agent_result.get('toolCalls') or []
            run_tool_calls(uid, tool_calls)

            character_message = agent_result.get('assistantMessage', '')

            updated_char_summary = agent_result.get('memorySummary', '')
            if not updated_char_summary:
                updated_char_summary = generate_updated_summary(
                    memory_summary,
                    messages + [{'role': 'assistant', 'content': character_message}],
                )
            save_agent_memory_summary(uid, character_id, updated_char_summary)

            if thread_id and character_message:
                _save_message(uid, thread_id, 'assistant', character_message, character_id, character_id, session_id)

        # Get Guider Response
        if respondent in ['guider_only', 'both']:
            guider_memory = load_agent_memory_summary(uid, 'guider')
            guider_message = get_guider_response_in_chat(
                messages=guided_messages,
                uid=uid,
                character_id=character_id,
                character_name=character_name,
                character_message=character_message,
                guider_memory=guider_memory,
            )

            if guider_message and thread_id:
                _save_message(uid, thread_id, 'assistant', guider_message, 'guider', None, session_id)

            all_new_messages = guided_messages.copy()
            if character_message:
                all_new_messages.append({'sender': character_name, 'content': character_message})
            if guider_message:
                all_new_messages.append({'sender': 'guider', 'content': guider_message})

            updated_guider_summary = generate_updated_summary(guider_memory, all_new_messages)
            save_agent_memory_summary(uid, 'guider', updated_guider_summary)

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
                if user_message:
                    scored_msgs.append({"role": "user", "content": user_message})
                if character_message:
                    scored_msgs.append({"role": "assistant", "content": character_message})
                if guider_message:
                    scored_msgs.append({"role": "assistant", "content": guider_message})

                score = score_intensity_with_llm(character_id, scored_msgs)
                evidence = user_message[:200]
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
            except Exception as e:
                print(f"[guided_video] Periodic update failed: {e}")

        return jsonify({
            'success': True,
            'characterMessage': character_message,
            'guiderMessage': guider_message,
            'respondent': respondent,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Guided video chat error: {str(e)}'}), 500

@video_bp.route('/transcribe', methods=['POST'])
def transcribe_route():
    try:
        file = None
        if 'file' in request.files:
            file = request.files['file']
        elif 'audio' in request.files:
            file = request.files['audio']

        if not file:
            return jsonify({'success': False, 'error': 'No audio file provided'}), 400

        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"temp_audio_{datetime.now().timestamp()}.wav")
        file.save(temp_path)

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

        if not transcript:
            return jsonify({'success': False, 'error': 'Empty transcription'}), 400

        return jsonify({'success': True, 'transcript': transcript, 'language': 'en'})

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500

@video_bp.route('/session_summary', methods=['POST'])
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

        intensity_score = score_intensity_with_llm(character_id, messages)

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

        summary = summarize_session_with_llm(character_id, messages)

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

        evidence = (messages[-1].get("content") if messages else "")[:200]
        plan_diff = _update_character_plan_from_score(uid, character_id, intensity_score, evidence=evidence)

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

        character_names = {
            'inner_critic': 'Inner Critic',
            'perfectionist': 'Perfectionist',
            'people_pleaser': 'People Pleaser',
            'lonely': 'Lonely Part',
            'workaholic': 'Workaholic',
            'procrastinator': 'Procrastinator',
            'wounded_child': 'Wounded Child',
            'jealous': 'Jealous Part',
            'ashamed': 'Ashamed Part',
            'fearful': 'Fearful Part',
            'overwhelmed': 'Overwhelmed Part',
            'controller': 'Controller Part',
        }
        display_name = character_names.get(character_id, character_id.replace('_', ' ').title())

        add_timeline_event(uid, {
            'type': 'video_session',
            'title': f'Video call with {display_name}',
            'summary': (summary.get('highlights') or ['Session completed'])[0][:200],
        })

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
        return jsonify({'success': False, 'error': f'Summary error: {str(e)}'}), 500

@video_bp.route('/end_session', methods=['POST'])
def end_session():
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
            "/video/chat_guided",
            "/video/transcribe",
            "/video/session_summary",
            "/video/end_session",
            "/video/create_session",
            "/video/get_active_session",
            "/video/health"
        ]
    })

@video_bp.route('/debug_messages', methods=['GET'])
def debug_messages():
    """Debug endpoint to check messages in a thread"""
    try:
        uid = request.args.get('uid')
        thread_id = request.args.get('threadId')

        if not uid or not thread_id:
            return jsonify({'success': False, 'error': 'uid and threadId required'}), 400

        messages_ref = _messages_ref(uid, thread_id)
        messages = []

        docs = messages_ref.order_by("createdAt").stream()
        for doc in docs:
            data = doc.to_dict()
            messages.append({
                'id': doc.id,
                'role': data.get('role'),
                'content': data.get('content', '')[:100],
                'sender': data.get('sender'),
                'createdAt': str(data.get('createdAt')),
            })

        return jsonify({
            'success': True,
            'threadId': thread_id,
            'messageCount': len(messages),
            'messages': messages,
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500