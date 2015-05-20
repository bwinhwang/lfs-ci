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
