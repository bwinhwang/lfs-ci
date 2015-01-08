DROP PROCEDURE IF EXISTS new_build_event;
DELIMITER //
CREATE PROCEDURE new_build_event( IN in_build_name VARCHAR(128), IN in_event VARCHAR(128), IN in_comment TEXT)
   BEGIN
   DECLARE cnt_event_id INT;
   DECLARE var_event_id INT;

   SELECT count(id) INTO cnt_event_id FROM events WHERE event_name = in_event;
   IF cnt_event_id = 0 THEN
       INSERT INTO events ( event_name ) VALUES ( in_event );
   END IF;
   SELECT id INTO var_event_id FROM events WHERE event_name = in_event;
   
   INSERT INTO build_events (event_id, build_name, timestamp, comment) VALUES ( var_event_id, in_build_name, now(), in_comment );
   
   END //
DELIMITER ;


DROP PROCEDURE IF EXISTS build_started;
DELIMITER //
CREATE PROCEDURE build_started( IN in_build_name VARCHAR(128), IN in_comment TEXT, IN in_branch_name VARCHAR(128), IN in_revision INT )
BEGIN
   INSERT INTO builds (build_name, branch_name, revision, comment) VALUES ( in_build_name, in_branch_name, in_revision, in_comment );
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


DROP PROCEDURE IF EXISTS test_finished;
DELIMITER //
CREATE PROCEDURE test_finished( IN in_build_name VARCHAR(128), IN in_comment TEXT )
BEGIN
    CALL new_build_event( in_build_name, 'test finished', in_comment );
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
    
    INSERT INTO test_executions ( build_name, test_suite_name, target_name, target_type ) VALUES ( in_build_name, in_test_suite_name, in_target_name, in_target_type );
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

