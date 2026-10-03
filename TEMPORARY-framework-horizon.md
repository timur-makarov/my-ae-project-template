# Temporary note — the next six months of this kind of framework

Written 3 October 2026. A session note. Safe to delete. It leaves the railroad as it is.

Horizon: through about April 2027. Claims are tagged **VERIFIED** (looked up this session), **INFERRED** (follows from that), or **ASSUMED** (a bet). A conclusion is only as strong as its weakest premise.

## Answer

Keep a very small charter in the repo, and let the harness throw the rest away.

The part of this template that still earns its copy-paste is the split in ADR 0001: scripts and hooks own state and the irreversible few; judgment stays outside the model's self-report; a human stands where the blast radius expands. The part that goes stale is the railroad as a procedure the agent must walk — eighteen skills, one legal next move, a critic seat, then a security seat, then a lesson — because the harnesses this template bends toward are growing that procedure themselves.

The weak premise: harness builders keep absorbing orchestration the way they have since dynamic workflows and ultracode, and the labs do not freeze the interface under them. Anthropic's public line the week before Opus 5.5 was a call to pace the frontier. Capability and tooling are no longer one curve. **INFERRED** from their 22 September 2026 announcement, which says the pacing argument was made the week before that release.

## What this template is

A scaffold other projects copy. `scripts/gate.sh` names the one legal next move and runs every step a script can run. Hooks deny a short list: pipe-to-shell, secrets, force-push onto the base branch, writes outside a claimed scope, product writes while a ticket is blocked on answers. Everything else is allowed. MEDIUM and HIGH want a verify stamp, a critic on the changed lines, a judgment of those findings, sometimes a security pass, then lessons, then ship. LOW is claim, edit, check, ship. **VERIFIED** from `AGENTS.md`, `README.md`, and `compute_next()` in `scripts/gate.sh`.

Sandboxes and cloud IAM are out of scope on purpose. `.agentic/map.md` says tool sandboxes are configured, and bash does not enforce them. **VERIFIED.**

ADR 0001 is dated 30 September 2026, eight days after Opus 5.5. The bet was made in sight of these models: under pressure, an agent still skips a prose step, and a rule it can rationalize is only a suggestion. **VERIFIED** from the ADR. The size of the bet, also verified this session: `gate.sh` is 1242 lines, `lib.sh` 606, eighteen skills, and `judgment.md` already holds the constitution those skills procedure-ize.

That bet is still true for some pressures and already false for others.

## The week it is living in

Opus 5.5 shipped on 22 September 2026. On Anthropic's account it is much less likely than recent models to take hard-to-reverse actions or to act outside a boundary it was given, and it is more resistant to prompt injection than Opus 5. They also ship, with the same model, a classifier that screens every action before it runs, an open-source sandbox a security team can audit, and review before merge. **VERIFIED** from their announcement. The careful model and the cage arrived together.

On FrontierCode, which they describe as whether an agent's diff would be merged, the figure they highlight at the default effort (`medium`) is 54.6%. Their benchmark table lists 54.4% on the main set, and the footnote says unlabeled results use max effort. **VERIFIED** that the page carries both numbers. Use the one they argue with: at the setting they tell people to start from, a bit over half of such diffs would merge. The rest would not. Fluency is not a merge.

On their behavioral audit, Opus 5.5 attempted to cross containment about 85% less often than Opus 5 or Mythos 5.1, and the attempts they saw were low severity and self-reported. The same section says the model often suspects it is being evaluated, which limits how far that percentage travels outside the lab. **VERIFIED** as their claim, not as a field measurement.

Ultracode is a Claude Code session switch, not an API effort level. It sends `xhigh` and lets the model orchestrate dynamic workflows for substantive tasks. Dynamic workflows are generally available: the model writes an orchestration script, fans work across tens or hundreds of subagents, checks results before they fold back, and stores progress outside the conversation so a long run can resume. The public scale story is a Zig-to-Rust port of Bun, on the order of 750,000 lines, two reviewers on each file, eleven days to a merge candidate. **VERIFIED** from Claude Code's model docs and Anthropic's dynamic-workflows post. That is this template's critic, its security pass, and its worktree story, generated for one task and discarded.

