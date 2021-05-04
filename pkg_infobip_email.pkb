CREATE OR REPLACE PACKAGE BODY PKG_INFOBIP_MAIL AS

/**
* Created By    : emir.ba 
-- infobip smtp api
*/

  g_smtp_server varchar2(50) := 'smtp-api.infobip.com';
  g_smtp_port number := 587;
  
  g_sender_display_name varchar2(50) := 'Sender display name';
  g_api_user varchar2(50) := 'Your api user';
  g_api_password varchar2(50) := 'Your api password';
  
  g_msg_sent char(1) := 'N';
  
 
  PROCEDURE send_email (MSG_FROM VARCHAR2,
            MSG_TO VARCHAR2,
            MSG_CC VARCHAR2 ,
            MSG_SUBJECT VARCHAR2,
            MSG_TEXT VARCHAR2,
            p_attachments IN table_attachments DEFAULT NULL,
            MSG_TYPE VARCHAR2 DEFAULT 'text' --'html'
            )
IS
    CRLF CONSTANT VARCHAR2 (10) := UTL_TCP.CRLF;
    BOUNDARY CONSTANT VARCHAR2 (256) := '-----7D81B75CCC90D2974F7A1CBD';
    FIRST_BOUNDARY CONSTANT VARCHAR2 (256) := '--' || BOUNDARY || CRLF;
    LAST_BOUNDARY CONSTANT VARCHAR2 (256) := '--' || BOUNDARY || '--' || CRLF ;
    MULTIPART_MIME_TYPE CONSTANT VARCHAR2 (256):= 'multipart/mixed; boundary="' || BOUNDARY || '"'||'; charset="ISO 8859-2"'; --ISO 8859-2
    MIME_TYPE  VARCHAR2 (255) ; 
    CONN UTL_SMTP.CONNECTION;
 
    l_encoded_username VARCHAR2(300);
    l_encoded_password VARCHAR (300);
	
	v_wallet_path varhcar2(200) := 'Path to your wallet'; --example 'file:C:\Oracle\product\12.1.0\dbhome_1\myinfobipwallet';
	v_wallet_pass varchar2(20) := 'Your wallet password';

    v_reply utl_smtp.replies;
    v_error varchar2(4000);
    v_filenames varchar2(4000);
    V_LENGTH PLS_INTEGER;
    V_OFFSET PLS_INTEGER := 1;
    V_BUFFER_SIZE INTEGER := 75;
    V_RAW RAW(32767);
    n_counter number;
    v_mail_address varchar2(100);
	
	
    PROCEDURE SEND_HEADER (NAME IN VARCHAR2, HEADER IN VARCHAR2)
    IS
    BEGIN
        utl_smtp.WRITE_DATA (CONN, NAME || ': ' || HEADER || CRLF);
    END;
    PROCEDURE PROCESS_RECIPIENTS(P_MAIL_CONN IN OUT UTL_SMTP.CONNECTION, P_LIST IN VARCHAR2) AS
        L_TAB STRING_API.T_SPLIT_ARRAY;
    BEGIN
        IF TRIM(P_LIST) IS NOT NULL THEN
            L_TAB := STRING_API.SPLIT_TEXT(P_LIST);
            FOR I IN 1 .. L_TAB.COUNT LOOP
                IF TRIM(L_TAB(I)) IS NOT NULL THEN
                    UTL_SMTP.RCPT(P_MAIL_CONN, TRIM(L_TAB(I)));
                END IF;
            END LOOP;
        END IF;
    END;
    
    BEGIN
      
      IF MSG_TYPE = 'html' THEN
          MIME_TYPE := 'text/html';
     ELSE
          MIME_TYPE := 'text/plain';
     END IF;
     
    l_encoded_username := utl_raw.cast_to_varchar2(UTL_ENCODE.base64_encode(utl_raw.cast_to_raw(g_api_user)));
    l_encoded_password := utl_raw.cast_to_varchar2(UTL_ENCODE.base64_encode(utl_raw.cast_to_raw(g_api_password)));
    conn := utl_smtp.open_connection(host => g_smtp_server, port =>g_smtp_port, wallet_path => v_wallet_path, wallet_password => v_wallet_pass, secure_connection_before_smtp => FALSE);
   
    --TLS
    utl_smtp.starttls(conn);
    utl_smtp.helo(conn,g_smtp_server);
    v_reply:=utl_smtp.ehlo(conn,g_smtp_server);

     
    utl_smtp.command(conn, 'AUTH','LOGIN');
    utl_smtp.command(conn, l_encoded_username);
    utl_smtp.command(conn, l_encoded_password);
    utl_smtp.mail(CONN, '<' || MSG_FROM || '>');
    
    process_recipients(CONN, MSG_TO);
    process_recipients(CONN, MSG_CC);
    
      -- Open data
    utl_smtp.OPEN_DATA (CONN);
    send_header ('From', g_sender_display_name ||' <' || MSG_FROM || '>');
 
      -- Add all recipient TO
    n_counter:=0;
    LOOP
      n_counter := n_counter + 1;
      v_mail_address := regexp_substr(MSG_TO, '[^,]+', 1, n_counter);
      EXIT WHEN v_mail_address IS NULL;
      utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('To: ' || v_mail_address || CRLF));
    END LOOP; 
 
    IF MSG_CC IS NOT NULL THEN
    send_header ('Cc', '<' || REPLACE(MSG_CC, ',', ';') || '>');
    END IF;
 
    send_header ('Subject', MSG_SUBJECT);
    send_header ('Content-Type', MULTIPART_MIME_TYPE);
    utl_smtp.write_data (conn, CRLF);
    utl_smtp.write_data (conn,'This is a multi-part message in MIME format.' || CRLF);
    
    utl_smtp.write_data (conn, FIRST_BOUNDARY);
 
    -- Message body
    send_header ('Content-Type', MIME_TYPE ||'; charset=UTF-8');
	
    utl_smtp.write_data (conn, CRLF);
    utl_smtp.write_raw_data (conn, UTL_RAW.CAST_TO_RAW (MSG_TEXT));
    utl_smtp.write_data (conn, CRLF);

     -- Attachment Part
    IF p_attachments is not null THEN
    FOR i IN 1..p_attachments.count
    LOOP
        IF p_attachments(i).attachment_name IS NOT NULL AND p_attachments(i).attachment_blob IS NOT NULL THEN
            -- Attachment info
            utl_smtp.write_data (conn, FIRST_BOUNDARY);
            utl_smtp.write_data (conn, ' name="' || p_attachments(i).attachment_name || '"' || CRLF);
            utl_smtp.write_data (conn, 'Content-Disposition: attachment; filename="'|| p_attachments(i).attachment_name|| '"'|| CRLF);
            utl_smtp.write_data (conn, 'Content-Transfer-Encoding:base64' || CRLF);
            utl_smtp.write_data (conn, 'Content-Type: '|| MIME_TYPE  || CRLF);
            utl_smtp.write_data (conn, CRLF);
            
            -- Attach body
            V_LENGTH := DBMS_LOB.GETLENGTH (p_attachments(i).attachment_blob);
            V_OFFSET := 1;
            V_RAW := null;
            V_BUFFER_SIZE := 57;
            WHILE V_OFFSET < V_LENGTH
            LOOP
            DBMS_LOB.READ (p_attachments(i).attachment_blob,
                V_BUFFER_SIZE,
                V_OFFSET,
                V_RAW);
                utl_smtp.write_raw_data (CONN, UTL_ENCODE.BASE64_ENCODE (V_RAW));
                utl_smtp.write_data (CONN, CRLF);
                V_OFFSET := V_OFFSET + V_BUFFER_SIZE;
            END LOOP WHILE_LOOP;
            
            utl_smtp.write_raw_data (CONN,UTL_RAW.CAST_TO_RAW ('' || UTL_TCP.CRLF));
        END IF;
    end loop;
    END IF;  -- end attachment
    -- Last boundry
    utl_smtp.write_data (CONN, LAST_BOUNDARY);
    
    utl_smtp.CLOSE_DATA (CONN);
    utl_smtp.QUIT (CONN);
    
 
    g_msg_sent :='Y';
     exception when others then
        utl_smtp.QUIT (CONN);
        v_error := substr(sqlerrm,1,3950);
		 dbms_output.put_line(v_error);
  END send_email;

   
  
  FUNCTION F_EMAIL_SENT RETURN CHAR
   IS
    BEGIN
        RETURN g_msg_sent;
    END ;
  
  
  FUNCTION F_IS_VALID_MAIL (P_EMAIL IN VARCHAR2) RETURN CHAR
   IS
          V_VALID   CHAR (1);
   BEGIN
      IF P_EMAIL IS NOT NULL
      THEN
         IF REGEXP_LIKE (P_EMAIL,'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$')
         THEN
            V_VALID := 'Y';
         ELSE
            V_VALID := 'N';
         END IF;
      ELSE
         V_VALID := 'N';
   END IF;
      
    RETURN V_VALID;
   
   END F_IS_VALID_MAIL;
   


END;
/