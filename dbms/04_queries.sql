-- READ | R1
SELECT "id", "email", "passwordHash", "name", "role",
       "isVerified", "isSuspended", "googleId"
FROM "User"
WHERE "email" = $1;

-- WRITE | W1
INSERT INTO "User" (
    "id", "email", "passwordHash", "name", "role",
    "isVerified", "isSuspended", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, 'TRADER', FALSE, FALSE, now(), now())
RETURNING "id", "email", "name", "role", "createdAt";

-- WRITE | W2
INSERT INTO "Portfolio" (
    "id", "userId", "name", "description",
    "startingBalance", "cashBalance", "reservedCash",
    "isDefault", "isActive", "createdAt", "updatedAt"
)
VALUES ($1, $2, 'Main Portfolio', NULL, 10000, 10000, 0, TRUE, TRUE, now(), now())
RETURNING "id", "name", "cashBalance";

-- READ | R2
SELECT "id", "email", "name", "avatarUrl", "role",
       "isVerified", "isSuspended",
       "emailAlerts", "emailDigest", "pushEnabled",
       "lastLoginAt", "createdAt"
FROM "User"
WHERE "id" = $1;

-- WRITE | W3
INSERT INTO "RefreshToken" (
    "id", "token", "userId", "expiresAt", "userAgent", "ipAddress", "createdAt"
)
VALUES ($1, $2, $3, $4, $5, $6, now())
RETURNING "id", "expiresAt";

-- READ | R3
SELECT rt."id", rt."userId", rt."expiresAt", rt."revokedAt",
       u."email", u."role", u."isSuspended"
FROM "RefreshToken" rt
JOIN "User" u ON u."id" = rt."userId"
WHERE rt."token" = $1;

-- WRITE | W4
UPDATE "RefreshToken"
SET "revokedAt" = now()
WHERE "userId" = $1
  AND "revokedAt" IS NULL;

-- WRITE | W5
UPDATE "User"
SET "lastLoginAt" = now(), "updatedAt" = now()
WHERE "id" = $1;

-- READ | R4
SELECT p."id", p."name", p."description",
       p."startingBalance", p."cashBalance", p."reservedCash",
       p."isDefault", p."isActive", p."createdAt",
       COUNT(h."id")::int                       AS "holdingsCount",
       COALESCE(SUM(h."totalInvested"), 0)      AS "investedValue",
       COUNT(*) OVER ()                         AS "totalCount"
FROM "Portfolio" p
LEFT JOIN "Holding" h ON h."portfolioId" = p."id"
WHERE p."userId" = $1
  AND p."isActive" = TRUE
GROUP BY p."id"
ORDER BY p."isDefault" DESC, p."createdAt" ASC;

-- READ | R5
SELECT p."id", p."name", p."startingBalance", p."cashBalance", p."reservedCash",
       p."isDefault", p."isActive",
       COUNT(h."id")::int                  AS "holdingsCount",
       COALESCE(SUM(h."totalInvested"), 0) AS "investedValue",
       COALESCE(SUM(h."quantity"), 0)      AS "totalUnits"
FROM "Portfolio" p
LEFT JOIN "Holding" h ON h."portfolioId" = p."id"
WHERE p."id" = $1
  AND p."userId" = $2
GROUP BY p."id";

-- READ | R6
SELECT "id", "symbol", "assetType", "quantity",
       "averageBuyPrice", "totalInvested", "isShort", "updatedAt"
FROM "Holding"
WHERE "portfolioId" = $1
ORDER BY "symbol" ASC;

-- WRITE | W6
INSERT INTO "Portfolio" (
    "id", "userId", "name", "description",
    "startingBalance", "cashBalance", "reservedCash",
    "isDefault", "isActive", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5, $5, 0, FALSE, TRUE, now(), now())
RETURNING "id", "name", "cashBalance";

-- WRITE | W7
INSERT INTO "Holding" (
    "id", "portfolioId", "symbol", "assetType",
    "quantity", "averageBuyPrice", "totalInvested",
    "isShort", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4::"AssetType", $5, $6, $7, FALSE, now(), now())
ON CONFLICT ("portfolioId", "symbol") DO UPDATE SET
    "quantity"        = "Holding"."quantity" + EXCLUDED."quantity",
    "totalInvested"   = "Holding"."totalInvested" + EXCLUDED."totalInvested",
    "averageBuyPrice" = ("Holding"."totalInvested" + EXCLUDED."totalInvested")
                        / ("Holding"."quantity" + EXCLUDED."quantity"),
    "isShort"         = FALSE,
    "updatedAt"       = now();

-- READ | R7
SELECT "id", "quantity", "totalInvested",
       ROUND("totalInvested" - (("totalInvested" * $3) / "quantity"), 8)
           AS "newTotalInvested"
FROM "Holding"
WHERE "portfolioId" = $1
  AND "symbol" = $2
  AND "quantity" >= $3
FOR UPDATE;

-- WRITE | W8
UPDATE "Holding"
SET "quantity"        = "quantity" - $3,
    "totalInvested"   = $4,
    "averageBuyPrice" = CASE
                          WHEN "quantity" - $3 > 0 THEN $4 / ("quantity" - $3)
                          ELSE 0
                        END,
    "updatedAt"       = now()
WHERE "portfolioId" = $1
  AND "symbol" = $2;

-- WRITE | W9
UPDATE "Portfolio"
SET "cashBalance"  = "cashBalance" + $2,
    "reservedCash" = "reservedCash" + $3,
    "updatedAt"    = now()
WHERE "id" = $1;

-- WRITE | W10
INSERT INTO "PerformanceSnapshot" (
    "id", "portfolioId", "totalValue", "cashBalance", "holdingsValue",
    "dailyPnl", "dailyPnlPct", "snapshotDate", "createdAt"
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8::date, now())
ON CONFLICT ("portfolioId", "snapshotDate") DO UPDATE SET
    "totalValue"    = EXCLUDED."totalValue",
    "cashBalance"   = EXCLUDED."cashBalance",
    "holdingsValue" = EXCLUDED."holdingsValue",
    "dailyPnl"      = EXCLUDED."dailyPnl",
    "dailyPnlPct"   = EXCLUDED."dailyPnlPct";

