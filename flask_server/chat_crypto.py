import base64
import os
import time
from threading import Lock
from typing import Any, Dict, Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import firebase_admin
from firebase_admin import firestore


class MasterKeyProvider:
    def wrap_dek(self, dek: bytes) -> Dict[str, str]:
        raise NotImplementedError()

    def unwrap_dek(self, payload: Dict[str, Any]) -> bytes:
        raise NotImplementedError()

    @property
    def key_version(self) -> str:
        raise NotImplementedError()

    @property
    def encrypted_dek_version(self) -> str:
        raise NotImplementedError()


class EnvMasterKeyProvider(MasterKeyProvider):
    def __init__(self) -> None:
        raw = os.getenv("CHAT_MASTER_KEY", "").strip()
        if not raw:
            raise RuntimeError("CHAT_MASTER_KEY must be set")
        self._master_key = self._decode_master_key(raw)
        if len(self._master_key) != 32:
            raise RuntimeError("CHAT_MASTER_KEY must decode to exactly 32 bytes")
        self._key_version = os.getenv("CHAT_MASTER_KEY_VERSION", "env_v1").strip() or "env_v1"
        self._encrypted_dek_version = "env_wrap_v1"

    @staticmethod
    def _decode_master_key(raw: str) -> bytes:
        # Support base64 first; if it fails, fallback to hex.
        try:
            return base64.b64decode(raw, validate=True)
        except Exception:
            try:
                return bytes.fromhex(raw)
            except Exception as e:
                raise RuntimeError("CHAT_MASTER_KEY must be base64 or hex") from e

    def wrap_dek(self, dek: bytes) -> Dict[str, str]:
        nonce = os.urandom(12)
        aes = AESGCM(self._master_key)
        ciphertext = aes.encrypt(nonce, dek, None)
        return {
            "wrappedDek": base64.b64encode(ciphertext).decode("utf-8"),
            "wrapNonce": base64.b64encode(nonce).decode("utf-8"),
            "keyVersion": self.key_version,
            "encryptedDekVersion": self.encrypted_dek_version,
        }

    def unwrap_dek(self, payload: Dict[str, Any]) -> bytes:
        nonce_b64 = str(payload.get("wrapNonce") or "")
        wrapped_b64 = str(payload.get("wrappedDek") or "")
        if not nonce_b64 or not wrapped_b64:
            raise RuntimeError("Missing wrapped DEK payload")
        nonce = base64.b64decode(nonce_b64)
        wrapped = base64.b64decode(wrapped_b64)
        aes = AESGCM(self._master_key)
        return aes.decrypt(nonce, wrapped, None)

    @property
    def key_version(self) -> str:
        return self._key_version

    @property
    def encrypted_dek_version(self) -> str:
        return self._encrypted_dek_version


_cache_lock = Lock()
_dek_cache: Dict[str, Dict[str, Any]] = {}
_cache_ttl_sec = max(10, int(os.getenv("CHAT_DEK_CACHE_TTL_SEC", "120")))
_provider_lock = Lock()
_provider_instance: Optional[MasterKeyProvider] = None


def _key_doc_ref(uid: str):
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app()
    db = firestore.client()
    return db.collection("users").document(uid).collection("chat_crypto").document("default")


def _get_provider() -> MasterKeyProvider:
    global _provider_instance
    if _provider_instance is not None:
        return _provider_instance
    with _provider_lock:
        if _provider_instance is None:
            _provider_instance = EnvMasterKeyProvider()
    return _provider_instance


def _load_cached_dek(uid: str) -> Optional[Dict[str, Any]]:
    now = time.time()
    with _cache_lock:
        entry = _dek_cache.get(uid)
        if not entry:
            return None
        if (now - float(entry.get("ts", 0))) > _cache_ttl_sec:
            _dek_cache.pop(uid, None)
            return None
        return entry


def _store_cached_dek(uid: str, dek: bytes, key_version: str, encrypted_dek_version: str) -> None:
    with _cache_lock:
        _dek_cache[uid] = {
            "dek": dek,
            "keyVersion": key_version,
            "encryptedDekVersion": encrypted_dek_version,
            "ts": time.time(),
        }


def get_user_dek(uid: str) -> Dict[str, Any]:
    cached = _load_cached_dek(uid)
    if cached:
        return cached

    ref = _key_doc_ref(uid)
    snap = ref.get()
    provider = _get_provider()
    if snap.exists:
        data = snap.to_dict() or {}
        dek = provider.unwrap_dek(data)
        key_version = str(data.get("keyVersion") or provider.key_version)
        encrypted_dek_version = str(data.get("encryptedDekVersion") or provider.encrypted_dek_version)
        _store_cached_dek(uid, dek, key_version, encrypted_dek_version)
        return _load_cached_dek(uid) or {}

    dek = os.urandom(32)
    wrapped = provider.wrap_dek(dek)
    ref.set(
        {
            **wrapped,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    _store_cached_dek(uid, dek, provider.key_version, provider.encrypted_dek_version)
    return _load_cached_dek(uid) or {}


def encrypt_message(uid: str, plaintext: str) -> Dict[str, str]:
    state = get_user_dek(uid)
    provider = _get_provider()
    dek = state.get("dek")
    if not isinstance(dek, (bytes, bytearray)) or len(dek) != 32:
        raise RuntimeError("Invalid DEK state")
    nonce = os.urandom(12)
    aes = AESGCM(bytes(dek))
    ciphertext = aes.encrypt(nonce, (plaintext or "").encode("utf-8"), None)
    return {
        "contentCiphertext": base64.b64encode(ciphertext).decode("utf-8"),
        "contentNonce": base64.b64encode(nonce).decode("utf-8"),
        "contentEncoding": "enc_v1",
        "keyVersion": str(state.get("keyVersion") or provider.key_version),
        "encryptedDekVersion": str(state.get("encryptedDekVersion") or provider.encrypted_dek_version),
    }


def decrypt_message(uid: str, message_data: Dict[str, Any]) -> str:
    encoding = str(message_data.get("contentEncoding") or "").strip().lower()
    if not encoding:
        return str(message_data.get("content") or "")
    if encoding != "enc_v1":
        raise RuntimeError(f"Unsupported contentEncoding: {encoding}")
    state = get_user_dek(uid)
    dek = state.get("dek")
    if not isinstance(dek, (bytes, bytearray)) or len(dek) != 32:
        raise RuntimeError("Invalid DEK state")
    nonce_b64 = str(message_data.get("contentNonce") or "")
    ciphertext_b64 = str(message_data.get("contentCiphertext") or "")
    if not nonce_b64 or not ciphertext_b64:
        raise RuntimeError("Missing encrypted message payload")
    nonce = base64.b64decode(nonce_b64)
    ciphertext = base64.b64decode(ciphertext_b64)
    aes = AESGCM(bytes(dek))
    plaintext = aes.decrypt(nonce, ciphertext, None)
    return plaintext.decode("utf-8")
