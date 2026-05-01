# Multi-User Login System — x86 Assembly (emu8086)

**Course:** CEL-323 Computer Organisation & Assembly Language  
**Class:** BS(CS) 4B — Bahria University Karachi  
**Members:** Omer Naeem | Sadia Saeed | Ayesha Khan  

---

## Project Overview
A console-based multi-user authentication system built entirely in x86 Assembly Language using emu8086. Implements real security concepts at the hardware/instruction level.

---

## Features
- Role-based access control (Admin / Standard User)
- XOR password hashing — passwords never stored in plaintext
- File persistence via DOS INT 21h — users survive program restart
- Masked password input (displays * per keystroke)
- 3-attempt account lockout
- Old password verification before password change
- Minimum 4 character password validation
- Activity audit log written to disk on exit
- Admin: view users, delete user, view activity log
- User: view profile, change password

---

## Security Implementation
| Feature | Implementation |
|---|---|
| Password Hashing | XOR each byte with key 0x5A |
| File Storage | DOS INT 21h AH=3Ch/3Dh/3Fh/40h/3Eh |
| Authentication | Null-terminated strcmp in pure assembly |
| Lockout | Register counter, 3 failures = locked |

---

## Built-in Credentials
| Username | Password | Role |
|---|---|---|
| admin | admin123 | Admin |
| omer | pass123 | User |
| sadia | pass456 | User |
| ayesha | pass789 | User |

---

## How to Run
1. Install emu8086 from emu8086.com
2. Place `login_system.asm` in `C:\emu8086\MySource\`
3. Open emu8086 → Open file → Compile → Emulate → Run

---

## Files Generated at Runtime
| File | Contents |
|---|---|
| users.dat | Registered users (binary, passwords XOR-hashed) |
| activity.log | Login, logout, register, delete events |

---

## Topics Covered (CEL-323)
- DOS Interrupts (INT 21h, INT 10h)
- Memory segmentation (.model small, DS/ES)
- Register-based string comparison
- File I/O (create, open, read, write, close)
- XOR operations for password hashing
- Stack usage (PUSH/POP for register preservation)
- Control flow (CMP, JE, JNZ, JMP, LOOP)