-- READ | R8
SELECT "snapshotDate", "totalValue", "cashBalance", "holdingsValue",
       "dailyPnl", "dailyPnlPct"
FROM "PerformanceSnapshot"
WHERE "portfolioId" = $1
  AND "snapshotDate" BETWEEN $2::date AND $3::date
ORDER BY "snapshotDate" ASC;

-- READ | R9
SELECT "id", "isActive", "cashBalance", "reservedCash"
FROM "Portfolio"
WHERE "id" = $1
  AND "userId" = $2
FOR UPDATE;

-- WRITE | W11
INSERT INTO "Order" (
    "id", "portfolioId", "symbol", "assetType",
    "side", "type", "status",
    "quantity", "reservedCash",
    "limitPrice", "stopPrice", "expiresAt",
    "source", "notes", "createdAt", "updatedAt"
)
VALUES (
    $1, $2, $3, $4::"AssetType",
    $5::"OrderSide", $6::"OrderType", 'PENDING',
    $7, $8,
    $9, $10, $11,
    $12::"OrderSource", $13, now(), now()
)
RETURNING "id", "status", "reservedCash", "createdAt";

-- READ | R10
SELECT o."id", o."symbol", o."assetType", o."side", o."type", o."status",
       o."quantity", o."reservedCash", o."limitPrice", o."stopPrice",
       o."executedPrice", o."executedAt", o."expiresAt", o."source",
       o."createdAt",
       COUNT(*) OVER () AS "totalCount"
FROM "Order" o
JOIN "Portfolio" p ON p."id" = o."portfolioId"
WHERE p."userId" = $1
  AND ($2::text IS NULL OR o."portfolioId" = $2)
  AND ($3::"OrderStatus" IS NULL OR o."status" = $3)
  AND ($4::text IS NULL OR o."symbol" = $4)
  AND ($5::timestamptz IS NULL OR o."createdAt" >= $5)
ORDER BY o."createdAt" DESC
LIMIT $6 OFFSET $7;

-- READ | R11
SELECT "id", "portfolioId", "symbol", "assetType", "side", "type",
       "quantity", "reservedCash", "limitPrice", "stopPrice", "expiresAt",
       "executionAttempts"
FROM "Order"
WHERE "status" = 'PENDING'
  AND ("expiresAt" IS NULL OR "expiresAt" > now())
  AND ("lastExecutionAttemptAt" IS NULL
       OR "lastExecutionAttemptAt" <= now() - interval '30 seconds')
ORDER BY "createdAt" ASC
LIMIT $1;

-- WRITE | W12
UPDATE "Order"
SET "status"                = $2::"OrderStatus",
    "executedPrice"         = $3,
    "executedAt"            = $4,
    "reservedCash"          = 0,
    "lastExecutionAttemptAt" = now(),
    "updatedAt"             = now()
WHERE "id" = $1
  AND "status" = 'PENDING'
RETURNING "id", "portfolioId", "symbol", "side", "quantity";

-- READ | R12
SELECT o."id", o."portfolioId", o."symbol", o."assetType",
       o."side", o."type", o."status", o."quantity",
       o."limitPrice", o."stopPrice", o."executedPrice", o."executedAt",
       o."createdAt",
       e."id"          AS "eventId",
       e."sequence"    AS "eventSequence",
       e."eventType"   AS "eventType",
       e."previousStatus" AS "eventPreviousStatus",
       e."newStatus"   AS "eventNewStatus",
       e."metadata"    AS "eventMetadata",
       e."createdAt"   AS "eventCreatedAt"
FROM "Order" o
LEFT JOIN "OrderEvent" e ON e."orderId" = o."id"
WHERE o."id" = $1
ORDER BY e."sequence" ASC;

-- READ | R13
SELECT "id"
FROM "Order"
WHERE "id" = $1
FOR UPDATE;

-- WRITE | W13
INSERT INTO "OrderEvent" (
    "id", "orderId", "sequence", "eventType",
    "previousStatus", "newStatus", "metadata", "createdAt"
)
VALUES ($1, $2, $3, $4::"OrderEventType",
        $5::"OrderStatus", $6::"OrderStatus", $7::jsonb, now())
RETURNING "id", "sequence", "createdAt";

-- READ | R14
SELECT t."id", t."symbol", t."assetType", t."side",
       t."quantity", t."price", t."totalValue", t."fees",
       t."realizedPnl", t."realizedPnlPct", t."executedAt",
       o."type"   AS "orderType",
       o."source" AS "orderSource",
       COUNT(*) OVER () AS "totalCount"
FROM "Trade" t
JOIN "Order" o     ON o."id" = t."orderId"
JOIN "Portfolio" p ON p."id" = t."portfolioId"
WHERE p."userId" = $1
  AND ($2::text IS NULL OR t."portfolioId" = $2)
  AND ($3::text IS NULL OR t."symbol" = $3)
  AND ($4::"OrderSide" IS NULL OR t."side" = $4)
  AND ($5::timestamptz IS NULL OR t."executedAt" >= $5)
  AND ($6::timestamptz IS NULL OR t."executedAt" < $6)
ORDER BY t."executedAt" DESC
LIMIT $7 OFFSET $8;

-- WRITE | W14
INSERT INTO "Trade" (
    "id", "portfolioId", "orderId", "symbol", "assetType", "side",
    "quantity", "price", "totalValue", "fees",
    "realizedPnl", "realizedPnlPct", "executedAt"
)
VALUES ($1, $2, $3, $4, $5::"AssetType", $6::"OrderSide",
        $7, $8, $9, $10, $11, $12, $13)
RETURNING "id", "executedAt";

-- READ | R15
SELECT t."symbol",
       COUNT(*)::int                                              AS "tradeCount",
       COUNT(*) FILTER (WHERE t."realizedPnl" > 0)::int           AS "winningTrades",
       COUNT(*) FILTER (WHERE t."realizedPnl" < 0)::int           AS "losingTrades",
       COALESCE(SUM(t."totalValue"), 0)                           AS "totalVolume",
       COALESCE(SUM(t."realizedPnl"), 0)                          AS "realizedPnl",
       COALESCE(SUM(t."fees"), 0)                                 AS "totalFees"
