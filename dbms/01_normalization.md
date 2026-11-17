# Database Normalisation Report — STOX

**Normal forms covered:** First Normal Form (1NF), Second Normal Form (2NF), Third Normal Form (3NF), and Boyce–Codd Normal Form (BCNF)  
**Database:** PostgreSQL

---

## 1. Introduction

Database normalisation is the process of organising relational tables to reduce unnecessary duplication, prevent insertion, update, and deletion anomalies, and maintain data integrity. This report explains the database design through the stages of 1NF, 2NF, 3NF, and BCNF, using examples involving users, portfolios, orders, trades, notifications, posts, alerts, and leagues.

## 2. Functional dependencies and keys

A functional dependency (FD) `X → Y` means that a value of attribute set `X` determines exactly one value of attribute set `Y`.

A **candidate key** is a minimal set of attributes that uniquely identifies a row. A **primary key** is the candidate key selected as the table's main identifier. A **superkey** is any attribute set that uniquely identifies a row, possibly with extra attributes.

Primary keys uniquely identify rows. Unique constraints define alternate candidate keys, while composite unique constraints define candidate keys made up of multiple attributes.

### 2.1 Key and functional-dependency examples

| Relation | Candidate key(s) visible in the schema | Example functional dependency |
|---|---|---|
| `User` | `id`, `email`, `googleId` (the latter two are nullable unique attributes) | `id → email, name, role, ...` |
| `Portfolio` | `id`, `(userId, name)` | `(userId, name) → description, cashBalance, ...` |
| `Holding` | `id`, `(portfolioId, symbol)` | `(portfolioId, symbol) → quantity, averageBuyPrice, ...` |
| `Order` | `id` | `id → portfolioId, symbol, side, type, status, ...` |
| `Symbol` | `id`, `symbol` | `symbol → name, assetType, exchange, ...` |
| `Trade` | `id`, `orderId` | `orderId → portfolioId, symbol, quantity, price, ...` |
| `OrderEvent` | `id`, `(orderId, sequence)` | `(orderId, sequence) → eventType, previousStatus, newStatus, ...` |
| `PerformanceSnapshot` | `id`, `(portfolioId, snapshotDate)` | `(portfolioId, snapshotDate) → totalValue, dailyPnl, ...` |
| `Follow` | `id`, `(followerId, followingId)` | `(followerId, followingId) → createdAt` |
| `CopyTrader` | `id`, `(copierId, copiedId)` | `(copierId, copiedId) → allocationPct, maxTradeSize, ...` |
| `LeaderboardSnapshot` | `id`, `(scope, period, snapshotDate)` | `(scope, period, snapshotDate) → createdAt` |
| `LeaderboardEntry` | `id`, `(scope, period, snapshotDate, userId)` | `(scope, period, snapshotDate, userId) → rank, totalValue, returnPct, ...` |
| `PostLike` | `id`, `(postId, userId)` | `(postId, userId) → createdAt` |
| `UserPreference` | `id`, `userId` | `userId → emailNotifications, pushNotifications, ...` |
| `SentimentVote` | `id`, `(userId, symbol)` | `(userId, symbol) → sentiment, updatedAt` |
| `Achievement` | `id`, `code` | `code → name, description, category, ...` |
| `UserAchievement` | `id`, `(userId, achievementId)` | `(userId, achievementId) → unlockedAt` |
| `LeagueMember` | `id`, `(leagueId, userId)`, `portfolioId` | `(leagueId, userId) → portfolioId, rank, finalReturn, ...` |

Other relations, including `RefreshToken`, `Notification`, `Alert`, `Post`, and `League`, use their `id` as the candidate key. Foreign keys connect these relations without copying full parent records into child tables.

**Nullable unique keys:** PostgreSQL normally permits multiple `NULL` values in a unique constraint. Thus, `User.email` and `User.googleId` are alternate unique identifiers when populated, but their nullable status matters when interpreting them as candidate keys.

---

## 3. First Normal Form (1NF)

A relation is in **1NF** when:

1. Each row represents one record.
2. Each column contains a single value from its declared domain.
3. There are no repeating groups or arrays of values stored as separate repeated columns.
4. Each row can be uniquely identified.

