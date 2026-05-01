; ================================================================
;  MULTI-USER LOGIN SYSTEM  v2.0
;  Course  : CEL-323  Computer Organisation & Assembly Language
;  Members : Omer Naeem (Lead) | Sadia Saeed | Ayesha Khan
;  Class   : BS(CS) 4B   |   Platform: emu8086
; ================================================================
;
;  NEW IN v2.0:
;   1. XOR password hashing  -- passwords never stored in plaintext
;   2. File persistence      -- registered users saved to users.dat
;                               loaded back on every startup
;   3. Audit log to disk     -- activity.log written on exit
;
;  BUILT-IN CREDENTIALS:
;   admin  / admin123  (Admin)
;   omer   / pass123   (User)
;   sadia  / pass456   (User)
;   ayesha / pass789   (User)
;
;  XOR KEY = 5Ah
;  Built-in passwords are pre-encoded in the table below.
;  Registered passwords are XOR-encoded before saving.
;  On login, input password is XOR-encoded before comparing.
; ================================================================

.model small
.stack 400h

UNAME_LEN  EQU  16
PASS_LEN   EQU  16
REC_SIZE   EQU  33
NUM_USERS  EQU  4
MAX_EXTRA  EQU  10
XOR_KEY    EQU  5Ah

PRINT MACRO lbl
    LEA  DX, lbl
    MOV  AH, 09h
    INT  21h
ENDM

.data

; ----------------------------------------------------------------
;  BUILT-IN USER TABLE  (passwords XOR-encoded with key 5Ah)
;
;  How to verify encoding manually:
;   'a' XOR 5Ah = 61h XOR 5Ah = 3Bh
;   'd' XOR 5Ah = 64h XOR 5Ah = 3Eh  ... etc.
;
;  admin123  encoded: 3Bh 3Eh 37h 33h 34h 6Bh 68h 69h
;  pass123   encoded: 2Ah 3Bh 29h 29h 6Bh 68h 69h
;  pass456   encoded: 2Ah 3Bh 29h 29h 6Eh 6Fh 6Ch
;  pass789   encoded: 2Ah 3Bh 29h 29h 6Dh 62h 63h
; ----------------------------------------------------------------
user_table:
    DB  'a','d','m','i','n',0,0,0,0,0,0,0,0,0,0,0
    DB  3Bh,3Eh,37h,33h,34h,6Bh,68h,69h,0,0,0,0,0,0,0,0
    DB  'A'

    DB  'o','m','e','r',0,0,0,0,0,0,0,0,0,0,0,0
    DB  2Ah,3Bh,29h,29h,6Bh,68h,69h,0,0,0,0,0,0,0,0,0
    DB  'U'

    DB  's','a','d','i','a',0,0,0,0,0,0,0,0,0,0,0
    DB  2Ah,3Bh,29h,29h,6Eh,6Fh,6Ch,0,0,0,0,0,0,0,0,0
    DB  'U'

    DB  'a','y','e','s','h','a',0,0,0,0,0,0,0,0,0,0
    DB  2Ah,3Bh,29h,29h,6Dh,62h,63h,0,0,0,0,0,0,0,0,0
    DB  'U'

extra_table   DB  (MAX_EXTRA * REC_SIZE) DUP(0)
extra_count   DB  0

login_role    DB  0
login_user    DB  17 DUP(0)
active_ppw    DW  0

uname_in      DB  17 DUP(0)
pass_in       DB  17 DUP(0)
pass_hashed   DB  17 DUP(0)

attempts      DB  0
del_idx       DB  0

users_file    DB  "users.dat",0
log_file      DB  "activity.log",0
file_hnd      DW  0
file_buf      DB  (MAX_EXTRA * REC_SIZE) DUP(0)
bytes_read    DW  0

mem_log       DB  512 DUP(0)
mem_log_len   DW  0

NL            DB  0Dh,0Ah,'$'

; ================================================================
;  STRINGS
; ================================================================
s_logo DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |                                                      |",0Dh,0Ah
 DB "  |            MULTI-USER LOGIN SYSTEM                   |",0Dh,0Ah
 DB "  |        CEL-323  COAL  --  BS(CS) 4B                  |",0Dh,0Ah
 DB "  |                                                      |",0Dh,0Ah
 DB "  |   Members: Omer Naeem | Sadia Saeed | Ayesha Khan    |",0Dh,0Ah
 DB "  |                                                      |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'

s_mainmenu DB 0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |                   MAIN MENU                        |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  |          [ 1 ]   Login                             |",0Dh,0Ah
 DB "  |          [ 2 ]   Register New Account              |",0Dh,0Ah
 DB "  |          [ 3 ]   Exit                              |",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB 0Dh,0Ah,"  Your choice > $"

