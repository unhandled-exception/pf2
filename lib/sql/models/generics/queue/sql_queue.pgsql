BEGIN;

CREATE TABLE "queue" (
  "task_id" bigserial NOT NULL,
  "task_type" INTEGER NOT NULL DEFAULT 0,
  "entity_id" INTEGER NOT NULL,
  "process_time" TIMESTAMP NOT NULL,
  "attempt" INTEGER DEFAULT '0',
  "created_at" TIMESTAMP DEFAULT NULL,
  PRIMARY KEY ("task_id")
);
CREATE UNIQUE INDEX "queue_unique_task_type_entity_id" ON "queue" ("task_type", "entity_id");
CREATE INDEX "queue_idx_process_time" ON "queue" ("process_time");

COMMIT:
