#!/usr/bin/env bash
# Persistent ledger, bash + standard utilities only. See FOLLOWUPS-FORMAT.md.
set -eu
command="${1:-}"; [ $# -gt 0 ] && shift
root=""; id=""; source_slug=""; task="-"; day=""; body=""; files=()
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || { echo 'forge-followups: invalid arguments' >&2; exit 6; }
  case "$1" in
    --root) root="$2";; --id) id="$2";; --source) source_slug="$2";;
    --task) task="$2";; --date) day="$2";; --text) body="$2";; --file) files+=("$2");;
    *) echo 'forge-followups: invalid arguments' >&2; exit 6;;
  esac
  shift 2
done
case "$command" in add|collect|take|dismiss|list) ;; *) echo 'forge-followups: expected add, collect, take, dismiss or list' >&2; exit 6;; esac
[ -n "$root" ] || root="$(bash "$(dirname "$0")/resolve-forge-root.sh")"
[ -n "$root" ] || root=.forge
ledger="$root/followups.md"
if [ -L "$ledger" ] || { [ -e "$ledger" ] && [ ! -f "$ledger" ]; }; then echo 'forge-followups: ledger is not a regular file' >&2; exit 6; fi
work="$(mktemp -d "${TMPDIR:-/tmp}/forge-followups.XXXXXX")"
trap 'rm -rf "$work"' EXIT
: > "$work/existing"
[ ! -f "$ledger" ] || cp "$ledger" "$work/existing"
if [ "$command" = add ]; then
  case "$body" in *'<!-- followup:'*) echo 'forge-followups: text must not contain a followup marker' >&2; exit 6;; esac
  [ -n "$id" ] || id="fu-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
  [ -n "$day" ] || day="$(date +%F)"
  printf '<!-- followup: %s | source: %s | task: %s | date: %s | status: open | taken: - -->\n%s\n' "$id" "$source_slug" "$task" "$day" "$body" > "$work/add"
  files+=("$work/add")
fi
if [ "$command" = collect ] && [ "${#files[@]}" -eq 0 ]; then echo 'forge-followups: collect requires --file' >&2; exit 6; fi
# Pass arbitrary text through files/environment, never awk -v escape processing.
export FU_COMMAND="$command" FU_ID="$id" FU_TASK="$task"
if ! awk '
function fail(s) { print "forge-followups: " s > "/dev/stderr"; bad=1; exit 6 }
function trim(s) { sub(/^[ \t\r\n]+/,"",s); sub(/[ \t\r\n]+$/,"",s); return s }
function positive(s) { return s ~ /^[1-9][0-9]*$/ }
function flush(  b) {
 if(cur=="") return
 b=trim(body); if(b=="") fail("empty followup body")
 if(cur in seen) { if(src[cur]!=cs || tasks[cur]!=ct || dates[cur]!=cd) fail("followup identity conflict") }
 else { order[++n]=cur; seen[cur]=1; src[cur]=cs; tasks[cur]=ct; dates[cur]=cd; states[cur]=cst; taken[cur]=ck; bodies[cur]=b }
 cur=""; body=""
}
FNR==1 { flush() }
{
 gsub(/\r/, "")
 if(index($0,"<!-- followup:")) {
  flush()
  if(split($0,a," \\| ")!=6 || a[1] !~ /^<!-- followup: fu-[0-9a-f]+$/ || length(a[1])!=30 || a[2] !~ /^source: [^[:space:]|<>\/\\]+$/ || a[3] !~ /^task: / || a[4] !~ /^date: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ || a[5] !~ /^status: (open|taken|dismissed)$/ || a[6] !~ /^taken: .* -->$/) fail("malformed followup marker")
  cur=substr(a[1],16); cs=substr(a[2],9); ct=substr(a[3],7); cd=substr(a[4],7); cst=substr(a[5],9); ck=substr(a[6],8,length(a[6])-11)
  if(cs ~ /^\./ || index(cs,"..")) fail("malformed followup marker")
  if((ct!="-" && !positive(ct)) || (ck!="-" && !positive(ck)) || ((cst=="taken") != (ck!="-"))) fail("malformed followup marker")
 } else if(cur!="") body=body $0 "\n"
}
END {
 if(bad) exit 6
 flush()
 cmd=ENVIRON["FU_COMMAND"]; id=ENVIRON["FU_ID"]; task=ENVIRON["FU_TASK"]
 if(cmd=="take" || cmd=="dismiss") {
  if(!(id in seen)) fail("unknown followup id")
  if(cmd=="take" && !positive(task)) fail("take requires positive task")
  st=(cmd=="take" ? "taken" : "dismissed")
  if(states[id]!="open" && (states[id]!=st || (st=="taken" && taken[id]!=task))) fail("terminal followup state")
  states[id]=st; taken[id]=(st=="taken" ? task : "-")
 }
 if(n) {
  printf "# Follow-ups\n\n"
  for(i=1;i<=n;i++) { k=order[i]; if(i>1) printf "\n"; printf "<!-- followup: %s | source: %s | task: %s | date: %s | status: %s | taken: %s -->\n%s\n",k,src[k],tasks[k],dates[k],states[k],taken[k],bodies[k] }
 }
}' "$work/existing" ${files[@]+"${files[@]}"} > "$work/result"; then exit 6; fi
if [ "$command" = list ]; then cat "$work/existing"; exit 0; fi
if [ -s "$work/result" ] && ! cmp -s "$work/result" "$work/existing"; then
  mkdir -p "$root"
  stage="$(mktemp "$root/.followups.XXXXXX")"
  if ! cp "$work/result" "$stage" || ! mv "$stage" "$ledger"; then rm -f "$stage"; exit 6; fi
fi
[ "$command" != add ] || printf '%s\n' "$id"