s_login_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |                 [ * ]  USER LOGIN                    |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'

s_ask_user  DB 0Dh,0Ah,"  Username  :  $"
s_ask_pass  DB "  Password  :  $"
s_ask_npw   DB 0Dh,0Ah,"  New Password :  $"

s_login_ok  DB 0Dh,0Ah
 DB "  +----------------------------------+",0Dh,0Ah
 DB "  |   [ OK ]  LOGIN SUCCESSFUL !    |",0Dh,0Ah
 DB "  +----------------------------------+",0Dh,0Ah
 DB '$'

s_login_bad DB 0Dh,0Ah
 DB "  +------------------------------------------+",0Dh,0Ah
 DB "  |  [ !! ]  Wrong username or password.     |",0Dh,0Ah
 DB "  +------------------------------------------+",0Dh,0Ah
 DB '$'

s_locked DB 0Dh,0Ah
 DB "  +------------------------------------------------------+",0Dh,0Ah
 DB "  |  [ ## ]  ACCOUNT LOCKED -- 3 failed attempts.       |",0Dh,0Ah
 DB "  |          Restart the program to try again.          |",0Dh,0Ah
 DB "  +------------------------------------------------------+",0Dh,0Ah
 DB '$'

s_att_left  DB "  Attempts left: $"

s_reg_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |            [ + ]  REGISTER NEW USER                  |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'

s_reg_role   DB 0Dh,0Ah,"  Role  [ A=Admin  /  U=User ] :  $"
s_reg_full   DB 0Dh,0Ah,"  [ !! ]  Registration table full!$"
s_reg_exists DB 0Dh,0Ah,"  [ !! ]  Username already exists!$"
s_reg_empty  DB 0Dh,0Ah,"  [ !! ]  Username cannot be empty!$"

s_reg_ok DB 0Dh,0Ah
 DB "  +-----------------------------------+",0Dh,0Ah
 DB "  |   [ OK ]  User registered!       |",0Dh,0Ah
 DB "  +-----------------------------------+",0Dh,0Ah
 DB '$'

s_adm_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |          [ A ]  ADMIN CONTROL PANEL                  |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |   Logged in as:  $"
s_adm_hdr2 DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'

s_adm_menu DB 0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |  ADMIN MENU                                        |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  |   [ 1 ]   View All Registered Users               |",0Dh,0Ah
 DB "  |   [ 2 ]   Delete a User                           |",0Dh,0Ah
 DB "  |   [ 3 ]   View Activity Log                       |",0Dh,0Ah
 DB "  |   [ 4 ]   Logout                                  |",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB 0Dh,0Ah,"  Select > $"

s_vu_hdr DB 0Dh,0Ah
 DB "  +================================================+",0Dh,0Ah
 DB "  |        [ U ]  REGISTERED USERS                 |",0Dh,0Ah
 DB "  +================================================+",0Dh,0Ah
 DB "  | No | Username         | Role                   |",0Dh,0Ah
 DB "  +----+------------------+------------------------+",0Dh,0Ah
 DB '$'
s_vu_foot DB "  +----+------------------+------------------------+",0Dh,0Ah
 DB '$'
s_vu_pipe  DB "  | $"
s_vu_col   DB " | $"

s_del_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |         [ X ]  DELETE USER                           |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'
s_del_prompt   DB 0Dh,0Ah,"  Enter username to delete: $"
s_del_ok       DB 0Dh,0Ah,"  [ OK ]  User deleted and file updated.$"
s_del_notfound DB 0Dh,0Ah,"  [ !! ]  User not found.$"
s_del_builtin  DB 0Dh,0Ah,"  [ !! ]  Cannot delete built-in accounts.$"

s_usr_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |         [ U ]  USER PANEL                            |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |   Welcome:  $"
s_usr_hdr2 DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'

s_usr_menu DB 0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |  USER MENU                                         |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  |   [ 1 ]   View Profile                            |",0Dh,0Ah
 DB "  |   [ 2 ]   Change Password                         |",0Dh,0Ah
 DB "  |   [ 3 ]   Logout                                  |",0Dh,0Ah
 DB "  |                                                    |",0Dh,0Ah
 DB "  +----------------------------------------------------+",0Dh,0Ah
 DB 0Dh,0Ah,"  Select > $"

