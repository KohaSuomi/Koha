ALTER TABLE reporting_items_fact ADD CONSTRAINT unique_item_id UNIQUE (item_id);
ALTER TABLE reporting_deleteditems_fact ADD CONSTRAINT unique_item_id UNIQUE (item_id);
