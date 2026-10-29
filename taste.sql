-- =============================================================================
-- Tastemap — init.sql
-- SQLite schema + seed data reconstructed from the app screenshots
-- (ranked list, "Add your restaurant" form, restaurant detail page).
--
-- Run:   sqlite3 tastemap.db < init.sql
--   or:  python3 -c "import sqlite3;c=sqlite3.connect('tastemap.db');c.executescript(open('init.sql').read())"
--
-- Requires SQLite >= 3.24 (UPSERT-era syntax, recursive CTEs, partial indexes).
-- Re-runnable: drops and recreates everything.
--
-- Data notes
--   * Names, taglines, neighbourhoods, ranks, price tiers, tags, Brat's
--     description, photo captions and its 4.9 / 184-review score come from the
--     screenshots.
--   * Phone numbers use Ofcom's reserved drama range (020 7946 0xxx) — they are
--     safe placeholders, not the venues' real numbers.
--   * Ratings/review counts other than Brat's, descriptions for other venues,
--     coordinates and the 3 "want to try" places are SAMPLE data.
--   * The 4 Lyon restaurants are entirely FICTIONAL (names, descriptions,
--     ratings). Real street names, approximate numbers/coordinates. Phones use
--     the 01 99 00 xx xx range (believed reserved for fiction by ARCEP).
--   * The 2 Israel restaurants (Tel Aviv, Jerusalem) are also FICTIONAL.
--     Real street names, approximate numbers/postcodes/coordinates; phone left
--     NULL to avoid hitting a real Israeli number.
-- =============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Reset
-- ---------------------------------------------------------------------------
DROP VIEW  IF EXISTS v_restaurant_detail;
DROP VIEW  IF EXISTS v_ranked_list;
DROP TABLE IF EXISTS stars;
DROP TABLE IF EXISTS photos;
DROP TABLE IF EXISTS restaurant_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS restaurants;

BEGIN TRANSACTION;

