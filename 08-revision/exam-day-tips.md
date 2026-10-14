# Exam-Day Tips

## Before the day

- Re-read the **official study guide** page for DP-800 — confirm the current skills outline and any changes.
- Try the **exam sandbox** (linked from the study guide) so the interface is familiar.
- If English isn't your first language and the exam isn't available in yours, you can request **extra time** (see the study guide).
- Online exam: test your system, webcam and room requirements in advance.

## Reading questions

1. **Find the requirement words:** *minimize cost*, *least administrative effort*, *without application changes*, *most secure*, *near real time*. They decide between otherwise-correct answers.
2. **Identify the platform:** SQL Server 2025, Azure SQL Database, Managed Instance or Fabric — feature availability differs (preview vs GA).
3. **Eliminate** clearly wrong options first; usually two remain.
4. **Prefer built-in, managed, passwordless, least-privilege** answers when two options both work.
5. For code questions, check details: `JSON_VALUE` vs `JSON_QUERY`, `ORDER BY distance` only with `WITH APPROXIMATE`, `ROWS` vs `RANGE`, `DENY` beats `GRANT`.

## Classic traps

| Trap | Remember |
|---|---|
| DDM as "encryption" | DDM only masks output |
| `NOT IN` with NULLs | Use `NOT EXISTS` |
| `TOP_N` in `VECTOR_SEARCH` | Deprecated; use `SELECT TOP (N) WITH APPROXIMATE` |
| Vector index on < 100 rows | Fails; use exact search |
| Index metric ≠ query metric | ANN index not used |
| Calling AI endpoints in triggers | Usually wrong for scale — prefer async (Functions/CT) |
| Distance vs similarity | Distance: smaller is closer; similarity: higher is closer |
| `JSON_VALUE` for long text | 4,000-char limit — use `OPENJSON … nvarchar(max)` |
| Over-privileged AI agents | Read-only, least privilege, minimal tools |

## Time management

- Don't get stuck: **mark for review** and move on.
- Case studies can be long — read the **question first**, then search the case for the relevant facts.
- Leave a few minutes to revisit marked questions.

## After the exam

- Pass: link your certification to your Microsoft Learn profile and note the **annual renewal** (free online assessment).
- Not yet: the score report shows performance by domain — focus there, redo the related labs, and rebook.
