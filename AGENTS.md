# AGENTS

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: `npx openskills read <skill-name>` (run in your shell)
  - For multiple: `npx openskills read skill-one,skill-two`
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>openspec-new-change</name>
<description>Start a new OpenSpec change using the experimental artifact workflow. Use when creating a new feature, fix, or modification with a structured step-by-step approach.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-continue-change</name>
<description>Continue working on an OpenSpec change by creating the next artifact. Use to progress a change or create the next artifact.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-apply-change</name>
<description>Implement tasks from an OpenSpec change. Use when starting implementation, continuing implementation, or working through tasks.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-verify-change</name>
<description>Verify implementation matches change artifacts. Use to validate implementation completeness, correctness, and coherence before archiving.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-archive-change</name>
<description>Archive a completed change in the experimental workflow. Use when finalizing and archiving a change after implementation is complete.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-bulk-archive-change</name>
<description>Archive multiple completed changes at once. Use when archiving several parallel changes.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-explore</name>
<description>Enter explore mode as a thinking partner for exploring ideas, investigating problems, and clarifying requirements.</description>
<location>project</location>
</skill>

<skill>
<name>doc-coauthoring</name>
<description>Guide users through a structured workflow for co-authoring documentation, proposals, and technical specs.</description>
<location>project</location>
</skill>

<skill>
<name>md-formatting</name>
<description>Format and normalize Markdown documents for consistent readability and scannable key points.</description>
<location>project</location>
</skill>

<skill>
<name>design-changelog-maintainer</name>
<description>Maintain per-project design.md and changelog.md artifacts across project scopes.</description>
<location>project</location>
</skill>

<skill>
<name>frontend-design</name>
<description>Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.</description>
<location>project</location>
</skill>

<skill>
<name>internal-comms</name>
<description>A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever asked to write some sort of internal communications (status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, project updates, etc.).</description>
<location>project</location>
</skill>

<skill>
<name>web-artifacts-builder</name>
<description>Build elaborate multi-component web artifacts using React, Tailwind CSS, and shadcn/ui for complex UIs.</description>
<location>project</location>
</skill>

<skill>
<name>webapp-testing</name>
<description>Use Playwright-based workflows to test and verify local web application behavior.</description>
<location>project</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Create new skills, improve existing skills, and measure skill performance.</description>
<location>project</location>
</skill>

<skill>
<name>skill-update-assistant</name>
<description>Audit and refine proposed skill changes against iteration standards and structural rules.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-ff-change</name>
<description>Fast-forward through OpenSpec artifact creation when you want all artifacts quickly.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-sync-specs</name>
<description>Sync delta specs from a change back to main specs without archiving the change.</description>
<location>project</location>
</skill>

<skill>
<name>openspec-onboard</name>
<description>Guided onboarding for OpenSpec with a narrated end-to-end workflow cycle.</description>
<location>project</location>
</skill>

<skill>
<name>theme-factory</name>
<description>Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. There are 10 pre-set themes with colors/fonts that you can apply to any artifact that has been creating, or can generate a new theme on-the-fly.</description>
<location>project</location>
</skill>

<skill>
<name>babysit</name>
<description>Keep a PR merge-ready by triaging comments, resolving clear conflicts, and fixing CI in a loop.</description>
<location>global</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