FROM "Trade" t
JOIN "Portfolio" p ON p."id" = t."portfolioId"
WHERE p."userId" = $1
  AND ($2::text IS NULL OR t."portfolioId" = $2)
  AND ($3::timestamptz IS NULL OR t."executedAt" >= $3)
  AND ($4::timestamptz IS NULL OR t."executedAt" < $4)
GROUP BY t."symbol"
ORDER BY "realizedPnl" DESC;

-- READ | R16
SELECT TO_CHAR(t."executedAt", 'YYYY-MM')                          AS "month",
       COUNT(*)::int                                               AS "totalTrades",
       COUNT(*) FILTER (WHERE t."realizedPnl" > 0)::int            AS "winningTrades",
       COUNT(*) FILTER (WHERE t."realizedPnl" < 0)::int            AS "losingTrades",
       COALESCE(SUM(t."totalValue"), 0)::text                      AS "totalVolume",
       COALESCE(SUM(t."realizedPnl"), 0)::text                     AS "realizedPnl",
       AVG(t."realizedPnlPct")::text                               AS "avgRealizedPnlPct"
FROM "Trade" t
JOIN "Portfolio" p ON p."id" = t."portfolioId"
WHERE p."userId" = $1
  AND ($2::text IS NULL OR t."portfolioId" = $2)
  AND ($3::text IS NULL OR t."symbol" = $3)
  AND ($4::"OrderSide" IS NULL OR t."side" = $4)
  AND ($5::timestamptz IS NULL OR t."executedAt" >= $5)
  AND ($6::timestamptz IS NULL OR t."executedAt" < $6)
GROUP BY "month"
ORDER BY "month" ASC;

-- READ | R17
SELECT p."id", p."cashBalance", p."startingBalance",
       (SELECT COUNT(*) FROM "Order" o
         WHERE o."portfolioId" = p."id" AND o."status" = 'PENDING')::int
           AS "pendingOrders",
       (SELECT COUNT(*) FROM "Holding" h
         WHERE h."portfolioId" = p."id")::int
           AS "openPositions",
       s."totalValue", s."dailyPnl", s."dailyPnlPct", s."snapshotDate"
FROM "Portfolio" p
LEFT JOIN LATERAL (
    SELECT "totalValue", "dailyPnl", "dailyPnlPct", "snapshotDate"
    FROM "PerformanceSnapshot"
    WHERE "portfolioId" = p."id"
    ORDER BY "snapshotDate" DESC
    LIMIT 1
) s ON TRUE
WHERE p."id" = $1
  AND p."userId" = $2;

-- READ | R18
SELECT a."id", a."condition", a."targetPrice", a."status",
       a."baselinePrice", a."baselineAt", a."triggeredAt", a."message",
       a."sendEmail", a."sendPush", a."createdAt",
       s."id" AS "symbolId", s."symbol" AS "symbolCode",
       s."name" AS "symbolName", s."assetType"
FROM "Alert" a
JOIN "Symbol" s ON s."id" = a."symbolId"
WHERE a."userId" = $1
  AND ($2::"AlertStatus" IS NULL OR a."status" = $2)
ORDER BY a."createdAt" DESC
LIMIT $3 OFFSET $4;

-- WRITE | W15
INSERT INTO "Alert" (
    "id", "userId", "symbolId", "condition", "targetPrice", "status",
    "sendEmail", "sendPush", "baselinePrice", "baselineAt",
    "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4::"AlertCondition", $5, 'ACTIVE',
        $6, $7, $8, $9, now(), now())
RETURNING "id", "status", "createdAt";

-- READ | R19
SELECT a."id", a."userId", a."condition", a."targetPrice",
       a."baselinePrice", a."baselineAt", a."lastEvaluatedAt",
       s."symbol" AS "symbolCode", s."assetType"
FROM "Alert" a
JOIN "Symbol" s ON s."id" = a."symbolId"
WHERE a."status" = 'ACTIVE'
  AND (a."lastEvaluatedAt" IS NULL
       OR a."lastEvaluatedAt" <= now() - interval '1 minute')
ORDER BY a."lastEvaluatedAt" ASC NULLS FIRST
LIMIT $1;

-- WRITE | W16
UPDATE "Alert"
SET "status"          = 'TRIGGERED',
    "triggeredAt"     = $2,
    "lastEvaluatedAt" = $2,
    "message"         = $3,
    "updatedAt"       = now()
WHERE "id" = $1
  AND "status" = 'ACTIVE'
RETURNING "id", "userId", "symbolId";

-- WRITE | W17
UPDATE "Alert"
SET "lastEvaluatedAt" = $2,
    "baselinePrice"   = COALESCE("baselinePrice", $3),
    "baselineAt"      = COALESCE("baselineAt", $2),
    "updatedAt"       = now()
WHERE "id" = ANY($1::text[])
  AND "status" = 'ACTIVE';

-- READ | R20
SELECT "id", "type", "title", "message", "data",
       "isRead", "readAt", "deliveryStatus", "createdAt"
FROM "Notification"
WHERE "userId" = $1
  AND ($2::boolean IS NULL OR "isRead" = $2)
ORDER BY "createdAt" DESC
LIMIT $3 OFFSET $4;

-- READ | R21
SELECT COUNT(*)::int AS "unreadCount"
FROM "Notification"
WHERE "userId" = $1
  AND "isRead" = FALSE;

-- WRITE | W18
UPDATE "Notification"
SET "isRead" = TRUE, "readAt" = now()
WHERE "id" = $1
  AND "userId" = $2
RETURNING "id", "isRead", "readAt";

-- WRITE | W19
UPDATE "Notification"
SET "isRead" = TRUE, "readAt" = now()
WHERE "userId" = $1
  AND "isRead" = FALSE;

-- WRITE | W20
INSERT INTO "Notification" (
    "id", "userId", "type", "title", "message", "data",
    "isRead", "deliveryStatus", "createdAt"
)
VALUES ($1, $2, $3::"NotificationType", $4, $5, $6::jsonb,
        FALSE, 'PENDING', now())
RETURNING "id", "createdAt";

