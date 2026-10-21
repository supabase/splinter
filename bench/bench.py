"""Benchmark splinter's lints on Supabase schemas, base vs head.

measure: loads a schema into a supabase/postgres database, either the synthetic
fixture at increasing sizes or a real project's migrations, then times every lint
(and the full union) from both checkouts in interleaved rounds, so runner drift
hits both sides equally. It also records a digest of each lint's sorted rows and
an EXPLAIN (ANALYZE, BUFFERS) of each lint.

fetch: downloads a project listed in projects/projects.json.

compare: turns one or more measure outputs into a markdown report and an exit code.

See bench/README.md.
"""

import argparse
import importlib.util
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURE = HERE / "fixture"
PROJECTS = HERE / "projects"
CHUNK = 200
DEFAULT_SIZES = "small=20,medium=300,large=2000"
EXPOSED_SCHEMAS = "public, app, billing, pgmq_public, graphql_public"
QUOTE = "$splinter_bench$"
MARK = "@@splinter_bench@@"

# Wall time regresses only when the medians differ by both bounds and no head
# round is as fast as any base round, so runner noise does not turn the check red.
REGRESSION_RATIO = 1.15
REGRESSION_MIN_MS = 3.0
# Buffer accesses do not depend on runner speed, so their bound is tighter.
BUFFERS_RATIO = 1.10
BUFFERS_MIN = 100
# A catalog scan repeated per outer row should be an index probe touching a few
# pages. More than this per loop means it reads a whole catalog or index each time.
REPEATED_SCAN_BLOCKS = 50

RUN_FN = """
create or replace function splinter_bench.run(q text, out ms float8, out n bigint, out digest text)
language plpgsql set search_path = '' as $fn$
declare t0 timestamptz;
begin
    t0 := pg_catalog.clock_timestamp();
    -- to_jsonb keeps column names, so renaming an output column changes the digest.
    execute pg_catalog.format(
        'select pg_catalog.count(*), pg_catalog.md5(coalesce(pg_catalog.string_agg(j::text, E''\\n'' order by j::text), '''')) from (select pg_catalog.to_jsonb(r) j from (%s) r) s',
        q
    ) into n, digest;
    ms := extract(epoch from pg_catalog.clock_timestamp() - t0) * 1000;
end
$fn$;
"""


def psql(sql, user, check=True, variables=None, single_transaction=False):
    args = ["psql", "-X", "-q", "-At", "-F", "|", "-U", user] + (
        ["--single-transaction"] if single_transaction else []
    )
    if check:
        args += ["-v", "ON_ERROR_STOP=1"]
    for k, v in (variables or {}).items():
        args += ["-v", f"{k}={v}"]
    proc = subprocess.run(args, input=sql, capture_output=True, text=True)
    if check and proc.returncode != 0:
        sys.exit(f"psql failed:\n{proc.stderr}")
    return proc


