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

    SELECT count(id) INTO cnt_branch_id FROM branches WHERE branch_name = in_branch_name;
    IF cnt_branch_id = 0 THEN
        INSERT INTO branches ( ps_branch_name, location_name, branch_name, date_created, comment ) VALUES ( in_branch_name, in_branch_name, in_branch_name, NOW(), in_comment );
    END IF;
    SELECT id INTO var_branch_id FROM branches WHERE branch_name = in_branch_name;

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
                                  IN in_event_state  VARCHAR(128),
                                  IN in_build_host   VARCHAR(256)
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

    INSERT INTO build_events (event_id, build_id, timestamp, comment, job_name, build_number, build_host)
        VALUES ( var_event_id, var_build_id, now(), in_comment, in_job_name, in_build_number, in_build_host );

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
                                IN in_task_name    VARCHAR(128),
                                IN in_build_host   VARCHAR(256)
                              )
BEGIN
    CALL new_build( in_build_name, in_branch_name, in_comment, in_revision);
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'build', 'started', in_build_host );
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
                               IN in_task_name    VARCHAR(128),
                               IN in_build_host   VARCHAR(256)
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'build', 'failed', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'build', 'finished', in_build_host );
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
                                   IN in_task_name    VARCHAR(128),
                                   IN in_build_host   VARCHAR(256)
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subbuild', 'started', in_build_host );
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
                                    IN in_task_name    VARCHAR(128),
                                    IN in_build_host   VARCHAR(256)
                                  )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subbuild', 'finished', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'build', in_build_host );
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
                                  IN in_task_name    VARCHAR(128),
                                  IN in_build_host   VARCHAR(256)
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subbuild', 'failed', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'build', in_build_host );
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
                               IN in_task_name    VARCHAR(128),
                               IN in_build_host   VARCHAR(256)
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'test', 'started', in_build_host );
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
                              IN in_task_name    VARCHAR(128),
                              IN in_build_host   VARCHAR(256)
                            )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'test', 'failed', in_build_host );
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
                                IN in_task_name    VARCHAR(128),
                                IN in_build_host   VARCHAR(256)
                            )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'test', 'finished', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ subtest_started

DROP PROCEDURE IF EXISTS subtest_started;
DELIMITER //
CREATE PROCEDURE subtest_started( IN in_build_name   VARCHAR(128),
                                  IN in_comment      TEXT,
                                  IN in_job_name     VARCHAR(128),
                                  IN in_build_number INT,
                                  IN in_product_name VARCHAR(128),
                                  IN in_task_name    VARCHAR(128),
                                  IN in_build_host   VARCHAR(256)
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subtest', 'started', in_build_host );
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
                                   IN in_task_name    VARCHAR(128),
                                   IN in_build_host   VARCHAR(256)
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subtest', 'unstable', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subtest', 'failed', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test', in_build_host );
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
                                   IN in_task_name    VARCHAR(128),
                                   IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subtest', 'finished', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'test', in_build_host );
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
                                  IN in_task_name    VARCHAR(128),
                                  IN in_build_host   VARCHAR(256)
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'package', 'started', in_build_host );
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
                                   IN in_task_name    VARCHAR(128),
                                   IN in_build_host   VARCHAR(256)
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'package', 'finished', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN 
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'package', 'failed', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_install_started
-- @fn     target_install_started
-- @brief  create a new build event for target install started
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>
DROP PROCEDURE IF EXISTS target_install_started;
DELIMITER //
CREATE PROCEDURE target_install_started( IN in_build_name   VARCHAR(128),
                                         IN in_comment      TEXT,
                                         IN in_job_name     VARCHAR(128),
                                         IN in_build_number INT,
                                         IN in_product_name VARCHAR(128),
                                         IN in_task_name    VARCHAR(128),
                                         IN in_build_host   VARCHAR(256)
                                       )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_install', 'started', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_install_finished
-- @fn     target_install_finished
-- @brief  create a new build event for target install finished
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>