-- WRITE | W21
UPDATE "Notification"
SET "deliveryStatus"    = 'SENDING',
    "deliveryStartedAt" = now(),
    "deliveryAttempts"  = "deliveryAttempts" + 1
WHERE "id" IN (
    SELECT "id"
    FROM "Notification"
    WHERE "deliveryStatus" = 'PENDING'
      AND "deliveryAttempts" < $1
      AND ("deliveryStartedAt" IS NULL
           OR "deliveryStartedAt" <= now() - interval '5 minutes')
    ORDER BY "createdAt" ASC
    LIMIT $2
    FOR UPDATE SKIP LOCKED
)
RETURNING "id", "userId", "type", "title", "message",
          "deliveryAttempts", "deliveryChannels";

-- WRITE | W22
UPDATE "Notification"
SET "deliveryStatus"   = $2::"NotificationDeliveryStatus",
    "deliveredAt"      = $3,
    "deliveryChannels" = $4::jsonb
WHERE "id" = $1;

-- READ | R22
SELECT p."id", p."content", p."symbol", p."metadata",
       p."createdAt",
       u."id"        AS "authorId",
       u."name"      AS "authorName",
       u."avatarUrl" AS "authorAvatarUrl",
       COUNT(pl."id")::int AS "likeCount",
       EXISTS (
           SELECT 1
           FROM "PostLike" mine
           WHERE mine."postId" = p."id"
             AND mine."userId" = $1
       ) AS "likedByMe",
       COUNT(*) OVER () AS "totalCount"
FROM "Post" p
JOIN "User" u     ON u."id" = p."authorId"
LEFT JOIN "PostLike" pl ON pl."postId" = p."id"
WHERE p."isHidden" = FALSE
  AND ($2::text IS NULL OR p."symbol" = $2)
  AND ($3::text IS NULL OR p."authorId" = $3)
GROUP BY p."id", u."id"
ORDER BY p."createdAt" DESC
LIMIT $4 OFFSET $5;

-- WRITE | W23
INSERT INTO "Post" (
    "id", "authorId", "content", "symbol", "metadata",
    "isHidden", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5::jsonb, FALSE, now(), now())
RETURNING "id", "content", "symbol", "createdAt";

-- WRITE | W24
INSERT INTO "PostLike" ("id", "postId", "userId", "createdAt")
VALUES ($1, $2, $3, now())
ON CONFLICT ("postId", "userId") DO NOTHING;

-- WRITE | W25
DELETE FROM "PostLike"
WHERE "postId" = $1
  AND "userId" = $2;

-- WRITE | W26
INSERT INTO "Follow" ("id", "followerId", "followingId", "createdAt")
VALUES ($1, $2, $3, now())
ON CONFLICT ("followerId", "followingId") DO NOTHING;

-- WRITE | W27
DELETE FROM "Follow"
WHERE "followerId" = $1
  AND "followingId" = $2;

-- READ | R23
SELECT u."id", u."name", u."avatarUrl", f."createdAt" AS "followedAt"
FROM "Follow" f
JOIN "User" u
  ON u."id" = CASE WHEN $2 = 'followers'
                   THEN f."followerId"
                   ELSE f."followingId"
              END
WHERE CASE WHEN $2 = 'followers'
           THEN f."followingId"
           ELSE f."followerId"
      END = $1
ORDER BY f."createdAt" DESC
LIMIT $3 OFFSET $4;

-- READ | R24
SELECT u."id", u."name", u."avatarUrl", u."createdAt",
       (SELECT COUNT(*) FROM "Follow" f
         WHERE f."followingId" = u."id")::int AS "followerCount",
       (SELECT COUNT(*) FROM "Follow" f
         WHERE f."followerId" = u."id")::int  AS "followingCount",
       (SELECT COUNT(*) FROM "Post" p
         WHERE p."authorId" = u."id" AND p."isHidden" = FALSE)::int
           AS "postCount"
FROM "User" u
WHERE u."id" = $1;

-- WRITE | W28
WITH latest AS (
    SELECT MAX("snapshotDate") AS "snapshotDate"
    FROM "LeaderboardSnapshot"
    WHERE "scope" = 'GLOBAL' AND "period" = $1::"LeaderboardPeriod"
)
SELECT le."rank", le."userId", le."totalValue", le."returnPct",
       le."snapshotDate", u."name", u."avatarUrl",
       COUNT(*) OVER () AS "totalCount"
FROM "LeaderboardEntry" le
JOIN "LeaderboardSnapshot" ls ON ls."id" = le."snapshotId"
JOIN "User" u                 ON u."id" = le."userId"
JOIN latest                   ON ls."snapshotDate" = latest."snapshotDate"
WHERE le."scope" = 'GLOBAL'
  AND le."period" = $1::"LeaderboardPeriod"
  AND u."isSuspended" = FALSE
ORDER BY le."rank" ASC
LIMIT $2 OFFSET $3;

-- READ | R25
SELECT u."id" AS "userId", u."name", u."avatarUrl",
       le."totalValue", le."returnPct"
FROM "LeaderboardEntry" le
JOIN "User" u ON u."id" = le."userId"
WHERE le."scope" = 'GLOBAL'
  AND le."period" = $2::"LeaderboardPeriod"
  AND le."snapshotDate" = (
      SELECT MAX("snapshotDate")
      FROM "LeaderboardSnapshot"
      WHERE "scope" = 'GLOBAL' AND "period" = $2::"LeaderboardPeriod"
  )
  AND (
      le."userId" = $1
      OR le."userId" IN (
          SELECT f."followingId"
          FROM "Follow" f
          WHERE f."followerId" = $1
      )
  )
ORDER BY le."returnPct" DESC, le."userId" ASC
LIMIT $3 OFFSET $4;

-- READ | R26
SELECT "rank", "totalValue", "returnPct", "snapshotDate"
FROM "LeaderboardEntry"
WHERE "userId" = $1
  AND "scope" = 'GLOBAL'
  AND "period" = $2::"LeaderboardPeriod"
ORDER BY "snapshotDate" DESC
LIMIT 1;

