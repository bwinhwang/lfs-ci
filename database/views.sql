
CREATE OR REPLACE VIEW v_build_events AS
    SELECT be.id, b.id build_id, b.build_name, be.timestamp, be.comment, be.job_name, be.build_number, e.event_type, e.event_state, e.product_name, e.task_name FROM builds b, build_events be, events e where b.id = be.build_id and e.id = be.event_id;

CREATE OR REPLACE VIEW v_builds as
    SELECT b.id, b.build_name, br.branch_name, b.revision, b.comment FROM builds b, branches br WHERE b.branch_id = br.id;

CREATE OR REPLACE VIEW v_releases AS
    SELECT b.build_name, b.branch_name, b.revision, b.comment, be.timestamp AS build_released, be.comment AS event_comment FROM v_builds b, build_events be, events e WHERE b.id = be.build_id AND e.id = be.event_id AND e.event_type = 'release' AND e.event_state = 'finished';

CREATE OR REPLACE VIEW v_test_results AS
    SELECT r.id, r.test_execution_id, n.test_result_name, r.test_result_value  FROM test_results r, test_result_names n WHERE r.test_result_name_id = n.id;

CREATE OR REPLACE VIEW v_ps_branches as
    SELECT ps.ps_branch_name, b.branch_name, ps.status, ps.ecl_url, ps.comment  from ps_branches ps, branches b, nm_branches_ps_branches nm where b.id = nm.branch_id and nm.ps_branch_id = ps.id;

