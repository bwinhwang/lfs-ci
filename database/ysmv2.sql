DROP PROCEDURE IF EXISTS reserveTarget;
DELIMITER //
CREATE PROCEDURE reserveTarget( IN in_target_name varchar(100), IN in_user varchar(8), IN in_comment varchar(1024) )
BEGIN
    DECLARE var_isFree INT;
    DECLARE var_target_id INT;

    START TRANSACTION WITH CONSISTENT SNAPSHOT;
    SET autocommit = 0;

    SELECT count(*) INTO var_isFree FROM targets WHERE target_name = in_target_name;
    IF var_isFree = 0 THEN
        -- target does not exist
        ROLLBACK;
        SIGNAL SQLSTATE '45001'
        SET MESSAGE_TEXT = 'target does not exist';
    END IF;

    SELECT count(*) INTO var_isFree FROM targets WHERE target_name = in_target_name and status = 'free';

    IF var_isFree = 1 THEN
        -- target is free
        UPDATE targets SET status = 'reserverd' WHERE target_name = in_target_name;

        SELECT id INTO var_target_id FROM targets WHERE target_name = in_target_name;
        INSERT INTO bookings ( user, target_id, comment, startTime ) VALUES ( in_user, var_target_id, in_comment, NOW() );
        COMMIT;
    ELSE
        -- target is not free => raise an error
        ROLLBACK;
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = "target is not free";
    END IF;

END //
DELIMITER ;

DROP PROCEDURE IF EXISTS unreserveTarget;
DELIMITER //
CREATE PROCEDURE unreserveTarget( IN in_target_name varchar(100) )
BEGIN
    DECLARE var_target_id INT;

    START TRANSACTION WITH CONSISTENT SNAPSHOT;

    SET autocommit = 0;

    SELECT id INTO var_target_id FROM targets WHERE target_name = in_target_name;
    UPDATE bookings SET endTime = NOW() WHERE target_id = var_target_id AND endTime IS NULL;
    UPDATE targets SET status = 'free' WHERE id = var_target_id;

    COMMIT;

END //
DELIMITER ;

