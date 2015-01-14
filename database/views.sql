CREATE OR REPLACE VIEW v_build_events AS
    SELECT be.id, b.build_name, be.timestamp, e.event_name, be.comment FROM builds b, build_events be, events e where b.id = be.build_id and e.id = be.event_id;

CREATE OR REPLACE VIEW v_releases AS
    SELECT b.build_name, b.branch_name, b.revision, b.comment, be.timestamp as build_released, be.comment as event_comment FROM builds b, build_events be, events e WHERE b.id = be.build_id AND e.id = be.event_id AND e.event_name = 'released';

