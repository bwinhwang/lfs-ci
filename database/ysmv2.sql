DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS targets;
-- DROP TABLE IF EXISTS target_status;
-- CREATE TABLE target_status (
--     id INT NOT NULL AUTO_INCREMENT,
--     status VARCHAR(10) NOT NULL,
--     PRIMARY KEY (id),
--     INDEX(id)
-- );

-- INSERT INTO target_status ( status ) values ( 'free' );
-- INSERT INTO target_status ( status ) values ( 'reserved' );
-- INSERT INTO target_status ( status ) values ( 'maintainance' );

DROP TABLE IF EXISTS targets;
CREATE TABLE targets (
    id INT NOT NULL AUTO_INCREMENT,
    target_name VARCHAR(100) NOT NULL,
    target_features VARCHAR(1024) ,
    status VARCHAR(10),

    PRIMARY KEY (id),
    INDEX(id)
);

-- INSERT INTO targets ( target_name, target_features, status  ) values ( 'fcmd15', 'FSM-r2', 'free' );
-- INSERT INTO targets ( target_name, target_features, status  ) values ( 'FSCA-1335-X03', 'FSM-r4 FSCA', 'free' );
-- INSERT INTO targets ( target_name, target_features, status  ) values ( 'FSPJ-1076-X02', 'FSM-r4 FSPJ', 'free' );
INSERT INTO targets ( target_name, target_features, status  ) values ( 'FSIH-214-101', 'FSM-r3 FSIH', 'free' );

-- DROP TABLE IF EXISTS booking;
DROP TABLE IF EXISTS bookings;
CREATE TABLE bookings (
    ID INT NOT NULL AUTO_INCREMENT,
    user VARCHAR(8) NOT NULL,
    target_id INT NOT NULL,
    comment VARCHAR(256) NULL,
    startTime DATETIME NOT NULL,
    endTime   DATETIME NULL,

    PRIMARY KEY (id),
    INDEX(id),
    FOREIGN KEY (target_id)
        REFERENCES targets(id)
);

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

-- select * from targets;
-- select * from bookings;

-- CALL reserveTarget( 'fcmd15', 'bm', 'foobar' );

-- select * from targets;
-- select * from bookings;
-- CALL reserveTarget( 'fcmd15', 'bm', 'foobar' );
-- CALL reserveTarget( 'abc', 'bm', 'foobar' );
-- select * from targets;
-- select * from bookings;
-- CALL unreserveTarget( 'fcmd15' );
-- select * from targets;
-- select * from bookings;
