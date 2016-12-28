create or replace PACKAGE BANK AS 
  
  TYPE cur_flow IS REF CURSOR;
  TYPE cur_card IS REF CURSOR;

END BANK;



create or replace PROCEDURE ADD_USER(iuserid in char, iname in varchar, iphone in char) AS 
BEGIN
  IF CHECK_USER(iuserid, iname, iphone)=FALSE THEN
    INSERT INTO BANKUSER(userid, name, phone) VALUES(iuserid, iname, iphone); 
    COMMIT;
  END IF;
END ADD_USER;



create or replace FUNCTION ADD_CARD(iuserid in char, iname in varchar2,
                                    iphone in char, ipassword in char) 
                                    RETURN CHAR AS 
  c_count NUMBER;
	char_cardid bankcard.cardid%TYPE := 0;
BEGIN
  IF CHECK_USER(iuserid, iname, iphone)=TRUE THEN
  	SELECT MAX(cardid) INTO char_cardid FROM bankcard;
    IF char_cardid=NULL THEN
      char_cardid := '6004857329440000001';
    ELSE
      char_cardid := TO_CHAR(TO_NUMBER(char_cardid, '9999999999999999999') + 1);
    END IF;
  	INSERT INTO bankcard (cardid, userid, pwd, deposit) 
      VALUES (char_cardid, iuserid, ipassword, 0);
  END IF;
  RETURN NVL(char_cardid, '0000000000000000001');
END ADD_CARD;



create or replace FUNCTION CHANGE_DEPOSIT(icardid in char, ipwd in char, ideposit in number, wrong out integer)
RETURN bank.cur_flow AS 
	iflowid financialflow.flowid%TYPE;
	change_card bankcard%ROWTYPE;
	iflow bank.cur_flow;
  f_count NUMBER;
  iflowtype char(1);
  iuserid char(18);
  idate timestamp;
BEGIN
  -- get card info
  IF CHECK_CARD(icardid, ipwd)=FALSE THEN
    wrong := 1;
    RETURN iflow;
  END IF;
  SELECT * INTO change_card FROM bankcard WHERE cardid = icardid AND pwd = ipwd;
  
  -- deposit not enough
	IF ideposit+change_card.deposit < 0 THEN
    wrong := 2;
		RETURN iflow;
  -- do change
	ELSE
		UPDATE bankcard SET deposit=deposit+ideposit WHERE cardid = icardid;
    -- get time
    idate := sysdate;
    -- get user info
    iuserid := change_card.userid;
    -- get flowtype
    IF ideposit<0 THEN
      iflowtype := 'o';
    ELSE
      iflowtype := 'i';
    END IF;
    
    -- flow table is empty?
    SELECT COUNT(*) INTO f_count FROM dual WHERE EXISTS (SELECT * FROM financialflow);
    IF f_count=0 THEN
      iflowid := '1000923347620000001';
    ELSE 
  		SELECT MAX(flowid) INTO iflowid FROM financialflow;
    	iflowid := TO_CHAR(TO_NUMBER(iflowid, '9999999999999999999') + 1);
    END IF;
    -- insert flow
    INSERT INTO financialflow(flowid, cardid, userid, amount, flowtype, flowtime) 
        VALUES(iflowid, icardid, iuserid, ideposit, iflowtype, idate);
    -- init data for output
    OPEN iflow FOR SELECT * FROM FINANCIALFLOW WHERE FLOWID=iflowid;
    wrong  := 0;
    RETURN iflow;
  END IF;
END CHANGE_DEPOSIT;



create or replace FUNCTION CHECK_CARD(icardid IN CHAR, ipwd IN CHAR) 
RETURN BOOLEAN AS 
  c_count NUMBER;
BEGIN	
	SELECT COUNT(*) INTO c_count FROM dual
    WHERE EXISTS(SELECT * FROM bankcard WHERE cardid = icardid AND pwd = ipwd);
  IF c_count=0 THEN
    RETURN FALSE;
  ELSE 
    RETURN TRUE;
  END IF;
END CHECK_CARD;



create or replace FUNCTION CHECK_USER(iuserid in char, iname in varchar2, iphone in char)
RETURN BOOLEAN AS 
  u_count NUMBER := 0;
BEGIN
	SELECT COUNT(*)INTO u_count FROM dual
    WHERE EXISTS(SELECT * FROM bankuser WHERE userid = iuserid AND name = iname AND phone = iphone);
  IF u_count=0 THEN
    RETURN FALSE;
  ELSE 
    RETURN TRUE;
  END IF;
END CHECK_USER;



create or replace FUNCTION GET_CARD(iuserid in char, wrong out integer)
RETURN bank.cur_card AS 
	icard bank.cur_card;
	card_rec bankcard%ROWTYPE;
  counter INTEGER := 0;
  is_user_right NUMBER;
BEGIN
  SELECT count(*) INTO is_user_right FROM dual 
    WHERE EXISTS (SELECT * FROM bankuser WHERE userid = iuserid);
  IF is_user_right=1 THEN
    OPEN icard FOR SELECT CARDID FROM bankcard WHERE userid = iuserid;
    wrong := 0;
  ELSE
    wrong := 1;
  END IF;
  RETURN icard;
END GET_CARD;



create or replace FUNCTION GET_DEPOSIT(icardid in char, ipwd in char)
RETURN NUMBER AS 
	ideposit NUMBER;
  is_user_right NUMBER;
BEGIN
  IF CHECK_CARD(icardid, ipwd)=FALSE THEN
    ideposit := -1;
  ELSE
    SELECT deposit INTO ideposit FROM bankcard 
      WHERE cardid = icardid AND pwd = ipwd;
  END IF;
	RETURN ideposit;
END GET_DEPOSIT;



create or replace FUNCTION GET_FLOW(icardid in char, ipwd in char, idate in char, wrong out int)
RETURN bank.cur_flow AS 
	iflow bank.cur_flow;
BEGIN
	IF check_card(icardid, ipwd)=FALSE THEN
    wrong := 1;
    RETURN iflow;
  ELSE
    wrong := 0;
		OPEN iflow FOR SELECT * FROM FINANCIALFLOW 
                            WHERE cardid = icardid AND TO_CHAR(flowtime, 'YYYY-MM') = idate;
		RETURN iflow;
	END IF;
END GET_FLOW;