s_profile_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |         [ P ]  MY PROFILE                            |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'
s_pf_user  DB "  Username  :  $"
s_pf_role  DB 0Dh,0Ah,"  Role      :  $"
s_pf_admin DB "Administrator",0Dh,0Ah,'$'
s_pf_user2 DB "Standard User",0Dh,0Ah,'$'
s_pf_sys   DB "  System    :  Multi-User Login System v2.0",0Dh,0Ah
 DB "  Security  :  XOR Password Hashing (Key=5Ah)",0Dh,0Ah
 DB "  Storage   :  Persistent File I/O (users.dat)",0Dh,0Ah
 DB "  Course    :  CEL-323  COAL",0Dh,0Ah,'$'

s_chpw_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |         [ K ]  CHANGE PASSWORD                       |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'
s_chpw_ok    DB 0Dh,0Ah,"  [ OK ]  Password changed and saved.",0Dh,0Ah,'$'
s_ask_oldpw  DB 0Dh,0Ah,"  Current Password :  $"
s_oldpw_bad  DB 0Dh,0Ah,"  [ !! ]  Wrong current password. Cancelled.",0Dh,0Ah,'$'
s_pass_short DB 0Dh,0Ah,"  [ !! ]  Password too short! Minimum 4 characters.",0Dh,0Ah,'$'

s_log_hdr DB 0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB "  |         [ L ]  ACTIVITY LOG                          |",0Dh,0Ah
 DB "  +======================================================+",0Dh,0Ah
 DB '$'
s_log_foot  DB "  +======================================================+",0Dh,0Ah,'$'
s_log_empty DB "  (No activity this session.)",0Dh,0Ah,'$'

s_anykey    DB 0Dh,0Ah,"  Press any key to continue . . . $"
s_loggedout DB 0Dh,0Ah,"  [ OK ]  Logged out.",0Dh,0Ah,'$'
s_bye DB 0Dh,0Ah
 DB "  +------------------------------------------+",0Dh,0Ah
 DB "  |   Goodbye from CEL-323 Group 4B  :)      |",0Dh,0Ah
 DB "  +------------------------------------------+",0Dh,0Ah
 DB '$'

row_num  DB  0

; ================================================================
;  CODE SEGMENT
; ================================================================
.code

main PROC
    MOV  AX, @data
    MOV  DS, AX
    MOV  ES, AX

    CALL load_users         ; load users.dat into extra_table

main_top:
    CALL cls
    PRINT s_logo
    PRINT s_mainmenu

    MOV  AH, 01h
    INT  21h
    CMP  AL, '1'
    JE   do_login
    CMP  AL, '2'
    JE   do_register
    CMP  AL, '3'
    JE   do_exit
    JMP  main_top

do_exit:
    CALL save_log           ; write activity.log to disk on exit
    CALL cls
    PRINT s_bye
    PRINT NL
    MOV  AH, 4Ch
    INT  21h

do_register:
    CALL register_user
    JMP  main_top

; ================================================================
;  LOGIN FLOW
; ================================================================
do_login:
    MOV  attempts, 0

login_screen:
    CALL cls
    PRINT s_login_hdr

    CMP  attempts, 0
    JE   skip_att
    PRINT s_att_left
    MOV  AL, 3
    SUB  AL, attempts
    ADD  AL, '0'
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    PRINT NL

skip_att:
    PRINT s_ask_user
    CALL get_input_uname
    PRINT NL

    PRINT s_ask_pass
    CALL get_masked_pass
    PRINT NL

    CALL xor_hash_pass      ; hash pass_in -> pass_hashed
    CALL do_auth            ; CF=0 ok  CF=1 fail

    JNC  auth_ok

    PRINT s_login_bad
    INC  attempts
    CMP  attempts, 3
    JL   login_screen
    PRINT s_locked
    MOV  AH, 01h
    INT  21h
    JMP  do_exit

auth_ok:
    CALL log_event_in
    PRINT s_login_ok
    MOV  AH, 01h
    INT  21h
    CMP  login_role, 'A'
    JE   admin_dash
    JMP  user_dash

; ================================================================
;  ADMIN DASHBOARD
; ================================================================
admin_dash:
    CALL cls
    PRINT s_adm_hdr
    LEA  SI, login_user
    CALL prnt_si
    PRINT s_adm_hdr2
    PRINT s_adm_menu

    MOV  AH, 01h
    INT  21h
    CMP  AL, '1'
    JE   adm_viewusers
    CMP  AL, '2'
    JE   adm_delete
    CMP  AL, '3'
    JE   adm_log
    CMP  AL, '4'
    JE   adm_logout
    JMP  admin_dash

adm_logout:
    CALL log_event_out
    PRINT s_loggedout
    JMP  main_top

adm_viewusers:
    CALL cls
    CALL show_users
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    JMP  admin_dash

