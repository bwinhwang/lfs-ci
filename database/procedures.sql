-- {{{ new_build
DROP PROCEDURE IF EXISTS new_build;
DELIMITER //
CREATE PROCEDURE new_build( IN in_build_name VARCHAR(128), 
                            IN in_branch_name VARCHAR(128), 
                            IN in_comment TEXT, 
                            IN in_revision INT )
BEGIN
    DECLARE cnt_branch_id INT;
    DECLARE var_branch_id INT;

    SELECT count(id) INTO cnt_branch_id FROM branches WHERE location_name = in_branch_name;
    IF cnt_branch_id = 0 THEN
        INSERT INTO branches ( ps_branch_name, location_name, branch_name, date_created, comment ) VALUES ( in_branch_name, in_branch_name, in_branch_name, NOW(), in_comment );
    END IF;
    SELECT id INTO var_branch_id FROM branches WHERE location_name = in_branch_name;

    INSERT INTO builds (build_name, branch_id, revision, comment) VALUES ( in_build_name, var_branch_id, in_revision, in_comment );
   
END //
DELIMITER ;
-- }}}
-- {{{ new_build_event
DROP PROCEDURE IF EXISTS new_build_event;
DELIMITER //
CREATE PROCEDURE new_build_event( IN in_build_name   VARCHAR(128), 
                                  IN in_comment      TEXT,
                                  IN in_job_name     VARCHAR(128),
                                  IN in_build_number INT, 
                                  IN in_product_name VARCHAR(128), 
                                  IN in_task_name    VARCHAR(128), 
                                  IN in_event_type   VARCHAR(128), 
                                  IN in_event_state  VARCHAR(128)
                                )
BEGIN
    DECLARE cnt_event_id INT;
    DECLARE var_event_id INT;
    DECLARE var_build_id INT;

    SELECT count(id) INTO cnt_event_id 
        FROM events 
        WHERE product_name  = in_product_name 
            AND task_name   = in_task_name
            AND event_type  = in_event_type
            AND event_state = in_event_state;

    IF cnt_event_id = 0 THEN
        INSERT INTO events ( product_name, task_name, event_type, event_state ) 
            VALUES ( in_product_name, in_task_name, in_event_type, in_event_state );
    END IF;

    SELECT id INTO var_event_id 
        FROM events 
        WHERE product_name  = in_product_name 
            AND task_name   = in_task_name
            AND event_type  = in_event_type
            AND event_state = in_event_state;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;
   
    INSERT INTO build_events (event_id, build_id, timestamp, comment, job_name, build_number) 
        VALUES ( var_event_id, var_build_id, now(), in_comment, in_job_name, in_build_number );

END //
DELIMITER ;
-- }}}
-- {{{ build_started
DROP PROCEDURE IF EXISTS build_started;
DELIMITER //
CREATE PROCEDURE build_started( IN in_build_name   VARCHAR(128), 
                                IN in_comment      TEXT, 
                                IN in_branch_name  VARCHAR(128), 
                                IN in_revision     INT, 
                                IN in_job_name     VARCHAR(128), 
                                IN in_build_number INT,
                                IN in_product_name VARCHAR(128),
                                IN in_task_name    VARCHAR(128) 
                              )
BEGIN
    CALL new_build( in_build_name, in_branch_name, in_comment, in_revision);
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'build', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ build_failed

DROP PROCEDURE IF EXISTS build_failed;
DELIMITER //
CREATE PROCEDURE build_failed( IN in_build_name   VARCHAR(128), 
                               IN in_comment      TEXT, 
                               IN in_job_name     VARCHAR(128), 
                               IN in_build_number INT,
                               IN in_product_name VARCHAR(128),
                               IN in_task_name    VARCHAR(128) 
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'build', 'failed' );
END //
DELIMITER ;

-- }}}
-- {{{ build_finished

DROP PROCEDURE IF EXISTS build_finished;
DELIMITER //
CREATE PROCEDURE build_finished( IN in_build_name   VARCHAR(128), 
                                 IN in_comment      TEXT, 
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'build', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_started

DROP PROCEDURE IF EXISTS subbuild_started;
DELIMITER //
CREATE PROCEDURE subbuild_started( IN in_build_name   VARCHAR(128), 
                                   IN in_comment      TEXT, 
                                   IN in_job_name     VARCHAR(128), 
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128) 
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subbuild', 'started' );
    CALL mustHaveRunningEvent( in_build_name, 'build', in_product_name, in_task_name );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_finished

DROP PROCEDURE IF EXISTS subbuild_finished;
DELIMITER //
CREATE PROCEDURE subbuild_finished( IN in_build_name   VARCHAR(128), 
                                    IN in_comment      TEXT,
                                    IN in_job_name     VARCHAR(128), 
                                    IN in_build_number INT,
                                    IN in_product_name VARCHAR(128),
                                    IN in_task_name    VARCHAR(128) 
                                  )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subbuild', 'finished' );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'build' );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_failed

DROP PROCEDURE IF EXISTS subbuild_failed;
DELIMITER //
CREATE PROCEDURE subbuild_failed( IN in_build_name   VARCHAR(128), 
                                  IN in_comment      TEXT,
                                  IN in_job_name     VARCHAR(128), 
                                  IN in_build_number INT,
                                  IN in_product_name VARCHAR(128),
                                  IN in_task_name    VARCHAR(128) 
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subbuild', 'failed' );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'build' );
END //
DELIMITER ;

-- }}}
-- {{{ test_started

DROP PROCEDURE IF EXISTS test_started;
DELIMITER //
CREATE PROCEDURE test_started( IN in_build_name   VARCHAR(128), 
                               IN in_comment      TEXT,
                               IN in_job_name     VARCHAR(128), 
                               IN in_build_number INT,
                               IN in_product_name VARCHAR(128),
                               IN in_task_name    VARCHAR(128) 
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'test', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ test_failed

DROP PROCEDURE IF EXISTS test_failed;
DELIMITER //
CREATE PROCEDURE test_failed( IN in_build_name   VARCHAR(128), 
                              IN in_comment      TEXT,
                              IN in_job_name     VARCHAR(128), 
                              IN in_build_number INT,
                              IN in_product_name VARCHAR(128),
                              IN in_task_name    VARCHAR(128) 
                            )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'test', 'failed' );
END //
DELIMITER ;

-- }}}
-- {{{ test_finished

DROP PROCEDURE IF EXISTS test_finished;
DELIMITER //
CREATE PROCEDURE test_finished( IN in_build_name   VARCHAR(128), 
                                IN in_comment      TEXT,
                                IN in_job_name     VARCHAR(128), 
                                IN in_build_number INT,
                                IN in_product_name VARCHAR(128),
                                IN in_task_name    VARCHAR(128) 
                            )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'test', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_started

DROP PROCEDURE IF EXISTS subtest_started;
DELIMITER //
CREATE PROCEDURE subtest_started( IN in_build_name VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_job_name VARCHAR(128), 
                                  IN in_build_number INT,
                                  IN in_product_name VARCHAR(128),
                                  IN in_task_name    VARCHAR(128) 
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subtest', 'started' );
    CALL mustHaveRunningEvent( in_build_name, 'test', in_product_name, in_task_name );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_unstable

DROP PROCEDURE IF EXISTS subtest_unstable;
DELIMITER //
CREATE PROCEDURE subtest_unstable( IN in_build_name   VARCHAR(128), 
                                   IN in_comment      TEXT,
                                   IN in_job_name     VARCHAR(128), 
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128) 
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subtest', 'unstable' );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test' );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_failed

DROP PROCEDURE IF EXISTS subtest_failed;
DELIMITER //
CREATE PROCEDURE subtest_failed( IN in_build_name   VARCHAR(128),
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subtest', 'failed' );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test' );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_finished

DROP PROCEDURE IF EXISTS subtest_finished;
DELIMITER //
CREATE PROCEDURE subtest_finished( IN in_build_name   VARCHAR(128),
                                   IN in_comment      TEXT,
                                   IN in_job_name     VARCHAR(128), 
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128) 
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'subtest', 'finished' );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test' );
END //
DELIMITER ;

-- }}}
-- {{{ package_started

DROP PROCEDURE IF EXISTS package_started;
DELIMITER //
CREATE PROCEDURE package_started( IN in_build_name   VARCHAR(128), 
                                  IN in_comment      TEXT,
                                  IN in_job_name     VARCHAR(128), 
                                  IN in_build_number INT,
                                  IN in_product_name VARCHAR(128),
                                  IN in_task_name    VARCHAR(128) 
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'package', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ package_finished

DROP PROCEDURE IF EXISTS package_finished;
DELIMITER //
CREATE PROCEDURE package_finished( IN in_build_name   VARCHAR(128), 
                                   IN in_comment      TEXT,
                                   IN in_job_name     VARCHAR(128), 
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128) 
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'package', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ package_failed

DROP PROCEDURE IF EXISTS package_failed;
DELIMITER //
CREATE PROCEDURE package_failed( IN in_build_name   VARCHAR(128), 
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                               )
BEGIN 
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'package', 'failed' );
END //
DELIMITER ;

-- }}}
-- {{{ release_started

DROP PROCEDURE IF EXISTS release_started;
DELIMITER //
CREATE PROCEDURE release_started( IN in_build_name   VARCHAR(128), 
                                  IN in_comment      TEXT,
                                  IN in_job_name     VARCHAR(128), 
                                  IN in_build_number INT,
                                  IN in_product_name VARCHAR(128),
                                  IN in_task_name    VARCHAR(128) 
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'release', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ release_finished

DROP PROCEDURE IF EXISTS release_finished;
DELIMITER //
CREATE PROCEDURE release_finished( IN in_build_name VARCHAR(128), 
                                   IN in_comment TEXT,
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128) 
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'release', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ other_started

DROP PROCEDURE IF EXISTS other_started;
DELIMITER //
CREATE PROCEDURE other_started( IN in_build_name   VARCHAR(128), 
                                IN in_comment      TEXT,
                                IN in_job_name     VARCHAR(128), 
                                IN in_build_number INT,
                                IN in_product_name VARCHAR(128),
                                IN in_task_name    VARCHAR(128) 
                              )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ other_finished

DROP PROCEDURE IF EXISTS other_finished;
DELIMITER //
CREATE PROCEDURE other_finished( IN in_build_name   VARCHAR(128), 
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ other_failed

DROP PROCEDURE IF EXISTS other_failed;
DELIMITER //
CREATE PROCEDURE other_failed( IN in_build_name   VARCHAR(128), 
                               IN in_comment      TEXT,
                               IN in_job_name     VARCHAR(128), 
                               IN in_build_number INT,
                               IN in_product_name VARCHAR(128),
                               IN in_task_name    VARCHAR(128) 
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'release', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ other_started

DROP PROCEDURE IF EXISTS other_started;
DELIMITER //
CREATE PROCEDURE other_started( IN in_build_name   VARCHAR(128), 
                                IN in_comment      TEXT,
                                IN in_job_name     VARCHAR(128), 
                                IN in_build_number INT,
                                IN in_product_name VARCHAR(128),
                                IN in_task_name    VARCHAR(128) 
                              )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'started' );
END //
DELIMITER ;

-- }}}
-- {{{ other_finished

DROP PROCEDURE IF EXISTS other_finished;
DELIMITER //
CREATE PROCEDURE other_finished( IN in_build_name   VARCHAR(128), 
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'finished' );
END //
DELIMITER ;

-- }}}
-- {{{ other_failed

DROP PROCEDURE IF EXISTS other_failed;
DELIMITER //
CREATE PROCEDURE other_failed( IN in_build_name   VARCHAR(128), 
                               IN in_comment      TEXT,
                               IN in_job_name     VARCHAR(128), 
                               IN in_build_number INT,
                               IN in_product_name VARCHAR(128),
                               IN in_task_name    VARCHAR(128) 
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'failed' );
END //
DELIMITER ;

-- }}}
-- {{{ other_unstable

DROP PROCEDURE IF EXISTS other_unstable;
DELIMITER //
CREATE PROCEDURE other_unstable( IN in_build_name   VARCHAR(128), 
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128), 
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128) 
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                          in_product_name, in_task_name, 'other', 'unstable' );
END //
DELIMITER ;

-- }}}

-- {{{ add_new_test_execution

DROP PROCEDURE IF EXISTS add_new_test_execution;
DELIMITER //
CREATE PROCEDURE add_new_test_execution( IN in_build_name          VARCHAR(128), 
                                         IN in_test_suite_name     VARCHAR(128), 
                                         IN in_target_name         VARCHAR(128),
                                         IN in_target_type         VARCHAR(128),
                                         OUT out_test_execution_id INT )
BEGIN
   DECLARE cnt_build_id INT;
   DECLARE var_build_id INT;

   SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;
   -- check if build name exists
   -- IF cnt_build_id = 0 THEN
   --      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
   -- END IF;
   -- more code below
   -- TODO: demx2fk3 2015-01-13 this is an hack, there is no better way to ghet the latest build id
   SELECT max(id) INTO var_build_id FROM builds WHERE build_name = in_build_name;
    
    INSERT INTO test_executions ( build_id, test_suite_name, target_name, target_type ) VALUES ( var_build_id, in_test_suite_name, in_target_name, in_target_type );
    SET out_test_execution_id = LAST_INSERT_ID();

END //
DELIMITER ;

-- }}}
-- {{{ add_new_test_result

DROP PROCEDURE IF EXISTS add_new_test_result;
DELIMITER //
CREATE PROCEDURE add_new_test_result( IN test_execution_id    INT, 
                                      IN in_test_result_name  TEXT,
                                      IN in_test_result_value INT )
BEGIN

    DECLARE cnt_test_result_name_id INT;
    DECLARE var_test_result_name_id INT;
    DECLARE var_test_suite_name     TEXT;

    SELECT test_suite_name INTO var_test_suite_name FROM test_executions WHERE id = test_execution_id;
    /* add check here */ 

    SELECT count(id) INTO cnt_test_result_name_id FROM test_result_names WHERE test_suite_name = var_test_suite_name AND test_result_name = in_test_result_name;
   
    IF cnt_test_result_name_id = 0 THEN
        INSERT INTO test_result_names ( test_suite_name, test_result_name ) VALUES ( var_test_suite_name, in_test_result_name );
    END IF;
    SELECT id INTO var_test_result_name_id FROM test_result_names WHERE test_suite_name = var_test_suite_name AND test_result_name = in_test_result_name;
   
    INSERT INTO test_results (test_execution_id, test_result_name_id, test_result_value) VALUES ( test_execution_id, var_test_result_name_id, in_test_result_value);

END //
DELIMITER ;

-- }}}
-- {{{ add_new_test_case_result

DROP PROCEDURE IF EXISTS add_new_test_case_result;
DELIMITER //
CREATE PROCEDURE add_new_test_case_result( IN test_execution_id     INT, 
                                           IN in_test_case_name     VARCHAR(128),
                                           IN in_test_case_result   INT,
                                           IN in_test_case_duration INT,
                                           IN in_test_case_owner    VARCHAR(128)
                                           )
BEGIN
    DECLARE cnt_test_case_id INT;
    DECLARE var_test_case_id INT;

    SELECT count(id) INTO cnt_test_case_id FROM test_cases WHERE test_case_name = in_test_case_name;
   
    IF cnt_test_case_id = 0 THEN
        INSERT INTO test_cases ( test_case_name, test_case_owner ) VALUES ( in_test_case_name, in_test_case_owner );
    END IF;
    SELECT id INTO var_test_case_id FROM test_cases WHERE test_case_name = in_test_case_name;
   
    INSERT INTO test_case_results ( test_execution_id, test_case_id, test_case_duration, test_case_result ) 
        VALUES ( test_execution_id, var_test_case_id, in_test_case_duration, in_test_case_result);
END //
DELIMITER ;

-- }}}
-- {{{ test_results

DROP PROCEDURE IF EXISTS test_results;
DELIMITER //
CREATE PROCEDURE test_results()
BEGIN

    SET @sql = NULL;
    SET SESSION group_concat_max_len = 40000;
    SELECT GROUP_CONCAT(DISTINCT
           CONCAT('MAX(CASE WHEN test_result_name = ''', test_result_name,
           ''' THEN test_result_value END) `', test_result_name, '`'))
    INTO @sql
    FROM v_test_results;

    DROP TABLE IF EXISTS tmp_test_results;
    SET @sql =
        CONCAT('CREATE TEMPORARY TABLE tmp_test_results
            SELECT test_execution_id, ', @sql, '
                     FROM v_test_results
                    GROUP BY test_execution_id');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END //
DELIMITER ;

-- }}}
-- {{{ isFailed

DROP FUNCTION IF EXISTS isFailed;

-- }}}
-- {{{ _running_tasks

DROP FUNCTION IF EXISTS _running_tasks;
DELIMITER //

CREATE FUNCTION _running_tasks( in_build_id     INT,
                                in_event_type   TEXT,
                                in_event_state  VARCHAR(128),
                                in_product_name VARCHAR(128), 
                                in_task_name    VARCHAR(128)
                              ) RETURNS int
    DETERMINISTIC
BEGIN
    DECLARE _running_tasks INT;

    SELECT count(*) INTO _running_tasks
        FROM build_events be, events e
        WHERE be.build_id      = in_build_id
            AND be.event_id    = e.id
            AND e.event_type   = CONCAT( "sub", in_event_type )
            AND e.event_state  = in_event_state
            AND e.product_name = in_product_name
            AND e.task_name    = in_task_name;

RETURN (_running_tasks);
END //
DELIMITER ;

-- }}}
-- {{{ _running_tasks

DROP FUNCTION IF EXISTS _running_tasks;
DELIMITER //

CREATE FUNCTION _running_tasks( in_build_id     INT,
                                in_event_type   TEXT,
                                in_event_state  VARCHAR(128),
                                in_product_name VARCHAR(128), 
                                in_task_name    VARCHAR(128)
                              ) RETURNS int
    DETERMINISTIC
BEGIN
    DECLARE _running_tasks INT;

    SELECT count(*) INTO _running_tasks
        FROM build_events be, events e
        WHERE be.build_id      = in_build_id
            AND be.event_id    = e.id
            AND e.event_type   = CONCAT( "sub", in_event_type )
            AND e.event_state  = in_event_state
            AND e.product_name = in_product_name
            AND e.task_name    = in_task_name;

RETURN (_running_tasks);
END //
DELIMITER ;

-- }}}
-- {{{ build_results

DROP PROCEDURE IF EXISTS build_results;
DELIMITER //
CREATE PROCEDURE build_results()
BEGIN

    -- TODO: demx2fk3 2015-04-15 FIXME
    -- DROP TABLE IF EXISTS tmp_build_results;
    -- CREATE TEMPORARY TABLE tmp_build_results
    -- SELECT b.id, 
    --        b.build_name, 
    --       b.branch_name, 
    --        b.revision, 
    --        b.comment, 
    --        be1.timestamp AS build_started, 
    --        CASE isFailed( b.id )
    --             WHEN 0 THEN be2.timestamp
    --             ELSE IF( be3.timestamp, be3.timestamp, DATE_ADD( be1.timestamp, INTERVAL 2 HOUR) )
    --        END AS build_ended,
    --        isFailed( b.id ) AS isFailed
    -- FROM v_builds b, 
    -- LEFT JOIN build_events be1 ON (b.id = be1.build_id AND be1.event_id = 1 )
    -- LEFT JOIN build_events be2 ON (b.id = be2.build_id AND be2.event_id = 2 )
    -- LEFT JOIN build_events be3 ON (b.id = be3.build_id AND be3.event_id = 3 )
    -- ;

END //
DELIMITER ;

-- {{{ migrateBranchData
DROP PROCEDURE IF EXISTS migrateBranchData;
-- }}}
-- {{{ _check_if_event_builds

DROP PROCEDURE IF EXISTS _check_if_event_builds;
DELIMITER //
CREATE PROCEDURE _check_if_event_builds( in_build_name   VARCHAR(128), 
                                         in_comment      TEXT,
                                         in_job_name     VARCHAR(128),
                                         in_build_number INT,
                                         in_product_name VARCHAR(128),
                                         in_task_name    VARCHAR(128),
                                         in_event_type   TEXT
                                       )
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_started  INT;
    DECLARE cnt_finished INT;
    DECLARE cnt_failed   INT;
    DECLARE cnt_unstable INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    SELECT _running_tasks( var_build_id, in_event_type, 'started',  in_product_name, in_task_name) INTO cnt_started;
    SELECT _running_tasks( var_build_id, in_event_type, 'finished', in_product_name, in_task_name) INTO cnt_finished;
    SELECT _running_tasks( var_build_id, in_event_type, 'failed',   in_product_name, in_task_name) INTO cnt_failed;
    SELECT _running_tasks( var_build_id, in_event_type, 'unstable', in_product_name, in_task_name) INTO cnt_unstable;

    IF cnt_started = cnt_finished THEN
        CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                            in_product_name, in_task_name, in_event_type, 'finished' );
    ELSEIF cnt_started = cnt_finished + cnt_unstable THEN
        CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                            in_product_name, in_task_name, in_event_type, 'unstable' );
    ELSEIF cnt_started = cnt_finished + cnt_failed + cnt_unstable THEN
        CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number, 
                            in_product_name, in_task_name, in_event_type, 'failed' );
    END IF;    
END //
DELIMITER ;

-- }}}
-- {{{ _get_build_id_of_build

DROP FUNCTION IF EXISTS _get_build_id_of_build;
DELIMITER //

CREATE FUNCTION _get_build_id_of_build( in_build_name TEXT ) RETURNS int
    DETERMINISTIC
BEGIN
    DECLARE cnt_build_id int;
    DECLARE v_build_id INT;
    SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;
    -- check if build name exists
    IF cnt_build_id = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
    END IF;
    SELECT max(id) INTO v_build_id FROM builds WHERE build_name = in_build_name;
RETURN (v_build_id);
END //
DELIMITER ;

-- }}}
-- {{{ mustHaveRunningEvent
DROP PROCEDURE IF EXISTS mustHaveRunningEvent;
DELIMITER //
CREATE PROCEDURE mustHaveRunningEvent( IN in_build_name   VARCHAR(128), 
                                       IN in_event_type   TEXT,
                                       IN in_product_name VARCHAR(128),
                                       IN in_task_name    VARCHAR(128)
                                     )
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_event    INT;
    DECLARE var_event_id INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    SELECT count(*) INTO cnt_event 
        FROM build_events be, events e 
        WHERE be.build_id       = var_build_id 
            AND be.event_id     = e.id 
            AND e.event_type    = in_event_type 
            AND e.product_name  = in_product_name
            AND e.task_name     = in_task_name
            AND e.event_state  != 'started';

    IF cnt_event = 1 THEN
        SELECT be.id INTO var_event_id 
            FROM build_events be, events e 
            WHERE be.build_id       = var_build_id 
                AND be.event_id     = e.id 
                AND e.event_type    = in_event_type 
                AND e.product_name  = in_product_name
                AND e.task_name     = in_task_name
                AND e.event_state  != 'started';
        DELETE FROM build_events WHERE id = var_event_id;
    END IF;    
END //
DELIMITER ;
-- }}}
-- {{{ add_new_subversion_commit
DROP PROCEDURE IF EXISTS add_new_subversion_commit;
DELIMITER //
CREATE  PROCEDURE add_new_subversion_commit( IN in_build_name VARCHAR(128),
                                             IN in_revision   INT,
                                             IN in_author     VARCHAR(16),
                                             IN in_date       TEXT,
                                             IN in_msg        TEXT)
BEGIN
   DECLARE cnt_build_id INT;
   DECLARE var_build_id INT;
   DECLARE cnt_is_already_done INT;

   SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;

   IF cnt_build_id = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
   END IF;


   SELECT max(id) INTO var_build_id FROM builds WHERE build_name = in_build_name;

   SELECT count(id) INTO cnt_is_already_done FROM subversion_commits WHERE build_id = var_build_id AND svn_revision = in_revision;

   IF cnt_is_already_done = 0 THEN
       INSERT INTO subversion_commits (build_id, svn_revision, svn_author, commit_date, commit_message ) 
            VALUES ( var_build_id, in_revision, in_author, STR_TO_DATE( in_date, "%Y-%m-%dT%H:%i:%S.%fZ" ), in_msg );
   END IF;

END //
DELIMITER ;

-- }}}
-- {{{ setBuildEventStateToUnstable
DROP PROCEDURE IF EXISTS setBuildEventStateToUnstable;
DELIMITER //
CREATE PROCEDURE setBuildEventStateToUnstable( IN in_build_name   VARCHAR(128), 
                                               IN in_event_type   TEXT,
                                               IN in_product_name VARCHAR(128),
                                               IN in_task_name    VARCHAR(128)
                                             )
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_build_event_finished INT;
    DECLARE var_build_event_finished INT;
    DECLARE var_event_id_unstable    INT;
    DECLARE cnt_event_id_unstable    INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    SELECT count(*) INTO cnt_build_event_finished 
        FROM build_events be, events e 
        WHERE be.build_id      = var_build_id 
            AND be.event_id    = e.id 
            AND e.event_type   = in_event_type 
            AND e.product_name = in_product_name
            AND e.task_name    = in_task_name
            AND e.event_state  = 'finished';

    IF cnt_build_event_finished = 1 THEN
        -- first, we need the id of the finished build event
        SELECT be.id INTO var_build_event_finished 
            FROM build_events be, events e 
            WHERE be.build_id      = var_build_id 
                AND be.event_id    = e.id 
                AND e.event_type   = in_event_type 
                AND e.product_name = in_product_name
                AND e.task_name    = in_task_name
                AND e.event_state  = 'finished';

        -- second step: we need the id of the unstable event
        SELECT count(*) INTO cnt_event_id_unstable
            FROM events
            WHERE event_type     = in_event_type 
                AND product_name = in_product_name
                AND task_name    = in_task_name
                AND event_state  = 'unstable';

        -- if this event does not exists, create one
        IF cnt_event_id_unstable = 0 THEN
            INSERT INTO events ( product_name, task_name, event_type, event_state ) 
                VALUES ( in_product_name, in_task_name, in_event_type, 'unstable' );
        END IF;

        SELECT id INTO var_event_id_unstable
            FROM events
            WHERE event_type     = in_event_type 
                AND product_name = in_product_name
                AND task_name    = in_task_name
                AND event_state  = 'unstable';

        -- update the old build event to the new event id (unstable)
        UPDATE build_events SET event_id = var_event_id_unstable WHERE id = var_build_event_finished;
    END IF;    
END //
DELIMITER ;
-- }}}

-- {{{ get new build name
DROP FUNCTION IF EXISTS get_new_build_name;
DELIMITER //
CREATE FUNCTION get_new_build_name(in_branch VARCHAR(32), in_product_name VARCHAR(32), in_label_prefix VARCHAR(32)) RETURNS VARCHAR(64)
BEGIN
    DECLARE var_suffix VARCHAR(4);
    DECLARE var_prefix VARCHAR(64);
    DECLARE var_value VARCHAR(64);
    DECLARE var_regex VARCHAR(64);
    DECLARE var_branch_cnt INT;

    SELECT _branch_exists(in_branch) INTO var_branch_cnt;

    SELECT replace(replace(release_name_regex, '${date_%Y}', YEAR(NOW())), '${date_%m}', LPAD(MONTH(NOW()), 2, 0)) 
        INTO var_regex FROM branches WHERE branch_name=in_branch;

    SET var_prefix = SUBSTRING(var_regex, 1, LENGTH(var_regex)-22);
    SET var_regex = CONCAT(in_label_prefix, var_regex);
    SET var_regex = CONCAT('^', CONCAT(var_regex, '$'));

    -- "ORDER BY timestamp" can not be used:
    -- I got lower values when using ORDER BY timestamp.

    -- "ORDER BY id" can not be used:
    -- I got lower values when using ORDER BY id.

    SELECT LPAD(CONVERT(SUBSTRING(MAX(build_name), -4)+1, CHAR), 4, '0') INTO var_suffix FROM v_build_events 
        WHERE build_name REGEXP var_regex AND event_state='finished' AND product_name=in_product_name
        AND event_type='subbuild' AND task_name='build' AND build_name NOT REGEXP '_99[0-9][0-9]$';

    SET var_value = CONCAT(var_prefix, var_suffix);

    IF var_suffix IS NULL THEN
        SET var_value = CONCAT(var_prefix, '0001');
    END IF;
RETURN (var_value);
END //
DELIMITER ;
-- }}}

-- {{{ get last successful build name
DROP FUNCTION IF EXISTS get_last_successful_build_name;
DELIMITER //
CREATE FUNCTION get_last_successful_build_name(in_branch VARCHAR(32), in_product_name VARCHAR(32), in_label_prefix VARCHAR(32)) RETURNS VARCHAR(64)
BEGIN
    DECLARE var_value VARCHAR(64);
    DECLARE var_regex VARCHAR(64);
    DECLARE var_branch_cnt INT;

    SELECT _branch_exists(in_branch) INTO var_branch_cnt;

    SELECT replace(replace(release_name_regex, '${date_%Y}', YEAR(NOW())), '${date_%m}', LPAD(MONTH(NOW()), 2, 0)) 
        INTO var_regex FROM branches WHERE branch_name=in_branch;

    SET var_regex = CONCAT(in_label_prefix, var_regex);
    SET var_regex = CONCAT('^', CONCAT(var_regex, '$'));

    SELECT MAX(build_name) INTO var_value FROM v_build_events 
        WHERE build_name REGEXP var_regex AND event_state='finished' AND product_name=in_product_name
        AND event_type='subbuild' AND build_name NOT REGEXP '_99[0-9][0-9]$';
RETURN (var_value);
END //
DELIMITER ;
-- }}}

-- {{{ check if branch exists in database
DROP FUNCTION IF EXISTS _branch_exists;
DELIMITER //
CREATE FUNCTION _branch_exists(in_branch VARCHAR(32)) RETURNS INT
BEGIN
    DECLARE var_branch_cnt INT;

    SELECT COUNT(branch_name) INTO var_branch_cnt FROM branches WHERE branch_name=in_branch;

    IF var_branch_cnt = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'branch does not exist in table branches';
    END IF;

    IF var_branch_cnt > 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'branch exists more than once in table branches';
    END IF;
RETURN (var_branch_cnt);
END //
DELIMITER ;
-- }}}
