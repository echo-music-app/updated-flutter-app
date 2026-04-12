BEGIN;

WITH user_seed AS (
    SELECT
        user_num,
        ('00000000-0000-0000-0000-' || lpad(user_num::text, 12, '0'))::uuid AS user_id,
        format('user%s@foo.bar', user_num) AS email,
        format('user%s', user_num) AS username
    FROM generate_series(1, 10) AS user_num
)
INSERT INTO users (id, email, username, password_hash, status, is_artist)
SELECT
    user_id,
    email,
    username,
    '$2b$12$6PeNHIqeY8m/lpBkpnvATezeLW8WsgKhXq8WNIZiodMQZbsIVQx8e',
    'active'::userstatus,
    false
FROM user_seed
ON CONFLICT (username) DO UPDATE
SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    status = EXCLUDED.status,
    is_artist = EXCLUDED.is_artist;

WITH user_seed AS (
    SELECT
        user_num,
        ('00000000-0000-0000-0000-' || lpad(user_num::text, 12, '0'))::uuid AS user_id
    FROM generate_series(1, 10) AS user_num
),
post_seed AS (
    SELECT
        u.user_num,
        u.user_id,
        post_num,
        ((u.user_num - 1) * 50 + post_num) AS post_seq,
        CASE ((post_num - 1) % 3)
            WHEN 0 THEN 'public'::privacy
            WHEN 1 THEN 'friends'::privacy
            ELSE 'only_me'::privacy
        END AS privacy
    FROM user_seed u
    CROSS JOIN generate_series(1, 50) AS post_num
)
INSERT INTO posts (id, user_id, privacy)
SELECT
    ('10000000-0000-0000-0000-' || lpad(post_seq::text, 12, '0'))::uuid AS id,
    user_id,
    privacy
FROM post_seed
ON CONFLICT (id) DO UPDATE
SET
    user_id = EXCLUDED.user_id,
    privacy = EXCLUDED.privacy;

WITH user_seed AS (
    SELECT
        user_num,
        ('00000000-0000-0000-0000-' || lpad(user_num::text, 12, '0'))::uuid AS user_id
    FROM generate_series(1, 10) AS user_num
),
post_seed AS (
    SELECT
        u.user_num,
        u.user_id,
        post_num,
        ((u.user_num - 1) * 50 + post_num) AS post_seq,
        CASE ((post_num - 1) % 3)
            WHEN 0 THEN 'public'::privacy
            WHEN 1 THEN 'friends'::privacy
            ELSE 'only_me'::privacy
        END AS privacy
    FROM user_seed u
    CROSS JOIN generate_series(1, 50) AS post_num
)
INSERT INTO attachments (id, attachment_type, post_id, content)
SELECT
    ('20000000-0000-0000-0000-' || lpad(post_seq::text, 12, '0'))::uuid AS id,
    'text'::attachmenttype,
    ('10000000-0000-0000-0000-' || lpad(post_seq::text, 12, '0'))::uuid AS post_id,
    format(
        'Text attachment for user%s with privacy=%s (post %s/50)',
        user_num,
        privacy::text,
        post_num
    ) AS content
FROM post_seed
ON CONFLICT (id) DO UPDATE
SET
    attachment_type = EXCLUDED.attachment_type,
    post_id = EXCLUDED.post_id,
    content = EXCLUDED.content;

COMMIT;
