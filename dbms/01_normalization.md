# Normalization: Netflix Streaming Data

This version is prepared in the DE workspace so it can be moved to the AP repository. It normalizes the Netflix streaming entities represented by this project's CSV files.

## Starting point and assumptions

The original wide application record is not available; only 11 separate CSV exports remain. To show the normalization steps, the starting relation below is an **illustrative flat join** with one row per viewing event and each genre assigned to its title. It repeats account, profile, title, and genre details when a title is viewed more than once or has several genres. It is not claimed to be one of the source CSVs.

`PLAYBACK_TAG_1NF` has atomic columns:

`(view_id, genre_id, profile_id, account_id, email, plan_id, plan_name, monthly_price_inr, profile_name, title_id, title_name, title_type, maturity_rating, episode_id, season_no, episode_no, started_at, duration_watched_sec, device_type, completed, genre_name)`

Its composite key is `(view_id, genre_id)`. Relevant dependencies in this flattened relation include:

- `view_id -> profile_id, title_id, episode_id, started_at, duration_watched_sec, device_type, completed`
- `profile_id -> account_id, profile_name`
- `account_id -> email, plan_id`
- `plan_id -> plan_name, monthly_price_inr`
- `title_id -> title_name, title_type, maturity_rating`
- `genre_id -> genre_name`

## 1NF: atomic values

All attributes in `PLAYBACK_TAG_1NF` contain one value per cell; a title's genres are separate rows rather than a comma-separated list. Viewing events, ratings, My List entries, and invoices are also represented as separate row types, not packed into repeating arrays.

The table is in 1NF, but it has partial dependencies on parts of its composite key: viewing details depend on `view_id`, while a genre name depends on `genre_id`. It also repeats account, title, and profile facts across viewing rows.

## 2NF: remove partial dependencies

Split the flat relation so each attribute depends on the whole key:

| 2NF table | Columns and key |
|---|---|
| `VIEWING_2NF` | `view_id` PK, `profile_id`, `account_id`, `email`, `plan_id`, `plan_name`, `monthly_price_inr`, profile details, title details, episode details, and viewing fields. |
| `GENRE_2NF` | `genre_id` PK, `genre_name`. |
| `TITLE_GENRE_2NF` | `(title_id, genre_id)` composite PK. |

Other independent facts use their natural row identities: `RATING_2NF(profile_id, title_id, rating, rated_at)`, `MY_LIST_2NF(profile_id, title_id, added_at)`, and `INVOICE_2NF(invoice_id, account_id, billing_period_start, amount_inr, status, paid_at)`. Their composite or single-column primary keys are described in the final schema.

The multi-column `VIEWING_2NF` relation has been decomposed by `view_id`, so no non-key attribute remains dependent on only part of its key. It is in 2NF. It still has transitive dependencies: for example `view_id -> account_id -> plan_id -> plan_name, monthly_price_inr`; `view_id -> title_id -> title_name`; and `view_id -> profile_id -> profile_name`.

## 3NF: remove transitive dependencies

Split each independently identified entity into its own table and link it with foreign keys:

| Final table | Primary key | Main attributes / foreign keys |
|---|---|---|
| `plans` | `plan_id` | Plan name, price, stream limit, resolution, ads flag. |
| `accounts` | `account_id` | Email, phone, country, plan FK, signup/status and billing dates. |
| `profiles` | `profile_id` | Account FK, profile name, kids flag, maturity limit, language, creation time. |
| `titles` | `title_id` | Type, name, release year, maturity rating, language, movie runtime, original flag and dates. |
| `genres` | `genre_id` | Unique genre name. |
| `title_genres` | `(title_id, genre_id)` | Title FK and genre FK. |
| `episodes` | `episode_id` | Series title FK, season/episode numbers, title, runtime and release date. |
| `viewing_activity` | `view_id` | Profile FK, title FK, optional episode FK, playback time, duration, device and completion result. |
| `ratings` | `(profile_id, title_id)` | Profile FK, title FK, rating and time. |
| `my_list` | `(profile_id, title_id)` | Profile FK, title FK and add time. |
| `invoices` | `invoice_id` | Account FK, billing month, charged amount, status and payment time. |

In the final schema, examples of the remaining dependencies are:

- `plan_id -> plan_name, monthly_price_inr, max_streams, max_resolution, has_ads`
- `account_id -> email, phone, country_code, plan_id, signup_date, status, cancelled_on, next_billing_date`
- `profile_id -> account_id, profile_name, is_kids, maturity_limit, language, created_at`
- `title_id -> title_type, name, release_year, maturity_rating, original_language, runtime_min, is_netflix_original, added_on, leaving_on`
- `episode_id -> title_id, season_no, episode_no, episode_title, runtime_min, release_date`
- `view_id -> profile_id, title_id, episode_id, started_at, duration_watched_sec, device_type, completed`
- `(profile_id, title_id) -> rating, rated_at` and `(profile_id, title_id) -> added_at` in their respective tables
- `invoice_id -> account_id, billing_period_start, amount_inr, status, paid_at`

Plan facts are no longer duplicated on every account, account facts are not repeated on every profile or view, and title/genre facts are not repeated in each viewing row. Every non-key column depends on its table's key, not a proper subset of a composite key and not another non-key attribute. The final design is therefore in 3NF.

## BCNF (where possible)

The final tables also satisfy BCNF: every non-trivial determinant shown above is a candidate key. Additional candidate keys include `plans.plan_name`, `accounts.email`, `genres.genre_name`, `(title_id, season_no, episode_no)` for episodes, and `(account_id, billing_period_start)` for invoices. The account phone uniqueness applies only when a phone is present. Nullable values and the actual constraints are documented in the DE schema design.

## Retained facts that may look redundant

- `viewing_activity.title_id` is repeated for series plays because it can be reached through `episode_id`; it is still needed for movie plays and is used by the workload. A composite FK enforces consistency for series plays.
- `completed` is not computed from duration. In the supplied data, 20,333 playback rows disagree with a simple watched-duration-versus-runtime rule.
- `invoices.amount_inr` is the historical charge. The current plan price cannot reliably reconstruct a past billed amount after plan changes.
