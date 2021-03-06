DROP TABLE IF EXISTS test_results;
DROP TABLE IF EXISTS test_result_names;
DROP TABLE IF EXISTS test_executions;
DROP TABLE IF EXISTS build_events;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS builds;
DROP TABLE IF EXISTS nm_branches_ps_branches;
DROP TABLE IF EXISTS ps_branches;
DROP TABLE IF EXISTS branches;

DROP TABLE IF EXISTS branches;
CREATE TABLE branches (
    id                 INT NOT NULL AUTO_INCREMENT,
    branch_name        VARCHAR(128) NOT NULL,
    location_name      VARCHAR(128) NOT NULL,
    status             VARCHAR(16) NOT NULL DEFAULT 'open',
    based_on_revision  INT NULL,
    based_on_release   VARCHAR(128) NULL,
    release_name_regex VARCHAR(128) NOT NULL DEFAULT 'PS_LFS_OS_$(date_Y)_$(date_m)_(\d\d\d\d)',
    date_created       DATETIME NOT NULL,
    date_closed        DATETIME,
    comment            TEXT,
    branch_description TEXT,
    product_name       VARCHAR(16) DEFAULT 'LFS',

    PRIMARY KEY (id),
    INDEX(branch_name)
);

CREATE TABLE ps_branches (
    id                 INT NOT NULL AUTO_INCREMENT,
    ps_branch_name     VARCHAR(128) NOT NULL,
    status             VARCHAR(16) NOT NULL DEFAULT 'open',
    ecl_url            VARCHAR(254) NOT NULL,
    comment            TEXT,

    PRIMARY KEY (id),
    UNIQUE(ps_branch_name)
);

CREATE TABLE nm_branches_ps_branches (
    id               INT NOT NULL AUTO_INCREMENT,
    ps_branch_id     INT NOT NULL,
    branch_id        INT NOT NULL,

    PRIMARY KEY (id),
    UNIQUE(ps_branch_id, branch_id),

    FOREIGN KEY (ps_branch_id)
        REFERENCES ps_branches(id),
    FOREIGN KEY (branch_id)
        REFERENCES branches(id)
);

DROP TABLE IF EXISTS builds;
CREATE TABLE builds (
    id          INT NOT NULL AUTO_INCREMENT,
    build_name  VARCHAR(128) NOT NULL,
    branch_id   INT NOT NULL,
    revision    INT NOT NULL,
    comment     TEXT,

    PRIMARY KEY (id),
    INDEX(build_name),
    FOREIGN KEY (branch_id)
        REFERENCES branches(id)
);

DROP TABLE IF EXISTS events;
CREATE TABLE events (
    id INT       NOT NULL AUTO_INCREMENT,
    event_type   VARCHAR(128) NOT NULL DEFAULT 'build',
    event_state  VARCHAR(128) NOT NULL DEFAULT 'started',
    product_name VARCHAR(128),
    task_name    VARCHAR(128),

    PRIMARY KEY (id),
    INDEX(id)
);

DROP TABLE IF EXISTS build_events;
CREATE TABLE build_events (
    id           INT NOT NULL AUTO_INCREMENT,
    build_id     INT NOT NULL,
    event_id     INT NOT NULL,
    timestamp    DATETIME NOT NULL,
    comment      TEXT,
    job_name     VARCHAR(128) NOT NULL,
    build_number INT NOT NULL,
    build_host   VARCHAR(256),

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
    job_name        VARCHAR(128) NULL,
    build_number    INT,

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

DROP TABLE IF EXISTS test_cases;
CREATE TABLE test_cases (
    id                  INT NOT NULL AUTO_INCREMENT,
    test_case_name      TEXT NOT NULL,
    test_case_owner     VARCHAR(128) NOT NULL,

    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS test_case_results;
CREATE TABLE test_case_results (
    id                      INT NOT NULL AUTO_INCREMENT,
    test_case_id            INT NOT NULL,
    test_execution_id       INT NOT NULL,
    test_case_duration      FLOAT NULL,
    test_case_failed_since  INT NULL,
    test_case_skipped       BOOLEAN NULL,
    test_case_result        TEXT NULL,

    PRIMARY KEY (id),
    FOREIGN KEY (test_execution_id)
        REFERENCES test_executions(id)
        ON UPDATE CASCADE     
        ON DELETE RESTRICT,
    FOREIGN KEY (test_case_id)
        REFERENCES test_cases(id)
        ON UPDATE CASCADE     
        ON DELETE RESTRICT
);

