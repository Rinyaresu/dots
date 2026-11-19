from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

def replace(a, b):
    global s
    assert s.count(a) == 1, a
    s = s.replace(a, b)

# stderr goes to the setup unit journal, including from command substitutions.
# Only controlled values, not API strings, ever reach the log.
probe = r'''
reListObservation() {
    local rc="$1" status="${2: -3}" body="${2%???}" shape category state
    [[ "$status" =~ ^[0-9]{3}$ ]] || status=unknown
    if [[ -z "$body" ]]; then
        shape=empty
    else
        shape=$(printf '%s' "$body" | "$jq" -sr '
          if length != 1 then "not-single-json"
          elif (.[0]|type) != "object" then (.[0]|type)
          else "object:lists=" + (if (.[0]|has("lists")) then (.[0].lists|type) else "absent" end)
               + ":error=" + (.[0].error|type)
          end' 2>/dev/null) || shape=malformed-json
    fi
    case "$rc:$status:$shape" in
        [1-9]*:*) category=transport-error;;
        0:401:*|0:403:*) category=session-refused;;
        0:200:object:lists=array:*) category=expected-shape;;
        0:200:*) category=json-incompatible;;
        *) category=http-incompatible;;
    esac
    state=$(systemctl show pihole-ftl.service -p ActiveState -p SubState -p MainPID --value | paste -sd, -) || state=unknown
    printf 'META phase=lists rc=%s http=%s shape=%s class=%s ftl(sub,pid,active)=%s authenticated=%s\n' "$rc" "$status" "$shape" "$category" "$state" "${validSession:-false}" >&2
}
'''
replace('TestAPIAvailability() {', probe + '\nTestAPIAvailability() {')
replace('if [ -z "${chaos_api_list}" ]; then', 'if [ -z "${chaos_api_list}" ]; then\n        echo "META phase=preflight class=no-discovery" >&2')
replace('if [ "${chaos_api_list#;;}" != "${chaos_api_list}" ]; then', 'if [ "${chaos_api_list#;;}" != "${chaos_api_list}" ]; then\n        echo "META phase=preflight class=discovery-error" >&2')
for variable, marker in [('authResponse', '-w ">>%{http_code}"'), ('sessionResponse', '-X POST'), ('response', '-X GET')]:
    lines = [l for l in s.splitlines() if l.lstrip().startswith(variable + '=') and marker in l]
    assert len(lines) == 1
    original = lines[0]
    indent = original[:len(original)-len(original.lstrip())]
    new = original
    if variable == 'sessionResponse':
        new = new.replace(' -X POST ', ' -w "%{http_code}" -X POST ')
    new = indent + 'local diag_rc=0\n' + new + ' || diag_rc=$?'
    if variable == 'authResponse':
        new += '\n' + indent + 'local diag_http="${authResponse: -3}"; [[ "$diag_http" =~ ^[0-9]{3}$ ]] || diag_http=unknown\n' + indent + 'printf "META phase=preflight rc=%s http=%s\\n" "$diag_rc" "$diag_http" >&2\n' + indent + '(exit "$diag_rc")'
    elif variable == 'sessionResponse':
        new += '\n' + indent + 'local diag_http="${sessionResponse: -3}"; [[ "$diag_http" =~ ^[0-9]{3}$ ]] || diag_http=unknown\n' + indent + 'sessionResponse="${sessionResponse%???}"\n' + indent + 'printf "META phase=login rc=%s http=%s\\n" "$diag_rc" "$diag_http" >&2\n' + indent + '(exit "$diag_rc")'
    else:
        new += '\n' + indent + 'if [[ "$1" == lists\\?* ]]; then reListObservation "$diag_rc" "$response"; fi\n' + indent + '(exit "$diag_rc")'
    replace(original, new)
replace('    if [ "${1}" = "verbose" ]; then\n        if [ "${validSession}" = true ]; then', '    if [ "${validSession}" = true ]; then\n        echo "META phase=login class=accepted" >&2\n    else\n        echo "META phase=login class=rejected" >&2\n    fi\n    if [ "${1}" = "verbose" ]; then\n        if [ "${validSession}" = true ]; then')
p.write_text(s)
