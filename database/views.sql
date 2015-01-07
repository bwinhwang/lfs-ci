CREATE OR REPLACE VIEW v_build_events AS
    SELECT be.id, be.build_name, be.timestamp, e.event_name, be.comment  FROM build_events be, events e where e.id = be.event_id;

CREATE OR REPLACE VIEW v_releases AS
    SELECT b.build_name, b.branch_name, b.revision, b.comment, be.timestamp as build_released, be.comment as event_comment FROM builds b, build_events be, events e WHERE b.build_name = be.build_name AND e.id = be.event_id AND e.event_name = 'released';