DROP PROCEDURE IF EXISTS target_install_finished;
DELIMITER //
CREATE PROCEDURE target_install_finished( IN in_build_name   VARCHAR(128),
                                          IN in_comment      TEXT,
                                          IN in_job_name     VARCHAR(128),
                                          IN in_build_number INT,
                                          IN in_product_name VARCHAR(128),
                                          IN in_task_name    VARCHAR(128),
                                          IN in_build_host   VARCHAR(256)
                                        )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_install', 'finished', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_install_failed
-- @fn     target_install_failed
-- @brief  create a new build event for target install failed
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>

DROP PROCEDURE IF EXISTS target_install_failed;
DELIMITER //
CREATE PROCEDURE target_install_failed( IN in_build_name   VARCHAR(128),
                                        IN in_comment      TEXT,
                                        IN in_job_name     VARCHAR(128),
                                        IN in_build_number INT,
                                        IN in_product_name VARCHAR(128),
                                        IN in_task_name    VARCHAR(128),
                                        IN in_build_host   VARCHAR(256)
                                      )
BEGIN 
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_install', 'failed', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_reserveration_started
-- @fn     target_reserveration_started
-- @brief  create a new build event for target reservation started
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>
DROP PROCEDURE IF EXISTS target_reserveration_started;
DELIMITER //
CREATE PROCEDURE target_reserveration_started( IN in_build_name   VARCHAR(128),
                                               IN in_comment      TEXT,
                                               IN in_job_name     VARCHAR(128),
                                               IN in_build_number INT,
                                               IN in_product_name VARCHAR(128),
                                               IN in_task_name    VARCHAR(128),
                                               IN in_build_host   VARCHAR(256)
                                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_reserveration', 'started', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_reserveration_finished
-- @fn     target_reserveration_finished
-- @brief  create a new build event for target reservation finished
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>

DROP PROCEDURE IF EXISTS target_reserveration_finished;
DELIMITER //
CREATE PROCEDURE target_reserveration_finished( IN in_build_name   VARCHAR(128),
                                                IN in_comment      TEXT,
                                                IN in_job_name     VARCHAR(128),
                                                IN in_build_number INT,
                                                IN in_product_name VARCHAR(128),
                                                IN in_task_name    VARCHAR(128),
                                                IN in_build_host   VARCHAR(256)
                                              )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_reservation', 'finished', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ target_reserveration_failed
-- @fn     target_reserveration_failed
-- @brief  create a new build event for target reservation failed
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @param  in_build_host          name of the build host (FQDN)
-- @return <none>

DROP PROCEDURE IF EXISTS target_reserveration_failed;
DELIMITER //
CREATE PROCEDURE target_reserveration_failed( IN in_build_name   VARCHAR(128),
                                              IN in_comment      TEXT,
                                              IN in_job_name     VARCHAR(128),
                                              IN in_build_number INT,
                                              IN in_product_name VARCHAR(128),
                                              IN in_task_name    VARCHAR(128),
                                              IN in_build_host   VARCHAR(256)
                                            )
BEGIN 
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'target_reservation', 'failed', in_build_host );
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
                                  IN in_task_name    VARCHAR(128),
                                  IN in_build_host   VARCHAR(256)
                                )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'release', 'started', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ release_finished
DROP PROCEDURE IF EXISTS release_finished;
DELIMITER //
CREATE PROCEDURE release_finished( IN in_build_name   VARCHAR(128),
                                   IN in_comment      TEXT,
                                   IN in_job_name     VARCHAR(128),
                                   IN in_build_number INT,
                                   IN in_product_name VARCHAR(128),
                                   IN in_task_name    VARCHAR(128),
                                   IN in_build_host   VARCHAR(256)
                                 )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'release', 'finished', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ release_failed