-- WRITE | W29
INSERT INTO "LeaderboardEntry" (
    "id", "userId", "scope", "period", "rank",
    "totalValue", "returnPct", "snapshotDate", "createdAt", "snapshotId"
)
VALUES ($1, $2, 'GLOBAL', $3::"LeaderboardPeriod", $4,
        $5, $6, $7::date, now(), $8)
ON CONFLICT ("scope", "period", "snapshotDate", "userId") DO UPDATE SET
    "rank"       = EXCLUDED."rank",
    "totalValue" = EXCLUDED."totalValue",
    "returnPct"  = EXCLUDED."returnPct";

-- READ | R27
SELECT l."id", l."name", l."description", l."status",
       l."startingBalance", l."maxParticipants",
       l."startDate", l."endDate", l."createdAt",
       COUNT(lm."id")::int AS "memberCount",
       COUNT(*) OVER () AS "totalCount"
FROM "League" l
LEFT JOIN "LeagueMember" lm ON lm."leagueId" = l."id"
WHERE ($1::"LeagueStatus" IS NULL OR l."status" = $1)
GROUP BY l."id"
ORDER BY l."startDate" DESC
LIMIT $2 OFFSET $3;

-- READ | R28
SELECT "id", "name", "startingBalance", "maxParticipants",
       "startDate", "endDate", "status"
FROM "League"
WHERE "id" = $1
FOR UPDATE;

-- WRITE | W30
INSERT INTO "LeagueMember" (
    "id", "leagueId", "userId", "portfolioId", "joinedAt"
)
VALUES ($1, $2, $3, $4, now())
RETURNING "id", "leagueId", "userId", "portfolioId";

-- READ | R29
SELECT lm."id", lm."rank", lm."finalReturn",
       u."id" AS "userId", u."name", u."avatarUrl",
       p."startingBalance", p."cashBalance",
       p."cashBalance" + COALESCE(h."investedValue", 0) AS "currentValue"
FROM "LeagueMember" lm
JOIN "User" u       ON u."id" = lm."userId"
JOIN "Portfolio" p  ON p."id" = lm."portfolioId"
LEFT JOIN (
    SELECT "portfolioId", SUM("totalInvested") AS "investedValue"
    FROM "Holding"
    GROUP BY "portfolioId"
) h ON h."portfolioId" = p."id"
WHERE lm."leagueId" = $1
ORDER BY COALESCE(lm."rank", 2147483647) ASC,
         p."cashBalance" DESC;

-- READ | R30
SELECT ua."id", ua."unlockedAt",
       a."id" AS "achievementId", a."code", a."name",
       a."description", a."iconUrl", a."category", a."criteria"
FROM "UserAchievement" ua
JOIN "Achievement" a ON a."id" = ua."achievementId"
WHERE ua."userId" = $1
ORDER BY ua."unlockedAt" DESC;

-- WRITE | W31
INSERT INTO "UserAchievement" ("id", "userId", "achievementId", "reason", "unlockedAt")
VALUES ($1, $2, $3, $4, now())
ON CONFLICT ("userId", "achievementId") DO NOTHING
RETURNING "id", "unlockedAt";

-- READ | R31
SELECT "userId", "emailNotifications", "pushNotifications", "updatedAt"
FROM "UserPreference"
WHERE "userId" = $1;