### 3.1 Applying 1NF to the database

Ordinary attributes use scalar PostgreSQL data types:

- `String`, `Int`, `Boolean`, `DateTime`, and `Decimal`
- Enum values such as `OrderStatus`, `AssetType`, and `Role`
- Primary keys such as `User.id`, `Portfolio.id`, and `Order.id`

For example, a `Holding` row stores one portfolio ID, one symbol, one asset type, one quantity, and one average purchase price. Multiple holdings are represented as multiple rows, rather than as columns such as `symbol1`, `symbol2`, and `symbol3`.

Repeating relationships are represented in their own tables:

- A user's many portfolios are represented by `Portfolio.userId`.
- A post's many likes are represented by `PostLike`.
- A user's many followers/following relationships are represented by `Follow`.
- A league's many participants are represented by `LeagueMember`.
- A user's many unlocked achievements are represented by `UserAchievement`.

### 3.2 JSON fields and the 1NF qualification

The database design includes JSON fields, for example:

- `OrderEvent.metadata`
- `Notification.data` and `Notification.deliveryChannels`
- `Post.metadata`
- `Achievement.criteria`

PostgreSQL stores each JSON/JSONB document as one column value, so it is one value at the SQL column level. However, if an application stores repeating business facts inside a JSON array or nested object and needs to query or constrain those facts as independent relational attributes, those facts may be better represented by child tables.

**1NF conclusion:** The relational columns and relationship tables follow the intended 1NF structure. JSON fields are flexible document attributes; if individual nested values need relational constraints or independent querying, they should be represented by separate relations.

---

## 4. Second Normal Form (2NF)

A relation is in **2NF** when:

1. It is already in 1NF.
2. Every non-prime attribute is fully functionally dependent on every candidate key.
3. No non-key attribute depends on only part of a composite candidate key.

A partial dependency can occur only when a candidate key contains multiple attributes.

### 4.1 Example: `Holding`

The schema defines:

- Primary key: `id`
- Composite unique key: `(portfolioId, symbol)`

The business dependency is:

`(portfolioId, symbol) → quantity, assetType, averageBuyPrice, totalInvested, isShort`

The holding details depend on the complete portfolio-and-symbol combination. The schema does not declare that `portfolioId` alone determines the holding's quantity or that `symbol` alone determines its holding quantity.

The portfolio's name and owner are not repeated in `Holding`; they are stored in `Portfolio` and reached through `portfolioId`.

### 4.2 Example: `Follow`

The relation uses `(followerId, followingId)` as a composite unique key.

`(followerId, followingId) → createdAt`

The relationship record is identified by the complete pair. Neither participant ID by itself identifies a particular follow relationship.

### 4.3 Other composite-key relations

The same pattern appears in:

- `OrderEvent`: `(orderId, sequence)`
- `PerformanceSnapshot`: `(portfolioId, snapshotDate)`
- `CopyTrader`: `(copierId, copiedId)`
- `PostLike`: `(postId, userId)`
- `SentimentVote`: `(userId, symbol)`
- `UserAchievement`: `(userId, achievementId)`
- `LeagueMember`: `(leagueId, userId)`

In these tables, the non-key attributes describe the complete relationship or event identified by the composite key.

**2NF conclusion:** Relationship-specific attributes depend on the complete composite key. Surrogate `id` primary keys do not remove the importance of composite unique constraints, which express the business candidate keys.

---

## 5. Third Normal Form (3NF)

A relation is in **3NF** when:

1. It is already in 2NF.
2. No non-key attribute has a transitive dependency on a candidate key through another non-key attribute.

Informally, non-key attributes should describe the key, the whole key, and nothing but the key.

### 5.1 Example: `Portfolio` and `User`

A poorly structured design might store user details in every portfolio row:

| portfolioId | userId | userEmail | userName | portfolioName |
|---|---|---|---|---|
| P1 | U1 | user@example.com | Alex | Main |
| P2 | U1 | user@example.com | Alex | Long-term |

The dependencies would include:

- `portfolioId → userId, portfolioName`
- `userId → userEmail, userName`

Therefore, `portfolioId → userId → userEmail, userName` is a transitive dependency. Updating the user's email would require changing multiple portfolio rows.

