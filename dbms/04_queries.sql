-- READ | Q01
SELECT "id", "email", "passwordHash", "name", "role",
       "isVerified", "isSuspended", "googleId"
FROM "User"
WHERE "email" = $1;

-- WRITE | Q02
INSERT INTO "User" (
    "id", "email", "passwordHash", "name", "role",
    "isVerified", "isSuspended", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, 'TRADER', FALSE, FALSE, now(), now())
RETURNING "id", "email", "name", "role", "createdAt";

-- WRITE | Q03
INSERT INTO "Portfolio" (
    "id", "userId", "name", "description",
    "startingBalance", "cashBalance", "reservedCash",
    "isDefault", "isActive", "createdAt", "updatedAt"
)
VALUES ($1, $2, 'Main Portfolio', NULL, 10000, 10000, 0, TRUE, TRUE, now(), now())
RETURNING "id", "name", "cashBalance";

-- READ | Q04
SELECT "id", "email", "name", "avatarUrl", "role",
       "isVerified", "isSuspended",
       "emailAlerts", "emailDigest", "pushEnabled",
       "lastLoginAt", "createdAt"
FROM "User"
WHERE "id" = $1;

-- WRITE | Q05
INSERT INTO "RefreshToken" (
    "id", "token", "userId", "expiresAt", "userAgent", "ipAddress", "createdAt"
)
VALUES ($1, $2, $3, $4, $5, $6, now())
RETURNING "id", "expiresAt";

-- READ | Q06
SELECT rt."id", rt."userId", rt."expiresAt", rt."revokedAt",
       u."email", u."role", u."isSuspended"
FROM "RefreshToken" rt
JOIN "User" u ON u."id" = rt."userId"
WHERE rt."token" = $1;

-- WRITE | Q07
UPDATE "RefreshToken"
SET "revokedAt" = now()
WHERE "userId" = $1
  AND "revokedAt" IS NULL;

-- WRITE | Q08
UPDATE "User"
SET "lastLoginAt" = now(), "updatedAt" = now()
WHERE "id" = $1;

-- READ | Q09
SELECT p."id", p."name", p."description",
       p."startingBalance", p."cashBalance", p."reservedCash",
       p."isDefault", p."isActive", p."createdAt",
       COUNT(h."id")::int                       AS "holdingsCount",
       COALESCE(SUM(h."totalInvested"), 0)      AS "investedValue"
FROM "Portfolio" p
LEFT JOIN "Holding" h ON h."portfolioId" = p."id"
WHERE p."userId" = $1
  AND p."isActive" = TRUE
GROUP BY p."id"
ORDER BY p."isDefault" DESC, p."createdAt" ASC;

-- READ | Q10
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

-- READ | Q11
SELECT "id", "symbol", "assetType", "quantity",
       "averageBuyPrice", "totalInvested", "isShort", "updatedAt"
FROM "Holding"
WHERE "portfolioId" = $1
ORDER BY "symbol" ASC;

-- WRITE | Q12
INSERT INTO "Portfolio" (
    "id", "userId", "name", "description",
    "startingBalance", "cashBalance", "reservedCash",
    "isDefault", "isActive", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5, $5, 0, FALSE, TRUE, now(), now())
RETURNING "id", "name", "cashBalance";

-- WRITE | Q13
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

-- READ | Q14
SELECT "id", "quantity", "totalInvested",
       ROUND("totalInvested" - (("totalInvested" * $3) / "quantity"), 8)
           AS "newTotalInvested"
FROM "Holding"
WHERE "portfolioId" = $1
  AND "symbol" = $2
  AND "quantity" >= $3
FOR UPDATE;

-- WRITE | Q15
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

-- WRITE | Q16
UPDATE "Portfolio"
SET "cashBalance"  = "cashBalance" + $2,
    "reservedCash" = "reservedCash" + $3,
    "updatedAt"    = now()
WHERE "id" = $1;

-- WRITE | Q17
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

-- READ | Q18
SELECT "snapshotDate", "totalValue", "cashBalance", "holdingsValue",
       "dailyPnl", "dailyPnlPct"
FROM "PerformanceSnapshot"
WHERE "portfolioId" = $1
  AND "snapshotDate" BETWEEN $2::date AND $3::date
ORDER BY "snapshotDate" ASC;

-- READ | Q19
SELECT "id", "isActive", "cashBalance", "reservedCash"
FROM "Portfolio"
WHERE "id" = $1
  AND "userId" = $2
FOR UPDATE;

-- WRITE | Q20
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

-- READ | Q21
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

-- READ | Q22
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