-- WRITE | W32
INSERT INTO "UserPreference" (
    "id", "userId", "emailNotifications", "pushNotifications",
    "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, now(), now())
ON CONFLICT ("userId") DO UPDATE SET
    "emailNotifications" = EXCLUDED."emailNotifications",
    "pushNotifications"  = EXCLUDED."pushNotifications",
    "updatedAt"          = now()
RETURNING "userId", "emailNotifications", "pushNotifications";

-- READ | R32
SELECT sv."sentiment", COUNT(*)::int AS "votes"
FROM "SentimentVote" sv
JOIN "User" u ON u."id" = sv."userId"
WHERE sv."symbol" = $1
  AND ($2::timestamptz IS NULL OR sv."updatedAt" >= $2)
  AND u."isSuspended" = FALSE
GROUP BY sv."sentiment";

-- WRITE | W33
INSERT INTO "SentimentVote" (
    "id", "userId", "symbol", "sentiment", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4::"Sentiment", now(), now())
ON CONFLICT ("userId", "symbol") DO UPDATE SET
    "sentiment" = EXCLUDED."sentiment",
    "updatedAt" = now()
RETURNING "id", "sentiment", "updatedAt";

-- READ | R33
SELECT "id", "symbol", "name", "assetType", "exchange",
       "currency", "sector", "isTradable"
FROM "Symbol"
WHERE "isActive" = TRUE
  AND ($1::text IS NULL
       OR "symbol" ILIKE '%' || $1 || '%'
       OR "name"   ILIKE '%' || $1 || '%')
  AND ($2::"AssetType" IS NULL OR "assetType" = $2)
ORDER BY "symbol" ASC
LIMIT $3 OFFSET $4;

-- WRITE | W34
INSERT INTO "CopyTrader" (
    "id", "copierId", "copiedId", "allocationPct",
    "maxTradeSize", "isActive", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5, TRUE, now(), now())
ON CONFLICT ("copierId", "copiedId") DO UPDATE SET
    "allocationPct" = EXCLUDED."allocationPct",
    "maxTradeSize"  = EXCLUDED."maxTradeSize",
    "isActive"      = TRUE,
    "updatedAt"     = now()
RETURNING "id", "allocationPct", "maxTradeSize", "isActive";

-- READ | R34
SELECT ct."id", ct."allocationPct", ct."maxTradeSize", ct."isActive",
       u."id" AS "traderId", u."name", u."avatarUrl",
       le."returnPct" AS "traderReturnPct",
       COUNT(*) OVER () AS "totalCount"
FROM "CopyTrader" ct
JOIN "User" u ON u."id" = ct."copiedId"
LEFT JOIN LATERAL (
    SELECT "returnPct"
    FROM "LeaderboardEntry"
    WHERE "userId" = ct."copiedId"
      AND "scope" = 'GLOBAL'
      AND "period" = 'ALL_TIME'
    ORDER BY "snapshotDate" DESC
    LIMIT 1
) le ON TRUE
WHERE ct."copierId" = $1
  AND ($2::boolean IS NULL OR ct."isActive" = $2)
ORDER BY ct."createdAt" DESC, ct."id" DESC
LIMIT $3 OFFSET $4;

-- READ | R35
SELECT "id", "email", "name", "avatarUrl", "role",
       "isVerified", "isSuspended", "googleId"
FROM "User"
WHERE "googleId" = $1;

-- WRITE | W35
UPDATE "User"
SET "name"      = COALESCE($2, "name"),
    "avatarUrl" = COALESCE($3, "avatarUrl"),
    "updatedAt" = now()
WHERE "id" = $1
RETURNING "id", "name", "avatarUrl";

-- READ | R36
SELECT u."id", u."email", u."name", u."avatarUrl", u."role",
       u."isVerified", u."isSuspended", u."createdAt", u."updatedAt",
       u."lastLoginAt",
       COUNT(*) OVER () AS "totalCount"
FROM "User" u
WHERE ($1::text IS NULL
       OR u."name" ILIKE '%' || $1 || '%'
       OR u."email" ILIKE '%' || $1 || '%')
  AND ($2::"Role" IS NULL OR u."role" = $2)
  AND ($3::boolean IS NULL OR u."isSuspended" = $3)
  AND ($4::boolean IS NULL OR u."isVerified" = $4)
ORDER BY u."createdAt" DESC
LIMIT $5 OFFSET $6;

-- READ | R37
SELECT "id", "email", "name", "avatarUrl", "role",
       "isVerified", "isSuspended", "createdAt", "updatedAt", "lastLoginAt"
FROM "User"
WHERE "id" = $1;

-- READ | R38
SELECT "id", "name", "startingBalance", "cashBalance", "reservedCash",
       "isDefault", "isActive"
FROM "Portfolio"
WHERE "userId" = $1
  AND "isDefault" = TRUE
  AND "isActive" = TRUE
ORDER BY "createdAt" ASC
LIMIT 1;

-- WRITE | W36
UPDATE "Portfolio"
SET "name"        = COALESCE($2, "name"),
    "description" = CASE WHEN $3::boolean THEN $4 ELSE "description" END,
    "updatedAt"   = now()
WHERE "id" = $1
  AND "userId" = $5
RETURNING "id", "name", "description";

-- WRITE | W37
UPDATE "Portfolio"
SET "isActive"  = $2,
    "updatedAt" = now()
WHERE "id" = $1
  AND "userId" = $3
RETURNING "id", "isActive";

-- READ | R39
SELECT "symbol", "assetType", "quantity"
FROM "Order"
WHERE "portfolioId" = $1
  AND "side" = 'SELL'
  AND "status" = 'PENDING';

-- READ | R40
SELECT p."id", p."userId", p."name", p."description",
       p."startingBalance", p."cashBalance", p."isDefault", p."isActive",
       p."createdAt", p."updatedAt",
       u."id" AS "ownerId", u."name" AS "ownerName", u."email" AS "ownerEmail",
       COUNT(*) OVER () AS "totalCount"
FROM "Portfolio" p
JOIN "User" u ON u."id" = p."userId"
WHERE ($1::text IS NULL
       OR p."name" ILIKE '%' || $1 || '%'
       OR u."email" ILIKE '%' || $1 || '%')
  AND ($2::boolean IS NULL OR p."isActive" = $2)
ORDER BY p."createdAt" DESC, p."id" ASC
LIMIT $3 OFFSET $4;

-- READ | R41
SELECT p."id", p."userId", p."name", p."description",
       p."startingBalance", p."cashBalance", p."reservedCash",
       p."isDefault", p."isActive", p."createdAt", p."updatedAt",
       u."id" AS "ownerId", u."name" AS "ownerName", u."email" AS "ownerEmail"
FROM "Portfolio" p
JOIN "User" u ON u."id" = p."userId"
WHERE p."id" = $1;

-- READ | R42
SELECT o."id", o."portfolioId", o."symbol", o."assetType", o."side",
       o."type", o."status", o."quantity", o."reservedCash",
       o."limitPrice", o."stopPrice", o."executedPrice",
       o."executedAt", o."expiresAt", o."notes", o."source",
       o."createdAt", o."updatedAt",
       p."name" AS "portfolioName", p."isActive" AS "portfolioActive",
       u."id" AS "ownerId", u."name" AS "ownerName", u."email" AS "ownerEmail",
       COUNT(*) OVER () AS "totalCount"
FROM "Order" o
JOIN "Portfolio" p ON p."id" = o."portfolioId"
JOIN "User" u      ON u."id" = p."userId"
WHERE ($1::"OrderStatus" IS NULL OR o."status" = $1)
  AND ($2::text IS NULL OR o."symbol" = $2)
  AND ($3::text IS NULL OR p."userId" = $3)
ORDER BY o."createdAt" DESC, o."id" ASC
LIMIT $4 OFFSET $5;

-- READ | R43
SELECT a."id", a."userId", a."condition", a."targetPrice", a."status",
       a."sendEmail", a."sendPush", a."triggeredAt", a."message",
       a."baselinePrice", a."baselineAt", a."lastEvaluatedAt",
       a."createdAt", a."updatedAt",
       s."id" AS "symbolId", s."symbol" AS "symbolCode",
       s."name" AS "symbolName", s."assetType"
FROM "Alert" a
JOIN "Symbol" s ON s."id" = a."symbolId"
WHERE a."id" = $1
  AND a."userId" = $2;

-- WRITE | W38
UPDATE "Alert"
SET "condition"     = COALESCE($2::"AlertCondition", "condition"),
    "targetPrice"   = COALESCE($3, "targetPrice"),
    "status"        = COALESCE($4::"AlertStatus", "status"),
    "sendEmail"     = COALESCE($5, "sendEmail"),
    "sendPush"      = COALESCE($6, "sendPush"),
    "baselinePrice" = CASE WHEN $7::boolean THEN $8 ELSE "baselinePrice" END,
    "baselineAt"    = CASE WHEN $7::boolean THEN $9 ELSE "baselineAt" END,
    "triggeredAt"   = CASE WHEN $4::"AlertStatus" = 'TRIGGERED'
                           THEN now() ELSE "triggeredAt" END,
    "updatedAt"     = now()
WHERE "id" = $1
  AND "userId" = $10
RETURNING "id", "status", "condition", "targetPrice";

-- WRITE | W39
DELETE FROM "Alert"
WHERE "id" = $1
  AND "userId" = $2
RETURNING "id";

-- READ | R44
SELECT "id", "userId", "type", "title", "message", "data",
       "isRead", "readAt", "deliveryStatus", "deliveredAt",
       "deliveryAttempts", "deliveryChannels", "createdAt"
FROM "Notification"
WHERE "id" = $1
  AND "userId" = $2;

-- WRITE | W40
UPDATE "Notification"
SET "deliveryStatus"   = $2::"NotificationDeliveryStatus",
    "deliveredAt"      = $3,
    "deliveryStartedAt" = NULL,
    "deliveryChannels" = COALESCE($4::jsonb, "deliveryChannels")
WHERE "id" = $1
  AND "deliveryStatus" = 'SENDING';

-- READ | R45
SELECT p."id", p."authorId", p."content", p."symbol", p."metadata",
       p."isHidden", p."createdAt", p."updatedAt",
       u."name" AS "authorName", u."avatarUrl" AS "authorAvatarUrl"
FROM "Post" p
JOIN "User" u ON u."id" = p."authorId"
WHERE p."id" = $1
  AND p."isHidden" = FALSE;

-- WRITE | W41
DELETE FROM "Post"
WHERE "id" = $1
  AND "authorId" = $2
RETURNING "id";

-- READ | R46
SELECT u."id", u."name", u."avatarUrl", u."createdAt",
       (SELECT COUNT(*) FROM "Follow" f
         WHERE f."followingId" = u."id")::int AS "followerCount",
       (SELECT COUNT(*) FROM "Follow" f
         WHERE f."followerId" = u."id")::int  AS "followingCount",
       (SELECT COUNT(*) FROM "Post" p
         WHERE p."authorId" = u."id" AND p."isHidden" = FALSE)::int
           AS "postCount",
       EXISTS (
           SELECT 1 FROM "Follow" f
           WHERE f."followerId" = $2 AND f."followingId" = u."id"
       ) AS "isFollowing"
FROM "User" u
WHERE u."id" = $1;

-- WRITE | W42
INSERT INTO "LeaderboardSnapshot" (
    "id", "scope", "period", "snapshotDate", "createdAt"
)
VALUES ($1, 'GLOBAL', $2::"LeaderboardPeriod", $3::date, now())
ON CONFLICT ("scope", "period", "snapshotDate")
DO UPDATE SET "scope" = EXCLUDED."scope"
RETURNING "id";

-- WRITE | W43
DELETE FROM "LeaderboardEntry"
WHERE "scope" = 'GLOBAL'
  AND "period" = $1::"LeaderboardPeriod"
  AND "snapshotDate" = $2::date;

-- WRITE | W44
INSERT INTO "LeaderboardEntry" (
    "id", "userId", "scope", "period", "rank",
    "totalValue", "returnPct", "snapshotDate", "createdAt", "snapshotId"
)
SELECT x."id", x."userId", 'GLOBAL', $1::"LeaderboardPeriod", x."rank",
       x."totalValue", x."returnPct", $2::date, now(), $3
FROM jsonb_to_recordset($4::jsonb)
     AS x("id" text, "userId" text, "rank" integer,
          "totalValue" numeric, "returnPct" numeric);

-- WRITE | W45
INSERT INTO "League" (
    "id", "name", "description", "startingBalance", "maxParticipants",
    "startDate", "endDate", "status", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8::"LeagueStatus", now(), now())
RETURNING "id", "name", "status", "startDate", "endDate";

-- WRITE | W46
UPDATE "League"
SET "status" = 'ACTIVE', "updatedAt" = now()
WHERE "status" = 'UPCOMING'
  AND "startDate" <= $1
  AND "endDate" > $1;

-- WRITE | W47
UPDATE "League"
SET "status" = $2::"LeagueStatus", "updatedAt" = now()
WHERE "id" = $1
RETURNING "id", "status";

-- READ | R47
SELECT l."id", l."name", l."description", l."startingBalance",
       l."maxParticipants", l."startDate", l."endDate", l."status",
       l."createdAt", l."updatedAt",
       COUNT(lm."id")::int AS "memberCount"
FROM "League" l
LEFT JOIN "LeagueMember" lm ON lm."leagueId" = l."id"
WHERE l."id" = $1
GROUP BY l."id";

-- READ | R48
SELECT "id", "leagueId", "userId", "portfolioId", "rank",
       "finalReturn", "joinedAt"
FROM "LeagueMember"
WHERE "leagueId" = $1
  AND "userId" = $2;

-- READ | R49
SELECT COUNT(*)::int AS "memberCount"
FROM "LeagueMember"
WHERE "leagueId" = $1;

-- WRITE | W48
UPDATE "LeagueMember"
SET "rank" = $2, "finalReturn" = $3
WHERE "id" = $1
RETURNING "id", "rank", "finalReturn";

-- READ | R50
SELECT "id", "code", "name", "description", "iconUrl",
       "category", "criteria", "createdAt"
FROM "Achievement"
ORDER BY "createdAt" ASC;

-- READ | R51
SELECT "id", "code", "name", "description", "iconUrl",
       "category", "criteria", "createdAt"
FROM "Achievement"
WHERE "code" = $1;

-- WRITE | W49
INSERT INTO "Achievement" (
    "id", "code", "name", "description", "iconUrl",
    "category", "criteria", "createdAt"
)
VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, now())
ON CONFLICT ("code") DO UPDATE SET
    "name"        = EXCLUDED."name",
    "description" = EXCLUDED."description",
    "category"    = EXCLUDED."category",
    "criteria"    = EXCLUDED."criteria"
