# video_transcript_store.py
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import firestore

from video_crypto import decrypt_video_message, encrypt_video_message


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


def serialize_video_message(uid: str, message_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """Decrypt and serialize a video message for display"""
    try:
        content = decrypt_video_message(uid, data)
    except Exception as e:
        print(f"Failed to decrypt message {message_id}: {e}")
        content = "[Encrypted message - unable to decrypt]"

    return {
        "id": message_id,
        "role": str(data.get("role") or "assistant"),
        "content": content,
        "createdAt": _to_iso(data.get("createdAt")),
        "sender": data.get("sender"),
        "characterId": data.get("characterId"),
        "sessionId": data.get("sessionId"),
        "metadata": data.get("metadata") if isinstance(data.get("metadata"), dict) else None,
    }


def append_video_message_encrypted(
    uid: str,
    thread_id: str,
    role: str,
    content: str,
    session_id: Optional[str] = None,
    sender: Optional[str] = None,
    character_id: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Append an encrypted video message to a thread.

    Args:
        uid: User ID
        thread_id: Thread ID
        role: 'user' or 'assistant'
        content: Plaintext message content
        session_id: Optional session ID for tracking
        sender: Optional sender identifier (e.g., 'guider', character ID)
        character_id: Optional character ID
        metadata: Optional metadata dict

    Returns:
        Dict with message info including ID and createdAt
    """
    encrypted = encrypt_video_message(uid, content or "")
    payload: Dict[str, Any] = {
        "role": role,
        **encrypted,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }

    if sender:
        payload["sender"] = sender
    if character_id:
        payload["characterId"] = character_id
    if session_id:
        payload["sessionId"] = session_id
    if isinstance(metadata, dict):
        payload["metadata"] = metadata

    ref = _messages_ref(uid, thread_id).document()
    ref.set(payload, merge=True)

    # Update thread's lastMessageAt
    _threads_ref(uid).document(thread_id).set(
        {
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    # Update session's message count and turn count
    if session_id:
        is_user = role == "user"
        update_data = {
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
            "messageCount": firestore.Increment(1),
        }
        if is_user:
            update_data["userTurnCount"] = firestore.Increment(1)
        _sessions_ref(uid).document(session_id).set(update_data, merge=True)

    created_at = datetime.now(timezone.utc).isoformat()
    return {
        "id": ref.id,
        "role": role,
        "content": content or "",
        "createdAt": created_at,
        "sender": sender,
        "characterId": character_id,
        "sessionId": session_id,
        "metadata": metadata if isinstance(metadata, dict) else None,
    }


def get_video_messages_decrypted(
    uid: str,
    thread_id: str,
    limit: int = 100,
    order_descending: bool = True
) -> List[Dict[str, Any]]:
    """
    Get decrypted video messages from a thread.

    Args:
        uid: User ID
        thread_id: Thread ID
        limit: Maximum number of messages to retrieve
        order_descending: If True, newest first; if False, oldest first

    Returns:
        List of decrypted message dicts (chronological order)
    """
    lim = max(1, min(500, int(limit)))

    # FIXED: Single order_by clause - no duplicates
    ref = _messages_ref(uid, thread_id)

    if order_descending:
        # Get newest first
        snaps = ref.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(lim).stream()
    else:
        # Get oldest first
        snaps = ref.order_by("createdAt").limit(lim).stream()

    rows: List[Dict[str, Any]] = []
    for snap in snaps:
        data = snap.to_dict() or {}
        rows.append(serialize_video_message(uid, snap.id, data))

    # Always return chronological order for display
    if order_descending:
        rows.reverse()

    return rows


def get_video_messages_chronological(
    uid: str,
    thread_id: str,
    limit: int = 200
) -> List[Dict[str, str]]:
    """
    Get decrypted video messages in chronological order for analysis.

    Returns:
        List of messages with 'role' and 'content' keys
    """
    lim = max(1, min(500, int(limit)))
    snaps = (
        _messages_ref(uid, thread_id)
        .order_by("createdAt")
        .limit(lim)
        .stream()
    )

    rows: List[Dict[str, str]] = []
    for snap in snaps:
        data = snap.to_dict() or {}
        try:
            content = decrypt_video_message(uid, data)
        except Exception:
            content = "[Encrypted]"
        rows.append(
            {
                "role": str(data.get("role") or "user"),
                "content": content,
                "sender": data.get("sender"),
                "characterId": data.get("characterId"),
            }
        )
    return rows


def load_video_messages_for_analysis(
    uid: str,
    thread_id: str,
    limit: int = 200
) -> List[Dict[str, str]]:
    """Load video messages for analysis (chronological order)"""
    return get_video_messages_chronological(uid, thread_id, limit)


def delete_video_messages_for_session(
    uid: str,
    thread_id: str,
    session_id: str
) -> int:
    """
    Delete all messages for a specific video session.

    Returns:
        Number of messages deleted
    """
    deleted_count = 0
    snaps = (
        _messages_ref(uid, thread_id)
        .where("sessionId", "==", session_id)
        .stream()
    )

    for snap in snaps:
        snap.reference.delete()
        deleted_count += 1

    return deleted_count


def get_video_session_message_count(uid: str, session_id: str) -> int:
    """Get the number of messages in a video session"""
    try:
        # First get thread_id from session
        snap = _sessions_ref(uid).document(session_id).get()
        if not snap.exists:
            return 0
        data = snap.to_dict() or {}
        thread_id = data.get("threadId")

        if not thread_id:
            return 0

        # Count messages
        count_snap = (
            _messages_ref(uid, thread_id)
            .where("sessionId", "==", session_id)
            .count()
            .get()
        )
        return count_snap[0][0] if count_snap else 0
    except Exception:
        return 0