-- WRITE | Q23
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

-- READ | Q24
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

-- READ | Q25
SELECT "id"
FROM "Order"
WHERE "id" = $1
FOR UPDATE;

-- WRITE | Q26
INSERT INTO "OrderEvent" (
    "id", "orderId", "sequence", "eventType",
    "previousStatus", "newStatus", "metadata", "createdAt"
)
VALUES ($1, $2, $3, $4::"OrderEventType",
        $5::"OrderStatus", $6::"OrderStatus", $7::jsonb, now())
RETURNING "id", "sequence", "createdAt";

-- READ | Q27
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

-- WRITE | Q28
INSERT INTO "Trade" (
    "id", "portfolioId", "orderId", "symbol", "assetType", "side",
    "quantity", "price", "totalValue", "fees",
    "realizedPnl", "realizedPnlPct", "executedAt"
)
VALUES ($1, $2, $3, $4, $5::"AssetType", $6::"OrderSide",
        $7, $8, $9, $10, $11, $12, $13)
RETURNING "id", "executedAt";

-- READ | Q29
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

-- READ | Q30
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

-- READ | Q31
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

-- READ | Q32
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

-- WRITE | Q33
INSERT INTO "Alert" (
    "id", "userId", "symbolId", "condition", "targetPrice", "status",
    "sendEmail", "sendPush", "baselinePrice", "baselineAt",
    "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4::"AlertCondition", $5, 'ACTIVE',
        $6, $7, $8, $9, now(), now())
RETURNING "id", "status", "createdAt";

-- READ | Q34
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

-- WRITE | Q35
UPDATE "Alert"
SET "status"          = 'TRIGGERED',
    "triggeredAt"     = $2,
    "lastEvaluatedAt" = $2,
    "message"         = $3,
    "updatedAt"       = now()
WHERE "id" = $1
  AND "status" = 'ACTIVE'
RETURNING "id", "userId", "symbolId";

-- WRITE | Q36
UPDATE "Alert"
SET "lastEvaluatedAt" = $2,
    "baselinePrice"   = COALESCE("baselinePrice", $3),
    "baselineAt"      = COALESCE("baselineAt", $2),
    "updatedAt"       = now()
WHERE "id" = ANY($1::text[])
  AND "status" = 'ACTIVE';

-- READ | Q37
SELECT "id", "type", "title", "message", "data",
       "isRead", "readAt", "deliveryStatus", "createdAt"
FROM "Notification"
WHERE "userId" = $1
  AND ($2::boolean IS NULL OR "isRead" = $2)
ORDER BY "createdAt" DESC
LIMIT $3 OFFSET $4;

-- READ | Q38
SELECT COUNT(*)::int AS "unreadCount"
FROM "Notification"
WHERE "userId" = $1
  AND "isRead" = FALSE;

-- WRITE | Q39
UPDATE "Notification"
SET "isRead" = TRUE, "readAt" = now()
WHERE "id" = $1
  AND "userId" = $2
RETURNING "id", "isRead", "readAt";

-- WRITE | Q40
UPDATE "Notification"
SET "isRead" = TRUE, "readAt" = now()
WHERE "userId" = $1
  AND "isRead" = FALSE;

-- WRITE | Q41
INSERT INTO "Notification" (
    "id", "userId", "type", "title", "message", "data",
    "isRead", "deliveryStatus", "createdAt"
)
VALUES ($1, $2, $3::"NotificationType", $4, $5, $6::jsonb,
        FALSE, 'PENDING', now())
RETURNING "id", "createdAt";

-- WRITE | Q42
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

-- WRITE | Q43
UPDATE "Notification"
SET "deliveryStatus"   = $2::"NotificationDeliveryStatus",
    "deliveredAt"      = $3,
    "deliveryChannels" = $4::jsonb
WHERE "id" = $1;

-- READ | Q44
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

-- WRITE | Q45
INSERT INTO "Post" (
    "id", "authorId", "content", "symbol", "metadata",
    "isHidden", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4, $5::jsonb, FALSE, now(), now())
RETURNING "id", "content", "symbol", "createdAt";

-- WRITE | Q46
INSERT INTO "PostLike" ("id", "postId", "userId", "createdAt")
VALUES ($1, $2, $3, now())
ON CONFLICT ("postId", "userId") DO NOTHING;

-- WRITE | Q47
DELETE FROM "PostLike"
WHERE "postId" = $1
  AND "userId" = $2;

-- WRITE | Q48
INSERT INTO "Follow" ("id", "followerId", "followingId", "createdAt")
VALUES ($1, $2, $3, now())
ON CONFLICT ("followerId", "followingId") DO NOTHING;