RETURNING "id";

-- READ | R52
SELECT "sentiment"
FROM "SentimentVote"
WHERE "userId" = $1
  AND "symbol" = $2;

-- READ | R53
SELECT t."id", t."portfolioId", t."symbol", t."assetType", t."side",
       t."quantity", t."price", t."totalValue", t."executedAt",
       o."id" AS "orderId", o."source" AS "orderSource",
       p."userId" AS "traderId"
FROM "Trade" t
JOIN "Order" o     ON o."id" = t."orderId"
JOIN "Portfolio" p ON p."id" = t."portfolioId"
WHERE t."id" = $1;

-- WRITE | W50
DELETE FROM "PerformanceSnapshot"
WHERE "snapshotDate" < $1::date
  AND ($2::text IS NULL OR "portfolioId" = $2);

-- READ | R54
SELECT 1;

-- WRITE | W51
UPDATE "CopyTrader"
SET "allocationPct" = COALESCE($2, "allocationPct"),
    "maxTradeSize"  = CASE WHEN $3::boolean THEN $4 ELSE "maxTradeSize" END,
    "isActive"      = COALESCE($5, "isActive"),
    "updatedAt"     = now()
WHERE "id" = $1
  AND "copierId" = $6
RETURNING "id", "allocationPct", "maxTradeSize", "isActive";