DROP PROCEDURE IF EXISTS release_failed;
DELIMITER //
CREATE PROCEDURE release_failed( IN in_build_name   VARCHAR(128),
                                 IN in_comment      TEXT,
                                 IN in_job_name     VARCHAR(128),
                                 IN in_build_number INT,
                                 IN in_product_name VARCHAR(128),
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'release', 'failed', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ subrelease_started
DROP PROCEDURE IF EXISTS subrelease_started;
DELIMITER //
CREATE PROCEDURE subrelease_started( IN in_build_name   VARCHAR(128),
                                     IN in_comment      TEXT,
                                     IN in_job_name     VARCHAR(128),
                                     IN in_build_number INT,
                                     IN in_product_name VARCHAR(128),
                                     IN in_task_name    VARCHAR(128),
                                     IN in_build_host   VARCHAR(256)
                                   )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subrelease', 'started', in_build_host );
    CALL mustHaveRunningEvent( in_build_name, 'release', in_product_name, in_task_name );
END //
DELIMITER ;

-- }}}
-- {{{ subrelease_finished
DROP PROCEDURE IF EXISTS subrelease_finished;
DELIMITER //
CREATE PROCEDURE subrelease_finished( IN in_build_name VARCHAR(128),
                                    IN in_comment      TEXT,
                                    IN in_job_name     VARCHAR(128),
                                    IN in_build_number INT,
                                    IN in_product_name VARCHAR(128),
                                    IN in_task_name    VARCHAR(128),
                                    IN in_build_host   VARCHAR(256)
                                  )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subrelease', 'finished', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'release', in_build_host );
END //
DELIMITER ;

-- }}}
-- {{{ subrelease_failed
DROP PROCEDURE IF EXISTS subrelease_failed;
DELIMITER //
CREATE PROCEDURE subrelease_failed( IN in_build_name   VARCHAR(128),
                                    IN in_comment      TEXT,
                                    IN in_job_name     VARCHAR(128),
                                    IN in_build_number INT,
                                    IN in_product_name VARCHAR(128),
                                    IN in_task_name    VARCHAR(128),
                                    IN in_build_host   VARCHAR(256)
                                  )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'subrelease', 'failed', in_build_host );
    CALL _check_if_event_builds( in_build_name, in_comment, in_job_name, in_build_number, in_product_name, in_task_name, 'release', in_build_host );
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
                                IN in_task_name    VARCHAR(128),
                                IN in_build_host   VARCHAR(256)
                              )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'started', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'finished', in_build_host );
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
                               IN in_task_name    VARCHAR(128),
                               IN in_build_host   VARCHAR(256)
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'release', 'finished', in_build_host );
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
                                IN in_task_name    VARCHAR(128),
                                IN in_build_host   VARCHAR(256)
                              )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'started', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'finished', in_build_host );
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
                               IN in_task_name    VARCHAR(128),
                               IN in_build_host   VARCHAR(256)
                             )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'failed', in_build_host );
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
                                 IN in_task_name    VARCHAR(128),
                                 IN in_build_host   VARCHAR(256)
                               )
BEGIN
    CALL new_build_event( in_build_name, in_comment, in_job_name, in_build_number,
                          in_product_name, in_task_name, 'other', 'unstable', in_build_host );
END //
DELIMITER ;

-- }}}

-- {{{ add_new_test_case_result
-- @fn     add_new_test_case_result
-- @brief  add a new test case result into the test resuls table
-- @param  test_case_name           name of the test case
-- @param  test_execution_id        id of the test execution
-- @param  test_case_failed_since   test case failed since
-- @param  test_case_skipped        is test case skipped?
-- @param  test_case_result         result of the test case
-- @return <none>
DROP PROCEDURE IF EXISTS add_new_test_case_result;
DELIMITER //
CREATE PROCEDURE add_new_test_case_result( IN in_test_execution_id      INTEGER,
                                           IN in_test_case_name         TEXT,
                                           IN in_test_case_duration     FLOAT,
                                           IN in_test_case_failed_since INTEGER,
                                           IN in_test_case_skipped      BOOLEAN,
                                           IN in_test_case_result       TEXT
                                         )
BEGIN
    DECLARE cnt_test_case_id INT;
    DECLARE var_test_case_id INT;

    DECLARE cnt_test_execution_id INT;

    SELECT count(id) INTO cnt_test_case_id FROM test_cases WHERE test_case_name = in_test_case_name;
    IF cnt_test_case_id = 0 THEN
        INSERT INTO test_cases ( test_case_name, test_case_owner ) VALUES ( in_test_case_name, '' );
    END IF;

    SELECT id INTO var_test_case_id FROM test_cases WHERE test_case_name = in_test_case_name;


    INSERT INTO test_case_results ( test_case_id, test_execution_id, test_case_duration, test_case_failed_since, test_case_skipped, test_case_result ) 
        VALUES ( var_test_case_id, in_test_execution_id, in_test_case_duration, in_test_case_failed_since, in_test_case_skipped, in_test_case_result );

END //
DELIMITER ;

call add_new_test_case_result( 107214, '...ddal_auth_set_login_faildelay_python', 0.0, 61, 1, '' );

-- }}}

