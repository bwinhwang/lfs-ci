DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS build_events;
DROP TABLE IF EXISTS builds;

DROP TABLE IF EXISTS builds;
CREATE TABLE builds (
    id          INT NOT NULL AUTO_INCREMENT,
    build_name  VARCHAR(128) NOT NULL,
    branch_name VARCHAR(128) NOT NULL,
    revision    INT NOT NULL,
    comment     TEXT,

    PRIMARY KEY (id),
    INDEX(build_name)
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
    build_name VARCHAR(128) NOT NULL,
    event_id   INT NOT NULL,
    timestamp  DATETIME NOT NULL,
    comment    TEXT,

    PRIMARY KEY (id),
    FOREIGN KEY (event_id)
        REFERENCES events(id),
    FOREIGN KEY (build_name)
        REFERENCES builds(build_name)
);

DROP TABLE IF EXISTS test_executions;
CREATE TABLE test_executions (
    id              INT NOT NULL AUTO_INCREMENT,
    build_name      VARCHAR(128) NOT NULL,
    test_suite_name VARCHAR(128) NOT NULL,
    target_name     VARCHAR(128) NOT NULL,
    target_type     VARCHAR(128) NOT NULL,

    PRIMARY KEY (id) 
    FOREIGN KEY (build_name)
        REFERENCES builds(build_name)
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

DROP TABLE IF EXISTS test_result_names;
CREATE TABLE test_result_names (
    id               INT NOT NULL AUTO_INCREMENT,
    test_suite_name  VARCHAR(128) NOT NULL,
    test_result_name VARCHAR(128) NOT NULL,

    PRIMARY KEY (id)
);