-- READ | R55
SELECT "id", "symbol", "name", "assetType", "exchange", "currency",
       "sector", "industry", "logoUrl", "description",
       "isActive", "isTradable"
FROM "Symbol"
WHERE "symbol" = $1;

-- READ | R56
SELECT "id"
FROM "Notification"
WHERE "deliveryStatus" = 'PENDING'
  AND "deliveryAttempts" < $1
  AND ("deliveryStartedAt" IS NULL
       OR "deliveryStartedAt" <= now() - interval '5 minutes')
ORDER BY "createdAt" ASC
LIMIT $2;

-- READ | R57
SELECT ct."id", ct."copierId", ct."allocationPct",
       ct."maxTradeSize", ct."copyPortfolioId"
FROM "CopyTrader" ct
WHERE ct."copiedId" = $1
  AND ct."isActive" = TRUE
ORDER BY ct."id" ASC
LIMIT $2;

-- READ | R58
SELECT "id", "allocationPct", "maxTradeSize", "isActive"
FROM "CopyTrader"
WHERE "copierId" = $1
  AND "copiedId" = $2;

-- WRITE | W52
WITH filtered AS (
    SELECT t."id", t."symbol", t."realizedPnl", t."realizedPnlPct",
           t."totalValue", t."executedAt"
    FROM "Trade" t
    JOIN "Portfolio" p ON p."id" = t."portfolioId"
    WHERE p."userId" = $1
      AND ($2::text IS NULL OR t."portfolioId" = $2)
      AND ($3::text IS NULL OR t."symbol" = $3)
      AND ($4::"OrderSide" IS NULL OR t."side" = $4)
      AND ($5::timestamptz IS NULL OR t."executedAt" >= $5)
      AND ($6::timestamptz IS NULL OR t."executedAt" < $6)
)
SELECT (SELECT COUNT(*) FROM filtered)::int                       AS "totalTrades",
       (SELECT COUNT(*) FROM filtered
         WHERE "realizedPnl" > 0)::int                            AS "winningTrades",
       (SELECT COUNT(*) FROM filtered
         WHERE "realizedPnl" < 0)::int                            AS "losingTrades",
       COALESCE((SELECT SUM("totalValue") FROM filtered), 0)      AS "totalVolume",
       (SELECT AVG("realizedPnlPct") FROM filtered)               AS "avgRealizedPnlPct",
       (SELECT row_to_json(b)
          FROM (SELECT "symbol", "realizedPnl", "realizedPnlPct"
                FROM filtered
                WHERE "realizedPnl" IS NOT NULL
                ORDER BY "realizedPnl" DESC, "executedAt" DESC
                LIMIT 1) b)                                       AS "bestTrade",
       (SELECT row_to_json(w)
          FROM (SELECT "symbol", "realizedPnl", "realizedPnlPct"
                FROM filtered
                WHERE "realizedPnl" IS NOT NULL
                ORDER BY "realizedPnl" ASC, "executedAt" DESC
                LIMIT 1) w)                                       AS "worstTrade";

-- READ | R59
SELECT p."id", p."userId", p."startingBalance", p."cashBalance",
       COALESCE(SUM(h."totalInvested"), 0) AS "holdingsValue",
       (lm."id" IS NOT NULL)               AS "isLeaguePortfolio"
FROM "Portfolio" p
JOIN "User" u               ON u."id" = p."userId"
LEFT JOIN "Holding" h       ON h."portfolioId" = p."id"
LEFT JOIN "LeagueMember" lm ON lm."portfolioId" = p."id"
WHERE u."isSuspended" = FALSE
GROUP BY p."id", lm."id";

-- READ | R60
SELECT COALESCE(SUM("realizedPnl"), 0) AS "realizedPnl",
       COALESCE(SUM("fees"), 0)        AS "fees",
       COUNT(*)::int                   AS "tradeCount"
FROM "Trade"
WHERE "portfolioId" = $1
  AND ($2::timestamptz IS NULL OR "executedAt" >= $2)
  AND ($3::timestamptz IS NULL OR "executedAt" <= $3);

-- READ | R61
SELECT "portfolioId",
       COALESCE(SUM("realizedPnl"), 0) AS "realizedPnl"
FROM "Trade"
WHERE "portfolioId" = ANY($1::text[])
  AND "executedAt" >= $2
  AND "executedAt" < $3
GROUP BY "portfolioId";

-- WRITE | W53
INSERT INTO "Notification" (
    "id", "eventKey", "userId", "type", "title", "message", "data",
    "isRead", "deliveryStatus", "createdAt"
)
VALUES ($1, $2, $3, $4::"NotificationType", $5, $6, $7::jsonb,
        FALSE, 'PENDING', now())
ON CONFLICT ("eventKey") DO UPDATE SET "eventKey" = EXCLUDED."eventKey"
RETURNING "id", "createdAt";

-- READ | R62
SELECT "id"
FROM "Trade"
WHERE "copyFanOutAt" IS NULL
ORDER BY "executedAt" ASC, "id" ASC
LIMIT $1;

-- WRITE | W54
UPDATE "Trade"
SET "copyFanOutAt" = $2
WHERE "id" = $1;