-- {{{ add_new_test_execution
-- @fn     add_new_test_execution
-- @brief  add and get the an new test execution
-- @detail this procedure is used while writing the test case results into the database
-- @param  in_build_name      name of the build
-- @param  in_test_suite_name name of the test suite
-- @param  in_target_name     name of the target
-- @param  in_target_type     type of the target
-- @param  in_job_name        name of the jenkins job
-- @param  in_build_number    build number of jenkins job
-- @return id of the new inserted test execution
DROP PROCEDURE IF EXISTS add_new_test_execution;
DELIMITER //
CREATE PROCEDURE add_new_test_execution( IN in_build_name          VARCHAR(128),
                                         IN in_test_suite_name     VARCHAR(128),
                                         IN in_target_name         VARCHAR(128),
                                         IN in_target_type         VARCHAR(128),
                                         IN in_job_name            VARCHAR(128),
                                         IN in_build_number        INTEGER,
                                         OUT out_test_execution_id INT )
BEGIN
    DECLARE cnt_build_id INT;
    DECLARE var_build_id INT;
    DECLARE cnt_test_execution_id INT;

    SELECT count(id) INTO cnt_build_id FROM builds WHERE build_name = in_build_name;
    -- check if build name exists
    IF cnt_build_id = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'build_name does not exist';
    END IF;
    -- more code below
    -- TODO: demx2fk3 2015-01-13 this is an hack, there is no better way to ghet the latest build id
    SELECT max(id) INTO var_build_id FROM builds WHERE build_name = in_build_name;

    SELECT count(id) INTO cnt_test_execution_id FROM test_executions WHERE job_name = in_job_name AND build_number = in_build_number;
    IF cnt_test_execution_id = 0 THEN
        INSERT INTO test_executions ( build_id, test_suite_name, target_name, target_type, job_name, build_number ) 
        VALUES ( var_build_id, in_test_suite_name, in_target_name, in_target_type, in_job_name, in_build_number );
        SET out_test_execution_id = LAST_INSERT_ID();
    ELSE
        SELECT id INTO out_test_execution_id FROM test_executions
            WHERE job_name = in_job_name AND build_number = in_build_number;
    END IF;

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

    DROP TABLE IF EXISTS tmp_build_results;
    CREATE TEMPORARY TABLE tmp_build_results
    SELECT b.id,
           b.build_name,
           b.branch_name,
           b.revision,
           b.comment,
           be1.timestamp AS build_started,
           IF( be2.timestamp, be2.timestamp, be3.timestamp ) AS build_ended,
           IF( be3.timestamp, 1, 0 ) AS isFailed
    FROM v_builds b
    LEFT JOIN v_build_events be1 ON ( b.id = be1.build_id AND be1.event_type = 'build' AND be1.task_name = 'build' AND b.product_name = 'LFS' AND be1.event_state = 'started' )
    LEFT JOIN v_build_events be2 ON ( b.id = be2.build_id AND be2.event_type = 'build' AND be2.task_name = 'build' AND b.product_name = 'LFS' and be2.event_state = 'finished' )
    LEFT JOIN v_build_events be3 ON ( b.id = be3.build_id AND be3.event_type = 'build' AND be3.task_name = 'build' AND b.product_name = 'LFS' AND be3.event_state = 'failed' )
    WHERE b.product_name = 'LFS'
    ;
END //
DELIMITER ;
-- }}}

