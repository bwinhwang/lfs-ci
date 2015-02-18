DROP PROCEDURE IF EXISTS new_build_event;
DELIMITER //
CREATE PROCEDURE new_build_event( IN in_build_name VARCHAR(128), IN in_event VARCHAR(128), IN in_comment TEXT)
   BEGIN
   DECLARE cnt_event_id INT;
   DECLARE var_event_id INT;
   DECLARE cnt_build_id INT;
   DECLARE var_build_id INT;

   SELECT count(id) INTO cnt_event_id FROM events WHERE event_name = in_event;
   IF cnt_event_id = 0 THEN
       INSERT INTO events ( event_name ) VALUES ( in_event );
   END IF;
   SELECT id INTO var_event_id FROM events WHERE event_name = in_event;

   SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;
   -- check if build name exists
   IF cnt_build_id = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
   END IF;
   -- more code below
   -- TODO: demx2fk3 2015-01-13 this is an hack, there is no better way to ghet the latest build id
   SELECT max(id) INTO var_build_id FROM builds WHERE build_name = in_build_name;
   
   INSERT INTO build_events (event_id, build_id, timestamp, comment) VALUES ( var_event_id, var_build_id, now(), in_comment );
   
   END //
DELIMITER ;

DROP PROCEDURE IF EXISTS new_build;
DELIMITER //
CREATE PROCEDURE new_build( IN in_build_name VARCHAR(128), IN in_branch_name VARCHAR(128), IN in_comment TEXT, IN in_revision INT )
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

DROP PROCEDURE IF EXISTS build_started;
DELIMITER //
CREATE PROCEDURE build_started( IN in_build_name VARCHAR(128), IN in_comment TEXT, IN in_branch_name VARCHAR(128), IN in_revision INT )
BEGIN
   CALL new_build( in_build_name, in_branch_name, in_comment, in_revision);
   CALL new_build_event( in_build_name, 'build started', in_comment );
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS build_finished;
DELIMITER //
CREATE PROCEDURE build_finished( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'build finished successfully', in_comment );
END //
DELIMITER ;


DROP PROCEDURE IF EXISTS build_failed;
DELIMITER //
CREATE PROCEDURE build_failed( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'build finished with error', in_comment );
END //
DELIMITER ;


DROP PROCEDURE IF EXISTS test_started;
DELIMITER //
CREATE PROCEDURE test_started( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'test started', in_comment );
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS test_unstable;
DELIMITER //
CREATE PROCEDURE test_unstable( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'test finished unstable', in_comment );
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS test_failed;
DELIMITER //
CREATE PROCEDURE test_failed( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'test finished with error', in_comment );
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS test_finished;
DELIMITER //
CREATE PROCEDURE test_finished( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'test finished successful', in_comment );
END //
DELIMITER ;


DROP PROCEDURE IF EXISTS release_started;
DELIMITER //
CREATE PROCEDURE release_started( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'release started', in_comment );
END //
DELIMITER ;