-- ---------------------------------------------------------------------------
-- tags  — cuisine filters (Basque, British…) and style tags (Open Fire, Wine Bar…)
-- ---------------------------------------------------------------------------
CREATE TABLE tags (
    id          INTEGER PRIMARY KEY,
    slug        TEXT    NOT NULL UNIQUE,
    name        TEXT    NOT NULL,
    kind        TEXT    NOT NULL DEFAULT 'cuisine'
                        CHECK (kind IN ('cuisine', 'style')),
    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- ---------------------------------------------------------------------------
-- restaurants
--   price_tier     1..4  → rendered as €, €€, €€€, €€€€ (symbol is a UI concern)
--   rating_avg /   cached aggregate of the `stars` table, kept in sync by
--   rating_count   triggers below (detail page: "★ 4.9 (184 reviews)")
--   editorial_rating  "Editorial Grade / Rating" field of the owner form
--   list_status    your personal list: 'ranked' | 'want_to_try' | NULL (not saved)
--   rank           head-to-head position; required iff list_status = 'ranked'
--   listing_status directory state: 'published' | 'pending' (owner submissions)
-- ---------------------------------------------------------------------------
CREATE TABLE restaurants (
    id                INTEGER PRIMARY KEY,
    slug              TEXT    NOT NULL UNIQUE,
    name              TEXT    NOT NULL,
    tagline           TEXT,                       -- "Basque Open Fire"
    description       TEXT,                       -- detail page / "Culinary Concept & Heritage"
    price_tier        INTEGER NOT NULL CHECK (price_tier BETWEEN 1 AND 4),
    avg_spend_min     INTEGER CHECK (avg_spend_min IS NULL OR avg_spend_min >= 0),
    avg_spend_max     INTEGER CHECK (avg_spend_max IS NULL OR avg_spend_max >= avg_spend_min),
    currency          TEXT    NOT NULL DEFAULT 'GBP' CHECK (length(currency) = 3),
    editorial_rating  REAL    CHECK (editorial_rating IS NULL OR editorial_rating BETWEEN 0 AND 5),
    rating_avg        REAL    NOT NULL DEFAULT 0 CHECK (rating_avg BETWEEN 0 AND 5),
    rating_count      INTEGER NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
    phone             TEXT,
    street_address    TEXT    NOT NULL,
    postcode          TEXT,
    neighborhood      TEXT    NOT NULL,
    city              TEXT    NOT NULL DEFAULT 'London',
    country_code      TEXT    NOT NULL DEFAULT 'GB',
    latitude          REAL    CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    longitude         REAL    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    list_status       TEXT    CHECK (list_status IS NULL OR list_status IN ('ranked', 'want_to_try')),
    rank              INTEGER CHECK (rank IS NULL OR rank >= 1),
    visit_count       INTEGER NOT NULL DEFAULT 0 CHECK (visit_count >= 0),
    listing_status    TEXT    NOT NULL DEFAULT 'published'
                              CHECK (listing_status IN ('published', 'pending')),
    created_at        TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at        TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    -- a rank exists exactly when the place is in the "Ranked" tab
    CHECK ((list_status IS 'ranked') = (rank IS NOT NULL))
);

CREATE UNIQUE INDEX ux_restaurants_rank      ON restaurants(rank) WHERE rank IS NOT NULL;
CREATE INDEX        ix_restaurants_list      ON restaurants(list_status, rank);
CREATE INDEX        ix_restaurants_geo       ON restaurants(latitude, longitude);
CREATE INDEX        ix_restaurants_city_hood ON restaurants(city, neighborhood);

-- ---------------------------------------------------------------------------
-- restaurant_tags — max 3 per restaurant (position 1..3, unique per restaurant)
-- ---------------------------------------------------------------------------
CREATE TABLE restaurant_tags (
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    tag_id        INTEGER NOT NULL REFERENCES tags(id)        ON DELETE CASCADE,
    position      INTEGER NOT NULL CHECK (position BETWEEN 1 AND 3),
    created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (restaurant_id, tag_id),
    UNIQUE (restaurant_id, position)
);
CREATE INDEX ix_restaurant_tags_tag ON restaurant_tags(tag_id);

-- ---------------------------------------------------------------------------
-- photos — exactly the 3-photo gallery of the detail page (position 1 = hero)
-- ---------------------------------------------------------------------------
CREATE TABLE photos (
    id            INTEGER PRIMARY KEY,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    position      INTEGER NOT NULL CHECK (position BETWEEN 1 AND 3),
    url           TEXT    NOT NULL,
    caption       TEXT,                              -- "Whole Turbot · Basque Wood Grill"
    alt_text      TEXT,
    created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (restaurant_id, position)
);

-- ---------------------------------------------------------------------------
-- stars — one row per review score (1..5). Feeds restaurants.rating_avg/count.
-- ---------------------------------------------------------------------------
CREATE TABLE stars (
    id            INTEGER PRIMARY KEY,
    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    stars         INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
    author        TEXT,
    comment       TEXT,
    created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX ix_stars_restaurant ON stars(restaurant_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- ---- updated_at: refresh on every UPDATE --------------------------------------
-- Fires only when the statement didn't set updated_at itself, so an explicit
-- value (e.g. a data import) is respected and the trigger never re-fires on
-- its own write (recursive_triggers is OFF by default in SQLite).
CREATE TRIGGER trg_tags_updated_at AFTER UPDATE ON tags
FOR EACH ROW WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE tags SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE rowid = NEW.rowid;
END;

CREATE TRIGGER trg_restaurants_updated_at AFTER UPDATE ON restaurants
FOR EACH ROW WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE restaurants SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE rowid = NEW.rowid;
END;

CREATE TRIGGER trg_restaurant_tags_updated_at AFTER UPDATE ON restaurant_tags
FOR EACH ROW WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE restaurant_tags SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE rowid = NEW.rowid;
END;

CREATE TRIGGER trg_photos_updated_at AFTER UPDATE ON photos
FOR EACH ROW WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE photos SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE rowid = NEW.rowid;
END;

CREATE TRIGGER trg_stars_updated_at AFTER UPDATE ON stars
FOR EACH ROW WHEN NEW.updated_at IS OLD.updated_at
BEGIN
    UPDATE stars SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE rowid = NEW.rowid;
END;

-- ---- created_at: set by DEFAULT on INSERT, immutable afterwards ---------------
CREATE TRIGGER trg_tags_created_at_immutable BEFORE UPDATE OF created_at ON tags
FOR EACH ROW WHEN NEW.created_at IS NOT OLD.created_at
BEGIN SELECT RAISE(ABORT, 'tags.created_at is immutable'); END;

CREATE TRIGGER trg_restaurants_created_at_immutable BEFORE UPDATE OF created_at ON restaurants
FOR EACH ROW WHEN NEW.created_at IS NOT OLD.created_at
BEGIN SELECT RAISE(ABORT, 'restaurants.created_at is immutable'); END;

CREATE TRIGGER trg_restaurant_tags_created_at_immutable BEFORE UPDATE OF created_at ON restaurant_tags
FOR EACH ROW WHEN NEW.created_at IS NOT OLD.created_at
BEGIN SELECT RAISE(ABORT, 'restaurant_tags.created_at is immutable'); END;

CREATE TRIGGER trg_photos_created_at_immutable BEFORE UPDATE OF created_at ON photos
FOR EACH ROW WHEN NEW.created_at IS NOT OLD.created_at
BEGIN SELECT RAISE(ABORT, 'photos.created_at is immutable'); END;

CREATE TRIGGER trg_stars_created_at_immutable BEFORE UPDATE OF created_at ON stars
FOR EACH ROW WHEN NEW.created_at IS NOT OLD.created_at
BEGIN SELECT RAISE(ABORT, 'stars.created_at is immutable'); END;

-- ---- max 3 tags / 3 photos: friendly error before the CHECK would fail -------
CREATE TRIGGER trg_restaurant_tags_max3 BEFORE INSERT ON restaurant_tags
FOR EACH ROW WHEN (SELECT COUNT(*) FROM restaurant_tags WHERE restaurant_id = NEW.restaurant_id) >= 3
BEGIN SELECT RAISE(ABORT, 'a restaurant can have at most 3 tags'); END;

CREATE TRIGGER trg_photos_max3 BEFORE INSERT ON photos
FOR EACH ROW WHEN (SELECT COUNT(*) FROM photos WHERE restaurant_id = NEW.restaurant_id) >= 3
BEGIN SELECT RAISE(ABORT, 'a restaurant can have at most 3 photos'); END;

-- ---- rating aggregate: keep restaurants.rating_avg / rating_count in sync ----
CREATE TRIGGER trg_stars_agg_insert AFTER INSERT ON stars
FOR EACH ROW
BEGIN
    UPDATE restaurants
       SET rating_count = (SELECT COUNT(*) FROM stars WHERE restaurant_id = NEW.restaurant_id),
           rating_avg   = COALESCE((SELECT ROUND(AVG(stars), 2) FROM stars WHERE restaurant_id = NEW.restaurant_id), 0)
     WHERE id = NEW.restaurant_id;
END;

CREATE TRIGGER trg_stars_agg_delete AFTER DELETE ON stars
FOR EACH ROW
BEGIN
    UPDATE restaurants
       SET rating_count = (SELECT COUNT(*) FROM stars WHERE restaurant_id = OLD.restaurant_id),
           rating_avg   = COALESCE((SELECT ROUND(AVG(stars), 2) FROM stars WHERE restaurant_id = OLD.restaurant_id), 0)
     WHERE id = OLD.restaurant_id;
END;

CREATE TRIGGER trg_stars_agg_update AFTER UPDATE OF stars, restaurant_id ON stars
FOR EACH ROW
BEGIN
    UPDATE restaurants
       SET rating_count = (SELECT COUNT(*) FROM stars s WHERE s.restaurant_id = restaurants.id),
           rating_avg   = COALESCE((SELECT ROUND(AVG(s.stars), 2) FROM stars s WHERE s.restaurant_id = restaurants.id), 0)
     WHERE id IN (OLD.restaurant_id, NEW.restaurant_id);
END;

-- =============================================================================
-- VIEWS (shape the data the way the screens consume it)
-- =============================================================================

-- Sidebar "Ranked" list: 1 Brat · Basque Open Fire · Shoreditch · €€€ · TOP PICK
CREATE VIEW v_ranked_list AS
SELECT r.rank,
       r.id,
       r.slug,
       r.name,
       r.tagline,
       r.neighborhood,
       r.price_tier,
       r.rating_avg,
       r.rating_count,
       r.visit_count,
       (r.rank = 1)                                            AS is_top_pick,
       (SELECT p.url FROM photos p
         WHERE p.restaurant_id = r.id ORDER BY p.position LIMIT 1) AS cover_url,
       r.latitude,
       r.longitude
  FROM restaurants r
 WHERE r.list_status = 'ranked' AND r.listing_status = 'published'
 ORDER BY r.rank;

-- Detail page: tags + gallery flattened, rating summary
CREATE VIEW v_restaurant_detail AS
SELECT r.*,
       (SELECT group_concat(name, ', ') FROM (
            SELECT t.name FROM restaurant_tags rt JOIN tags t ON t.id = rt.tag_id
             WHERE rt.restaurant_id = r.id ORDER BY rt.position))      AS tag_names,
       (SELECT COUNT(*) FROM photos p WHERE p.restaurant_id = r.id)    AS photo_count,
       r.street_address || ', ' || r.city ||
         COALESCE(' ' || r.postcode, '')                               AS full_address
  FROM restaurants r;

-- =============================================================================
-- SEED DATA
-- =============================================================================

-- ---- tags (filter chips + form chips + detail badges) ------------------------
INSERT INTO tags (slug, name, kind) VALUES
    ('basque',       'Basque',       'cuisine'),
    ('british',      'British',      'cuisine'),
    ('spanish',      'Spanish',      'cuisine'),
    ('italian',      'Italian',      'cuisine'),
    ('european',     'European',     'cuisine'),
    ('indian',       'Indian',       'cuisine'),
    ('punjabi',      'Punjabi',      'cuisine'),
    ('taiwanese',    'Taiwanese',    'cuisine'),
    ('thai',         'Thai',         'cuisine'),
    ('lyonnaise',    'Lyonnaise',    'cuisine'),
    ('french',       'French',       'cuisine'),
    ('vietnamese',   'Vietnamese',   'cuisine'),
    ('israeli',      'Israeli',      'cuisine'),
    ('open-fire',    'Open Fire',    'style'),
    ('wine-bar',     'Wine Bar',     'style'),
    ('wood-fired',   'Wood-fired',   'style'),
    ('bakery',       'Bakery',       'style'),
    ('grill',        'Grill',        'style'),
    ('nose-to-tail', 'Nose-to-Tail', 'style'),
    ('pasta',        'Pasta',        'style'),
    ('small-plates', 'Small Plates', 'style'),
    ('bistro',       'Bistro',       'style'),
    ('cafe',         'Café',         'style'),
    ('bouchon',      'Bouchon',      'style');

-- ---- restaurants -------------------------------------------------------------
INSERT INTO restaurants
    (slug, name, tagline, description, price_tier, avg_spend_min, avg_spend_max, currency,
     editorial_rating, phone, street_address, postcode, neighborhood, city,
     latitude, longitude, list_status, rank, visit_count, listing_status)
VALUES
-- Ranked (9) -------------------------------------------------------------------
    ('brat', 'Brat', 'Basque Open Fire',
     'Whole wild turbot slow-roasted on bespoke iron wood grills, smoky roasted greens, spider crab toast, and exceptional cellar list.',
     3, NULL, NULL, 'GBP', NULL, '+44 20 7946 0101',
     '4 Redchurch St', 'E1 6JL', 'Shoreditch', 'London',
     51.5246, -0.0743, 'ranked', 1, 3, 'published'),

    ('tayyabs', 'Tayyabs', 'Punjabi Grill',
     'Sizzling lamb chops straight off the tandoor, rich karahi curries and fresh naan in a buzzing, bring-your-own-bottle East End dining hall.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0102',
     '83–89 Fieldgate St', 'E1 1JU', 'Whitechapel', 'London',
     51.5172, -0.0632, 'ranked', 2, 5, 'published'),

    ('st-john', 'St. JOHN', 'Nose-to-Tail British',
     'Bone marrow and parsley salad, seasonal British game and warm madeleines baked to order in a whitewashed former smokehouse.',
     3, NULL, NULL, 'GBP', NULL, '+44 20 7946 0103',
     '26 St John St', 'EC1M 4AY', 'Barbican', 'London',
     51.5203, -0.1016, 'ranked', 3, 2, 'published'),

    ('padella', 'Padella', 'Handmade Pasta',
     'Short menu of fresh pasta rolled daily — pici cacio e pepe and slow-cooked beef shin pappardelle — beside Borough Market.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0104',
     '6 Southwark St', 'SE1 1TQ', 'London Bridge', 'London',
     51.5053, -0.0910, 'ranked', 4, 6, 'published'),

    ('bao-soho', 'BAO Soho', 'Taiwanese Buns',
     'Pillowy steamed buns stuffed with braised pork, fried chicken and confit pork, plus small Taiwanese plates and peanut milk.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0105',
     '53 Lexington St', 'W1F 9AS', 'Soho', 'London',
     51.5133, -0.1361, 'ranked', 5, 5, 'published'),

    ('dishoom-covent-garden', 'Dishoom', 'Bombay Café',
     'All-day Irani café: bacon naan rolls at breakfast, house black daal simmered for 24 hours and chai until late.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0106',
     '12 Upper St Martin''s Lane', 'WC2H 9FB', 'Covent Garden', 'London',
     51.5124, -0.1269, 'ranked', 6, 4, 'published'),

    ('xu', 'Xu', 'Taiwanese Dining',
     'Wood-panelled 1930s Taipei-style dining room serving Xu''s beef noodles, char siu pork and tea-smoked dishes.',
     3, NULL, NULL, 'GBP', NULL, '+44 20 7946 0107',
     '30 Rupert St', 'W1D 6DL', 'Soho', 'London',
     51.5115, -0.1333, 'ranked', 7, 0, 'published'),

    ('rochelle-canteen', 'Rochelle Canteen', 'British Garden Bistro',
     'Seasonal British cooking served in a walled garden behind an old school bike shed — pies, roasts and simple puddings.',
     3, NULL, NULL, 'GBP', NULL, '+44 20 7946 0108',
     'Rochelle School, Arnold Circus', 'E2 7ES', 'Shoreditch', 'London',
     51.5268, -0.0758, 'ranked', 8, 1, 'published'),

    ('brawn', 'Brawn', 'Continental Bistro',
     'Relaxed neighbourhood bistro with Italian and French plates, house charcuterie and a natural-leaning wine list.',
     3, NULL, NULL, 'GBP', NULL, '+44 20 7946 0109',
     '49 Columbia Rd', 'E2 7RG', 'Columbia Rd', 'London',
     51.5296, -0.0705, 'ranked', 9, 1, 'published'),

-- Want to try (3) — SAMPLE entries ---------------------------------------------
    ('lyles', 'Lyle''s', 'Modern British Tasting',
     'Pared-back seasonal British tasting menu in a bright former tea warehouse.',
     4, NULL, NULL, 'GBP', NULL, '+44 20 7946 0110',
     'Tea Building, 56 Shoreditch High St', 'E1 6JJ', 'Shoreditch', 'London',
     51.5236, -0.0775, 'want_to_try', NULL, 0, 'published'),

    ('smoking-goat', 'Smoking Goat', 'Thai Canteen',
     'Northern Thai drinking food cooked over charcoal — fish sauce wings, laab and smoky curries.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0111',
     '64 Shoreditch High St', 'E1 6JJ', 'Shoreditch', 'London',
     51.5240, -0.0773, 'want_to_try', NULL, 0, 'published'),

    ('kiln', 'Kiln', 'Thai Clay-Pot Grill',
     'Counter seats facing clay pots and wood grills turning out fiery Thai and Burmese-border dishes.',
     2, NULL, NULL, 'GBP', NULL, '+44 20 7946 0112',
     '58 Brewer St', 'W1F 9TL', 'Soho', 'London',
     51.5114, -0.1359, 'want_to_try', NULL, 0, 'published'),

-- Owner submission from the "Add your restaurant" form (pending review) -------
    ('brat-clodagh-and-co', 'Brat Clodagh & Co.', 'Basque Wine Bar',
     'Open wood-fired grills pairing Cornish seafood with northern Basque country culinary traditions.',
     3, 45, 60, 'EUR', 4.8, NULL,
     '4 Redchurch Street', 'E1 6JL', 'Shoreditch', 'London',
     51.5246, -0.0743, NULL, NULL, 0, 'pending');

-- ---- Lyon (4) — FICTIONAL restaurants: 2 ranked, 2 want to try ---------------
INSERT INTO restaurants
    (slug, name, tagline, description, price_tier, avg_spend_min, avg_spend_max, currency,
     editorial_rating, phone, street_address, postcode, neighborhood, city, country_code,
     latitude, longitude, list_status, rank, visit_count, listing_status)
VALUES
    ('le-bouchon-des-canuts', 'Le Bouchon des Canuts', 'Bouchon Lyonnais',
     'Nappes à carreaux et zinc patiné : quenelle de brochet sauce Nantua, tablier de sapeur, cervelle de canut et pot de côtes-du-rhône sur les pentes de la Croix-Rousse.',
     2, 28, 40, 'EUR', NULL, '+33 1 99 00 01 01',
     '14 Rue d''Austerlitz', '69004', 'Croix-Rousse', 'Lyon', 'FR',
     45.7745, 4.8320, 'ranked', 10, 3, 'published'),

    ('braise-merciere', 'Braise', 'Open-Fire Bistronomy',
     'Volaille de Bresse rôtie entière au feu de bois, légumes des Monts du Lyonnais braisés dans la cendre et belle cave de Beaujolais crus, en plein cœur de la Presqu''île.',
     3, 55, 75, 'EUR', NULL, '+33 1 99 00 01 02',
     '37 Rue Mercière', '69002', 'Presqu''île', 'Lyon', 'FR',
     45.7620, 4.8330, 'ranked', 11, 1, 'published'),

    ('comptoir-saint-georges', 'Comptoir Saint-Georges', 'Natural Wine Bar',
     'Cave à manger voûtée du Vieux Lyon : vins nature du Rhône et du Jura au verre, saucisson brioché, saint-marcellin coulant et petites assiettes du marché.',
     2, 25, 35, 'EUR', NULL, '+33 1 99 00 01 03',
     '22 Rue Saint-Georges', '69005', 'Vieux Lyon', 'Lyon', 'FR',
     45.7570, 4.8270, 'want_to_try', NULL, 0, 'published'),

    ('may-guillotiere', 'Mây', 'Vietnamese Canteen',
     'Cantine familiale de la Guillotière : phở au bouillon mijoté 12 heures, bánh xèo croustillant, bún chả grillé au charbon et café glacé au lait concentré.',
     1, 14, 22, 'EUR', NULL, '+33 1 99 00 01 04',
     '58 Grande Rue de la Guillotière', '69007', 'Guillotière', 'Lyon', 'FR',
     45.7530, 4.8440, 'want_to_try', NULL, 0, 'published');

-- ---- Israel (2) — FICTIONAL restaurants: 1 ranked, 1 want to try -------------
INSERT INTO restaurants
    (slug, name, tagline, description, price_tier, avg_spend_min, avg_spend_max, currency,
     editorial_rating, phone, street_address, postcode, neighborhood, city, country_code,
     latitude, longitude, list_status, rank, visit_count, listing_status)
VALUES
    ('gefen-neve-tzedek', 'Gefen', 'Israeli Open Fire',
     'Petite salle aux murs de pierre de Neve Tzedek : chou-fleur entier rôti à la braise, poisson du jour grillé au tahini, pita soufflée au four à bois et vins de Galilée.',
     3, 180, 260, 'ILS', NULL, NULL,
     '41 Shabazi St', '6514416', 'Neve Tzedek', 'Tel Aviv', 'IL',
     32.0612, 34.7652, 'ranked', 12, 2, 'published'),

    ('shuk-lavan', 'Shuk Lavan', 'Market Small Plates',
     'Comptoir animé en bordure du marché Mahane Yehuda : houmous tiède, brochettes grillées au charbon, salades du marché et arak glacé jusque tard dans la nuit.',
     2, 90, 140, 'ILS', NULL, NULL,
     '87 Agrippas St', '9434127', 'Mahane Yehuda', 'Jerusalem', 'IL',
     31.7853, 35.2121, 'want_to_try', NULL, 0, 'published');

-- ---- restaurant_tags (≤ 3 each, ordered) -------------------------------------
WITH v(restaurant_slug, tag_slug, position) AS (VALUES
        ('brat',                  'basque',       1),
        ('brat',                  'open-fire',    2),
        ('tayyabs',               'punjabi',      1),
        ('tayyabs',               'indian',       2),
        ('tayyabs',               'grill',        3),
        ('st-john',               'british',      1),
        ('st-john',               'nose-to-tail', 2),
        ('padella',               'italian',      1),
        ('padella',               'pasta',        2),
        ('bao-soho',              'taiwanese',    1),
        ('bao-soho',              'small-plates', 2),
        ('dishoom-covent-garden', 'indian',       1),
        ('dishoom-covent-garden', 'cafe',         2),
        ('xu',                    'taiwanese',    1),
        ('rochelle-canteen',      'british',      1),
        ('rochelle-canteen',      'bistro',       2),
        ('brawn',                 'european',     1),
        ('brawn',                 'bistro',       2),
        ('brawn',                 'wine-bar',     3),
        ('lyles',                 'british',      1),
        ('lyles',                 'small-plates', 2),
        ('smoking-goat',          'thai',         1),
        ('smoking-goat',          'wood-fired',   2),
        ('kiln',                  'thai',         1),
        ('kiln',                  'grill',        2),
        ('kiln',                  'wood-fired',   3),
        ('brat-clodagh-and-co',   'basque',       1),
        ('brat-clodagh-and-co',   'wine-bar',     2),
        ('le-bouchon-des-canuts', 'lyonnaise',    1),
        ('le-bouchon-des-canuts', 'bouchon',      2),
        ('braise-merciere',       'french',       1),
        ('braise-merciere',       'open-fire',    2),
        ('braise-merciere',       'wood-fired',   3),
        ('comptoir-saint-georges','french',       1),
        ('comptoir-saint-georges','wine-bar',     2),
        ('comptoir-saint-georges','small-plates', 3),
        ('may-guillotiere',       'vietnamese',   1),
        ('may-guillotiere',       'grill',        2),
        ('gefen-neve-tzedek',     'israeli',      1),
        ('gefen-neve-tzedek',     'open-fire',    2),
        ('gefen-neve-tzedek',     'small-plates', 3),
        ('shuk-lavan',            'israeli',      1),
        ('shuk-lavan',            'small-plates', 2),
        ('shuk-lavan',            'grill',        3)
)
INSERT INTO restaurant_tags (restaurant_id, tag_id, position)
SELECT r.id, t.id, v.position
  FROM v
  JOIN restaurants r ON r.slug = v.restaurant_slug
  JOIN tags        t ON t.slug = v.tag_slug;

-- ---- photos (3 per restaurant; position 1 is the hero image) -----------------
WITH v(slug, position, caption, alt_text) AS (VALUES
        ('brat', 1, 'Whole Turbot · Basque Wood Grill', 'Whole turbot and steaks grilling over open flames'),
        ('brat', 2, 'Snacks',                           'Grilled flatbread snacks with herbs'),
        ('brat', 3, 'Cellar & Sides',                   'Wine glasses beside a bowl of green salad'),

        ('tayyabs', 1, 'Lamb Chops · Tandoor',  'Sizzling lamb chops on a cast-iron platter'),
        ('tayyabs', 2, 'Karahi',                'Chicken karahi in a steel pan'),
        ('tayyabs', 3, 'Naan & Sides',          'Basket of naan with chutneys'),

        ('st-john', 1, 'Bone Marrow & Parsley Salad', 'Roasted bone marrow with parsley salad and toast'),
        ('st-john', 2, 'Seasonal Game',                'Plate of seasonal game with greens'),
        ('st-john', 3, 'Warm Madeleines',              'A dozen warm madeleines in a napkin'),

        ('padella', 1, 'Pici Cacio e Pepe',  'Thick pici pasta coated in pecorino and pepper'),
        ('padella', 2, 'Beef Shin Ragù',     'Pappardelle with slow-cooked beef shin'),
        ('padella', 3, 'The Counter',        'Chefs rolling pasta behind the counter'),

        ('bao-soho', 1, 'Classic Bao',       'Steamed bun with braised pork and peanut powder'),
        ('bao-soho', 2, 'Small Eats',        'Plates of Taiwanese small eats'),
        ('bao-soho', 3, 'Peanut Milk',       'Glass of peanut milk on a wooden counter'),

        ('dishoom-covent-garden', 1, 'House Black Daal',  'Bowl of black daal with naan'),
        ('dishoom-covent-garden', 2, 'Bacon Naan Roll',   'Bacon naan roll with chilli jam'),
        ('dishoom-covent-garden', 3, 'Chai',              'Cups of chai on a marble table'),

        ('xu', 1, 'Xu''s Beef Noodles', 'Bowl of beef noodle soup'),
        ('xu', 2, 'Char Siu',           'Sliced char siu pork'),
        ('xu', 3, 'Dining Room',        'Wood-panelled dining room'),

        ('rochelle-canteen', 1, 'Garden Lunch',   'Plates of lunch on a table in a walled garden'),
        ('rochelle-canteen', 2, 'Pie of the Day', 'Golden pie with greens'),
        ('rochelle-canteen', 3, 'Puddings',       'Seasonal fruit tart with cream'),

        ('brawn', 1, 'Charcuterie',     'Board of house charcuterie'),
        ('brawn', 2, 'Pasta & Greens',  'Plate of pasta with greens'),
        ('brawn', 3, 'Wine Wall',       'Shelves of natural wine bottles'),

        ('lyles', 1, 'Tasting Course',  'Minimal plated tasting course'),
        ('lyles', 2, 'Dining Room',     'Bright dining room with large windows'),
        ('lyles', 3, 'Dessert',         'Seasonal dessert on a stoneware plate'),

        ('smoking-goat', 1, 'Fish Sauce Wings', 'Glazed chicken wings'),
        ('smoking-goat', 2, 'Charcoal Grill',   'Meat grilling over charcoal'),
        ('smoking-goat', 3, 'Laab',             'Herby minced laab salad'),

        ('kiln', 1, 'Clay Pot',          'Glass noodles in a clay pot'),
        ('kiln', 2, 'Wood Grill',        'Skewers on a wood grill'),
        ('kiln', 3, 'The Counter',       'Diners at a counter facing the grills'),

        ('brat-clodagh-and-co', 1, NULL, 'Owner-submitted photo 1'),
        ('brat-clodagh-and-co', 2, NULL, 'Owner-submitted photo 2'),
        ('brat-clodagh-and-co', 3, NULL, 'Owner-submitted photo 3'),

        ('le-bouchon-des-canuts', 1, 'Quenelle · Sauce Nantua', 'Quenelle de brochet gratinée dans un plat en fonte'),
        ('le-bouchon-des-canuts', 2, 'Cervelle de Canut',       'Fromage blanc aux herbes avec pain de campagne'),
        ('le-bouchon-des-canuts', 3, 'La Salle',                'Salle de bouchon avec nappes à carreaux rouges'),

        ('braise-merciere', 1, 'Volaille de Bresse · Feu de Bois', 'Poulet rôti entier au-dessus des braises'),
        ('braise-merciere', 2, 'Légumes à la Cendre',              'Poireaux et carottes braisés dans la cendre'),
        ('braise-merciere', 3, 'La Cave',                          'Bouteilles de Beaujolais sur des étagères en bois'),

        ('comptoir-saint-georges', 1, 'Vins au Verre',     'Verres de vin nature sur un comptoir en pierre'),
        ('comptoir-saint-georges', 2, 'Saucisson Brioché', 'Tranches de saucisson brioché sur une planche'),
        ('comptoir-saint-georges', 3, 'La Voûte',          'Cave voûtée éclairée à la bougie'),

        ('may-guillotiere', 1, 'Phở Bò',        'Bol de phở au bœuf avec herbes fraîches'),
        ('may-guillotiere', 2, 'Bánh Xèo',      'Crêpe vietnamienne croustillante et salade'),
        ('may-guillotiere', 3, 'Cà Phê Sữa Đá', 'Café glacé au lait concentré'),

        ('gefen-neve-tzedek', 1, 'Chou-fleur · Braise',  'Chou-fleur entier rôti posé sur des braises'),
        ('gefen-neve-tzedek', 2, 'Poisson au Tahini',    'Poisson grillé nappé de tahini et d''herbes'),
        ('gefen-neve-tzedek', 3, 'Pita du Four',         'Pita soufflée sortant d''un four à bois'),

        ('shuk-lavan', 1, 'Houmous Tiède',   'Bol de houmous à l''huile d''olive et pois chiches'),
        ('shuk-lavan', 2, 'Brochettes',      'Brochettes grillées au charbon sur un plateau'),
        ('shuk-lavan', 3, 'Le Comptoir',     'Comptoir animé ouvert sur le marché')
)
INSERT INTO photos (restaurant_id, position, url, caption, alt_text)
SELECT r.id, v.position,
       '/media/restaurants/' || r.slug || '/0' || v.position || '.jpg',
       v.caption, v.alt_text
  FROM v
  JOIN restaurants r ON r.slug = v.slug;

-- ---- stars (review scores) ---------------------------------------------------
-- Distribution per restaurant; Brat reproduces the detail page exactly:
-- 166×5 + 18×4 = 902 / 184 = 4.90.  Others are SAMPLE distributions.
CREATE TEMP TABLE seed_star_distribution (slug TEXT, stars INTEGER, n INTEGER);
INSERT INTO seed_star_distribution (slug, stars, n) VALUES
    ('brat', 5, 166), ('brat', 4, 18),                                         -- 4.90 / 184
    ('tayyabs', 5, 210), ('tayyabs', 4, 80), ('tayyabs', 3, 22),               -- 4.60 / 312
    ('st-john', 5, 180), ('st-john', 4, 50), ('st-john', 3, 11),               -- 4.70 / 241
    ('padella', 5, 260), ('padella', 4, 120), ('padella', 3, 48),              -- 4.50 / 428
    ('bao-soho', 5, 190), ('bao-soho', 4, 110), ('bao-soho', 3, 56),           -- 4.38 / 356
    ('dishoom-covent-garden', 5, 350), ('dishoom-covent-garden', 4, 130),
    ('dishoom-covent-garden', 3, 40),                                          -- 4.60 / 520
    ('xu', 5, 120), ('xu', 4, 60), ('xu', 3, 18),                              -- 4.52 / 198
    ('rochelle-canteen', 5, 95), ('rochelle-canteen', 4, 40),
    ('rochelle-canteen', 3, 8),                                                -- 4.61 / 143
    ('brawn', 5, 100), ('brawn', 4, 55), ('brawn', 3, 12),                     -- 4.53 / 167
    ('lyles', 5, 110), ('lyles', 4, 35), ('lyles', 3, 5),                      -- 4.70 / 150
    ('smoking-goat', 5, 130), ('smoking-goat', 4, 60), ('smoking-goat', 3, 20),-- 4.52 / 210
    ('kiln', 5, 170), ('kiln', 4, 70), ('kiln', 3, 20),                        -- 4.58 / 260
    -- Lyon (fictional)
    ('le-bouchon-des-canuts', 5, 140), ('le-bouchon-des-canuts', 4, 60),
    ('le-bouchon-des-canuts', 3, 15),                                          -- 4.58 / 215
    ('braise-merciere', 5, 90), ('braise-merciere', 4, 20),
    ('braise-merciere', 3, 4),                                                 -- 4.75 / 114
    ('comptoir-saint-georges', 5, 70), ('comptoir-saint-georges', 4, 45),
    ('comptoir-saint-georges', 3, 10),                                         -- 4.48 / 125
    ('may-guillotiere', 5, 150), ('may-guillotiere', 4, 70),
    ('may-guillotiere', 3, 25), ('may-guillotiere', 2, 5),                     -- 4.46 / 250
    -- Israel (fictional)
    ('gefen-neve-tzedek', 5, 120), ('gefen-neve-tzedek', 4, 30),
    ('gefen-neve-tzedek', 3, 6),                                               -- 4.73 / 156
    ('shuk-lavan', 5, 95), ('shuk-lavan', 4, 55),
    ('shuk-lavan', 3, 15), ('shuk-lavan', 2, 3);                               -- 4.44 / 168
    -- 'brat-clodagh-and-co' is pending: no public reviews yet.

-- Expand counts into rows; created_at spread deterministically over ~2 years.
WITH RECURSIVE seq(n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 400
)
INSERT INTO stars (restaurant_id, stars, created_at, updated_at)
SELECT r.id,
       d.stars,
       strftime('%Y-%m-%dT%H:%M:%fZ', '2026-10-01',
                '-' || ((seq.n * 7 + r.id * 13 + d.stars * 31) % 700) || ' days'),
       strftime('%Y-%m-%dT%H:%M:%fZ', '2026-10-01',
                '-' || ((seq.n * 7 + r.id * 13 + d.stars * 31) % 700) || ' days')
  FROM seed_star_distribution d
  JOIN restaurants r ON r.slug = d.slug
  JOIN seq           ON seq.n <= d.n
 ORDER BY r.id, d.stars DESC, seq.n;

DROP TABLE seed_star_distribution;

COMMIT;

-- Housekeeping
PRAGMA optimize;