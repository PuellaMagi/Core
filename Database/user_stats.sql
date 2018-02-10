CREATE PROCEDURE `user_stats`
(
IN
    userId INT(11),
    sessionId INT(11),
    todayOnline INT(11),
    totalOnline INT(11),
    specOnline INT(11),
    playOnline INT(11),
    userName VARCHAR(32)
)

SQL SECURITY INVOKER

BEGIN

DECLARE dbStep TINYINT(3) DEFAULT 0;

START TRANSACTION;

    /* UPDATE dxg_users */
    UPDATE  `dxg_users`
    SET     `lastseen` = UNIX_TIMESTAMP(),
            `username` = `userName`
    WHERE   `uid` = `userId`;

    IF (ROW_COUNT() > 0) THEN
        SET dbStep = dbStep + 1;
    END IF;

    UPDATE  `dxg_stats`
    SET     `connectTimes` = `connectTimes` + 1,
            `onlineToday`  = `onlineToday`  + `todayOnline`,
            `onlineTotal`  = `onlineTotal`  + `totalOnline`,
            `onlineOB`     = `onlineOB`     + `specOnline`,
            `onlinePlay`   = `onlinePlay`   + `playOnline`
    WHERE   `uid` = `userId`;
    
    IF (ROW_COUNT() > 0) THEN
        SET dbStep = dbStep + 1;
    END IF;
    
    UPDATE  `dxg_analytics`
    SET     `duration` = `totalOnline`
    WHERE   `uid` = `userId` AND `id` = `sessionId`;
    
    IF (ROW_COUNT() > 0) THEN
        SET dbStep = dbStep + 1;
    END IF;

    SELECT dbStep;

END;