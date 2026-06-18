#!/usr/bin/env bash
# mock result: FA_FAIL_ISSUES に含まれる issue は failed、他は merge-ready。
issue="$1"
case " ${FA_FAIL_ISSUES:-} " in
  *" $issue "*) echo "failed" ;;
  *) echo "merge-ready" ;;
esac