adm_delete:
    CALL cls
    CALL delete_user
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    JMP  admin_dash

adm_log:
    CALL cls
    CALL show_log
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    JMP  admin_dash

; ================================================================
;  USER DASHBOARD
; ================================================================
user_dash:
    CALL cls
    PRINT s_usr_hdr
    LEA  SI, login_user
    CALL prnt_si
    PRINT s_usr_hdr2
    PRINT s_usr_menu

    MOV  AH, 01h
    INT  21h
    CMP  AL, '1'
    JE   usr_profile
    CMP  AL, '2'
    JE   usr_chpw
    CMP  AL, '3'
    JE   usr_logout
    JMP  user_dash

usr_logout:
    CALL log_event_out
    PRINT s_loggedout
    JMP  main_top

usr_profile:
    CALL cls
    CALL show_profile
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    JMP  user_dash

usr_chpw:
    CALL change_pw
    JMP  user_dash

main ENDP

; ================================================================
;  PROC: cls
; ================================================================
cls PROC
    MOV  AH, 06h
    MOV  AL, 00h
    MOV  BH, 07h
    MOV  CX, 0000h
    MOV  DX, 184Fh
    INT  10h
    MOV  AH, 02h
    MOV  BH, 00h
    XOR  DX, DX
    INT  10h
    RET
cls ENDP

; ================================================================
;  PROC: get_input_uname
; ================================================================
get_input_uname PROC
    LEA  DI, uname_in
    MOV  CX, 17
    MOV  AL, 0
giu_clr:
    MOV  [DI], AL
    INC  DI
    LOOP giu_clr
    LEA  DI, uname_in
    MOV  CX, 0
giu_lp:
    MOV  AH, 01h
    INT  21h
    CMP  AL, 0Dh
    JE   giu_done
    CMP  CX, 16
    JGE  giu_lp
    MOV  [DI], AL
    INC  DI
    INC  CX
    JMP  giu_lp
giu_done:
    MOV  BYTE PTR [DI], 0
    RET
get_input_uname ENDP

; ================================================================
;  PROC: get_masked_pass
; ================================================================
get_masked_pass PROC
    LEA  DI, pass_in
    MOV  CX, 17
    MOV  AL, 0
gmp_clr:
    MOV  [DI], AL
    INC  DI
    LOOP gmp_clr
    LEA  DI, pass_in
    MOV  CX, 0
gmp_lp:
    MOV  AH, 08h
    INT  21h
    CMP  AL, 0Dh
    JE   gmp_done
    CMP  AL, 08h
    JE   gmp_bs
    CMP  CX, 16
    JGE  gmp_lp
    MOV  [DI], AL
    INC  DI
    INC  CX
    MOV  AH, 02h
    MOV  DL, '*'
    INT  21h
    JMP  gmp_lp
gmp_bs:
    CMP  CX, 0
    JE   gmp_lp
    DEC  DI
    DEC  CX
    MOV  AH, 02h
    MOV  DL, 08h
    INT  21h
    MOV  DL, ' '
    INT  21h
    MOV  DL, 08h
    INT  21h
    JMP  gmp_lp
gmp_done:
    MOV  BYTE PTR [DI], 0
    RET
get_masked_pass ENDP

; ================================================================
;  PROC: xor_hash_pass
;
;  Reads pass_in, XORs each byte with XOR_KEY (5Ah),
;  stores result in pass_hashed.
;
;  Why XOR?
;   - XOR is reversible: (byte XOR key) XOR key = byte
;   - So we hash on store, hash on compare -- both sides match
;   - Passwords never appear as plaintext in memory or on disk
;   - One instruction (XOR AL, 5Ah) does the entire operation
; ================================================================
xor_hash_pass PROC
    PUSH AX
    PUSH SI
    PUSH DI
    LEA  SI, pass_in
    LEA  DI, pass_hashed
    MOV  CX, 17
xhp_clr:
    MOV  BYTE PTR [DI], 0
    INC  DI
    LOOP xhp_clr
    LEA  DI, pass_hashed
xhp_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   xhp_done
    XOR  AL, XOR_KEY        ; single XOR instruction = the hash
    MOV  [DI], AL
    INC  SI
    INC  DI
    JMP  xhp_lp
xhp_done:
    MOV  BYTE PTR [DI], 0
    POP  DI
    POP  SI
    POP  AX
    RET
xor_hash_pass ENDP

; ================================================================
;  PROC: strcmp
;  Null-terminated string compare DS:SI vs DS:DI
;  ZF=1 equal, ZF=0 not equal
; ================================================================
strcmp PROC
    PUSH SI
    PUSH DI