The database separates these facts:

- `User(id, email, name, ...)`
- `Portfolio(id, userId, name, ...)`

Now user details are stored once in `User`, and `Portfolio.userId` references the owner.

### 5.2 Example: `Order` and `Trade`

The schema separates order instructions from execution records:

- `Order` stores order type, side, status, requested quantity, limit/stop prices, and expiry information.
- `Trade` stores execution information such as executed quantity, price, fees, total value, and realised P&L.

`Trade.orderId` is unique and references `Order.id`, making the relationship one-to-zero-or-one at the database level.

This separation avoids mixing the order lifecycle and the resulting execution record into one large relation. The `Trade` table does repeat some descriptive values (`portfolioId`, `symbol`, `assetType`, and `side`) that also exist on `Order`. Because `orderId` is unique in `Trade`, these values are functionally dependent on a candidate key of `Trade`; this duplication is therefore not, by itself, a 3NF violation within `Trade`. It is nevertheless a cross-table consistency consideration. If these values are intended to be identical to the referenced order forever, they could instead be derived through the order relationship. If they are retained as an execution-time record, the application should keep their meaning clear.

### 5.3 Other examples of entity separation

- `Symbol` stores instrument metadata once; `Alert` references it through `symbolId`.
- `Achievement` stores achievement definitions; `UserAchievement` stores which user unlocked which achievement.
- `League` stores competition details; `LeagueMember` stores participation.
- `Post` stores post content; `PostLike` stores user interactions.
- `User` stores account details; `UserPreference` stores notification preferences.

**3NF conclusion:** Independently meaningful entities are separated and referenced through foreign keys. This avoids common transitive dependencies, such as copying user, symbol, achievement, or league descriptions into every related row.

---

## 6. Boyce–Codd Normal Form (BCNF)

A relation is in **BCNF** when, for every non-trivial functional dependency:

`X → Y`

`X` must be a superkey.

BCNF is stricter than 3NF. A relation can satisfy 3NF but fail BCNF if a determinant is not a superkey, even when the dependent attributes are prime attributes.

### 6.1 Potential BCNF issue: `LeaderboardEntry`

The `Holding` relation defines:

- `LeaderboardSnapshot.id` as the primary key.
- `(scope, period, snapshotDate)` as a unique key in `LeaderboardSnapshot`.
- `LeaderboardEntry.snapshotId` as a foreign key to `LeaderboardSnapshot.id`.
- `LeaderboardEntry` also stores `scope`, `period`, and `snapshotDate`.
- `(scope, period, snapshotDate, userId)` is unique in `LeaderboardEntry`.

The intended business rule is that a snapshot ID identifies one snapshot, and therefore determines its scope, period, and date:

`snapshotId → scope, period, snapshotDate`

However, in `LeaderboardEntry`, `snapshotId` alone is **not** declared as a superkey because many users can have entries for one snapshot. Under this intended functional dependency, `LeaderboardEntry` does not satisfy BCNF.

This dependency is a semantic assumption based on the meaning of a leaderboard snapshot. The current database design has a foreign key on `snapshotId`, but it does not itself enforce that the copied `scope`, `period`, and `snapshotDate` values in each entry match the referenced snapshot row.

### 6.2 BCNF decomposition for the leaderboard

A cleaner BCNF design is to store the snapshot-level attributes only in `LeaderboardSnapshot`, and keep the entry-specific attributes in `LeaderboardEntry`.

**LeaderboardSnapshot**

| Attribute | Meaning |
|---|---|
| `id` (PK) | Snapshot identifier |
| `scope` | Global or friends |
| `period` | Daily, weekly, monthly, all-time |
| `snapshotDate` | Date represented by the snapshot |
| `createdAt` | Snapshot creation time |

Candidate keys:

- `id`
- `(scope, period, snapshotDate)`

**LeaderboardEntry (decomposed)**

| Attribute | Meaning |
|---|---|
| `id` (PK) | Entry identifier |
| `snapshotId` (FK) | Parent snapshot |
| `userId` (FK) | Ranked user |
| `rank` | User's rank in this snapshot |
| `totalValue` | Portfolio value used for ranking |
| `returnPct` | Return percentage |

Candidate keys:

