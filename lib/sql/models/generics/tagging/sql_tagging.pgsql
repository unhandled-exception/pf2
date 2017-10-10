/* Структура табличек для Постгреса */

CREATE TABLE "tags" (
  "tag_id" SERIAL,
  "parent_id" INT NOT NULL DEFAULT '0',
  "thread_id" INT NOT NULL DEFAULT '0',
  "title" VARCHAR(125) NOT NULL,
  "slug" VARCHAR(250) DEFAULT NULL,
  "description" TEXT,
  "sort_order" INT NOT NULL DEFAULT '0',
  "is_active" BOOLEAN NOT NULL DEFAULT '1',
  "created_at" TIMESTAMP DEFAULT NULL,
  "updated_at" TIMESTAMP DEFAULT NULL,
  PRIMARY KEY ("tag_id")
);
CREATE UNIQUE INDEX "tags_idx_uq_title" ON "tags" (lower("title"));
CREATE INDEX "tags_idx_thread_parent" ON "tags" ("thread_id","parent_id");
CREATE INDEX "tags_idx_slug" ON "tags" ("slug");

CREATE TABLE "tags_content" (
  "tag_id" INT NOT NULL,
  "content_id" INT NOT NULL,
  "content_type_id" INT NOT NULL DEFAULT '0',
  "created_at" TIMESTAMP DEFAULT NULL,
  "updated_at" TIMESTAMP DEFAULT NULL,
  PRIMARY KEY ("tag_id", "content_id", "content_type_id")
);

CREATE TABLE "tags_counters" (
  "tag_id" INT NOT NULL,
  "content_type_id" INT NOT NULL,
  "cnt" INT NOT NULL DEFAULT '0',
  "created_at" TIMESTAMP DEFAULT NULL,
  "updated_at" TIMESTAMP DEFAULT NULL,
  PRIMARY KEY ("tag_id", "content_type_id")
);
