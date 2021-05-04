declare 

      v_MSG_FROM       VARCHAR2 (32767) := 'myemail@mydomain.ba';
      v_MSG_TO         VARCHAR2 (32767) := 'toemail@mydomain.ba';  -- multiple emails email1@domain.com, email2@domain.com
      v_MSG_CC         VARCHAR2 (32767);
      v_MSG_SUBJECT    VARCHAR2 (32767) := 'my subject';
      v_MSG_TEXT       VARCHAR2 (32767);
      v_MSG_TYPE       VARCHAR2 (32767) := 'html'; -- or 'text' for plain text
	  
	  v_my_file		   blob;
	  v_file_name      varchar2(100);
	  v_mime_type	   varchar2(100);
      
      --attachment
      tbl_attachment table_attachments := table_attachments(); 
      tbl_attachment_data  mail_attachment;
 

begin

	select 	file_name,mime_type, file_content
	into   	v_file_name,v_mime_type,v_my_file
	from 	my_table
	where file_name = 'mydocument.pdf'
  
			v_MSG_TEXT := 'Just testing my email' || '<br>' || 'and hope it' || '<br>' || 'will work!';
			
            tbl_attachment_data := mail_attachment(v_file_name,v_mime_type,v_my_file);    
            tbl_attachment.extend;  
            tbl_attachment(1) := tbl_attachment_data;
 
                pkg_infobip_mail.send_email (v_MSG_FROM,
                        v_MSG_TO,
                        v_MSG_CC,
                        v_MSG_SUBJECT,
                        v_MSG_TEXT,
                        tbl_attachment,
                        'html');
end;