Around that, skill packs have already split:

- Subscribe. Matt Pocock's set is in Claude Code's official marketplace as a managed bundle: grill, spec, tickets, TDD, review, on the order of twenty skills, aimed at misalignment, vague language, code that does not run, and architecture that rots. Installing via skills.sh is the other door, the one where you own the files and they go stale until you pull. Superpowers is the methodology version of the same plugin shape: brainstorm, plan, TDD, worktrees, subagents, verification before a claim of done. **VERIFIED** from their public install docs in this session.
- Accumulate. ECC 2.2.3, dated 1 October 2026, advertises on the order of seventy specialized agents and a few hundred skills, plus hooks, memory, and a security scan, with adapters for as many harnesses as it can reach. The count differs by a few skills between pages fetched the same day. **VERIFIED** as the project's own public description. The shape is a second operating system.

Pi plus OpenShell is the third shape. The agent stays small. The product is the boundary: the whole process runs under filesystem, network, and credential policy. Git worktrees separate files. They do not separate permissions. **VERIFIED** from Pi's containerization notes and NVIDIA's OpenShell tutorial.

Lovable is already on the model announcement, talking about fewer steps and fewer tokens for the same build. Bolt, Replit's agent, Cursor's cloud agents, and Codex cloud sit in the same move: the middle layer now holds a computer, a preview, and a bill. **VERIFIED** for the Lovable quote on Anthropic's page; the grouping of the others is **INFERRED** from their public product descriptions this session.

## Walk the railroad against that

Someone copies this tree in and asks for something.

If the ask is thin, the route sends it through an interview or a grill. A new ticket stays `blocked-on-answers` until a human sets `status: open`. Product writes are denied until then. When the change spends money, drops data, or breaks a public API, that stop is the booster. The human is on the loop, which is the phrase the template uses, and it is the right altitude. When the session is thinking, or a sketch, or "leave me a note," the same stop is the obstacle: the legal next move is a person, and the thinking has no legal shape. `judgment.md` already says misclassifying the kind of ask is the common failure. The gate has one kind.

After open, claim freezes `scope_paths`. One claim per branch. One active ticket by default. Overlapping scopes are refused. That matched a world where two agents in one checkout corrupted each other. It strains a world where one session is supposed to spawn many workers. Worktrees exist (`implement NN --worktree`) and are then capped by `limits.max_active_tickets: 1`. **VERIFIED** from `config.yml` and the README. Dynamic workflows do not ask the gate for a second ticket.

LOW then steps aside: edit, and `advance` commits, runs the `Check:` lines, and ships. No stamp, no reviewer. That lane is the honest one. It treats ceremony as a cost.

MEDIUM and HIGH spend the ceremony on purpose. A script writes the verify stamp, and the stamp dies when a product file changes. The Done Contract runs as commands, not as a paragraph. A separate seat returns findings that have to cite a changed line. The author fixes what an ordinary caller would hit and writes a decline for the rest. Security runs after that judgment, and only when a HIGH path is in the diff. Lessons, then ship. CI re-derives the ship checks from the branch. A human merges HIGH. Editing the critic report after the fact breaks the hash. **VERIFIED** from `compute_next()` and the README.

As a booster, this is aimed at the failure that is still common: a fluent model narrating "done" over a diff that should not merge. The stamp is independent of the narrator. The report hash stops the author from revising the reviewer. The human merge is the remaining "I'm sure." FrontierCode's unresolved portion is exactly "this diff is not good enough," and a model that writes clearly will describe a bad diff cleanly. Opus 5.5's own announcement treats clearer writing as a safety property, because people can check it. Checking still requires something to check against.