def load_lints(checkout):
    """Per-lint query text, compiled the way that checkout's bin/compile.py compiles it."""
    spec = importlib.util.spec_from_file_location(
        f"compile_{abs(hash(checkout))}", checkout / "bin" / "compile.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    lints = dict(mod.load_sql_files(checkout / "lints"))
    lints["all"] = "\nunion all\n".join(lints.values())
    return mod.HEADER, lints


def build_fixture(lo, hi, admin):
    if lo == 1:
        psql((PROJECTS / "services-stub.sql").read_text(), admin)
        psql((FIXTURE / "head.sql").read_text(), admin)
    chunk = (FIXTURE / "chunk.sql").read_text()
    for start in range(lo, hi + 1, CHUNK):
        psql(chunk, admin, variables={"lo": start, "hi": min(start + CHUNK - 1, hi)})
    psql((FIXTURE / "tail.sql").read_text(), admin)


def apply_project(migrations, user, admin):
    """Apply a project's migrations in order. A failing file is skipped and counted: real
    projects lean on services (auth, storage) that the bare image only partly provides.
    """
    psql((PROJECTS / "services-stub.sql").read_text(), admin)
    failed = []
    files = sorted(Path(migrations).glob("*.sql"))
    for f in files:
        # One transaction per file, so a failed migration leaves nothing half-applied.
        proc = psql(
            f.read_text(),
            user,
            check=False,
            variables={"ON_ERROR_STOP": 1},
            single_transaction=True,
        )
        if proc.returncode != 0:
            errors = [l for l in proc.stderr.splitlines() if "ERROR" in l] or ["failed"]
            failed.append(f"{f.name}: {errors[0].strip()}")
    psql("analyze;", admin, check=False)
    return {"migrations": len(files), "failed": failed}


def catalog_stats(user):
    out = psql(
        """
        select pg_catalog.json_build_object(
            'tables', (select count(*) from pg_catalog.pg_class where relkind in ('r', 'p')),
            'views', (select count(*) from pg_catalog.pg_class where relkind in ('v', 'm')),
            'indexes', (select count(*) from pg_catalog.pg_class where relkind = 'i'),
            'functions', (select count(*) from pg_catalog.pg_proc),
            'policies', (select count(*) from pg_catalog.pg_policy),
            'constraints', (select count(*) from pg_catalog.pg_constraint),
            'pg_depend', (select count(*) from pg_catalog.pg_depend)
        )
        """,
        user,
    ).stdout
    return json.loads(out)


def txn(header, body):
    return (
        "begin;\n"
        "set local search_path = '';\n"
        f"set local pgrst.db_schemas = '{EXPOSED_SCHEMAS}';\n"
        "set local statement_timeout = '120s';\n"
        f"{header}\n{body}\n"
        "rollback;\n"
    )


def round_script(sides, scenarios, flip):
    parts = []
    for scenario in scenarios:
        order = list(sides.items())
        if flip:
            order.reverse()
        for side, (header, lints) in order:
            if scenario in lints:
                parts.append(
                    txn(
                        header,
                        f"select '{side}', '{scenario}', ms, n, digest "
                        f"from splinter_bench.run({QUOTE}{lints[scenario]}{QUOTE});",
                    )
                )
    return "".join(parts)


def plan_script(sides, scenarios):
    parts = []
    for scenario in scenarios:
        for side, (header, lints) in sides.items():
            if scenario in lints:
                parts.append(f"\\echo {MARK}{side}|{scenario}\n")
                parts.append(
                    txn(
                        header,
                        f"explain (analyze, buffers, format json) {lints[scenario]};",
                    )
                )
    return "".join(parts)


def blocks(node):
    return node.get("Shared Hit Blocks", 0) + node.get("Shared Read Blocks", 0)


def repeated_scans(node, found):
    """Catalog scans that run once per outer row and read far more than an index probe."""
    children = node.get("Plans", [])
    own = blocks(node) - sum(blocks(c) for c in children)
    loops = node.get("Actual Loops", 1)
    rel = node.get("Relation Name", "")
    if rel.startswith("pg_") and loops > 1 and own / loops > REPEATED_SCAN_BLOCKS:
        found.append(
            f"{node['Node Type']} on {rel}"
            + (f" using {node['Index Name']}" if "Index Name" in node else "")
            + f": {loops} loops × {own / loops:.0f} blocks"
        )
    for c in children:
        repeated_scans(c, found)
    return found


def collect_plans(sides, scenarios, user, runs):
    # Buffer counts include catalog cache misses, so the first pass only warms the
    # session's caches and the second is the one recorded.
    script = plan_script(sides, scenarios)
    proc = psql(script.replace(MARK, "warmup") + script, user, check=False)
    for chunk in proc.stdout.split(MARK)[1:]:
        key, _, body = chunk.partition("\n")
        side, scenario = key.split("|")
        try:
            plan = json.loads(body)[0]["Plan"]
        except (json.JSONDecodeError, IndexError, KeyError):
            continue
        cell = runs[scenario][side]
        cell["buffers"] = blocks(plan)
        cell["repeated_scans"] = repeated_scans(plan, [])
    # A lint without a plan would otherwise skip the plan and buffer guards.
    for cells in runs.values():
        for cell in cells.values():
            if "buffers" not in cell and not cell["error"]:
                cell["error"] = "EXPLAIN failed: " + (
                    proc.stderr.strip()[-300:] or "no plan"
                )


def measure(args):
    sides = {"head": load_lints(Path(args.head).resolve())}
    if args.base:
        sides["base"] = load_lints(Path(args.base).resolve())
    scenarios = sorted(set().union(*(lints for _, lints in sides.values())))
    psql("create schema if not exists splinter_bench;" + RUN_FN, args.admin_user)

    if args.project:
        label, migrations = args.project.split("=", 1)
        t0 = time.monotonic()
        applied = apply_project(migrations, args.user, args.admin_user)
        print(
            f"[{label}] {applied['migrations'] - len(applied['failed'])}/{applied['migrations']} migrations "
            f"applied in {time.monotonic() - t0:.0f}s",
            file=sys.stderr,
        )
        stages = [(label, lambda: applied)]
    else:
        stages = []
        built = 0
        for size in args.sizes.split(","):
            label, n = size.split("=")

            def build(lo=built + 1, hi=int(n)):
                build_fixture(lo, hi, args.admin_user)
                return {"fixture_tables": hi}

            stages.append((label, build))
            built = int(n)

    result = {
        "target": args.target
        or (args.project.split("=")[0] if args.project else "synthetic"),
        "pg_version": psql("show server_version", args.user).stdout.strip(),
        "rounds": args.rounds,
        "sizes": {},
    }
    for label, build in stages:
        t0 = time.monotonic()
        source = build()
        print(
            f"[{label}] schema ready in {time.monotonic() - t0:.0f}s", file=sys.stderr
        )

        runs = {
            s: {
                side: {"ms": [], "n": None, "digest": None, "error": None}
                for side in sides
                if s in sides[side][1]
            }
            for s in scenarios
        }
        # Round 0 warms caches and is discarded.
        for r in range(args.rounds + 1):
            t0 = time.monotonic()
            proc = psql(
                round_script(sides, scenarios, flip=r % 2 == 1), args.user, check=False
            )
            seen = set()
            for line in proc.stdout.splitlines():
                side, scenario, ms, count, digest = line.split("|")
                seen.add((side, scenario))
                cell = runs[scenario][side]
                if r > 0:
                    cell["ms"].append(float(ms))
                if cell["digest"] not in (None, digest):
                    cell["error"] = "results differ between rounds"
                cell["n"], cell["digest"] = int(count), digest
            for scenario, cells in runs.items():
                for side, cell in cells.items():
                    if (side, scenario) not in seen:
                        cell["error"] = proc.stderr.strip()[-500:] or "no result"
            print(
                f"[{label}] round {r}/{args.rounds} in {time.monotonic() - t0:.1f}s",
                file=sys.stderr,
            )
        collect_plans(sides, scenarios, args.user, runs)
        result["sizes"][label] = {
            "source": source,
            "stats": catalog_stats(args.user),
            "scenarios": runs,
        }

    Path(args.out).write_text(json.dumps(result, indent=2))


def fetch(args):
    project = json.loads((PROJECTS / "projects.json").read_text())[args.name]
    dest = Path(args.dest)
    dest.mkdir(parents=True, exist_ok=True)
    git = lambda *a: subprocess.run(
        ["git", "-C", str(dest), *a], check=True, capture_output=True
    )
    git("init", "-q")
    git("remote", "add", "origin", f"https://github.com/{project['repo']}.git")
    git("sparse-checkout", "set", "--no-cone", project["migrations"])
    git("fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", project["sha"])
    git("checkout", "-q", "FETCH_HEAD")
    print(dest / project["migrations"])


def judge(base, head):
    """Every (status, detail) that applies to one scenario at one size; [("same", "")] if none.
    Statuses are independent so that waiving one (say, a results change) cannot hide another.
    """
    if head is None:
        return [("removed", "")]
    if head["error"]:
        return [("error", head["error"])]
    base_scans = (
        set()
        if base is None or base["error"]
        else {s.split(":")[0] for s in base.get("repeated_scans", [])}
    )
    found = []
    new_scans = [
        s for s in head.get("repeated_scans", []) if s.split(":")[0] not in base_scans
    ]
    if new_scans:
        found.append(("plan", "; ".join(new_scans)))
    if base is None:
        return found + [("new", "")]
    if base["error"]:
        return found + [("base-error", base["error"])]
    if (base["n"], base["digest"]) != (head["n"], head["digest"]):
        found.append(("results-changed", f"{base['n']} → {head['n']} rows"))
    hb, bb = head["buffers"], base["buffers"]
    if hb >= bb * BUFFERS_RATIO and hb - bb >= BUFFERS_MIN:
        found.append(("buffers", f"{bb:,} → {hb:,} blocks"))
    elif bb >= hb * BUFFERS_RATIO and bb - hb >= BUFFERS_MIN:
        found.append(("fewer-buffers", ""))
    b, h = statistics.median(base["ms"]), statistics.median(head["ms"])
    if (
        h >= b * REGRESSION_RATIO
        and h - b >= REGRESSION_MIN_MS
        and min(head["ms"]) > max(base["ms"])
    ):
        found.append(("slower", ""))
    elif (
        b >= h * REGRESSION_RATIO
        and b - h >= REGRESSION_MIN_MS
        and min(base["ms"]) > max(head["ms"])
    ):
        found.append(("faster", ""))
    return found or [("same", "")]


ICONS = {
    "same": "",
    "faster": "🚀 faster",
    "fewer-buffers": "🚀 fewer buffers",
    "slower": "🔴 slower",
    "buffers": "🔴 more buffers",
    "plan": "🔴 repeated catalog scan",
    "results-changed": "🔴 results changed",
    "error": "🔴 error",
    "base-error": "🔴 base error",
    "new": "🆕 new",
    "removed": "removed",
}
# Which label waives which status. Errors on head are never waived.
WAIVERS = {
    "slower": "perf",
    "buffers": "perf",
    "plan": "perf",
    "base-error": "perf",
    "results-changed": "results",
}


def fmt_ms(cell):
    if not cell or not cell["ms"]:
        return "–"
    ms = cell["ms"]
    return f"{statistics.median(ms):,.1f} ({min(ms):,.1f}–{max(ms):,.1f})"


def fmt_buf(cell):
    return f"{cell['buffers']:,}" if cell and cell.get("buffers") is not None else "–"


def describe(size):
    st, src = size["stats"], size["source"]
    what = (
        f"{src['fixture_tables']} fixture tables"
        if "fixture_tables" in src
        else f"{src['migrations'] - len(src['failed'])}/{src['migrations']} migrations applied"
    )
    return (
        f"{what}: {st['tables']} tables, {st['views']} views, {st['indexes']} indexes, "
        f"{st['functions']} functions, {st['policies']} policies, {st['pg_depend']:,} pg_depend rows"
    )


def compare(args):
    results = [json.loads(Path(p).read_text()) for p in args.results]
    has_base = any(
        "base" in cells
        for d in results
        for s in d["sizes"].values()
        for cells in s["scenarios"].values()
    )
    failures = {"perf": [], "results": [], "error": []}
    lines = [
        "<!-- splinter-bench -->\n## splinter lint benchmark\n",
        f"supabase/postgres {results[0]['pg_version']}, median (min–max) of {results[0]['rounds']} interleaved rounds per side. "
        f"Fails when a lint's rows change (count + digest of sorted rows), it errors, its plan gains a catalog scan "
        f"repeated per row (>{REPEATED_SCAN_BLOCKS} blocks per loop), it reads ≥{BUFFERS_RATIO - 1:.0%} and ≥{BUFFERS_MIN} more buffers, "
        f"or its median is ≥{REGRESSION_RATIO - 1:.0%} and ≥{REGRESSION_MIN_MS:g} ms slower with every head round slower than every base round.\n",
    ]
    header = (
        "| lint | rows | base ms | head ms | Δ | buffers | |\n|---|--:|--:|--:|--:|--:|---|"
        if has_base
        else "| lint | rows | ms | buffers | |\n|---|--:|--:|--:|---|"
    )
    for data in results:
        for label, size in data["sizes"].items():
            title = (
                f"{data['target']} / {label}"
                if data["target"] == "synthetic"
                else data["target"]
            )
            lines.append(f"\n### {title}\n{describe(size)}\n")
            rows, flagged = [], []
            scenarios = size["scenarios"]
            for name in sorted(scenarios, key=lambda s: (s != "all", s)):
                base, head = scenarios[name].get("base"), scenarios[name].get("head")
                key = f"{title}/{name}"
                if not has_base:
                    status = (
                        "error"
                        if head["error"]
                        else ("plan" if head.get("repeated_scans") else "same")
                    )
                    detail = head["error"] or "; ".join(head.get("repeated_scans", []))
                    if head["error"]:
                        failures["error"].append(key)
                    row = f"| `{name}` | {head['n'] if head['n'] is not None else '–'} | {fmt_ms(head)} | {fmt_buf(head)} | {ICONS[status]} {detail} |"
                    rows.append(row)
                    continue
                verdicts = judge(base, head)
                delta = "–"
                if (
                    base
                    and head
                    and base["ms"]
                    and head["ms"]
                    and statistics.median(base["ms"])
                ):
                    b, h = statistics.median(base["ms"]), statistics.median(head["ms"])
                    delta = f"{(h - b) / b:+.0%}"
                buf = (
                    f"{fmt_buf(base)} → {fmt_buf(head)}"
                    if base and head and base.get("buffers") != head.get("buffers")
                    else fmt_buf(head or base)
                )
                row = (
                    f"| `{name}` | {head['n'] if head and head['n'] is not None else '–'} | {fmt_ms(base)} | "
                    f"{fmt_ms(head)} | {delta} | {buf} | "
                    + "<br>".join(f"{ICONS[s]} {d}".strip() for s, d in verdicts)
                    + " |"
                )
                if verdicts != [("same", "")] or name == "all":
                    flagged.append(row)
                for status, _ in verdicts:
                    if status == "error":
                        failures["error"].append(key)
                    elif status in WAIVERS and key not in failures[WAIVERS[status]]:
                        failures[WAIVERS[status]].append(key)
            if has_base:
                unchanged = len(scenarios) - len(flagged)
                lines += [header, *flagged, ""]
                if unchanged:
                    lines.append(
                        f"{unchanged} lints within noise (rows identical, time and buffers inside the bounds above).\n"
                    )
            else:
                lines += [header, *rows]
            if size["source"].get("failed"):
                lines.append(
                    f"\n<details><summary>{len(size['source']['failed'])} migrations failed to apply</summary>\n\n"
                    + "\n".join(f"- `{f}`" for f in size["source"]["failed"])
                    + "\n</details>\n"
                )
    blocking = []
    if failures["error"]:
        blocking.append(f"lints failed on head: {', '.join(failures['error'])}")
    if failures["results"] and not args.accept_results:
        blocking.append(
            f"results changed: {', '.join(failures['results'])} (add the `lint-results-changed` label if intended)"
        )
    if failures["perf"] and not args.accept_perf:
        blocking.append(
            f"performance: {', '.join(failures['perf'])} (add the `perf-accepted` label if intended)"
        )
    lines.insert(
        1,
        "**Verdict:** "
        + ("🔴 " + "; ".join(blocking) if blocking else "✅ no regression")
        + "\n",
    )
    report = "\n".join(lines) + "\n"
    if args.markdown:
        Path(args.markdown).write_text(report)
    print(report)
    return 1 if blocking else 0


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser(
        "measure",
        help="load a schema and time the lints (connects with the PG* env vars)",
    )
    m.add_argument(
        "--head", default=".", help="checkout whose lints are measured (default: .)"
    )
    m.add_argument(
        "--base", help="checkout to compare against; omit for absolute numbers only"
    )
    m.add_argument(
        "--sizes",
        default=DEFAULT_SIZES,
        help=f"synthetic fixture, label=n_tables ascending (default: {DEFAULT_SIZES})",
    )
    m.add_argument(
        "--project",
        help="label=path/to/migrations: apply a real project's migrations instead of the fixture",
    )
    m.add_argument(
        "--target",
        help="name of this run in the report (default: synthetic or the project label)",
    )
    m.add_argument("--rounds", type=int, default=5)
    m.add_argument("--user", default="postgres")
    m.add_argument("--admin-user", default="supabase_admin")
    m.add_argument("--out", default="bench-results.json")
    f = sub.add_parser(
        "fetch",
        help="download a project from projects/projects.json at its pinned commit",
    )
    f.add_argument("name")
    f.add_argument("--dest", required=True)
    c = sub.add_parser(
        "compare", help="report on measure outputs; exits 1 on a regression"
    )
    c.add_argument("results", nargs="+")
    c.add_argument("--markdown", help="also write the report here")
    c.add_argument("--accept-perf", action="store_true")
    c.add_argument("--accept-results", action="store_true")
    args = parser.parse_args()
    os.environ.setdefault("PGDATABASE", "postgres")
    if args.cmd == "measure":
        measure(args)
    elif args.cmd == "fetch":
        fetch(args)
    else:
        sys.exit(compare(args))


if __name__ == "__main__":
    main()
