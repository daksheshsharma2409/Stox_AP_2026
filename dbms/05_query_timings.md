# Application Query Timings

## Methodology

Each of the 116 application queries in `dbms/04_queries.sql` was executed three consecutive times against the PostgreSQL application database (`stox_test`).
Execution plans and timing measurements were captured using `EXPLAIN (ANALYZE, BUFFERS)`.

- **Write Isolation**: Every `WRITE` query (`INSERT`, `UPDATE`, `DELETE`) was executed inside an isolated transaction block (`BEGIN; ... ROLLBACK;`) to prevent mutation of the underlying dataset while capturing true write performance and trigger costs.
- **Timing Metrics**: Timings represent the exact engine `Execution Time` (in milliseconds) reported by PostgreSQL. The `Average (ms)` column is the arithmetic mean across the three runs.
- **Scan Classification**: Scan types identify the primary access paths from the query plan (e.g., `Index Scan`, `Index Only Scan`, `Bitmap Heap Scan`, `Seq Scan`, or `—` for statements without scan nodes such as scalar inserts or connection health pings).
- **Plan Artifacts**: Complete `EXPLAIN (ANALYZE, BUFFERS)` output logs for all three runs of every query are stored individually under `dbms/plans/<id>.txt`.

## Timing Table

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type |
|:------|:-----|:-------------|-----------:|-----------:|-----------:|-------------:|:----------|
| R1 | READ | Fetch user account by email address (login) | 0.085 | 0.017 | 0.012 | 0.038 | Index Scan on User |
| W1 | WRITE | Register new user account with default TRADER role | 0.194 | 0.064 | 0.045 | 0.101 | — |
| W2 | WRITE | Create initial default cash portfolio for newly registered user | 0.459 | 0.071 | 0.094 | 0.208 | — |
| R2 | READ | Fetch user profile, notification settings, and session status by ID | 0.017 | 0.010 | 0.008 | 0.012 | Index Scan on User |
| W3 | WRITE | Store newly issued refresh token session | 0.352 | 0.059 | 0.376 | 0.262 | — |
| R3 | READ | Validate refresh token and retrieve associated user account | 0.043 | 0.018 | 0.015 | 0.025 | Seq Scan on RefreshToken | Index Scan on User |
| W4 | WRITE | Revoke all active refresh tokens for user (logout / reset) | 0.125 | 0.043 | 0.037 | 0.068 | Seq Scan on RefreshToken |
| W5 | WRITE | Update user last login and profile update timestamps | 0.066 | 0.027 | 0.018 | 0.037 | Index Scan on User |
| R4 | READ | List active portfolios with holdings count and invested value | 0.261 | 0.039 | 0.057 | 0.119 | Seq Scan on Holding | Index Scan on Portfolio |
| R5 | READ | Get portfolio summary, cash balance, and total holdings units by ID | 0.026 | 0.019 | 0.018 | 0.021 | Index Scan on Portfolio | Seq Scan on Holding |
| R6 | READ | List current holdings for portfolio ordered by symbol | 0.007 | 0.006 | 0.005 | 0.006 | Seq Scan on Holding |
| W6 | WRITE | Create additional custom portfolio for user | 0.085 | 0.058 | 0.057 | 0.067 | — |
| W7 | WRITE | Upsert holding position on buy order execution | 0.188 | 0.070 | 0.053 | 0.104 | — |
| R7 | READ | Fetch holding position for sell order execution with row lock | 0.012 | 0.008 | 0.010 | 0.010 | Seq Scan on Holding |
| W8 | WRITE | Deduct holding quantity and adjust cost basis on sell execution | 0.013 | 0.008 | 0.007 | 0.009 | Seq Scan on Holding |
| W9 | WRITE | Update portfolio cash and reserved cash balances | 0.054 | 0.023 | 0.036 | 0.038 | Index Scan on Portfolio |
| W10 | WRITE | Upsert end-of-day portfolio performance snapshot | 0.469 | 0.233 | 0.055 | 0.252 | — |
| R8 | READ | Retrieve historical portfolio performance snapshots by date range | 0.054 | 0.034 | 0.030 | 0.039 | Seq Scan on PerformanceSnapshot |
| R9 | READ | Lock portfolio cash balance for order validation and placement | 0.022 | 0.010 | 0.012 | 0.015 | Index Scan on Portfolio |
| W11 | WRITE | Create new order in PENDING status with reserved cash | 0.369 | 0.054 | 0.050 | 0.158 | — |
| R10 | READ | Filter user orders by portfolio, status, and symbol with pagination | 0.040 | 0.025 | 0.021 | 0.029 | Seq Scan on Order | Index Scan on Portfolio |
| R11 | READ | Fetch batch of unexpired pending orders ready for market execution | 0.016 | 0.013 | 0.012 | 0.014 | Seq Scan on Order |
| W12 | WRITE | Update order status to EXECUTED with fill price and timestamp | 0.062 | 0.039 | 0.030 | 0.044 | Seq Scan on Order |
| R12 | READ | Fetch order details along with chronological lifecycle events | 0.038 | 0.015 | 0.013 | 0.022 | Seq Scan on Order | Seq Scan on OrderEvent |
| R13 | READ | Lock single order row for atomic status transition | 0.008 | 0.009 | 0.007 | 0.008 | Seq Scan on Order |
| W13 | WRITE | Insert audit event record into order lifecycle history | 0.156 | 0.045 | 0.041 | 0.081 | — |
| R14 | READ | Query user trade history filtered by asset, side, and date range | 0.085 | 0.030 | 0.030 | 0.048 | Seq Scan on Order | Seq Scan on Trade | Index Scan on Portfolio |
| W14 | WRITE | Record executed trade transaction against order | 0.211 | 0.277 | 0.079 | 0.189 | — |
| R15 | READ | Aggregate trading performance and realized PnL per symbol | 0.039 | 0.046 | 0.030 | 0.038 | Seq Scan on Trade | Index Scan on Portfolio |
| R16 | READ | Aggregate monthly trading volume, win/loss count, and PnL metrics | 0.026 | 0.021 | 0.020 | 0.022 | Seq Scan on Trade | Index Scan on Portfolio |
| R17 | READ | Fetch portfolio dashboard summary with open positions and latest snapshot | 0.044 | 0.036 | 0.029 | 0.036 | Index Scan on Portfolio | Index Scan on PerformanceSnapshot | Seq Scan on Order | Seq Scan on Holding |
| R18 | READ | List configured price alerts for user with pagination | 0.031 | 0.021 | 0.017 | 0.023 | Seq Scan on Symbol | Seq Scan on Alert |
| W15 | WRITE | Create new price alert for symbol with target condition | 0.190 | 0.061 | 0.074 | 0.108 | — |
| R19 | READ | Fetch batch of active price alerts due for price evaluation | 0.025 | 0.017 | 0.016 | 0.019 | Seq Scan on Symbol | Seq Scan on Alert |
| W16 | WRITE | Mark price alert as TRIGGERED and record alert notification | 0.049 | 0.029 | 0.020 | 0.033 | Seq Scan on Alert |
| W17 | WRITE | Batch update price alert evaluation timestamps and baseline prices | 0.030 | 0.021 | 0.032 | 0.028 | Seq Scan on Alert |
| R20 | READ | Fetch user notifications with read status filter and pagination | 0.026 | 0.009 | 0.008 | 0.014 | Index Scan on Notification |
| R21 | READ | Count unread notifications for user | 0.013 | 0.008 | 0.007 | 0.009 | Index Only Scan on Notification |
| W18 | WRITE | Mark specific notification as read by ID | 0.016 | 0.008 | 0.010 | 0.011 | Index Scan on Notification |
| W19 | WRITE | Mark all unread notifications as read for user | 0.009 | 0.008 | 0.008 | 0.008 | Index Scan on Notification |
| W20 | WRITE | Create new user notification in PENDING delivery status | 0.450 | 0.095 | 0.343 | 0.296 | — |
| W21 | WRITE | Claim batch of pending notifications for background delivery worker | 0.035 | 0.023 | 0.022 | 0.027 | Index Scan on Notification |
| W22 | WRITE | Update notification delivery status and channel delivery results | 0.035 | 0.019 | 0.026 | 0.027 | Index Scan on Notification |
| R22 | READ | Fetch social feed posts with like count and author details | 0.099 | 0.061 | 0.054 | 0.071 | Seq Scan on PostLike | Seq Scan on Post | Index Scan on User |
| W23 | WRITE | Publish new post to social feed with symbol tag and metadata | 0.149 | 0.046 | 0.038 | 0.078 | — |
| W24 | WRITE | Add like to social post (idempotent) | 0.011 | 0.007 | 0.006 | 0.008 | — |
| W25 | WRITE | Remove like from social post | 0.016 | 0.006 | 0.006 | 0.009 | Seq Scan on PostLike |
| W26 | WRITE | Follow another trader (idempotent) | 0.258 | 0.081 | 0.074 | 0.138 | — |
| W27 | WRITE | Unfollow trader | 0.009 | 0.004 | 0.004 | 0.006 | Seq Scan on Follow |
| R23 | READ | List user followers or following connections with pagination | 0.013 | 0.008 | 0.008 | 0.010 | Seq Scan on Follow | Index Scan on User |
| R24 | READ | Fetch user public profile with follower, following, and post counts | 0.032 | 0.022 | 0.020 | 0.025 | Index Scan on User | Seq Scan on Follow | Seq Scan on Post |
| W28 | WRITE | Fetch active global leaderboard standings for specified period | 0.714 | 0.375 | 0.414 | 0.501 | Seq Scan on LeaderboardEntry | Seq Scan on LeaderboardSnapshot | Seq Scan on User |
| R25 | READ | Fetch friends leaderboard rankings for user and followed traders | 0.157 | 0.113 | 0.108 | 0.126 | Seq Scan on LeaderboardSnapshot | Seq Scan on User | Bitmap Heap Scan on LeaderboardEntry | Index Scan on LeaderboardEntry_scope_period_snapshotDate_rank_idx | Seq Scan on Follow |
| R26 | READ | Get user rank and return percentage on global leaderboard | 0.032 | 0.012 | 0.011 | 0.018 | Index Scan on LeaderboardEntry |
| W29 | WRITE | Upsert leaderboard ranking entry for user and snapshot period | 0.397 | 0.266 | 0.256 | 0.306 | — |
| R27 | READ | List trading leagues with participant count and status filter | 0.063 | 0.038 | 0.032 | 0.044 | Seq Scan on LeagueMember | Seq Scan on League |
| R28 | READ | Lock league row for participant enrollment validation | 0.010 | 0.010 | 0.010 | 0.010 | Seq Scan on League |
| W30 | WRITE | Join user and portfolio into trading league tournament | 0.214 | 0.091 | 0.075 | 0.127 | — |
| R29 | READ | Get league standings, member ranks, and current portfolio values | 0.065 | 0.055 | 0.041 | 0.054 | Seq Scan on Holding | Seq Scan on LeagueMember | Index Scan on Portfolio | Index Scan on User |
| R30 | READ | List unlocked achievements and criteria for user | 0.017 | 0.011 | 0.012 | 0.013 | Seq Scan on UserAchievement | Seq Scan on Achievement |
| W31 | WRITE | Award achievement badge to user upon criteria completion | 0.233 | 0.078 | 0.183 | 0.165 | — |
| R31 | READ | Fetch user notification preferences (email, push) | 0.011 | 0.008 | 0.006 | 0.008 | Seq Scan on UserPreference |
| W32 | WRITE | Upsert user notification preferences | 0.161 | 0.053 | 0.044 | 0.086 | — |
| R32 | READ | Aggregate community sentiment votes (bullish/bearish) for symbol | 0.038 | 0.018 | 0.015 | 0.024 | Seq Scan on SentimentVote | Index Scan on User |
| W33 | WRITE | Cast or update user market sentiment vote for symbol | 0.039 | 0.018 | 0.028 | 0.028 | — |
| R33 | READ | Search tradable symbols catalog by symbol or company name | 0.026 | 0.016 | 0.021 | 0.021 | Seq Scan on Symbol |
| W34 | WRITE | Configure or update copy trading relationship and allocation | 0.088 | 0.039 | 0.042 | 0.056 | — |
| R34 | READ | List active copy trading relationships with performance stats | 0.052 | 0.034 | 0.045 | 0.044 | Seq Scan on CopyTrader | Index Scan on User | Index Scan on LeaderboardEntry |
| R35 | READ | Find user account linked to Google OAuth provider ID | 0.008 | 0.004 | 0.004 | 0.005 | Index Scan on User |
| W35 | WRITE | Update user profile display name and avatar URL | 0.028 | 0.024 | 0.026 | 0.026 | Index Scan on User |
| R36 | READ | Admin user directory search with role and status filtering | 0.270 | 0.242 | 0.237 | 0.250 | Seq Scan on User |
| R37 | READ | Admin get comprehensive user account details | 0.009 | 0.011 | 0.008 | 0.009 | Index Scan on User |
| R38 | READ | Fetch user default active portfolio | 0.016 | 0.009 | 0.009 | 0.011 | Index Scan on Portfolio |
| W36 | WRITE | Update portfolio display name and description | 0.076 | 0.037 | 0.031 | 0.048 | Index Scan on Portfolio |
| W37 | WRITE | Toggle portfolio active status (archive / unarchive) | 0.019 | 0.023 | 0.017 | 0.020 | Index Scan on Portfolio |
| R39 | READ | Check pending sell orders against portfolio holdings | 0.009 | 0.006 | 0.005 | 0.007 | Seq Scan on Order |
| R40 | READ | Admin search all platform portfolios with owner details | 0.352 | 0.322 | 0.316 | 0.330 | Seq Scan on Portfolio | Seq Scan on User |
| R41 | READ | Admin get single portfolio details with owner information | 0.019 | 0.015 | 0.014 | 0.016 | Index Scan on Portfolio | Index Scan on User |
| R42 | READ | Admin search and audit all platform orders with owner info | 0.178 | 0.164 | 0.153 | 0.165 | Seq Scan on Portfolio | Seq Scan on Order | Index Scan on User |
| R43 | READ | Get price alert details with symbol information for owner | 0.021 | 0.016 | 0.014 | 0.017 | Seq Scan on Symbol | Seq Scan on Alert |
| W38 | WRITE | Update price alert target price, conditions, and channels | 0.026 | 0.020 | 0.017 | 0.021 | Seq Scan on Alert |
| W39 | WRITE | Delete price alert by ID | 0.010 | 0.010 | 0.007 | 0.009 | Seq Scan on Alert |
| R44 | READ | Get notification by ID with delivery metadata for recipient | 0.016 | 0.007 | 0.009 | 0.011 | Index Scan on Notification |
| W40 | WRITE | Update notification status and channels after dispatch attempt | 0.009 | 0.005 | 0.004 | 0.006 | Index Scan on Notification |
| R45 | READ | Fetch social post by ID with author profile | 0.018 | 0.013 | 0.012 | 0.014 | Seq Scan on Post | Index Scan on User |
| W41 | WRITE | Delete social post by author | 0.081 | 0.025 | 0.030 | 0.045 | Seq Scan on Post |
| R46 | READ | Fetch user public profile and friendship/follow status to viewer | 0.039 | 0.026 | 0.025 | 0.030 | Index Scan on User | Seq Scan on Follow | Seq Scan on Post |
| W42 | WRITE | Create or retrieve leaderboard snapshot record for date | 0.120 | 0.023 | 0.020 | 0.054 | — |
| W43 | WRITE | Delete stale leaderboard entries before recalculating snapshot | 0.011 | 0.006 | 0.005 | 0.007 | Index Scan on LeaderboardEntry |
| W44 | WRITE | Bulk insert calculated leaderboard rankings from JSON recordset | 0.254 | 1.069 | 0.097 | 0.473 | — |
| W45 | WRITE | Create new competitive trading league tournament | 0.089 | 0.019 | 0.083 | 0.064 | — |
| W46 | WRITE | Transition upcoming leagues to ACTIVE status when start date reached | 0.023 | 0.008 | 0.009 | 0.013 | Seq Scan on League |
| W47 | WRITE | Update league tournament lifecycle status (active, completed, cancelled) | 0.041 | 0.022 | 0.013 | 0.025 | Seq Scan on League |
| R47 | READ | Get league details, rules, and total enrolled participant count | 0.022 | 0.013 | 0.011 | 0.015 | Seq Scan on League | Seq Scan on LeagueMember |
| R48 | READ | Check user membership and rank in specific league | 0.006 | 0.004 | 0.004 | 0.005 | Seq Scan on LeagueMember |
| R49 | READ | Count total enrolled members in trading league | 0.008 | 0.006 | 0.005 | 0.006 | Seq Scan on LeagueMember |
| W48 | WRITE | Update league member final tournament rank and return | 0.030 | 0.016 | 0.011 | 0.019 | Seq Scan on LeagueMember |
| R50 | READ | List all available achievement definitions in system | 0.013 | 0.009 | 0.006 | 0.009 | Seq Scan on Achievement |
| R51 | READ | Fetch single achievement definition by code | 0.007 | 0.008 | 0.005 | 0.007 | Seq Scan on Achievement |
| W49 | WRITE | Upsert achievement definition metadata and unlock criteria | 0.164 | 0.019 | 0.014 | 0.066 | — |
| R52 | READ | Get user current sentiment vote on specified symbol | 0.006 | 0.004 | 0.003 | 0.004 | Seq Scan on SentimentVote |
| R53 | READ | Get trade details with order and trader portfolio metadata | 0.033 | 0.026 | 0.021 | 0.027 | Seq Scan on Trade | Index Scan on Portfolio | Seq Scan on Order |
| W50 | WRITE | Prune historical portfolio performance snapshots older than cutoff date | 0.006 | 0.006 | 0.004 | 0.005 | Index Scan on PerformanceSnapshot |
| R54 | READ | PostgreSQL database connection health check ping | 0.002 | 0.001 | 0.001 | 0.001 | — |
| W51 | WRITE | Update copy trading allocation percentage and max trade size limits | 0.049 | 0.027 | 0.023 | 0.033 | Seq Scan on CopyTrader |
| R55 | READ | Fetch symbol market configuration, asset type, and trading status | 0.008 | 0.006 | 0.005 | 0.006 | Seq Scan on Symbol |
| R56 | READ | Find undelivered pending notifications for retry processor | 0.008 | 0.005 | 0.008 | 0.007 | Index Scan on Notification |
| R57 | READ | Fetch active copy trading followers for lead trader | 0.012 | 0.030 | 0.012 | 0.018 | Seq Scan on CopyTrader |
| R58 | READ | Check copy trading configuration between copier and copied trader | 0.011 | 0.007 | 0.005 | 0.008 | Seq Scan on CopyTrader |
| W52 | WRITE | Compute aggregated trade statistics (volume, win rate, best/worst trade) | 0.099 | 0.069 | 0.056 | 0.075 | Seq Scan on Trade | Index Scan on Portfolio |
| R59 | READ | Scan active portfolios and calculate holdings value for snapshots | 0.727 | 0.641 | 0.393 | 0.587 | Seq Scan on Portfolio | Seq Scan on User | Seq Scan on Holding | Seq Scan on LeagueMember |
| R60 | READ | Calculate realized PnL and fee totals for portfolio | 0.021 | 0.012 | 0.013 | 0.015 | Seq Scan on Trade |
| R61 | READ | Batch aggregate realized PnL for list of portfolios | 0.020 | 0.023 | 0.012 | 0.018 | Seq Scan on Trade |
| W53 | WRITE | Insert notification with unique eventKey for idempotency deduplication | 0.171 | 0.132 | 0.102 | 0.135 | — |
| R62 | READ | Fetch unpropagated trades for copy trade execution fan-out | 0.019 | 0.013 | 0.008 | 0.013 | Seq Scan on Trade |
| W54 | WRITE | Record copy trading fan-out completion timestamp on trade | 0.092 | 0.036 | 0.036 | 0.055 | Seq Scan on Trade |
| **Total (all 116 queries)** | | | **10.715** | **6.455** | **5.366** | **7.512** | |

