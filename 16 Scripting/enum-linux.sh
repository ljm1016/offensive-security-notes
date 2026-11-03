#!/usr/bin/env bash
# enum-linux.sh - READ-ONLY baseline enumeration for Linux boxes
# (Task / openSUSE Leap, PLC1 / Ubuntu 24.04, PLC2 / Debian 13)
# Changes nothing on the system. Safe for assume-breach boxes.
#
# Usage:  sudo bash enum-linux.sh
# Output: /root/enum-<hostname>-<timestamp>/ plus a .tar.gz of it

if [ "$(id -u)" -ne 0 ]; then
  echo "[!] Run as root (sudo bash $0) for complete results."
  exit 1
fi

HOST=$(hostname)
TS=$(date +%Y%m%d-%H%M%S)
OUT="/root/enum-${HOST}-${TS}"
mkdir -p "$OUT"
chmod 700 "$OUT"

# run "<file>" "<command>" : appends command + output to a section file
run() {
  local file="$OUT/$1"; shift
  {
    echo "### $*"
    bash -c "$*" 2>&1
    echo
  } >> "$file"
}
have() { command -v "$1" >/dev/null 2>&1; }

echo "[*] Enumerating $HOST -> $OUT"

# ---------- 01 system ----------
run 01_system.txt "hostname; date; uptime"
run 01_system.txt "cat /etc/os-release"
run 01_system.txt "uname -a"
run 01_system.txt "free -h"
run 01_system.txt "nproc"
run 01_system.txt "df -hT -x tmpfs -x devtmpfs"

# ---------- 02 network ----------
run 02_network.txt "ip -br addr"
run 02_network.txt "ip route"
run 02_network.txt "cat /etc/resolv.conf"
run 02_network.txt "cat /etc/hosts"
run 03_ports.txt   "ss -tulpn"
run 03_ports.txt   "ss -tunp state established"

# ---------- 04 users ----------
run 04_users.txt "awk -F: '\$3==0 {print \"UID 0: \"\$1}' /etc/passwd"
run 04_users.txt "awk -F: '\$7 !~ /(nologin|false|sync|shutdown|halt)\$/ {print \$1\":\"\$3\":\"\$6\":\"\$7}' /etc/passwd"
run 04_users.txt "awk -F: '(\$2==\"\" ) {print \"EMPTY PASSWORD: \"\$1}' /etc/shadow"
run 04_users.txt "getent group sudo wheel adm admin root docker lxd 2>/dev/null"
run 04_users.txt "grep -vE '^\s*(#|$)' /etc/sudoers; for f in /etc/sudoers.d/*; do [ -f \"\$f\" ] && echo \"--- \$f\" && grep -vE '^\s*(#|$)' \"\$f\"; done"
run 04_users.txt "who; echo; last -n 30 2>/dev/null"
run 04_users.txt "lastlog 2>/dev/null | grep -v 'Never logged in'"

# ---------- 05 ssh ----------
run 05_ssh.txt "grep -iE '^\s*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|PermitEmptyPasswords|AuthorizedKeysFile|Port|AllowUsers|AllowGroups|X11Forwarding)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null"
run 05_ssh.txt "for d in /root \$(awk -F: '\$3>=1000 {print \$6}' /etc/passwd); do for f in \"\$d\"/.ssh/authorized_keys*; do [ -f \"\$f\" ] && echo \"--- \$f\" && cat \"\$f\"; done; done"

# ---------- 06 services / processes ----------
if have systemctl; then
  run 06_services.txt "systemctl list-units --type=service --state=running --no-pager"
  run 06_services.txt "systemctl list-unit-files --type=service --state=enabled --no-pager"
  run 06_services.txt "systemctl list-timers --all --no-pager"
  run 06_services.txt "find /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system -name '*.service' -newermt '-30 days' 2>/dev/null"
fi
run 07_processes.txt "ps auxfww"

