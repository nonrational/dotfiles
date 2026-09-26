---
id: trans-02
type: transformation
status: approved
source_commit: c8fa24c
---

## input

It caused an immediate uproar in developer communities. The idea of an AI unilaterally rewriting a low-level systems programming language runtime feels inherently unsettling. But here is the hard truth: very soon, if you run tools like Claude locally on your machine, it will be executing on that very Rust rewrite. Like it or not, we are being forced to become users of AI-authored infrastructure.

## task

Flatten the op-ed register in this paragraph -- cut the throat-clearing announcement ('here is the hard truth'), the inflated reaction ('immediate uproar', 'inherently unsettling'), and the overstated stakes ('forced to become') -- while keeping the same claim.

## reference

Developer communities did not take it well, and an AI rewriting a low-level runtime out from under everyone is an unsettling thing to sit with. But very soon, if you run tools like Claude locally, you will be executing on that very Rust rewrite. Like it or not, we are becoming users of AI-authored infrastructure.

## rubric

```yaml
violation_fixed: Is 'here is the hard truth' (throat-clearing) gone? Is the dramatized reaction ('immediate uproar... feels inherently unsettling') replaced with a plainer claim? Is 'forced to become' softened to 'becoming'?
no_new_violation: No em-dash, no 'just', no new grandiosity introduced while flattening.
voice_match: "Subjective -- the paragraph should keep some of its color: the reference holds on to one plain word for the discomfort and one wry aside, in its own words. A rewrite that scrubs every trace of feeling along with the op-ed tells has over-corrected (see det-02 for what over-correction looks like). No particular word from the reference is required."
```

## note

SKILL.md doesn't name 'op-ed tells' as a rule verbatim; the closest textual anchors are baseline 'No throat-clearing' and prohibition 'No grandiosity. Don't grant a machine a stake it cannot have.' Accept either as the cited rule.