sc_lp:
    MOV  AL, [SI]
    CMP  AL, [DI]
    JNZ  sc_no
    CMP  AL, 0
    JZ   sc_yes
    INC  SI
    INC  DI
    JMP  sc_lp
sc_yes:
    POP  DI
    POP  SI
    CMP  AL, AL
    RET
sc_no:
    POP  DI
    POP  SI
    MOV  AL, 1
    OR   AL, AL
    RET
strcmp ENDP

; ================================================================
;  PROC: do_auth
;  Username compared plaintext, password compared hashed.
;  CF=0 match, CF=1 fail.
; ================================================================
do_auth PROC
    LEA  BX, user_table
    MOV  DX, NUM_USERS

da_next:
    CMP  DX, 0
    JE   da_extras
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JNZ  da_miss
    LEA  SI, pass_hashed
    MOV  DI, BX
    ADD  DI, UNAME_LEN
    CALL strcmp
    JZ   da_hit
da_miss:
    ADD  BX, REC_SIZE
    DEC  DX
    JMP  da_next

da_extras:
    MOV  AL, extra_count
    CMP  AL, 0
    JE   da_fail
    MOV  AH, 0
    MOV  DX, AX
    LEA  BX, extra_table
da_xnext:
    CMP  DX, 0
    JE   da_fail
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JNZ  da_xmiss
    LEA  SI, pass_hashed
    MOV  DI, BX
    ADD  DI, UNAME_LEN
    CALL strcmp
    JZ   da_hit
da_xmiss:
    ADD  BX, REC_SIZE
    DEC  DX
    JMP  da_xnext

da_fail:
    STC
    RET

da_hit:
    MOV  DI, BX
    ADD  DI, UNAME_LEN
    ADD  DI, PASS_LEN
    MOV  AL, [DI]
    MOV  login_role, AL
    MOV  AX, BX
    ADD  AX, UNAME_LEN
    MOV  active_ppw, AX
    LEA  SI, uname_in
    LEA  DI, login_user
da_cp:
    MOV  AL, [SI]
    MOV  [DI], AL
    INC  SI
    INC  DI
    CMP  AL, 0
    JNE  da_cp
    CLC
    RET
do_auth ENDP

; ================================================================
;  PROC: register_user
; ================================================================
register_user PROC
    CALL cls
    PRINT s_reg_hdr

    MOV  AL, extra_count
    CMP  AL, MAX_EXTRA
    JL   ru_ok
    PRINT s_reg_full
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET

ru_ok:
    PRINT s_ask_user
    CALL get_input_uname
    PRINT NL

    MOV  AL, uname_in
    CMP  AL, 0
    JNE  ru_notempty
    PRINT s_reg_empty
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET

ru_notempty:
    LEA  BX, user_table
    MOV  DX, NUM_USERS
ru_dup1:
    CMP  DX, 0
    JE   ru_dup2
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JZ   ru_exists
    ADD  BX, REC_SIZE
    DEC  DX
    JMP  ru_dup1
ru_dup2:
    MOV  AL, extra_count
    CMP  AL, 0
    JE   ru_getpass
    MOV  AH, 0
    MOV  DX, AX
    LEA  BX, extra_table
ru_dup3:
    CMP  DX, 0
    JE   ru_getpass
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JZ   ru_exists
    ADD  BX, REC_SIZE
    DEC  DX
    JMP  ru_dup3
ru_exists:
    PRINT s_reg_exists
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET

ru_getpass:
    PRINT s_ask_pass
    CALL get_masked_pass
    PRINT NL

    ; minimum password length check (4 chars)
    LEA  SI, pass_in
    MOV  CX, 0
ru_len:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   ru_len_done
    INC  SI
    INC  CX
    JMP  ru_len
ru_len_done:
    CMP  CX, 4
    JGE  ru_len_ok
    PRINT s_pass_short
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET
ru_len_ok:
    CALL xor_hash_pass      ; hash password before storing

    PRINT s_reg_role
    MOV  AH, 01h
    INT  21h
    MOV  BL, 'U'
    CMP  AL, 'A'
    JNE  ru_do
    MOV  BL, 'A'
ru_do:
    PRINT NL

    MOV  AL, extra_count
    MOV  AH, 0
    MOV  CX, REC_SIZE
    MUL  CX
    LEA  DI, extra_table
    ADD  DI, AX

    ; write username
    LEA  SI, uname_in
    MOV  CX, UNAME_LEN
ru_wu:
    MOV  AL, [SI]
    MOV  [DI], AL
    INC  DI
    CMP  AL, 0
    JE   ru_wu_pad
    INC  SI
    DEC  CX
    JCXZ ru_wp
    JMP  ru_wu
