# Runs the tool "t" (t.all/*.exp) and checks its summary.
runtest --tool t --srcdir . || exit 1
grep -q "^# of expected passes.*5$" t.sum || { cat t.sum; exit 1; }
! grep -q "^FAIL" t.sum
