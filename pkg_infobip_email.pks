CREATE OR REPLACE PACKAGE PKG_INFOBIP_MAIL AS 

/*
 emir.ba 08.2020
*/
  
    PROCEDURE  send_email (MSG_FROM VARCHAR2,
        MSG_TO VARCHAR2,
        MSG_CC VARCHAR2 ,
        MSG_SUBJECT VARCHAR2,
        MSG_TEXT VARCHAR2,
        p_attachments IN table_attachments DEFAULT NULL,
        MSG_TYPE VARCHAR2 DEFAULT 'text' --'text or html'
       );
-- infobip email smtp api
    
   function f_email_sent return char;
-- if sent Y, else N

    function f_is_valid_mail (p_email IN VARCHAR2) return char;
-- validate email (Y,N)


END;
/