ru_wu_pad:
    DEC  CX
    JCXZ ru_wp
ru_wu_z:
    MOV  BYTE PTR [DI], 0
    INC  DI
    LOOP ru_wu_z
ru_wp:
    ; write hashed password
    LEA  SI, pass_hashed
    MOV  CX, PASS_LEN
ru_ww:
    MOV  AL, [SI]
    MOV  [DI], AL
    INC  DI
    CMP  AL, 0
    JE   ru_ww_pad
    INC  SI
    DEC  CX
    JCXZ ru_wr
    JMP  ru_ww
ru_ww_pad:
    DEC  CX
    JCXZ ru_wr
ru_ww_z:
    MOV  BYTE PTR [DI], 0
    INC  DI
    LOOP ru_ww_z
ru_wr:
    MOV  [DI], BL
    INC  extra_count

    CALL log_register       ; log the registration event
    CALL save_users         ; persist to users.dat immediately

    PRINT s_reg_ok
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET
register_user ENDP

; ================================================================
;  PROC: save_users
;  Writes extra_table to users.dat (creates/overwrites).
;  Called after register and after delete.
; ================================================================
save_users PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 3Ch
    XOR  CX, CX
    LEA  DX, users_file
    INT  21h
    JC   svu_done

    MOV  file_hnd, AX

    MOV  AL, extra_count
    MOV  AH, 0
    MOV  CX, REC_SIZE
    MUL  CX
    MOV  CX, AX
    CMP  CX, 0
    JE   svu_close

    MOV  AH, 40h
    MOV  BX, file_hnd
    LEA  DX, extra_table
    INT  21h

svu_close:
    MOV  AH, 3Eh
    MOV  BX, file_hnd
    INT  21h
svu_done:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
save_users ENDP

; ================================================================
;  PROC: load_users
;  Reads users.dat into extra_table on startup.
;  extra_count = bytes_read / REC_SIZE
; ================================================================
load_users PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AH, 3Dh
    MOV  AL, 00h
    LEA  DX, users_file
    INT  21h
    JC   lu_notfound

    MOV  file_hnd, AX
    MOV  AH, 3Fh
    MOV  BX, file_hnd
    MOV  CX, MAX_EXTRA * REC_SIZE
    LEA  DX, extra_table
    INT  21h
    MOV  bytes_read, AX

    MOV  AH, 3Eh
    MOV  BX, file_hnd
    INT  21h

    MOV  AX, bytes_read
    MOV  BX, REC_SIZE
    XOR  DX, DX
    DIV  BX
    MOV  extra_count, AL
    JMP  lu_done

lu_notfound:
    MOV  extra_count, 0
lu_done:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
load_users ENDP

; ================================================================
;  PROC: show_users  (password column hidden -- hashed anyway)
; ================================================================
show_users PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    PRINT s_vu_hdr
    MOV  row_num, 1

    ; ---- built-in users ----
    LEA  BX, user_table
    MOV  CX, NUM_USERS
su_lp:
    CMP  CX, 0
    JE   su_xtra
    MOV  AL, [BX]
    CMP  AL, 0
    JE   su_skip

    PRINT s_vu_pipe
    MOV  AL, row_num
    ADD  AL, '0'
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    PRINT s_vu_col
    MOV  SI, BX
    CALL prnt_padded_16
    PRINT s_vu_col
    MOV  SI, BX
    ADD  SI, UNAME_LEN
    ADD  SI, PASS_LEN
    MOV  AL, [SI]
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    PRINT NL
    INC  row_num

su_skip:
    ADD  BX, REC_SIZE
    DEC  CX
    JMP  su_lp

    ; ---- registered users ----
su_xtra:
    MOV  AL, extra_count
    CMP  AL, 0
    JE   su_done
    MOV  AH, 0
    MOV  CX, AX
    LEA  BX, extra_table

su_xlp:
    CMP  CX, 0
    JE   su_done
    MOV  AL, [BX]
    CMP  AL, 0
    JE   su_xskip

    PRINT s_vu_pipe
    MOV  AL, row_num
    ADD  AL, '0'
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    PRINT s_vu_col
    MOV  SI, BX
    CALL prnt_padded_16
    PRINT s_vu_col
    MOV  SI, BX
    ADD  SI, UNAME_LEN
    ADD  SI, PASS_LEN
    MOV  AL, [SI]
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    PRINT NL
    INC  row_num

su_xskip:
    ADD  BX, REC_SIZE
    DEC  CX
    JMP  su_xlp

su_done:
    PRINT s_vu_foot
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
show_users ENDP

