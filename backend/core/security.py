import os
import secrets
from datetime import datetime, timedelta
from typing import Optional
from cryptography.fernet import Fernet
from jose import JWTError, jwt
from passlib.context import CryptContext

# Configuration (In production, these should be environment variables)
# IMPORTANT: Set these as environment variables for production!
# Example: export SECRET_KEY="your-secure-random-key-here"
# Example: export ENCRYPTION_KEY="your-fernet-key-here"

# Generate persistent keys if not set (save them for reuse)
def get_or_create_secret_key():
    """Get secret key from env or create a persistent one."""
    key = os.getenv("SECRET_KEY")
    if not key:
        # For development - create a key file
        key_file = os.path.join(os.path.dirname(__file__), ".secret_key")
        if os.path.exists(key_file):
            with open(key_file, 'r') as f:
                key = f.read().strip()
        else:
            key = secrets.token_urlsafe(32)
            with open(key_file, 'w') as f:
                f.write(key)
            print(f"WARNING: Generated new SECRET_KEY. Save this for production: {key}")
    return key

def get_or_create_encryption_key():
    """Get encryption key from env or create a persistent one."""
    key = os.getenv("ENCRYPTION_KEY")
    if not key:
        # For development - create a key file
        key_file = os.path.join(os.path.dirname(__file__), ".encryption_key")
        if os.path.exists(key_file):
            with open(key_file, 'r') as f:
                key = f.read().strip()
        else:
            key = Fernet.generate_key().decode()
            with open(key_file, 'w') as f:
                f.write(key)
            print(f"WARNING: Generated new ENCRYPTION_KEY. Save this for production: {key}")
    return key

SECRET_KEY = get_or_create_secret_key()
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week

# AES Encryption Key for API Keys
ENCRYPTION_KEY = get_or_create_encryption_key()
cipher_suite = Fernet(ENCRYPTION_KEY.encode())

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def encrypt_api_key(api_key: str) -> str:
    """Encrypts an API key using AES-256."""
    if not api_key:
        return ""
    try:
        return cipher_suite.encrypt(api_key.encode()).decode()
    except Exception as e:
        print(f"Encryption error: {e}")
        return ""

def decrypt_api_key(encrypted_key: str) -> str:
    """Decrypts an API key."""
    if not encrypted_key:
        return ""
    try:
        return cipher_suite.decrypt(encrypted_key.encode()).decode()
    except Exception as e:
        print(f"Decryption error: {e}")
        return ""

def verify_password(plain_password, hashed_password):
    if not plain_password or not hashed_password:
        return False
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = payload.get("exp")
        if exp and exp > datetime.utcnow().timestamp():
            return payload
        return None
    except JWTError:
        return None
    except Exception as e:
        print(f"Token decode error: {e}")
        return None
