CREATE OR REPLACE TYPE  "MAIL_ATTACHMENT" AS OBJECT (
    attachment_name varchar2(2000),
    attachment_mime varchar2(200),
    attachment_blob blob
);


CREATE OR REPLACE TYPE "TABLE_ATTACHMENTS" IS TABLE OF mail_attachment;