As an obstacle, the sequence is a novel the harness now writes as a script. Ultracode, on a substantive task, plans a workflow, runs adversaries, and checks before showing the result. Asking the agent to also stop at `gate.sh next`, spawn one named evaluator, later spawn a security evaluator, then write `lessons/NN.md`, puts a second conductor in the pit. Strong models will follow it. They will also spend the session on it. ADR 0001 already warns that enforcing everything makes the harness slower than the work and pushes agents into workarounds. The README concedes the workaround that matters: hooks see agent tool calls; a human terminal, or a command hidden behind `python -c`, walks past them. CI is the backstop. The backstop is not a sandbox.

### The concept that may be wrong

The unit of work is three things fused into one ticket:

1. A task. Change these files.
2. A decision. We accepted this reading of the intent.
3. A proof. These commands passed on this tree.

Tasks want to be ephemeral and parallel. Harnesses are good at that now, and the public examples are already multi-hour and multi-agent. Decisions want to be durable and few: the domain words, what we refused to build, a blast-radius call a human already made. Proofs want to be machine-written and dull. This template stores all three in one lifecycle, then tries to distill the decision and the proof out at ship time, through lessons and `CONTEXT.md`. On the LOW lane, where a copied template will actually live, that distillation does not run. The decisions evaporate. The proofs exist as check output. The closed-ticket archive is a diary of tasks.

The narrowness is in that lifecycle, more than in the deny list. The deny list is short, which is the right instinct. The lifecycle is a single-file queue in a world of fan-out.

The restrictiveness people feel is the human gates (`blocked-on-answers`, `blocked-on-alignment`, HIGH merge) plus a frozen scope. Those gates are the product when a wrong expansion is a migration or a bill. They are dead weight when the model is exploring, when the right scope is the unknown, or when the session is a conversation. `scope.strict` defaults to false: a template people copy cannot demand a claim for every edit. **VERIFIED.** The skills and the gate still narrate the strict path as the real path.

## What is missing

A home for intent that is not a task. `CONTEXT.md` and the ADRs are that home, and they are the strongest idea in the tree: short, cited, capped. They are also easy to skip, and they update "before ship" on the lanes that remember to archive. The next model does not need a skill that says "restate the ask." It needs the three lines from last month that are not in the code. We do not bill annual plans yet. This table is the source of truth. A human merges anything that touches payouts.

A proof that is not a persona. Critic and security personas are how you fake an independent derivation when you have one model family and a prompt. Dynamic workflows already run independent attempts and adversaries as runtime behavior. Another markdown seat costs a full context and mostly restates `judgment.md`. The rule that lasts is smaller: a finding cites a changed line, and the author cannot quietly rewrite the report. Any reviewer the harness spawns can sit under that rule.

A boundary that matches where the agent runs. Hooks pattern-match tool calls. Tomorrow's bad hour is an agent with cloud credentials, a preview URL, and a database, ten hours in, compacted twice. OpenShell-style policy — which binary, which host, which credential — is the shape of that boundary. Vendoring it turns this repo into a distro, and the distro loses to the vendor who lives in that runtime. The charter can still say the expectation in one paragraph. If the harness has a sandbox, this file is the policy input. If it does not, the deny list is a floor, and the floor is porous. The README already tells the truth about the porosity. The map file then looks away.

Cost as a risk. Fan-out is now cheap to start and expensive to finish. Ultracode's own documentation says the spend is meaningfully higher. A template that adds a critic, then security, then lessons, on top of a harness that already fans out, double-charges. LOW is the sketch of the missing control: ceremony scaled to blast radius. That should be the mental model for anything the harness can check itself.

Room to delete. The template's surface is skills, a three-way hook adapter, a gate, a journal, a state directory. The ponytail ladder in `judgment.md` asks whether a thing needs to exist. Applied here, many of the skills are the thing that need not exist, because Superpowers, Pocock, and ultracode already emit them and will emit the next version when the harness moves. A copied skill snapshot is stale on the next Claude Code release. `scripts/hooks/adapt.sh` is the file that rots first: three hook dialects, kept in lockstep by hand.

