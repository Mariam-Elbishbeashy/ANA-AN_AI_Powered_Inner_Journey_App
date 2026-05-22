from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import firestore

from chat_crypto import decrypt_message, encrypt_message

def _threads_ref(uid: str):
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app()
    db = firestore.client()
    return db.collection("users").document(uid).collection("chat_threads")


def _messages_ref(uid: str, thread_id: str):
    return _threads_ref(uid).document(thread_id).collection("messages")


def _sessions_ref(uid: str):
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app()
    db = firestore.client()
    return db.collection("users").document(uid).collection("sessions")


def _to_iso(ts: Any) -> Optional[str]:
    if ts is None:
        return None
    if hasattr(ts, "isoformat"):
        try:
            return ts.isoformat()
        except Exception:
            return str(ts)
    return str(ts)


def serialize_message(uid: str, message_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
    content = decrypt_message(uid, data)
    return {
        "id": message_id,
        "role": str(data.get("role") or "assistant"),
        "content": content,
        "createdAt": _to_iso(data.get("createdAt")),
        "metadata": data.get("metadata") if isinstance(data.get("metadata"), dict) else None,
    }


def append_message_encrypted(
    uid: str,
    thread_id: str,
    role: str,
    content: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    encrypted = encrypt_message(uid, content or "")
    payload: Dict[str, Any] = {
        "role": role,
        **encrypted,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }
    if isinstance(metadata, dict):
        payload["metadata"] = metadata

    ref = _messages_ref(uid, thread_id).document()
    ref.set(payload, merge=True)

    _threads_ref(uid).document(thread_id).set(
        {
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    session_id = str((metadata or {}).get("sessionId") or "").strip()
    if session_id:
        is_user = role == "user"
        _sessions_ref(uid).document(session_id).set(
            {
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "lastMessageAt": firestore.SERVER_TIMESTAMP,
                "messageCount": firestore.Increment(1),
                **({"userTurnCount": firestore.Increment(1)} if is_user else {}),
            },
            merge=True,
        )

    created_at = datetime.now(timezone.utc).isoformat()
    return {
        "id": ref.id,
        "role": role,
        "content": content or "",
        "createdAt": created_at,
        "metadata": metadata if isinstance(metadata, dict) else None,
    }


def get_recent_messages_decrypted(uid: str, thread_id: str, limit: int = 20) -> List[Dict[str, Any]]:
    lim = max(1, min(200, int(limit)))
    snaps = (
        _messages_ref(uid, thread_id)
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(lim)
        .stream()
    )
    rows: List[Dict[str, Any]] = []
    for snap in snaps:
        data = snap.to_dict() or {}
        rows.append(serialize_message(uid, snap.id, data))
    rows.reverse()
    return rows


def load_messages_for_analysis(uid: str, thread_id: str, limit: int = 200) -> List[Dict[str, str]]:
    lim = max(1, min(400, int(limit)))
    snaps = (
        _messages_ref(uid, thread_id)
        .order_by("createdAt")
        .limit(lim)
        .stream()
    )
    rows: List[Dict[str, str]] = []
    for snap in snaps:
        data = snap.to_dict() or {}
        rows.append(
            {
                "role": str(data.get("role") or "user"),
                "content": decrypt_message(uid, data),
            }
        )
    return rows