DROP PROCEDURE IF EXISTS release_finished;
DELIMITER //
CREATE PROCEDURE release_finished( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
CALL new_build_event( in_build_name, 'released', in_comment );
END //
DELIMITER ;


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
   IF cnt_build_id = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
   END IF;
   -- more code below
   -- TODO: demx2fk3 2015-01-13 this is an hack, there is no better way to ghet the latest build id
   SELECT max(id) INTO var_build_id FROM builds WHERE build_name = in_build_name;
    
    INSERT INTO test_executions ( build_id, test_suite_name, target_name, target_type ) VALUES ( var_build_id, in_test_suite_name, in_target_name, in_target_type );
    SET out_test_execution_id = LAST_INSERT_ID();

END //
DELIMITER ;


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
    FROM v_builds b
    LEFT JOIN build_events be1 ON (b.id = be1.build_id AND be1.event_id = 1 )
    LEFT JOIN build_events be2 ON (b.id = be2.build_id AND be2.event_id = 2 )
    LEFT JOIN build_events be3 ON (b.id = be3.build_id AND be3.event_id = 3 )
    ;

END //
DELIMITER ;


DROP PROCEDURE IF EXISTS build_workflow_per_branch;
DELIMITER //
CREATE PROCEDURE build_workflow_per_branch()
BEGIN
    DECLARE bDone             INT;
    DECLARE tmp_branch_name   VARCHAR(128);
    DECLARE tmp_build_id      INT;

    DECLARE curs CURSOR FOR  SELECT max(b.id) build_id, branch_name FROM v_builds b GROUP BY branch_name;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

    -- create temp table with event data
    DROP TEMPORARY TABLE IF EXISTS tmp_build_events_per_branches_latest_builds;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_build_events_per_branches_latest_builds  (
        build_id     INT,
        event_name   VARCHAR(128),
        event_date   DATETIME
    );

    OPEN curs;

    -- fill temp table
    SET bDone = 0;
    REPEAT
        FETCH curs INTO tmp_build_id, tmp_branch_name;

        INSERT INTO tmp_build_events_per_branches_latest_builds ( build_id, event_name, event_date )
            SELECT tmp_build_id, event_name, timestamp from v_build_events where build_id = tmp_build_id;
    UNTIL bDone END REPEAT;

    CLOSE curs;

    -- rotate table (create new tmp table)
    SET @sql = NULL;
    SET SESSION group_concat_max_len = 40000;
    SELECT GROUP_CONCAT(DISTINCT
           CONCAT('MAX(CASE WHEN event_name = ''', event_name,
           ''' THEN event_date END) `', REPLACE( event_name, " ", "_" ), '`'))
    INTO @sql
    FROM tmp_build_events_per_branches_latest_builds;

    DROP TABLE IF EXISTS tmp_build_events_per_branches_latest_builds_rotated;
    SET @sql =
        CONCAT('CREATE TEMPORARY TABLE tmp_build_events_per_branches_latest_builds_rotated
            SELECT build_id, ', @sql, '
                     FROM tmp_build_events_per_branches_latest_builds
                    GROUP BY build_id');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- create finally the temp table with all data
    DROP TEMPORARY TABLE IF EXISTS tmp_build_workflow_per_branch;
    CREATE TEMPORARY TABLE tmp_build_workflow_per_branch
        SELECT tmp.build_id, 
            build_name,
            branch_name,
            tmp.build_started, 
            IF( tmp.build_finished_successfully, tmp.build_finished_successfully, tmp.build_finished_with_error) build_ended ,
            IF( tmp.build_finished_successfully, "ok", 
                IF( tmp.build_finished_with_error, "error", "running" ) 
              ) AS build_status,
            tmp.test_started,
            IF( tmp.test_finished_with_error, tmp.test_finished_with_error,
                IF( tmp.test_finished_successful, tmp.test_finished_successful,
                    IF( tmp.test_finished_unstable, tmp.test_finished_unstable, 'unknown' )
                  )
              ) AS test_ended,
            IF( tmp.test_finished_successful, "ok", 
                IF( tmp.test_finished_with_error, "error",
                    IF( tmp.test_finished_unstable, "unstable", 
                        IF( tmp.test_started, "running", "unknown")
                      )
                  )
              ) AS test_status,
            IF( tmp.release_started, tmp.release_started, tmp.released ) as release_started,
            tmp.released,
            IF( tmp.released, "ok", 
                IF( tmp.release_started, "error", "unknown" ) 
              ) AS release_status
        FROM tmp_build_events_per_branches_latest_builds_rotated tmp, v_builds b
        WHERE tmp.build_id = b.id 
        ORDER BY branch_name;

        DROP TEMPORARY TABLE IF EXISTS tmp_build_events_per_branches_latest_builds_rotated;
        DROP TEMPORARY TABLE IF EXISTS tmp_build_events_per_branches_latest_builds;
END //
DELIMITER ;


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

