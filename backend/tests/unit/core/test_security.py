from backend.core.security import generate_token, hash_password, hash_token, verify_password


def test_generate_token_returns_base64url_string():
    raw, token_hash = generate_token()
    # 64 bytes base64url-encoded = 88 chars (with padding)
    assert len(raw) == 88
    assert isinstance(raw, str)


def test_generate_token_returns_32_byte_hash():
    _, token_hash = generate_token()
    assert len(token_hash) == 32
    assert isinstance(token_hash, bytes)


def test_hash_token_is_deterministic():
    raw, _ = generate_token()
    h1 = hash_token(raw)
    h2 = hash_token(raw)
    assert h1 == h2


def test_hash_token_matches_generate():
    raw, expected_hash = generate_token()
    assert hash_token(raw) == expected_hash


def test_hash_password_verify_roundtrip():
    password = "S3cur3P@ss!"
    hashed = hash_password(password)
    assert verify_password(password, hashed) is True


def test_verify_password_wrong_password():
    hashed = hash_password("correct-password")
    assert verify_password("wrong-password", hashed) is False


def test_hash_password_different_each_time():
    p = "same-password"
    h1 = hash_password(p)
    h2 = hash_password(p)
    assert h1 != h2  # bcrypt uses random salts