# ---------- 08 persistence ----------
run 08_persistence.txt "cat /etc/crontab"
run 08_persistence.txt "ls -la /etc/cron.* 2>/dev/null"
run 08_persistence.txt "for f in /etc/cron.d/*; do [ -f \"\$f\" ] && echo \"--- \$f\" && cat \"\$f\"; done"
run 08_persistence.txt "for f in /var/spool/cron/crontabs/* /var/spool/cron/tabs/* /var/spool/cron/*; do [ -f \"\$f\" ] && echo \"--- \$f\" && cat \"\$f\"; done 2>/dev/null"
run 08_persistence.txt "cat /etc/rc.local 2>/dev/null"
run 08_persistence.txt "cat /etc/ld.so.preload 2>/dev/null && echo '[!] ld.so.preload exists - check it'"
run 08_persistence.txt "ls -la /etc/profile.d/"
run 08_persistence.txt "for d in /root \$(awk -F: '\$3>=1000 {print \$6}' /etc/passwd); do for f in .bashrc .bash_profile .profile; do [ -f \"\$d/\$f\" ] && grep -HnE 'curl|wget|nc |ncat|bash -i|/dev/tcp|base64|python|perl' \"\$d/\$f\"; done; done"

# ---------- 09 file checks ----------
run 09_files.txt "find / -xdev -perm -4000 -type f 2>/dev/null"
run 09_files.txt "find / -xdev -perm -2000 -type f 2>/dev/null"
run 09_files.txt "find /etc -xdev -perm -o+w -type f 2>/dev/null"
run 09_files.txt "ls -la /tmp /var/tmp /dev/shm"
run 09_files.txt "find /etc /usr/bin /usr/sbin /bin /sbin -xdev -type f -newermt '-14 days' 2>/dev/null"
run 09_files.txt "ls -la /var/www /srv/www 2>/dev/null"

# ---------- 10 firewall ----------
have ufw       && run 10_firewall.txt "ufw status verbose"
have firewall-cmd && run 10_firewall.txt "firewall-cmd --state; firewall-cmd --list-all-zones"
have iptables  && run 10_firewall.txt "iptables -S"
have nft       && run 10_firewall.txt "nft list ruleset"

# ---------- 11 packages ----------
if have dpkg; then
  run 11_packages.txt "dpkg -l"
elif have rpm; then
  run 11_packages.txt "rpm -qa --last"
fi

# ---------- summary ----------
{
  echo "Host: $HOST    Collected: $TS"
  grep -h '^PRETTY_NAME' /etc/os-release
  echo "RAM: $(free -h | awk '/Mem:/ {print $2" total, "$7" available"}')"
  echo "CPUs: $(nproc)"
  echo
  echo "== Listening ports =="
  ss -tulpn 2>/dev/null | awk 'NR>1 {print $1, $5, $7}'
  echo
  echo "== UID 0 accounts =="
  awk -F: '$3==0 {print $1}' /etc/passwd
  echo
  echo "== Accounts with login shells =="
  awk -F: '$7 !~ /(nologin|false|sync|shutdown|halt)$/ {print $1}' /etc/passwd
  echo
  echo "== Empty passwords =="
  awk -F: '($2=="") {print $1}' /etc/shadow
  echo
  echo "== authorized_keys files =="
  for d in /root $(awk -F: '$3>=1000 {print $6}' /etc/passwd); do
    for f in "$d"/.ssh/authorized_keys*; do [ -f "$f" ] && echo "$f ($(grep -c . "$f") keys)"; done
  done
  [ -f /etc/ld.so.preload ] && echo && echo "[!] /etc/ld.so.preload EXISTS"
} > "$OUT/00_SUMMARY.txt" 2>&1

tar -czf "${OUT}.tar.gz" -C /root "$(basename "$OUT")"
chmod 600 "${OUT}.tar.gz"
echo "[+] Done. Read $OUT/00_SUMMARY.txt first."
echo "[+] Archive: ${OUT}.tar.gz"
