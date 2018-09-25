UPDATE marc_subfield_structure SET kohafield = '',                       authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'a' AND frameworkcode = 'HLD';
UPDATE marc_subfield_structure SET kohafield = '',                       authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'b' AND frameworkcode = 'HLD';
UPDATE marc_subfield_structure SET kohafield = 'holdings.location',      authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'c' AND frameworkcode = 'HLD';
UPDATE marc_subfield_structure SET kohafield = 'holdings.callnumber',    authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'h' AND frameworkcode = 'HLD';
UPDATE marc_subfield_structure SET kohafield = 'holdings.callnumber',    authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'i' AND frameworkcode = 'HLD';
UPDATE marc_subfield_structure SET kohafield = '',                       authorised_value = ''         WHERE tagfield = '852' AND tagsubfield = 'k' AND frameworkcode = 'HLD';

ALTER TABLE holdings ADD ccode varchar(80) DEFAULT NULL, ADD INDEX hldccodeidx (ccode);
