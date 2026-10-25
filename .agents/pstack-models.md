# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit the subagent `model`). Alias entries in a panel list still count toward its fan-out.
# budget: medium (high)
feature, refactoring: opencode-go/deepseek-v4.1-flash
bug-fix: opencode-go/deepseek-v4.1-flash
perf-issue: opencode-go/deepseek-v4.1-flash
hillclimb: opencode-go/deepseek-v4.1-flash
judgment and prose: claude-code/claude-sonnet-5-5
hardest tasks: claude-code/claude-sonnet-5-5
how explorer: opencode-go/deepseek-v4.1-flash
how explainer: claude-code/claude-sonnet-5-5
why investigators: opencode-go/deepseek-v4.1-flash
why synthesizer: claude-code/claude-sonnet-5-5
reflect tooling: opencode-go/deepseek-v4.1-flash
reflect judgment, divergent, synthesizer: claude-code/claude-sonnet-5-5
arena runners: opencode-go/muse-spark-1.3-contributor, opencode-go/deepseek-v4.1-flash, claude-code/claude-sonnet-5-5
arena cross-judge pool: opencode-go/muse-spark-1.3-contributor, opencode-go/deepseek-v4.1-flash, claude-code/claude-sonnet-5-5
swarm workers: opencode-go/deepseek-v4.1-flash
architect runners: opencode-go/muse-spark-1.3-contributor, opencode-go/deepseek-v4.1-flash, claude-code/claude-sonnet-5-5
interrogate reviewers: opencode-go/muse-spark-1.3-contributor, opencode-go/deepseek-v4.1-flash, claude-code/claude-sonnet-5-5
