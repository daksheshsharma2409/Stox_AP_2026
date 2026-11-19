
-- 1. ENUM TYPES

CREATE TYPE "Role" AS ENUM (
    'TRADER', 'ADMIN', 'MODERATOR'
);

CREATE TYPE "AssetType" AS ENUM (
    'STOCK', 'CRYPTO', 'FOREX'
);

CREATE TYPE "OrderSide" AS ENUM (
    'BUY', 'SELL'
);

CREATE TYPE "OrderType" AS ENUM (
    'MARKET', 'LIMIT', 'STOP_LOSS', 'TAKE_PROFIT'
);

CREATE TYPE "OrderStatus" AS ENUM (
    'PENDING', 'EXECUTED', 'CANCELLED', 'EXPIRED', 'REJECTED'
);

CREATE TYPE "OrderEventType" AS ENUM (
    'CREATED', 'EXECUTED', 'CANCELLED', 'EXPIRED', 'REJECTED'
);

CREATE TYPE "OrderSource" AS ENUM (
    'MANUAL', 'COPY_TRADE', 'DCA_BOT', 'LEAGUE'
);

CREATE TYPE "AlertCondition" AS ENUM (
    'PRICE_ABOVE',
    'PRICE_BELOW',
    'PERCENT_CHANGE_UP',
    'PERCENT_CHANGE_DOWN'
);

CREATE TYPE "AlertStatus" AS ENUM (
    'ACTIVE', 'TRIGGERED', 'EXPIRED', 'CANCELLED'
);

CREATE TYPE "NotificationType" AS ENUM (
    'ORDER_EXECUTED',
    'ORDER_CANCELLED',
    'ORDER_REJECTED',
    'ORDER_EXPIRED',
    'PRICE_ALERT',
    'ACHIEVEMENT_UNLOCKED',
    'COPY_TRADE_EXECUTED',
    'LEAGUE_UPDATE',
    'NEW_FOLLOWER',
    'SYSTEM'
);

CREATE TYPE "NotificationDeliveryStatus" AS ENUM (
    'PENDING', 'SENDING', 'DELIVERED', 'SKIPPED', 'FAILED'
);

CREATE TYPE "LeaderboardScope" AS ENUM (
    'GLOBAL', 'FRIENDS'
);

CREATE TYPE "LeaderboardPeriod" AS ENUM (
    'DAILY', 'WEEKLY', 'MONTHLY', 'ALL_TIME'
);

CREATE TYPE "LeagueStatus" AS ENUM (
    'UPCOMING', 'ACTIVE', 'COMPLETED', 'CANCELLED'
);

CREATE TYPE "Sentiment" AS ENUM (
    'BULLISH', 'BEARISH', 'NEUTRAL'
);


-- 2. USER

CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "googleId" TEXT,
    "name" TEXT NOT NULL,
    "avatarUrl" TEXT,

    "role" "Role" NOT NULL DEFAULT 'TRADER',

    "isVerified" BOOLEAN NOT NULL DEFAULT FALSE,
    "isSuspended" BOOLEAN NOT NULL DEFAULT FALSE,

    "emailAlerts" BOOLEAN NOT NULL DEFAULT TRUE,
    "emailDigest" BOOLEAN NOT NULL DEFAULT TRUE,
    "pushEnabled" BOOLEAN NOT NULL DEFAULT FALSE,
    "pushToken" TEXT,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastLoginAt" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "User_email_key" UNIQUE ("email"),
    CONSTRAINT "User_googleId_key" UNIQUE ("googleId")
);

CREATE INDEX "User_role_idx" ON "User" ("role");


-- 3. REFRESH TOKENS

CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,

    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),

    "userAgent" TEXT,
    "ipAddress" TEXT,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "RefreshToken_token_key" UNIQUE ("token"),

    CONSTRAINT "RefreshToken_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "RefreshToken_userId_idx"
    ON "RefreshToken" ("userId");


-- 4. PORTFOLIO

CREATE TABLE "Portfolio" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,

    "name" TEXT NOT NULL DEFAULT 'Main Portfolio',
    "description" TEXT,

    "startingBalance" DECIMAL(18,8) NOT NULL DEFAULT 10000,
    "cashBalance" DECIMAL(18,8) NOT NULL DEFAULT 10000,
    "reservedCash" DECIMAL(18,8) NOT NULL DEFAULT 0,

    "isDefault" BOOLEAN NOT NULL DEFAULT FALSE,
    "isActive" BOOLEAN NOT NULL DEFAULT TRUE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Portfolio_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Portfolio_userId_name_key" UNIQUE ("userId", "name"),

    CONSTRAINT "Portfolio_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Portfolio_userId_idx"
    ON "Portfolio" ("userId");