-- {{{ _check_if_event_builds
-- @fn     _check_if_event_builds
-- @brief  check if all sub builds/tests/... are finished and create the finished event for the parent job
-- @param  in_build_name          name of the build
-- @param  in_comment             a comment
-- @param  in_job_name            name of the jenkins job
-- @param  in_build_number        build number of the jenkins job
-- @param  in_product_name        name of the product (LFS, UBOOT, ...)
-- @param  in_task_name           name of the task (build, test, smoketest, releas)
-- @param  in_event_type          type of the event (build, test, release, other)
-- @return <none>

DROP PROCEDURE IF EXISTS _check_if_event_builds;
DELIMITER //
CREATE PROCEDURE _check_if_event_builds( in_build_name   VARCHAR(128),
                                         in_comment      TEXT,
                                         in_job_name     VARCHAR(128),
                                         in_build_number INT,
                                         in_product_name VARCHAR(128),
                                         in_task_name    VARCHAR(128),
                                         in_event_type   TEXT,
                                         in_build_host   VARCHAR(256)
                                       )
BEGIN
    DECLARE var_build_id INT;
    DECLARE cnt_started  INT;
    DECLARE cnt_finished INT;
    DECLARE cnt_failed   INT;
    DECLARE cnt_unstable INT;
    DECLARE var_started_job_name     VARCHAR(128);
    DECLARE var_started_build_number INT;

    SELECT _get_build_id_of_build( in_build_name ) INTO var_build_id;

    -- for some reason, this is not working in a single select statement
    SELECT build_number INTO var_started_build_number
        FROM v_build_events
        WHERE build_id       = var_build_id
            AND event_type   = in_event_type
            AND product_name = in_product_name
            AND task_name    = in_task_name
            AND event_state  = 'started';
    SELECT job_name INTO var_started_job_name
        FROM v_build_events
        WHERE build_id       = var_build_id
            AND event_type   = in_event_type
            AND product_name = in_product_name
            AND task_name    = in_task_name
            AND event_state  = 'started';

    SELECT _running_tasks( var_build_id, in_event_type, 'started',  in_product_name, in_task_name) INTO cnt_started;
    SELECT _running_tasks( var_build_id, in_event_type, 'finished', in_product_name, in_task_name) INTO cnt_finished;
    SELECT _running_tasks( var_build_id, in_event_type, 'failed',   in_product_name, in_task_name) INTO cnt_failed;
    SELECT _running_tasks( var_build_id, in_event_type, 'unstable', in_product_name, in_task_name) INTO cnt_unstable;

    IF cnt_started = cnt_finished THEN
        -- TODO: demx2fk3 2015-09-19 HACK special handling for release jobs
        -- release jobs should only create failed or unstable message, not finished.
        IF in_event_type != 'release' THEN
            CALL new_build_event( in_build_name, in_comment, var_started_job_name, var_started_build_number,
                                in_product_name, in_task_name, in_event_type, 'finished', in_build_host );
        END IF;
    ELSEIF cnt_started = cnt_finished + cnt_unstable THEN
        CALL new_build_event( in_build_name, in_comment, var_started_job_name, var_started_build_number,
                            in_product_name, in_task_name, in_event_type, 'unstable', in_build_host );
    ELSEIF cnt_started = cnt_finished + cnt_failed + cnt_unstable THEN
        CALL new_build_event( in_build_name, in_comment, var_started_job_name, var_started_build_number,
                            in_product_name, in_task_name, in_event_type, 'failed', in_build_host );
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
      INTO var_regex FROM branches WHERE branch_name=in_branch AND branch_name != CONCAT(in_branch, '_FSMR4');

    SET var_prefix = SUBSTRING(var_regex, 1, LENGTH(var_regex)-22);
    SET var_regex = CONCAT(in_label_prefix, var_regex);
    SET var_regex = CONCAT('^', CONCAT(var_regex, '$'));

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
    DECLARE tmp INTEGER;

    SELECT _branch_exists(in_branch) INTO tmp;

    SELECT b.build_name INTO var_value
        FROM v_build_events be, v_builds b
        WHERE be.event_state = 'finished'
        AND be.build_id = b.id
        AND be.event_type = 'build'
        AND be.task_name = 'build'
        AND b.branch_name = in_branch
        AND b.product_name = in_product_name
        ORDER BY timestamp DESC LIMIT 1;

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

    SELECT COUNT(branch_name) INTO var_branch_cnt FROM branches
        WHERE branch_name=in_branch AND branch_name != CONCAT(in_branch, '_FSMR4');

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

-- {{{ new_branch
DROP PROCEDURE IF EXISTS new_branch;
DELIMITER //
CREATE PROCEDURE new_branch( in_branch_name VARCHAR(128),
                             in_location_name VARCHAR(128),
                             in_based_on_revision INT,
                             in_based_on_release VARCHAR(128),
                             in_release_name_regex VARCHAR(128),
                             in_date_created DATETIME,
                             in_comment TEXT,
                             in_branch_description TEXT,
                             in_ps_branch_name VARCHAR(128),
                             in_ps_branch_comment TEXT,
                             in_ecl_url VARCHAR(254))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Could not create branch in DB';
    END;

    IF in_comment = '' OR in_comment = ' ' THEN
        SET in_comment:= NULL;
    END IF;

    IF in_branch_description = '' OR in_branch_description = ' ' THEN
        SET in_branch_description:= NULL;
    END IF;

    IF in_ps_branch_comment = '' OR in_ps_branch_comment = ' ' THEN
        SET in_ps_branch_comment:= NULL;
    END IF;

    START TRANSACTION;

        INSERT INTO branches (branch_name, location_name, based_on_revision, based_on_release,
                              release_name_regex, date_created, comment, branch_description)
               VALUES (in_branch_name, in_location_name, in_based_on_revision, in_based_on_release,
                       in_release_name_regex, in_date_created, in_comment, in_branch_description);

        INSERT INTO ps_branches (ps_branch_name, ecl_url, comment)
               VALUES (in_ps_branch_name, in_ecl_url, in_ps_branch_comment);

        INSERT INTO nm_branches_ps_branches (ps_branch_id, branch_id)
               VALUES ((SELECT id FROM ps_branches WHERE ps_branch_name=in_ps_branch_name),
                       (SELECT id FROM branches WHERE branch_name=in_branch_name));

    COMMIT;
END //
DELIMITER ;
-- }}}

-- {{{ tmp_bm
DROP PROCEDURE IF EXISTS tmp_bm;
DELIMITER //
CREATE PROCEDURE tmp_bm(IN in_task_name VARCHAR(128))
BEGIN
    DECLARE var_event_id_unstable    INT;
    DECLARE cnt_event_id_unstable    INT;

    DECLARE v_finished INTEGER DEFAULT 0;
    DECLARE v_branch_name VARCHAR(20);

    DECLARE last_build_branches CURSOR FOR
        SELECT DISTINCT branch_name FROM v_build_events AS be, v_builds AS b WHERE b.id = be.build_id AND timestamp BETWEEN DATE_SUB(NOW(), INTERVAL 5 DAY) AND NOW();

    DECLARE CONTINUE HANDLER
        FOR NOT FOUND SET v_finished = 1;
    CREATE TEMPORARY TABLE tmp_bm_results (
        id_event INT,
        build_id INT,
        build_name_event TEXT,
        timestamp DATETIME,
        comment_event TEXT,
        job_name TEXT,
        build_number INT,
        event_type TEXT,
        event_state TEXT,
        product_name TEXT,
        task_name TEXT,
        id INT,
        build_name TEXT,
        branch_name TEXT,
        revision INT,
        comment TEXT
    );


    OPEN last_build_branches;

branch: LOOP
        FETCH last_build_branches INTO v_branch_name;
        IF v_finished = 1 THEN
            LEAVE branch;
        END IF;
        INSERT INTO tmp_bm_results
            SELECT * FROM v_build_events AS be, v_builds AS b
                WHERE b.id = be.build_id AND branch_name = v_branch_name AND task_name = 'smoketest' AND product_name = 'LFS' AND event_type = 'test' ORDER BY timestamp DESC LIMIT 1;
        INSERT INTO tmp_bm_results
            SELECT * FROM v_build_events AS be, v_builds AS b
                WHERE b.id = be.build_id AND branch_name = v_branch_name AND task_name = 'build' AND product_name = 'LFS' AND event_type = 'build' ORDER BY timestamp DESC LIMIT 1;
        INSERT INTO tmp_bm_results
            SELECT * FROM v_build_events AS be, v_builds AS b
                WHERE b.id = be.build_id AND branch_name = v_branch_name AND task_name = 'test' AND product_name = 'LFS' AND event_type = 'test' ORDER BY timestamp DESC LIMIT 1;
        INSERT INTO tmp_bm_results
            SELECT * FROM v_build_events AS be, v_builds AS b
                WHERE b.id = be.build_id AND branch_name = v_branch_name AND task_name = 'releasing' AND product_name = 'LFS' AND event_type = 'release' ORDER BY timestamp DESC LIMIT 1;

    END LOOP branch;

    CLOSE last_build_branches;

    SET @sql = NULL;
    SET SESSION group_concat_max_len = 40000;
    SELECT GROUP_CONCAT(DISTINCT
           CONCAT('MAX(CASE WHEN task_name = ''', task_name,
           ''' THEN id_event END) `', task_name, '`'))
    INTO @sql
    FROM tmp_bm_results;

    DROP TABLE IF EXISTS tmp_bm_results_2;
    SET @sql =
        CONCAT('CREATE TEMPORARY TABLE tmp_bm_results_2
            SELECT branch_name, ', @sql, '
                     FROM tmp_bm_results
                    GROUP BY branch_name');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END //
DELIMITER ;
-- }}}

-- {{{ new_md_branch_ecl_entry_for_lrc
DROP PROCEDURE IF EXISTS new_md_branch_ecl_entry_for_lrc;
DELIMITER //
CREATE PROCEDURE new_md_branch_ecl_entry_for_lrc(in_branch_name VARCHAR(64), in_ps_branch_name VARCHAR(64))
BEGIN
    DECLARE var_nm_entries INT;
    DECLARE var_branch_number INT;
    DECLARE var_branch_number_lrc INT;
    DECLARE var_branch_name_lrc VARCHAR(64);
    DECLARE var_branch_id_lrc INT;

    SELECT count(id) INTO var_nm_entries FROM nm_branches_ps_branches WHERE ps_branch_id=(
        SELECT id FROM ps_branches WHERE ps_branch_name=in_ps_branch_name);

    IF var_nm_entries = 1 AND in_branch_name LIKE 'MD%' THEN
        SET var_branch_number:= substring(in_branch_name, 4);
        IF in_branch_name NOT LIKE '%01' THEN
            SET var_branch_number_lrc:= var_branch_number - 1;
        ELSE
            SET var_branch_number_lrc:= var_branch_number - 89;
        END IF;
        SET var_branch_name_lrc:= concat('LRC_FB', var_branch_number_lrc);
        SELECT id INTO var_branch_id_lrc FROM branches WHERE branch_name=var_branch_name_lrc AND status!='closed';
        IF var_branch_id_lrc IS NOT NULL THEN
            INSERT INTO nm_branches_ps_branches (ps_branch_id, branch_id)
                VALUES ((SELECT id FROM ps_branches WHERE ps_branch_name=in_ps_branch_name),
                        (var_branch_id_lrc));
        END IF;
    END IF;
END //
DELIMITER ;
-- }}}

-- {{{ new_ps_branch_for_md_lrc
DROP PROCEDURE IF EXISTS new_ps_branch_for_md_lrc;
DELIMITER //
CREATE PROCEDURE new_ps_branch_for_md_lrc(in_branch_name VARCHAR(64), in_ps_branch_name VARCHAR(64), in_ecl_url VARCHAR(254))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Could not create entry for MD LRC PS branch in DB';
    END;

    START TRANSACTION;

        INSERT INTO ps_branches (ps_branch_name, ecl_url) VALUES (in_ps_branch_name, in_ecl_url);

        INSERT INTO nm_branches_ps_branches (ps_branch_id, branch_id)
               VALUES ((SELECT id FROM ps_branches WHERE ps_branch_name=in_ps_branch_name),
                       (SELECT id FROM branches WHERE branch_name=in_branch_name));
    COMMIT;

END //
DELIMITER ;
-- }}}

-- {{{ close_ps_branch_for_md_lrc
DROP PROCEDURE IF EXISTS close_ps_branch_for_md_lrc;
DELIMITER //
CREATE PROCEDURE close_ps_branch_for_md_lrc(in_ps_branch_name VARCHAR(64))
BEGIN

    UPDATE ps_branches SET status='closed' WHERE ps_branch_name=in_ps_branch_name;

END //
DELIMITER ;
-- }}}
