DROP TABLE IF EXISTS test_results;
DROP TABLE IF EXISTS test_result_names;
DROP TABLE IF EXISTS test_executions;
DROP TABLE IF EXISTS build_events;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS builds;
DROP TABLE IF EXISTS branches;

DROP TABLE IF EXISTS branches;
CREATE TABLE branches (
    id                 INT NOT NULL AUTO_INCREMENT,
    branch_name        VARCHAR(128) NOT NULL,
    location_name      VARCHAR(128) NOT NULL,
    ps_branch_name     VARCHAR(128) NOT NULL,
    status             VARCHAR(16) NOT NULL DEFAULT 'open',
    based_on_revision  INT NULL,
    based_on_release   VARCHAR(128) NULL,
    release_name_regex VARCHAR(128) NOT NULL DEFAULT 'PS_LFS_OS_$(date_Y)_$(date_m)_(\d\d\d\d)',
    date_created       DATETIME NOT NULL,
    date_closed        DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    comment            TEXT,

    PRIMARY KEY (id),
    INDEX(branch_name)
);

DROP TABLE IF EXISTS builds;
CREATE TABLE builds (
    id          INT NOT NULL AUTO_INCREMENT,
    build_name  VARCHAR(128) NOT NULL,
    branch_id   VARCHAR(128) NOT NULL,
    revision    INT NOT NULL,
    comment     TEXT,

    PRIMARY KEY (id),
    INDEX(build_name),
    FOREIGN KEY (branch_id)
        REFERENCES branches(id)
);

DROP TABLE IF EXISTS events;
CREATE TABLE events (
    id INT NOT NULL AUTO_INCREMENT,
    event_name VARCHAR(128) NOT NULL,
    event_type VARCHAR(128),
    event_description TEXT,

    PRIMARY KEY (id),
    INDEX(id)
);

DROP TABLE IF EXISTS build_events;
CREATE TABLE build_events (
    id         INT NOT NULL AUTO_INCREMENT,
    build_id   INT NOT NULL,
    event_id   INT NOT NULL,
    timestamp  DATETIME NOT NULL,
    comment    TEXT,

    PRIMARY KEY (id),
    FOREIGN KEY (event_id)
        REFERENCES events(id),
    FOREIGN KEY (build_id)
        REFERENCES builds(id)
);

DROP TABLE IF EXISTS test_executions;
CREATE TABLE test_executions (
    id              INT NOT NULL AUTO_INCREMENT,
    build_id        INT NOT NULL,
    test_suite_name VARCHAR(128) NOT NULL,
    target_name     VARCHAR(128) NOT NULL,
    target_type     VARCHAR(128) NOT NULL,

    PRIMARY KEY (id), 
    FOREIGN KEY (build_id)
        REFERENCES builds(id)
);



DROP TABLE IF EXISTS test_result_names;
CREATE TABLE test_result_names (
    id               INT NOT NULL AUTO_INCREMENT,
    test_suite_name  VARCHAR(128) NOT NULL,
    test_result_name VARCHAR(128) NOT NULL,

    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS test_results;
CREATE TABLE test_results (
    id                  INT NOT NULL AUTO_INCREMENT,
    test_execution_id   INT NOT NULL,
    test_result_name_id INT NOT NULL,
    test_result_value   INT,

    PRIMARY KEY (id),
    FOREIGN KEY (test_execution_id)
        REFERENCES test_executions(id),
    FOREIGN KEY (test_result_name_id)
        REFERENCES test_result_names(id)
);


DROP PROCEDURE migrateBranchData;
DELIMITER //
CREATE PROCEDURE migrateBranchData()
BEGIN
  DECLARE bDone INT;

  DECLARE var1 TEXT;
  DECLARE var2 INT;

  DECLARE curs CURSOR FOR  select branch_name, min(revision) from builds group by branch_name;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

  OPEN curs;

  SET bDone = 0;
  REPEAT
    FETCH curs INTO var1,var2;
       INSERT INTO branches ( location_name, ps_branch_name, branch_name, based_on_revision, date_created) values ( var1, var1, var1, var2 , NOW());
        UPDATE builds SET branch_id = LAST_INSERT_ID() WHERE branch_name = var1;
        
  UNTIL bDone END REPEAT;

  CLOSE curs;
   END //
DELIMITER ;