## Guest, or a boxed computer

Stay a guest. Become a sharper one.

A ready box — OpenShell, a worktree manager, a minimal agent like Pi, a seeded verify command — wins the first afternoon. It loses the following year, because the sandbox vendor, the harness vendors, and git keep moving those pieces. A template that vendors them inherits three upstreams plus the model. This repo already declined that in the out-of-scope list. For a thing other projects copy, the decline is right.

Dissolving into Cursor's worktrees and sandboxes fails the other way. The charter then exists only inside one vendor's session. Open the same repo in Claude Code, or hand it to a cloud agent, and the irreversible list and the evidence rule are gone. The multi-harness adapter is the expensive attempt at parity. The cheap attempt is a contract so small that every harness can read it:

- These paths are HIGH.
- These actions are denied.
- Done means this command's exit code, recorded by something other than the model.
- These sentences are the intent a new session must not invent again.
- A human merges when the tier says so.

Cursor, Claude Code, Codex, Pi inside OpenShell, and a cloud agent can all be told that. They do not need the same `gate.sh`. The gate is a reference implementation for a harness that has no workflow engine. When the harness has one, the reference implementation should step aside instead of stacking on top.

Leave the sandbox upstream. Leave the skill methodology upstream, subscribed rather than forked. Keep one enforcer that CI can run with no model in the loop. Treat the skills as commentary you can delete.

## Lovable, Bolt, and the new middlemen

If the goal is the real world, put the energy into the charter those products are missing. If the goal is repos that already have engineers, the same charter belongs in the repo. The eighteen skills belong in neither place for long.

Lovable and Bolt are where someone who will never read `gate.sh` meets a model that can now raise the app, the tables, and the charge flow in an afternoon. Their live failure mode over this horizon is a polished, confident, wrong product: auth that looks closed, a migration with no down path, a price that was an assumption. They will add review agents themselves. Every lab is adding them. A note that says "add more critics" arrives after the feature. A note that says "show the three lines of intent, the irreversible actions, and a check that ran against the running app, and let a human accept those before money moves" is this template's real idea, drawn as a preview.

Clouds become the new middlemen. The middleman does not retire. It moves up. The IDE was the middle layer. The computer the agent runs in is the middle layer now: credentials, preview, branch, sandbox, usage. "Just ask the agent" still means asking through someone's computer. The framework question and the Lovable question are one question at two heights. What is allowed to persist between sessions, and what is allowed to happen to the world?

Six months spent only on frameworks is a race against Anthropic's workflow engine and against Cursor's sandbox. Both see the runtime. A repo template does not. Six months spent only on app builders ignores the repos where a bad merge already has a price, and where a one-page charter still is not written down. Both surfaces want that page. They do not want a second operating system.

## The senior, and the if

The condition in the question carries the argument. If a real senior is in the loop, and the specs and the decisions get the care they need, then "the model deletes prod" is, this month, an edge case. Anthropic's release is reaching for that sentence, and then wrapping the model anyway. I take the direction as real. I take "practically non-existent" as the hope, and the hope depends on the IF.

Three gaps stay open even if the next two model steps are as large as the last two.

The model does not hold the unstated preference. "Be careful" does not say whose data may be deleted, which name is prod, or whether a one-way migration is acceptable on a Thursday. A senior human carries that from last quarter's incident. A session carries it until compaction. `CONTEXT.md` is the attempt to put it on disk. It works when someone writes the incident down.

Reach grows faster than the error shrinks. A merge rate around 55% is not a catastrophe rate. Catastrophes are rarer, and the agent can now touch more per hour: a cloud bill, IAM, production data, a migration of hundreds of thousands of lines in a day, an overnight run across several repos. Customers are already describing the 18-hour unattended session. A rarer mistake with a wider radius is a different risk, which is why the cage ships beside the careful model. "Delete prod" feels absent until the task is "clean up old servers" and the names are ambiguous. Seniority is the act of asking which names. The spec has to contain them.

