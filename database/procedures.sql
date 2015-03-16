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
    ELSE
        SELECT * FROM branches WHERE location_name = in_branch_name;
    END IF;
    SELECT id INTO var_branch_id FROM branches WHERE location_name = in_branch_name;

    INSERT INTO builds (build_name, branch_id, revision, comment) VALUES ( in_build_name, var_branch_id, in_revision, in_comment );
   
END //
DELIMITER ;
-- }}}
-- {{{ new_build_event
DROP PROCEDURE IF EXISTS new_build_event;
DELIMITER //
CREATE PROCEDURE new_build_event( IN in_build_name VARCHAR(128), 
                                  IN in_event VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_job_name VARCHAR(128),
                                  IN in_build_number INT )
BEGIN
    DECLARE cnt_event_id INT;
    DECLARE var_event_id INT;
    DECLARE var_build_id INT;

    SELECT count(id) INTO cnt_event_id FROM events WHERE event_name = in_event;
    IF cnt_event_id = 0 THEN
        INSERT INTO events ( event_name ) VALUES ( in_event );
    END IF;
    SELECT id INTO var_event_id FROM events WHERE event_name = in_event;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;
   
    INSERT INTO build_events (event_id, build_id, timestamp, comment, job_name, build_number) VALUES ( var_event_id, var_build_id, now(), in_comment, in_job_name, in_build_number );
END //
DELIMITER ;
-- }}}
-- {{{ build_started
DROP PROCEDURE IF EXISTS build_started;
DELIMITER //
CREATE PROCEDURE build_started( IN in_build_name VARCHAR(128), 
                                IN in_comment TEXT, 
                                IN in_branch_name VARCHAR(128), 
                                IN in_revision INT, 
                                IN in_job_name VARCHAR(128), 
                                IN in_build_number INT )
BEGIN
    CALL new_build( in_build_name, in_branch_name, in_comment, in_revision);
    CALL new_build_event( in_build_name, 'build_started', in_comment,  in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ build_failed

DROP PROCEDURE IF EXISTS build_failed;
DELIMITER //
CREATE PROCEDURE build_failed( IN in_build_name VARCHAR(128), 
                               IN in_comment TEXT, 
                               IN in_job_name VARCHAR(128), 
                               IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'build_failed', in_comment,  in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ build_finished

DROP PROCEDURE IF EXISTS build_finished
DELIMITER //
CREATE PROCEDURE build_finished( IN in_build_name VARCHAR(128), 
                                 IN in_comment TEXT, 
                                 IN in_job_name VARCHAR(128), 
                                 IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'build_finished', in_comment,  in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_started

DROP PROCEDURE IF EXISTS subbuild_started;
DELIMITER //
CREATE PROCEDURE subbuild_started( IN in_build_name VARCHAR(128), 
                                   IN in_comment TEXT, 
                                   IN in_target VARCHAR(16),
                                   IN in_subtarget VARCHAR(16),
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subbuild_started', '_', in_target, '_', in_subtarget ), in_comment, in_job_name, in_build_number );
    CALL mustHaveRunningEvent( in_build_name, 'build' );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_finished

DROP PROCEDURE IF EXISTS subbuild_finished;
DELIMITER //
CREATE PROCEDURE subbuild_finished( IN in_build_name VARCHAR(128), 
                                    IN in_comment TEXT,
                                    IN in_target VARCHAR(16),
                                    IN in_subtarget VARCHAR(16),
                                    IN in_job_name VARCHAR(128), 
                                    IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subbuild_finished', '_', in_target, '_', in_subtarget ), in_comment, in_job_name, in_build_number );
    CALL _check_if_event_builds( in_build_name, 'build', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ subbuild_failed

DROP PROCEDURE IF EXISTS subbuild_failed;
DELIMITER //
CREATE PROCEDURE subbuild_failed( IN in_build_name VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_target VARCHAR(16),
                                  IN in_subtarget VARCHAR(16),
                                  IN in_job_name VARCHAR(128), 
                                  IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subbuild_failed', '_', in_target, '_', in_subtarget), in_comment, in_job_name, in_build_number );
    CALL _check_if_event_builds( in_build_name, 'build', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ test_started

DROP PROCEDURE IF EXISTS test_started;
DELIMITER //
CREATE PROCEDURE test_started( IN in_build_name VARCHAR(128), 
                               IN in_comment TEXT,
                               IN in_job_name VARCHAR(128), 
                               IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'test_started', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ test_failed

DROP PROCEDURE IF EXISTS test_failed;
DELIMITER //
CREATE PROCEDURE test_failed( IN in_build_name VARCHAR(128), 
                               IN in_comment TEXT,
                               IN in_job_name VARCHAR(128), 
                               IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'test_failed', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ test_finished

DROP PROCEDURE IF EXISTS test_finished;
DELIMITER //
CREATE PROCEDURE test_finished( IN in_build_name VARCHAR(128), 
                               IN in_comment TEXT,
                               IN in_job_name VARCHAR(128), 
                               IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'test_finished', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_started

DROP PROCEDURE IF EXISTS subtest_started;
DELIMITER //
CREATE PROCEDURE subtest_started( IN in_build_name VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_target VARCHAR(16),
                                  IN in_subtarget VARCHAR(16),
                                  IN in_job_name VARCHAR(128), 
                                  IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subtest_started', '_', in_target, '_', in_subtarget), in_comment, in_job_name, in_build_number );
    CALL mustHaveRunningEvent( in_build_name, 'test' );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_unstable

DROP PROCEDURE IF EXISTS subtest_unstable;
DELIMITER //
CREATE PROCEDURE subtest_unstable( IN in_build_name VARCHAR(128), 
                                   IN in_comment TEXT,
                                   IN in_target VARCHAR(16),
                                   IN in_subtarget VARCHAR(16),
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subtest_unstable', '_', in_target, '_', in_subtarget), in_comment, in_job_name, in_build_number );
    CALL _check_if_event_builds( in_build_name, 'test', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_failed

DROP PROCEDURE IF EXISTS subtest_failed;
DELIMITER //
CREATE PROCEDURE subtest_failed( IN in_build_name VARCHAR(128),
                                 IN in_comment TEXT,
                                 IN in_target VARCHAR(16),
                                 IN in_subtarget VARCHAR(16),
                                 IN in_job_name VARCHAR(128), 
                                 IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subtest_failed', '_', in_target, '_', in_subtarget), in_comment, in_job_name, in_build_number );
    CALL _check_if_event_builds( in_build_name, 'test' );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_finished

DROP PROCEDURE IF EXISTS subtest_finished;
DELIMITER //
CREATE PROCEDURE subtest_finished( IN in_build_name VARCHAR(128),
                                   IN in_comment TEXT,
                                   IN in_target VARCHAR(16),
                                   IN in_subtarget VARCHAR(16),
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, CONCAT( 'subtest_finished', '_', in_target, '_', in_subtarget), in_comment, in_job_name, in_build_number );
    CALL _check_if_event_builds( in_build_name, 'test', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ package_started

DROP PROCEDURE IF EXISTS package_started;
DELIMITER //
CREATE PROCEDURE package_started( IN in_build_name VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_job_name VARCHAR(128), 
                                  IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'package_started', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ package_finished

DROP PROCEDURE IF EXISTS package_finished;
DELIMITER //
CREATE PROCEDURE package_finished( IN in_build_name VARCHAR(128), 
                                   IN in_comment TEXT,
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'package_finished', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ package_failed

DROP PROCEDURE IF EXISTS package_failed;
DELIMITER //
CREATE PROCEDURE package_failed( IN in_build_name VARCHAR(128), 
                                 IN in_comment TEXT,
                                 IN in_job_name VARCHAR(128), 
                                 IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'package_failed', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ release_started

DROP PROCEDURE IF EXISTS release_started;
DELIMITER //
CREATE PROCEDURE release_started( IN in_build_name VARCHAR(128), 
                                  IN in_comment TEXT,
                                  IN in_job_name VARCHAR(128), 
                                  IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'release_started', in_comment, in_job_name, in_build_number );
END //
DELIMITER ;

-- }}}
-- {{{ release_finished

DROP PROCEDURE IF EXISTS release_finished;
DELIMITER //
CREATE PROCEDURE release_finished( IN in_build_name VARCHAR(128), 
                                   IN in_comment TEXT,
                                   IN in_job_name VARCHAR(128), 
                                   IN in_build_number INT )
BEGIN
    CALL new_build_event( in_build_name, 'release_finished', in_comment, in_job_name, in_build_number );
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
DELIMITER //

CREATE FUNCTION isFailed(in_build_id int) RETURNS int
    DETERMINISTIC
BEGIN
    DECLARE cnt_isFailed1 int;
    DECLARE cnt_isFailed2 int;
    DECLARE isFailed INT;

    SELECT count(*) INTO cnt_isFailed1 FROM build_events WHERE build_id = in_build_id AND event_id = 3;
    IF cnt_isFailed1 >= 1 THEN
        SET isFailed = 1;
    ELSE
        SELECT count(*) INTO cnt_isFailed2 FROM build_events 
        WHERE build_id = in_build_id AND event_id NOT IN (1, 2) AND TIMESTAMPDIFF(HOUR, timestamp, NOW() ) > 2;

        IF cnt_isFailed2 >= 1 THEN
            SET isFailed = 1;
        ELSE
            SET isFailed = 0;
        END IF;
    END IF;

RETURN (isFailed);
END //
DELIMITER ;

-- }}}
-- {{{ build_results

DROP PROCEDURE IF EXISTS build_results;
DELIMITER //
CREATE PROCEDURE build_results()
BEGIN

    DROP TABLE IF EXISTS tmp_build_results;
    CREATE TEMPORARY TABLE tmp_build_results
    SELECT b.id, b.build_name, b.branch_name, b.revision, b.comment, 
           be1.timestamp AS build_started, 
           CASE isFailed( b.id )
                WHEN 0 THEN be2.timestamp
                ELSE IF( be3.timestamp, be3.timestamp, DATE_ADD( be1.timestamp, INTERVAL 2 HOUR) )
        END AS build_ended,
        isFailed( b.id ) AS isFailed
    FROM builds b
    LEFT JOIN build_events be1 ON (b.id = be1.build_id AND be1.event_id = 1 )
    LEFT JOIN build_events be2 ON (b.id = be2.build_id AND be2.event_id = 2 )
    LEFT JOIN build_events be3 ON (b.id = be3.build_id AND be3.event_id = 3 )
    ;

END //
DELIMITER ;

-- }}}
-- {{{ migrateBranchData

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

-- }}}
-- {{{ _check_if_event_builds

DROP PROCEDURE IF EXISTS _check_if_event_builds;
DELIMITER //
CREATE PROCEDURE _check_if_event_builds( IN in_build_name VARCHAR(128), 
                                         IN in_event_type TEXT,
                                         IN in_comment TEXT,
                                         IN in_job_name VARCHAR(128),
                                         IN in_build_number INT )
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_started  INT;
    DECLARE cnt_finished INT;
    DECLARE cnt_failed   INT;
    DECLARE cnt_unstable INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    SELECT count(*) INTO cnt_started  FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = CONCAT( "sub", in_event_type ) and e.event_state = 'started';
    SELECT count(*) INTO cnt_finished FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = CONCAT( "sub", in_event_type ) and e.event_state = 'finished';
    SELECT count(*) INTO cnt_failed   FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = CONCAT( "sub", in_event_type ) and e.event_state = 'failed';
    SELECT count(*) INTO cnt_unstable FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = CONCAT( "sub", in_event_type ) and e.event_state = 'unstable';

    IF cnt_started = cnt_finished THEN
        CALL new_build_event( in_build_name, CONCAT( in_event_type, '_finished' ), in_comment, in_job_name, in_build_number );
    ELSEIF cnt_started = cnt_finished + cnt_unstable THEN
        CALL new_build_event( in_build_name, CONCAT( in_event_type, '_unstable' ), in_comment, in_job_name, in_build_number );
    ELSEIF cnt_started = cnt_finished + cnt_failed + cnt_unstable THEN
        CALL new_build_event( in_build_name, CONCAT( in_event_type, '_failed' ), in_comment, in_job_name, in_build_number );
    END IF;    
END //
DELIMITER ;

-- }}}
-- {{{ _get_build_id_of_build

DROP FUNCTION IF EXISTS _get_build_id_of_build;
DELIMITER //

CREATE FUNCTION _get_build_id_of_build(in_build_name TEXT) RETURNS int
    DETERMINISTIC
BEGIN
    DECLARE cnt_build_id int;
    DECLARE v_build_id INT;
    SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;
    -- check if build name exists
    -- IF cnt_build_id = 0 THEN
        -- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
    -- END IF;
    SELECT max(id) INTO v_build_id FROM builds WHERE build_name = in_build_name;
RETURN (v_build_id);
END //
DELIMITER ;

-- }}}
-- {{{ mustHaveRunningEvent
DROP PROCEDURE IF EXISTS mustHaveRunningEvent;
DELIMITER //
CREATE PROCEDURE mustHaveRunningEvent( IN in_build_name VARCHAR(128), 
                                       IN in_event_type TEXT)
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_event    INT;
    DECLARE var_event_id INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    SELECT count(*) INTO cnt_event FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = in_event_type and e.event_state != 'started';

    IF cnt_event = 1 THEN
        SELECT be.id INTO var_event_id FROM build_events be, events e WHERE be.build_id = var_build_id AND be.event_id = e.id and e.event_type = in_event_type and e.event_state != 'started';
        DELETE from build_events WHERE id = var_event_id;
    END IF;    
END //
DELIMITER ;
-- }}}
-- {{{ add_new_subversion_commit
DROP PROCEDURE add_new_subversion_commit;
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
       INSERT INTO subversion_commits (build_id, svn_revision, svn_author, commit_date, commit_message ) VALUES ( var_build_id, in_revision, in_author, in_date, in_msg );
   END IF;

END //
DELIMITER ;

-- }}}
