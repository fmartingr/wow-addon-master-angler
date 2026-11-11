#!/usr/bin/env bash
set -euo pipefail

report="${1:-luacov.report.out}"
min="${LUA_COVERAGE_MIN:-80}"

awk -v min="$min" '
	/^Summary/ { summary = 1 }
	!summary { next }
	$1 ~ /^MasterAngler\// { hits += $2; missed += $3 }
	END {
		if (hits + missed == 0) { print "Coverage: no logic files in the report"; exit 1 }
		cov = 100 * hits / (hits + missed)
		printf "Coverage: %.2f%% (min %s%%)\n", cov, min
		exit (cov < min)
	}
' "$report"