-- WRITE | Q49
DELETE FROM "Follow"
WHERE "followerId" = $1
  AND "followingId" = $2;

-- READ | Q50
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

-- READ | Q51
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

-- READ | Q52
WITH latest AS (
    SELECT MAX("snapshotDate") AS "snapshotDate"
    FROM "LeaderboardSnapshot"
    WHERE "scope" = 'GLOBAL' AND "period" = $1::"LeaderboardPeriod"
)
SELECT le."rank", le."userId", le."totalValue", le."returnPct",
       le."snapshotDate", u."name", u."avatarUrl"
FROM "LeaderboardEntry" le
JOIN "LeaderboardSnapshot" ls ON ls."id" = le."snapshotId"
JOIN "User" u                 ON u."id" = le."userId"
JOIN latest                   ON ls."snapshotDate" = latest."snapshotDate"
WHERE le."scope" = 'GLOBAL'
  AND le."period" = $1::"LeaderboardPeriod"
  AND u."isSuspended" = FALSE
ORDER BY le."rank" ASC
LIMIT $2 OFFSET $3;

-- READ | Q53
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

-- READ | Q54
SELECT "rank", "totalValue", "returnPct", "snapshotDate"
FROM "LeaderboardEntry"
WHERE "userId" = $1
  AND "scope" = 'GLOBAL'
  AND "period" = $2::"LeaderboardPeriod"
ORDER BY "snapshotDate" DESC
LIMIT 1;

-- WRITE | Q55
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

-- READ | Q56
SELECT l."id", l."name", l."description", l."status",
       l."startingBalance", l."maxParticipants",
       l."startDate", l."endDate", l."createdAt",
       COUNT(lm."id")::int AS "memberCount"
FROM "League" l
LEFT JOIN "LeagueMember" lm ON lm."leagueId" = l."id"
WHERE ($1::"LeagueStatus" IS NULL OR l."status" = $1)
GROUP BY l."id"
ORDER BY l."startDate" DESC
LIMIT $2 OFFSET $3;

-- READ | Q57
SELECT "id", "name", "startingBalance", "maxParticipants",
       "startDate", "endDate", "status"
FROM "League"
WHERE "id" = $1
FOR UPDATE;

-- WRITE | Q58
INSERT INTO "LeagueMember" (
    "id", "leagueId", "userId", "portfolioId", "joinedAt"
)
VALUES ($1, $2, $3, $4, now())
RETURNING "id", "leagueId", "userId", "portfolioId";

-- READ | Q59
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

-- READ | Q60
SELECT ua."id", ua."unlockedAt",
       a."id" AS "achievementId", a."code", a."name",
       a."description", a."iconUrl", a."category", a."criteria"
FROM "UserAchievement" ua
JOIN "Achievement" a ON a."id" = ua."achievementId"
WHERE ua."userId" = $1
ORDER BY ua."unlockedAt" DESC;

-- WRITE | Q61
INSERT INTO "UserAchievement" ("id", "userId", "achievementId", "unlockedAt")
VALUES ($1, $2, $3, now())
ON CONFLICT ("userId", "achievementId") DO NOTHING
RETURNING "id", "unlockedAt";

-- READ | Q62
SELECT "userId", "emailNotifications", "pushNotifications", "updatedAt"
FROM "UserPreference"
WHERE "userId" = $1;

-- WRITE | Q63
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

-- READ | Q64
SELECT sv."sentiment", COUNT(*)::int AS "votes"
FROM "SentimentVote" sv
JOIN "User" u ON u."id" = sv."userId"
WHERE sv."symbol" = $1
  AND ($2::timestamptz IS NULL OR sv."updatedAt" >= $2)
  AND u."isSuspended" = FALSE
GROUP BY sv."sentiment";

-- WRITE | Q65
INSERT INTO "SentimentVote" (
    "id", "userId", "symbol", "sentiment", "createdAt", "updatedAt"
)
VALUES ($1, $2, $3, $4::"Sentiment", now(), now())
ON CONFLICT ("userId", "symbol") DO UPDATE SET
    "sentiment" = EXCLUDED."sentiment",
    "updatedAt" = now()
RETURNING "id", "sentiment", "updatedAt";

-- READ | Q66
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

-- WRITE | Q67
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

-- READ | Q68
SELECT ct."id", ct."allocationPct", ct."maxTradeSize", ct."isActive",
       u."id" AS "traderId", u."name", u."avatarUrl",
       le."returnPct" AS "traderReturnPct"
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
ORDER BY ct."createdAt" DESC;