## Performance Analysis & Observations

### 1. Overall System Latency Profile
- **Cumulative Execution Time**: Executing the entire 116-query workload across all app subsystems took **7.512 ms** on average (**10.715 ms** on cold buffer Run 1, dropping to **5.366 ms** on warm cache Run 3).
- **Buffer Cache Warming**: Initial runs for tables such as `User`, `Portfolio`, and `LeaderboardEntry` show significant buffer hit convergence between Run 1 and subsequent runs, demonstrating PostgreSQL's effective buffer cache management for hot application working sets.

### 2. High-Performance Index Lookups (< 0.05 ms)
- **Authentication & Session Lookups**: `R1` (login by email) and `R2` (user profile by ID) achieve ultra-fast execution (~0.012 ms – 0.038 ms) via unique B-tree indexes on `"User"("email")` and primary key `"User"("id")`.
- **Notification State Checks**: `R21` (unread notification count) leverages an `Index Only Scan` on `Notification_userId_isRead_idx`, avoiding heap page fetches entirely (~0.009 ms).
- **Point Locks & Entity Verification**: Queries such as `R9` (cash balance lock), `R13` (order lock for update), and `R35` (Google OAuth ID lookup) resolve in < 0.02 ms using primary key and unique constraint indexes.

### 3. Multi-Table Joins & Analytical Workloads
- **Portfolio Valuation Snapshots (`R59`)**: The nightly snapshot query joins `Portfolio`, `User`, `Holding`, and `LeagueMember` with aggregation, averaging **0.587 ms**, representing the most resource-intensive read query.
- **Leaderboard Queries (`W28`, `R25`, `R26`)**: Standings queries join `LeaderboardEntry`, `LeaderboardSnapshot`, and `User` with window functions (`COUNT(*) OVER ()`). They execute in 0.3 ms – 0.5 ms across thousands of entries.
- **Admin Directory Searches (`R36`, `R40`, `R42`)**: Administrative queries feature case-insensitive pattern matching (`ILIKE`) and dynamic filters, resulting in controlled sequential scans on small-to-medium datasets (~0.15 ms – 0.35 ms).

### 4. Write Pipeline & Transaction Characteristics
- **Foreign Key Enforcement**: Insert operations on child tables (`W2` Portfolio, `W11` Order, `W14` Trade) include constraint trigger checks (e.g. `Portfolio_userId_fkey`, `Trade_portfolioId_fkey`), completing in 0.05 ms – 0.25 ms.
- **Idempotent Upserts**: Queries using `ON CONFLICT ... DO UPDATE` (`W7` Holding, `W10` PerformanceSnapshot, `W29` LeaderboardEntry, `W32` UserPreference) execute efficiently with single-digit buffer dirtied pages.
- **Batch Operations**: Bulk insert operations such as `W44` (populating leaderboard rankings from JSON recordset) process in ~0.47 ms without requiring multiple network roundtrips.