; ================================================================
;  PROC: delete_user
; ================================================================
delete_user PROC
    PRINT s_del_hdr

    MOV  AL, extra_count
    CMP  AL, 0
    JNE  du_getinput
    PRINT s_del_notfound
    RET

du_getinput:
    PRINT s_del_prompt
    CALL get_input_uname
    PRINT NL

    LEA  BX, user_table
    MOV  DX, NUM_USERS
du_chk:
    CMP  DX, 0
    JE   du_search
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JZ   du_builtin
    ADD  BX, REC_SIZE
    DEC  DX
    JMP  du_chk
du_builtin:
    PRINT s_del_builtin
    RET

du_search:
    MOV  AL, extra_count
    MOV  AH, 0
    MOV  DX, AX
    LEA  BX, extra_table
    MOV  del_idx, 0
du_srch:
    CMP  DX, 0
    JE   du_notfound
    LEA  SI, uname_in
    MOV  DI, BX
    CALL strcmp
    JZ   du_found
    ADD  BX, REC_SIZE
    INC  del_idx
    DEC  DX
    JMP  du_srch
du_notfound:
    PRINT s_del_notfound
    RET

du_found:
    MOV  AL, extra_count
    DEC  AL
    SUB  AL, del_idx
    CMP  AL, 0
    JE   du_skip_shift
    MOV  AH, 0
    MOV  CX, REC_SIZE
    MUL  CX
    MOV  DI, BX
    MOV  SI, BX
    ADD  SI, REC_SIZE
    MOV  CX, AX
du_shift:
    MOV  AL, [SI]
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP du_shift
du_skip_shift:
    DEC  extra_count
    MOV  AL, extra_count
    MOV  AH, 0
    MOV  CX, REC_SIZE
    MUL  CX
    LEA  DI, extra_table
    ADD  DI, AX
    MOV  CX, REC_SIZE
    MOV  AL, 0
du_zero:
    MOV  [DI], AL
    INC  DI
    LOOP du_zero

    CALL log_delete         ; log the delete event
    CALL save_users         ; update users.dat after delete

    PRINT s_del_ok
    RET
delete_user ENDP

; ================================================================
;  PROC: show_profile
; ================================================================
show_profile PROC
    PRINT s_profile_hdr
    PRINT s_pf_user
    LEA  SI, login_user
    CALL prnt_si
    PRINT s_pf_role
    CMP  login_role, 'A'
    JE   sp_admin
    PRINT s_pf_user2
    JMP  sp_sys
sp_admin:
    PRINT s_pf_admin
sp_sys:
    PRINT s_pf_sys
    RET
show_profile ENDP

; ================================================================
;  PROC: change_pw
;  Step 1: ask current password, hash it, compare with stored.
;  Step 2: only if match, ask new password (min 4 chars) and save.
; ================================================================
change_pw PROC
    CALL cls
    PRINT s_chpw_hdr

    ; --- verify current password first ---
    PRINT s_ask_oldpw
    CALL get_masked_pass
    PRINT NL
    CALL xor_hash_pass          ; hash what they typed

    ; compare pass_hashed vs stored password at active_ppw
    LEA  SI, pass_hashed
    MOV  DI, active_ppw
    CALL strcmp
    JZ   cpw_old_ok

    PRINT s_oldpw_bad
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET                         ; wrong old password - cancel

cpw_old_ok:
    ; --- ask new password ---
    PRINT s_ask_npw
    CALL get_masked_pass
    PRINT NL

    ; minimum 4 char check
    LEA  SI, pass_in
    MOV  CX, 0
cpw_len:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   cpw_len_done
    INC  SI
    INC  CX
    JMP  cpw_len
cpw_len_done:
    CMP  CX, 4
    JGE  cpw_len_ok
    PRINT s_pass_short
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET

cpw_len_ok:
    CALL xor_hash_pass          ; hash new password

    ; write hashed new password into the matched record
    MOV  DI, active_ppw
    LEA  SI, pass_hashed
    MOV  CX, PASS_LEN
    REP  MOVSB

    ; if registered user (not built-in), save to disk
    LEA  AX, extra_table
    CMP  active_ppw, AX
    JL   cpw_done
    CALL save_users

cpw_done:
    PRINT s_chpw_ok
    PRINT s_anykey
    MOV  AH, 01h
    INT  21h
    RET
change_pw ENDP

; ================================================================
;  PROC: show_log
; ================================================================
show_log PROC
    PRINT s_log_hdr
    CMP  mem_log_len, 0
    JE   sl_empty
    LEA  SI, mem_log
    MOV  CX, mem_log_len