- `id`
- `(snapshotId, userId)`

The entry relation now has the dependency:

`(snapshotId, userId) → rank, totalValue, returnPct`

The determinant is a candidate key, so the relation satisfies BCNF under the stated dependencies.

The uniqueness constraint `(snapshotId, userId)` prevents the same user from appearing more than once in a snapshot. Snapshot scope, period, and date are obtained by joining to `LeaderboardSnapshot`.

### 6.3 Other relations

For the other relations, the functional dependencies represented by their primary and unique keys have candidate keys or superkeys as determinants. For example:

- `Symbol.symbol → name, assetType, exchange, ...`, where `symbol` is unique.
- `UserPreference.userId → emailNotifications, pushNotifications, ...`, where `userId` is unique.
- `Achievement.code → name, description, category, ...`, where `code` is unique.
- `Portfolio(userId, name) → description, balances, ...`, where `(userId, name)` is unique.

No additional non-key determinant is apparent from the database alone. This assessment depends on the functional dependencies actually guaranteed by the database and business rules; a database design cannot enumerate every possible domain-specific dependency.

**BCNF conclusion:** The database is largely structured around key-based dependencies. A potential BCNF exception is the duplicated snapshot descriptor in `LeaderboardEntry`, assuming `snapshotId` determines `scope`, `period`, and `snapshotDate`. Removing those repeated attributes and using `(snapshotId, userId)` as the entry's composite unique key resolves that issue.

---

## 7. Normalisation summary

| Normal form | Requirement | Assessment of database |
|---|---|---|
| **1NF** | Atomic column values; no relational repeating groups | Ordinary scalar attributes and relationship tables follow 1NF. JSON columns need care if nested values are treated as independent relational facts. |
| **2NF** | No partial dependency on part of a composite candidate key | Composite relationship/event keys are defined with attributes describing the complete pair or combination. |
| **3NF** | No transitive dependency of non-key attributes on a key | Major entities are separated and connected using foreign keys, reducing repeated descriptive data. |
| **BCNF** | Every determinant in every non-trivial FD is a superkey | Most declared dependencies are key-based. `LeaderboardEntry` has a potential BCNF issue due to repeated snapshot descriptors. |

## 8. Recommended BCNF decomposition

For a strict BCNF-oriented design, consider changing `LeaderboardEntry` as follows:

1. Remove `scope`, `period`, and `snapshotDate` from `LeaderboardEntry`.
2. Retain `snapshotId` as a foreign key to `LeaderboardSnapshot`.
3. Add a composite unique constraint on `(snapshotId, userId)`.
4. Query snapshot scope, period, and date through the related `LeaderboardSnapshot` row.

Conceptual PostgreSQL shape:

```sql
CREATE TABLE "LeaderboardEntry" (
    "id" TEXT PRIMARY KEY,
    "snapshotId" TEXT NOT NULL
        REFERENCES "LeaderboardSnapshot" ("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    "userId" TEXT NOT NULL
        REFERENCES "User" ("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    "rank" INTEGER NOT NULL,
    "totalValue" DECIMAL(18,8) NOT NULL,
    "returnPct" DECIMAL(10,4) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "LeaderboardEntry_snapshotId_userId_key"
        UNIQUE ("snapshotId", "userId")
);
```

This is a conceptual target definition for the normalised relation. An implementation would need to preserve existing rows and update queries, foreign-key relationships, and unique/index definitions carefully.

## 9. Final conclusion

The STOX database follows a normalised relational design: users, portfolios, holdings, orders, trades, market symbols, notifications, social interactions, achievements, and leagues are represented as separate relations connected through primary and foreign keys. Composite unique constraints prevent duplicate relationship records and express important candidate keys.

The database meets the intended 1NF and 2NF structure, and its entity separation supports 3NF. For BCNF, the main issue to examine is `LeaderboardEntry`: if `snapshotId` determines the repeated `scope`, `period`, and `snapshotDate` values, those attributes should be stored only in `LeaderboardSnapshot`. The proposed decomposition removes that redundancy and gives the entry relation key-based functional dependencies.

**Overall:** The database is substantially normalised, with a specific leaderboard decomposition recommended to achieve a cleaner BCNF design.
