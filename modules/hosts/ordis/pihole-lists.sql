BEGIN;

UPDATE adlist SET address = '@pro@', comment = 'HaGeZi Multi PRO'
WHERE type = 0 AND (
  address = 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'
  OR (address GLOB 'file:///nix/store/*-hosts'
      AND comment = 'StevenBlack unified hosts snapshot (35c74714)')
);

INSERT INTO adlist (address, comment)
SELECT '@pro@', 'HaGeZi Multi PRO'
WHERE NOT EXISTS (SELECT 1 FROM adlist WHERE address = '@pro@' AND type = 0);

CREATE TEMP TABLE gambling_scope AS
SELECT id, enabled FROM adlist
WHERE address = '@pro@' AND type = 0
  AND NOT EXISTS (SELECT 1 FROM adlist WHERE address = '@gambling@' AND type = 0);

INSERT INTO adlist (address, enabled, comment)
SELECT '@gambling@', enabled, 'HaGeZi Gambling Medium' FROM gambling_scope;

DELETE FROM adlist_by_group
WHERE adlist_id = (SELECT id FROM adlist WHERE address = '@gambling@' AND type = 0)
  AND EXISTS (SELECT 1 FROM gambling_scope);

INSERT INTO adlist_by_group (adlist_id, group_id)
SELECT new.id, old.group_id FROM gambling_scope
JOIN adlist_by_group old ON old.adlist_id = gambling_scope.id
JOIN adlist new ON new.address = '@gambling@' AND new.type = 0;

COMMIT;