sl_pr:
    JCXZ sl_foot
    MOV  AL, [SI]
    INC  SI
    DEC  CX
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    JMP  sl_pr
sl_empty:
    PRINT s_log_empty
sl_foot:
    PRINT s_log_foot
    RET
show_log ENDP

; ================================================================
;  PROC: save_log
;  Writes mem_log buffer to activity.log on program exit.
; ================================================================
save_log PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    CMP  mem_log_len, 0
    JE   sl2_done

    MOV  AH, 3Ch
    XOR  CX, CX
    LEA  DX, log_file
    INT  21h
    JC   sl2_done

    MOV  file_hnd, AX
    MOV  AH, 40h
    MOV  BX, file_hnd
    MOV  CX, mem_log_len
    LEA  DX, mem_log
    INT  21h
    MOV  AH, 3Eh
    MOV  BX, file_hnd
    INT  21h

sl2_done:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
save_log ENDP

; ================================================================
;  PROC: log_event_in
; ================================================================
log_event_in PROC
    PUSH AX
    PUSH SI
    PUSH DI
    LEA  SI, login_user
    LEA  DI, mem_log
    ADD  DI, mem_log_len
lei_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   lei_sfx
    MOV  [DI], AL
    INC  SI
    INC  DI
    INC  mem_log_len
    JMP  lei_lp
lei_sfx:
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'l'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'o'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'g'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'g'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'i'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'n'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Dh
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Ah
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    POP  DI
    POP  SI
    POP  AX
    RET
log_event_in ENDP

; ================================================================
;  PROC: log_event_out
; ================================================================
log_event_out PROC
    PUSH AX
    PUSH SI
    PUSH DI
    LEA  SI, login_user
    LEA  DI, mem_log
    ADD  DI, mem_log_len
leo_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   leo_sfx
    MOV  [DI], AL
    INC  SI
    INC  DI
    INC  mem_log_len
    JMP  leo_lp
leo_sfx:
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'l'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'o'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'g'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'g'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'o'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'u'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 't'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Dh
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Ah
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    POP  DI
    POP  SI
    POP  AX
    RET
log_event_out ENDP

; ================================================================
;  PROC: log_register -- appends "username registered\r\n"
; ================================================================
log_register PROC
    PUSH AX
    PUSH SI
    PUSH DI
    LEA  SI, uname_in
    LEA  DI, mem_log
    ADD  DI, mem_log_len
lreg_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   lreg_sfx
    MOV  [DI], AL
    INC  SI
    INC  DI
    INC  mem_log_len
    JMP  lreg_lp
lreg_sfx:
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'r'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'g'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'i'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 's'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 't'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'r'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Dh
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Ah
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    POP  DI
    POP  SI
    POP  AX
    RET
log_register ENDP

; ================================================================
;  PROC: log_delete -- appends "admin deleted: username\r\n"
; ================================================================
log_delete PROC
    PUSH AX
    PUSH SI
    PUSH DI
    LEA  DI, mem_log
    ADD  DI, mem_log_len
    ; write "admin deleted: "
    MOV  AL, 'a'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'm'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'i'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'n'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'l'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 't'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'e'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 'd'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, ':'
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, ' '
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    ; write the deleted username (uname_in still has it)
    LEA  SI, uname_in
ldel_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   ldel_sfx
    MOV  [DI], AL
    INC  SI
    INC  DI
    INC  mem_log_len
    JMP  ldel_lp
ldel_sfx:
    MOV  AL, 0Dh
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    MOV  AL, 0Ah
    MOV  [DI], AL
    INC  DI
    INC  mem_log_len
    POP  DI
    POP  SI
    POP  AX
    RET
log_delete ENDP
prnt_si PROC
psi_lp:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   psi_done
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    INC  SI
    JMP  psi_lp
psi_done:
    RET
prnt_si ENDP

; ================================================================
;  PROC: prnt_padded_16
; ================================================================
prnt_padded_16 PROC
    PUSH AX
    PUSH CX
    PUSH DX
    MOV  CX, 0
pp16_char:
    CMP  CX, UNAME_LEN
    JGE  pp16_done
    MOV  AL, [SI]
    CMP  AL, 0
    JE   pp16_pad
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h
    INC  SI
    INC  CX
    JMP  pp16_char
pp16_pad:
    CMP  CX, UNAME_LEN
    JGE  pp16_done
    MOV  AH, 02h
    MOV  DL, ' '
    INT  21h
    INC  CX
    JMP  pp16_pad
pp16_done:
    POP  DX
    POP  CX
    POP  AX
    RET
prnt_padded_16 ENDP

END main