CREATE INDEX "Portfolio_userId_isActive_idx"
    ON "Portfolio" ("userId", "isActive");


-- 5. HOLDING

CREATE TABLE "Holding" (
    "id" TEXT NOT NULL,
    "portfolioId" TEXT NOT NULL,

    "symbol" TEXT NOT NULL,
    "assetType" "AssetType" NOT NULL,

    "quantity" DECIMAL(18,8) NOT NULL,
    "averageBuyPrice" DECIMAL(18,8) NOT NULL,
    "totalInvested" DECIMAL(18,8) NOT NULL,

    "isShort" BOOLEAN NOT NULL DEFAULT FALSE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Holding_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Holding_portfolioId_symbol_key"
        UNIQUE ("portfolioId", "symbol"),

    CONSTRAINT "Holding_portfolioId_fkey"
        FOREIGN KEY ("portfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Holding_portfolioId_idx"
    ON "Holding" ("portfolioId");

CREATE INDEX "Holding_symbol_idx"
    ON "Holding" ("symbol");


-- 6. ORDER

CREATE TABLE "Order" (
    "id" TEXT NOT NULL,
    "portfolioId" TEXT NOT NULL,

    "symbol" TEXT NOT NULL,
    "assetType" "AssetType" NOT NULL,

    "side" "OrderSide" NOT NULL,
    "type" "OrderType" NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING',

    "quantity" DECIMAL(18,8) NOT NULL,
    "reservedCash" DECIMAL(18,8) NOT NULL DEFAULT 0,

    "limitPrice" DECIMAL(18,8),
    "stopPrice" DECIMAL(18,8),
    "executedPrice" DECIMAL(18,8),

    "executedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),

    "executionAttempts" INTEGER NOT NULL DEFAULT 0,
    "lastExecutionAttemptAt" TIMESTAMP(3),

    "notes" TEXT,

    "source" "OrderSource" NOT NULL DEFAULT 'MANUAL',

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Order_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "Order_portfolioId_fkey"
        FOREIGN KEY ("portfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Order_portfolioId_idx"
    ON "Order" ("portfolioId");

CREATE INDEX "Order_portfolioId_status_idx"
    ON "Order" ("portfolioId", "status");

CREATE INDEX "Order_status_createdAt_idx"
    ON "Order" ("status", "createdAt");

CREATE INDEX "Order_symbol_status_idx"
    ON "Order" ("symbol", "status");


-- 7. SYMBOL

CREATE TABLE "Symbol" (
    "id" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "assetType" "AssetType" NOT NULL,
    "exchange" TEXT,
    "currency" TEXT NOT NULL DEFAULT 'USD',

    "sector" TEXT,
    "industry" TEXT,
    "logoUrl" TEXT,
    "description" TEXT,

    "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
    "isTradable" BOOLEAN NOT NULL DEFAULT TRUE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Symbol_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Symbol_symbol_key" UNIQUE ("symbol")
);

CREATE INDEX "Symbol_symbol_idx"
    ON "Symbol" ("symbol");

CREATE INDEX "Symbol_assetType_idx"
    ON "Symbol" ("assetType");


-- 8. TRADE

CREATE TABLE "Trade" (
    "id" TEXT NOT NULL,
    "portfolioId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,

    "symbol" TEXT NOT NULL,
    "assetType" "AssetType" NOT NULL,
    "side" "OrderSide" NOT NULL,

    "quantity" DECIMAL(18,8) NOT NULL,
    "price" DECIMAL(18,8) NOT NULL,
    "totalValue" DECIMAL(18,8) NOT NULL,
    "fees" DECIMAL(18,8) NOT NULL DEFAULT 0,

    "realizedPnl" DECIMAL(18,8),
    "realizedPnlPct" DECIMAL(18,8),

    "executedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "copyFanOutAt" TIMESTAMP(3),

    CONSTRAINT "Trade_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Trade_orderId_key" UNIQUE ("orderId"),

    CONSTRAINT "Trade_portfolioId_fkey"
        FOREIGN KEY ("portfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "Trade_orderId_fkey"
        FOREIGN KEY ("orderId")
        REFERENCES "Order" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Trade_portfolioId_idx"
    ON "Trade" ("portfolioId");

CREATE INDEX "Trade_symbol_idx"
    ON "Trade" ("symbol");

CREATE INDEX "Trade_executedAt_idx"
    ON "Trade" ("executedAt");

CREATE INDEX "Trade_portfolioId_executedAt_idx"
    ON "Trade" ("portfolioId", "executedAt");

CREATE INDEX "Trade_copyFanOutAt_executedAt_idx"
    ON "Trade" ("copyFanOutAt", "executedAt");


-- 9. ORDER EVENT

CREATE TABLE "OrderEvent" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,

    "sequence" INTEGER NOT NULL DEFAULT 1,

    "eventType" "OrderEventType" NOT NULL,
    "previousStatus" "OrderStatus",
    "newStatus" "OrderStatus" NOT NULL,

    "metadata" JSONB,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OrderEvent_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "OrderEvent_orderId_sequence_key"
        UNIQUE ("orderId", "sequence"),

    CONSTRAINT "OrderEvent_orderId_fkey"
        FOREIGN KEY ("orderId")
        REFERENCES "Order" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "OrderEvent_orderId_createdAt_idx"
    ON "OrderEvent" ("orderId", "createdAt");


-- 10. PERFORMANCE SNAPSHOT

CREATE TABLE "PerformanceSnapshot" (
    "id" TEXT NOT NULL,
    "portfolioId" TEXT NOT NULL,

    "totalValue" DECIMAL(18,8) NOT NULL,
    "cashBalance" DECIMAL(18,8) NOT NULL,
    "holdingsValue" DECIMAL(18,8) NOT NULL,

    "dailyPnl" DECIMAL(18,8) NOT NULL,
    "dailyPnlPct" DECIMAL(10,4) NOT NULL,

    "snapshotDate" DATE NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PerformanceSnapshot_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "PerformanceSnapshot_portfolioId_snapshotDate_key"
        UNIQUE ("portfolioId", "snapshotDate"),

    CONSTRAINT "PerformanceSnapshot_portfolioId_fkey"
        FOREIGN KEY ("portfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "PerformanceSnapshot_portfolioId_idx"
    ON "PerformanceSnapshot" ("portfolioId");

CREATE INDEX "PerformanceSnapshot_snapshotDate_idx"
    ON "PerformanceSnapshot" ("snapshotDate");


-- 11. NOTIFICATION

CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "eventKey" TEXT,
    "userId" TEXT NOT NULL,

    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "data" JSONB,

    "isRead" BOOLEAN NOT NULL DEFAULT FALSE,
    "readAt" TIMESTAMP(3),

    "deliveryStatus" "NotificationDeliveryStatus"
        NOT NULL DEFAULT 'PENDING',

    "deliveredAt" TIMESTAMP(3),
    "deliveryAttempts" INTEGER NOT NULL DEFAULT 0,
    "deliveryStartedAt" TIMESTAMP(3),
    "deliveryChannels" JSONB,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Notification_eventKey_key" UNIQUE ("eventKey"),

    CONSTRAINT "Notification_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Notification_userId_isRead_idx"
    ON "Notification" ("userId", "isRead");

CREATE INDEX "Notification_createdAt_idx"
    ON "Notification" ("createdAt");

CREATE INDEX "Notification_deliveryStatus_createdAt_idx"
    ON "Notification" ("deliveryStatus", "createdAt");


-- 12. FOLLOW

CREATE TABLE "Follow" (
    "id" TEXT NOT NULL,

    "followerId" TEXT NOT NULL,
    "followingId" TEXT NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Follow_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Follow_followerId_followingId_key"
        UNIQUE ("followerId", "followingId"),

    CONSTRAINT "Follow_followerId_fkey"
        FOREIGN KEY ("followerId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "Follow_followingId_fkey"
        FOREIGN KEY ("followingId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Follow_followerId_idx"
    ON "Follow" ("followerId");

CREATE INDEX "Follow_followingId_idx"
    ON "Follow" ("followingId");


-- 13. COPY TRADER

CREATE TABLE "CopyTrader" (
    "id" TEXT NOT NULL,

    "copierId" TEXT NOT NULL,
    "copiedId" TEXT NOT NULL,
    "copyPortfolioId" TEXT,

    "allocationPct" DECIMAL(5,2) NOT NULL DEFAULT 100,
    "maxTradeSize" DECIMAL(18,8),

    "isActive" BOOLEAN NOT NULL DEFAULT TRUE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CopyTrader_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "CopyTrader_copierId_copiedId_key"
        UNIQUE ("copierId", "copiedId"),

    CONSTRAINT "CopyTrader_copierId_fkey"
        FOREIGN KEY ("copierId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "CopyTrader_copiedId_fkey"
        FOREIGN KEY ("copiedId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "CopyTrader_copyPortfolioId_fkey"
        FOREIGN KEY ("copyPortfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    -- Database-level integrity constraints
    CONSTRAINT "CopyTrader_allocationPct_check"
        CHECK ("allocationPct" > 0 AND "allocationPct" <= 100),

    CONSTRAINT "CopyTrader_distinct_users_check"
        CHECK ("copierId" <> "copiedId"),

    CONSTRAINT "CopyTrader_maxTradeSize_check"
        CHECK ("maxTradeSize" IS NULL OR "maxTradeSize" > 0)
);

CREATE INDEX "CopyTrader_copierId_idx"
    ON "CopyTrader" ("copierId");

CREATE INDEX "CopyTrader_copiedId_idx"
    ON "CopyTrader" ("copiedId");

CREATE INDEX "CopyTrader_copyPortfolioId_idx"
    ON "CopyTrader" ("copyPortfolioId");


-- 14. ALERT

CREATE TABLE "Alert" (
    "id" TEXT NOT NULL,

    "userId" TEXT NOT NULL,
    "symbolId" TEXT NOT NULL,

    "condition" "AlertCondition" NOT NULL,
    "targetPrice" DECIMAL(18,8) NOT NULL,
    "status" "AlertStatus" NOT NULL DEFAULT 'ACTIVE',

    "sendEmail" BOOLEAN NOT NULL DEFAULT TRUE,
    "sendPush" BOOLEAN NOT NULL DEFAULT FALSE,

    "triggeredAt" TIMESTAMP(3),
    "message" TEXT,

    "baselinePrice" DECIMAL(18,8),
    "baselineAt" TIMESTAMP(3),

    "lastEvaluatedAt" TIMESTAMP(3),

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Alert_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "Alert_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "Alert_symbolId_fkey"
        FOREIGN KEY ("symbolId")
        REFERENCES "Symbol" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Alert_userId_status_idx"
    ON "Alert" ("userId", "status");

CREATE INDEX "Alert_status_symbolId_idx"
    ON "Alert" ("status", "symbolId");

CREATE INDEX "Alert_symbolId_idx"
    ON "Alert" ("symbolId");

CREATE INDEX "Alert_status_lastEvaluatedAt_idx"
    ON "Alert" ("status", "lastEvaluatedAt");


-- 15. LEADERBOARD SNAPSHOT

CREATE TABLE "LeaderboardSnapshot" (
    "id" TEXT NOT NULL,

    "scope" "LeaderboardScope" NOT NULL,
    "period" "LeaderboardPeriod" NOT NULL,

    "snapshotDate" DATE NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeaderboardSnapshot_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "LeaderboardSnapshot_scope_period_snapshotDate_key"
        UNIQUE ("scope", "period", "snapshotDate")
);

CREATE INDEX "LeaderboardSnapshot_scope_period_snapshotDate_idx"
    ON "LeaderboardSnapshot" ("scope", "period", "snapshotDate");


-- 16. LEADERBOARD ENTRY

CREATE TABLE "LeaderboardEntry" (
    "id" TEXT NOT NULL,

    "userId" TEXT NOT NULL,

    "scope" "LeaderboardScope" NOT NULL,
    "period" "LeaderboardPeriod" NOT NULL,

    "rank" INTEGER NOT NULL,
    "totalValue" DECIMAL(18,8) NOT NULL,
    "returnPct" DECIMAL(10,4) NOT NULL,

    "snapshotDate" DATE NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "snapshotId" TEXT NOT NULL,

    CONSTRAINT "LeaderboardEntry_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "LeaderboardEntry_scope_period_snapshotDate_userId_key"
        UNIQUE ("scope", "period", "snapshotDate", "userId"),

    CONSTRAINT "LeaderboardEntry_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "LeaderboardEntry_snapshotId_fkey"
        FOREIGN KEY ("snapshotId")
        REFERENCES "LeaderboardSnapshot" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "LeaderboardEntry_scope_period_snapshotDate_rank_idx"
    ON "LeaderboardEntry" ("scope", "period", "snapshotDate", "rank");

CREATE INDEX "LeaderboardEntry_snapshotId_idx"
    ON "LeaderboardEntry" ("snapshotId");


-- 17. POST

CREATE TABLE "Post" (
    "id" TEXT NOT NULL,

    "authorId" TEXT NOT NULL,

    "content" TEXT NOT NULL,
    "symbol" TEXT,
    "metadata" JSONB,

    "isHidden" BOOLEAN NOT NULL DEFAULT FALSE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Post_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "Post_authorId_fkey"
        FOREIGN KEY ("authorId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "Post_authorId_createdAt_idx"
    ON "Post" ("authorId", "createdAt");

CREATE INDEX "Post_createdAt_idx"
    ON "Post" ("createdAt");


-- 18. POST LIKE

CREATE TABLE "PostLike" (
    "id" TEXT NOT NULL,

    "postId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PostLike_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "PostLike_postId_userId_key"
        UNIQUE ("postId", "userId"),

    CONSTRAINT "PostLike_postId_fkey"
        FOREIGN KEY ("postId")
        REFERENCES "Post" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "PostLike_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "PostLike_userId_createdAt_idx"
    ON "PostLike" ("userId", "createdAt");


-- 19. USER PREFERENCE

CREATE TABLE "UserPreference" (
    "id" TEXT NOT NULL,

    "userId" TEXT NOT NULL,

    "emailNotifications" BOOLEAN NOT NULL DEFAULT TRUE,
    "pushNotifications" BOOLEAN NOT NULL DEFAULT TRUE,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserPreference_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "UserPreference_userId_key" UNIQUE ("userId"),

    CONSTRAINT "UserPreference_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- 20. SENTIMENT VOTE

CREATE TABLE "SentimentVote" (
    "id" TEXT NOT NULL,

    "userId" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "sentiment" "Sentiment" NOT NULL,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SentimentVote_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "SentimentVote_userId_symbol_key"
        UNIQUE ("userId", "symbol"),

    CONSTRAINT "SentimentVote_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "SentimentVote_symbol_updatedAt_idx"
    ON "SentimentVote" ("symbol", "updatedAt");


-- 21. ACHIEVEMENT

CREATE TABLE "Achievement" (
    "id" TEXT NOT NULL,

    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "iconUrl" TEXT,
    "category" TEXT NOT NULL,
    "criteria" JSONB,

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Achievement_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Achievement_code_key" UNIQUE ("code")
);


-- 22. USER ACHIEVEMENT

CREATE TABLE "UserAchievement" (
    "id" TEXT NOT NULL,

    "userId" TEXT NOT NULL,
    "achievementId" TEXT NOT NULL,

    "reason" TEXT NOT NULL,

    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserAchievement_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "UserAchievement_userId_achievementId_key"
        UNIQUE ("userId", "achievementId"),

    CONSTRAINT "UserAchievement_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "UserAchievement_achievementId_fkey"
        FOREIGN KEY ("achievementId")
        REFERENCES "Achievement" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "UserAchievement_userId_idx"
    ON "UserAchievement" ("userId");

CREATE INDEX "UserAchievement_achievementId_idx"
    ON "UserAchievement" ("achievementId");


-- 23. LEAGUE

CREATE TABLE "League" (
    "id" TEXT NOT NULL,

    "name" TEXT NOT NULL,
    "description" TEXT,

    "startingBalance" DECIMAL(18,8) NOT NULL DEFAULT 10000,
    "maxParticipants" INTEGER,

    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,

    "status" "LeagueStatus" NOT NULL DEFAULT 'UPCOMING',

    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "League_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "League_status_idx"
    ON "League" ("status");

CREATE INDEX "League_startDate_endDate_idx"
    ON "League" ("startDate", "endDate");


-- 24. LEAGUE MEMBER

CREATE TABLE "LeagueMember" (
    "id" TEXT NOT NULL,

    "leagueId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "portfolioId" TEXT NOT NULL,

    "rank" INTEGER,
    "finalReturn" DECIMAL(18,8),

    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeagueMember_pkey" PRIMARY KEY ("id"),

    CONSTRAINT "LeagueMember_portfolioId_key"
        UNIQUE ("portfolioId"),

    CONSTRAINT "LeagueMember_leagueId_userId_key"
        UNIQUE ("leagueId", "userId"),

    CONSTRAINT "LeagueMember_leagueId_fkey"
        FOREIGN KEY ("leagueId")
        REFERENCES "League" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "LeagueMember_userId_fkey"
        FOREIGN KEY ("userId")
        REFERENCES "User" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT "LeagueMember_portfolioId_fkey"
        FOREIGN KEY ("portfolioId")
        REFERENCES "Portfolio" ("id")
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX "LeagueMember_leagueId_idx"
    ON "LeagueMember" ("leagueId");

CREATE INDEX "LeagueMember_userId_idx"
    ON "LeagueMember" ("userId");

