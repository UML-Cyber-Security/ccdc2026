## SUID_BitCheck.sh

**Functionality/Description:** Scans the entire filesystem for files with the SUID bit set using `find / -perm /4000`. For each file found, displays the file owner/permissions via `ls -l` and checks if the file is currently running via `ps`. Prompts the operator to delete, move (to an `./Untrusted/` directory), or ignore each file. All actions taken are logged to `file_report.txt`.

**Use Case During Event:** Run early in a round to identify potentially dangerous SUID binaries that red team could use for privilege escalation. Lets you make quick triage decisions per file without blindly removing everything.

**Risk Assessment:** High - deleting or moving legitimate SUID binaries (e.g., `passwd`, `sudo`, `ping`) can break system functionality. Review each file carefully before choosing delete or move. The move option is safer than deletion since files can be recovered from `./Untrusted/` if needed. **Note:** The script also contains a typo (`donesdf` instead of `done`) that will cause it to fail at runtime - this must be fixed before use.

---

## User_check.sh

**Functionality/Description:** Audits three categories of potentially suspicious accounts on the system: users with UID 0 (root-level privilege) that are not the actual `root` account, users with `/sh` as their shell, and users with `/bash` as their shell. For each user found in any category, prompts the operator to delete (`userdel -f`), lock (`passwd -l`), change the password (`chpasswd`), or ignore them.

**Use Case During Event:** Run during initial hardening to hunt for backdoor accounts or privilege escalation vectors. UID 0 non-root accounts are a major red flag and should be addressed immediately. The shell-based checks help surface accounts that have interactive login capability that may not be immediately obvious.

**Risk Assessment:** High - forcefully deleting service accounts (`userdel -f`) can break running services. Locking accounts is the safer option when unsure. The password change option reads the new password in plaintext via `read`, so be mindful of shoulder surfing or terminal logs. Always cross-reference with your `users.txt` from enumeration before taking destructive action.