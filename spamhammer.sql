-- WARNING! WARNING! READ ME! I'M NOT KIDDING! This is a giant footgun that
-- could easily make it so that you can't restore your database backups _if you
-- ignore this advice_.
--
-- When you add a PostgreSQL constraint, that constraint is evaluated when you
-- add it and then again when you change a row, e.g. by inserting or updating
-- data. That's the only time. If the constraint calls a user-defined function
-- like ours does here, and you change that function's definition, then
-- PostgreSQL won't evaluate any existing rows again. Why's that a problem? Say
-- you modify the 'frz_text_is_abusive' function in-place without dropping the
-- constraint first. Now it's possible that there will already be existing
-- statuses rows that violate the new, updated constraint. Nothing will happen.
-- PostgreSQL won't re-check them. Now if you backup the database and try to
-- restore it, the constraint *will* be evaluated on each row as it gets
-- inserted, and it will fail when it gets to one of the demon rows, and you
-- will have a sad.
--
-- Don't do that. Any time you want to edit this function, drop the constraint,
-- make your edits, and re-add the constraint. If you have bad data, PostgreSQL
-- will complain about it then and won't let you add it until you delete the
-- abusive statuses. Yes, it's slower that way. Yes, you will be so happy when
-- your next database backup/restore succeeds.
\timing on
\set ON_ERROR_STOP on
BEGIN;
-- Did I mention that you should always drop a constraint before modifying a
-- user-defined function that it references? I think I did! If you don't believe
-- me, go back and read that giant warning paragraph above that you skipped
-- over.
ALTER TABLE statuses
    DROP CONSTRAINT IF EXISTS frz_2024_10_10_01;
-- Create a function where you pass in a string and it tells you if that string
-- contains abusive text.
DROP FUNCTION IF EXISTS frz_text_is_abusive;
CREATE FUNCTION frz_text_is_abusive (status_text TEXT)
    RETURNS BOOLEAN
    AS $$
DECLARE
    lower_status_text TEXT = LOWER(status_text);
    abuse_text TEXT;
    -- This is the collection of strings that we do not wish to allow to exist
    -- in our statuses. BE CONSERVATIVE. If you add the spam string 'e',
    -- you're gonna have a really bad time. For speed and robustness, we
    -- compare these to the lowercase value of the passed-in status text. Be
    -- sure the strings you add here are lowercase, then, or they'll never
    -- match anything.
    abuse_text_strings TEXT ARRAY = ARRAY[
        '%<a href="https://midokuriserver.github.io/minidon/%',
        '%black friday%shorturl.at%'
    ];
BEGIN
    -- This algorithm isn't super fast and it only gets slower as we add more
    -- abuse strings. However, "slow" here is relative. At the moment I'm
    -- writing this, I have about 10M statuses in my database. A query to check
    -- every row takes about 1 minute, so it runs about 160,000 checks per
    -- second. If your instance receives more than 160,000 new statuses per
    -- second, contact me for information about my hourly consulting rates.
    -- You can afford it.
    FOREACH abuse_text IN ARRAY abuse_text_strings LOOP
        IF lower_status_text LIKE abuse_text THEN
            RETURN TRUE;
        END IF;
    END LOOP;
    RETURN FALSE;
    END;
$$
LANGUAGE plpgsql;
COMMIT;

-- See if our constraint works as expected, identifying spam but not matching benign toots.
DO $$
BEGIN
    ASSERT (
        SELECT
            *
        FROM frz_text_is_abusive ('hello, world!')) = FALSE,
    'Matched an innocent status.';
END;
$$;

DO $$
BEGIN
    ASSERT (
        SELECT
            *
        FROM frz_text_is_abusive ('i am annoyed by <a href="https://midokuriserver.github.io/minidon/')) = TRUE,
    'Did not match a spam status.';
END;
$$;

DO $$
BEGIN
    ASSERT (
        SELECT
            *
        FROM frz_text_is_abusive ('Black Friday Sale :Grab Your $300 Discount on $1,000+ Mattress Purchases – Ending Soon!<br /><a href="https://shorturl.at/iSuCk"')) = TRUE,
    'Did not match a spam status.';
END;
$$;

-- See if any current rows are abusive. If so, this gives you a list of status
-- IDs to investigate. You'll need to delete all of them before you can apply
-- the constraint in the next step.
DO $$
DECLARE
    ids BIGINT[];
BEGIN
    ids := ARRAY (
        SELECT
            id
        FROM
            STATUSES
        WHERE
            frz_text_is_abusive (text));
    ASSERT ARRAY_LENGTH(ids, 1) IS NULL,
    'Matching IDs: ' || ARRAY_TO_STRING(ids, ',');
END;
$$;

BEGIN;
-- Now tell PostgreSQL never to insert values where that function returns
-- true.
ALTER TABLE statuses
    ADD CONSTRAINT frz_2024_10_10_01 CHECK (NOT frz_text_is_abusive (text));
COMMIT;

\timing off