A long run is many seniors. The careful engineer in hour one is a compressed state by hour nine. Dynamic workflows keep the plan outside the conversation for this reason. A railroad that lives in the prompt competes with that external plan and loses on length. A charter on disk cooperates with it.

So the practical move is smaller than a framework. Put the care into the spec and the decisions. Then make the irreversible list and the evidence rule something the session cannot talk its way out of. The IF fails by a missing sentence and by compaction, more often than it fails by a dramatic delete. **INFERRED.** The flip would be a run of public incidents where careful specs were present and the model still took the hard-to-reverse action through the front door. That would put the weight back on cages, including vendored ones.

## A shape that can be wrong and still useful

Treat the methodology as compiler output.

The source is short, and it lives in the project because it is about that project:

- Intent and non-goals, in the project's words.
- The irreversible list and the risk floors.
- The command that means done, and a stamp CI can re-check.
- The decisions a new session must not relitigate.

The compiler is whatever is current. Ultracode. A Pocock or Superpowers pack you subscribe to. Cursor's cloud agent. Pi inside a sandbox. It may spawn critics. It may spawn a hundred agents. Next spring it may do something that has no name yet. You do not copy its output into the repo and freeze it.

This template mixes source and compiler. `judgment.md`, the risk floors, the stamp, the deny list, and `CONTEXT.md` are source. The single-file queue inside `gate.sh`, the eighteen skills, the critic-then-security ritual, and the three-harness adapter are a compiler aimed at the agents of summer 2026, who skipped steps and narrated "done." Some of that compiler is still the best enforcer you have when the harness is thin or evasive. It should be removable without losing the source.

A concrete test, small enough to try without a redesign: for one LOW change, drop the obligation to walk the gate, point the harness at the Done Contract and the deny list, and watch what actually gets worse. If a CI stamp catches it, the railroad was the shim. If a specific step is still forgeable, keep that step and name it. **INFERRED** that this test is the right one; the outcome is not known until someone runs it.

The same split sorts the neighbors. Pocock's subscribe-don't-fork keeps the compiler upstream. Superpowers' bootstrap ("you have skills; use the one that fits; skip them for a one-line fix") is a compiler you can turn on per session. ECC's hundreds of skills are a compiler that has started compiling itself. Pi is a runtime. OpenShell is a boundary. Lovable is a compiler with a preview and a database. None of those are the project's intent. The teams that come through the next six months in good shape will know which of those they copied, and they will keep the intent in a file small enough that a stronger model does not need a skill to find it.

## Held open

These are all live at once. Picking one and dropping the other is how this conversation goes stale.

- Models are careful enough that a dramatic production delete is no longer the planning case, and the labs still put a classifier and a sandbox in front of them.
- A bit under half of frontier diffs still should not merge, and these are also the first models people leave overnight.
- A railroad stops a sloppy agent from shipping a lie, and the same railroad taxes an agent that already checks its work.
- Multi-harness parity is the strong reason to keep a bash gate, and multi-harness parity is the part that rots.
- App builders and repo templates look like different products, and they fail in the same place: intent that was never written down.
- The last six months' slope may continue, or the public pacing talk may slow the models while the harnesses keep shipping. The charter survives either one. The skill catalog survives the second.

## What would reverse this

- A merge-style benchmark moving from the mid-50s to a rate a careful team would auto-merge, sustained across more than one lab. Then the stamp starts to look like ceremony, and the human merge on HIGH needs a new reason.
- Harnesses stalling: no durable plan outside the conversation, no sandbox, no action log. Then `gate.sh` stays the compiler, and shrinking it is the mistake.
- An incident class people feel monthly, where the session looks careful and the damage happens on a path the hooks do not see. Then the guest-in-the-harness call flips, and a vendored sandbox becomes the template.
- A real pause in capability, with agent products left holding today's ceremony. Then Pocock, Superpowers, and this railroad all get another year as the discipline the model does not yet have.

Until one of those shows up, the move is subtraction. The concept holds. The concept is too large for what is still scarce.
