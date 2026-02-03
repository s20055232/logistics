---
name: skill-generator
description: Generates Claude Code skills from user descriptions. Use when creating new skills, converting documentation to skills, or scaffolding skill structure.
allowed-tools: Read, Write, Edit
---

# Skill Generator

## Purpose

Generate production-ready Claude Code skills from natural language descriptions, existing documentation, or code examples.

## When to Use

- User asks to "create a skill" or "generate a skill"
- Converting documentation into skill format
- Scaffolding new skill structure
- Creating skills from examples or patterns

## Process

1. **Understand Requirements**
   - Ask clarifying questions if needed:
     - What should the skill do?
     - What tools/APIs does it need?
     - Who is the target audience?
     - Are there existing docs or examples?

2. **Determine Skill Type**
   - Generator skill (creates content)
   - Integrator skill (connects to services)
   - Converter skill (transforms formats)
   - Or combination

3. **Generate SKILL.md**
   Follow this structure:

   ```markdown
   ---
   name: [skill-name]
   description: [What it does + when to use it - max 1024 chars]
   allowed-tools: [optional - list tools]
   ---

   # [Skill Name]

   ## Purpose
   [2-3 sentences]

   ## Process
   1. [Step 1]
   2. [Step 2]
   3. [Step 3]

   ## Examples
   [Concrete examples]

   ## Best Practices
   [Key guidelines]
   ```

4. **Create Directory Structure**
   ```
   .claude/skills/[skill-name]/
   ├── SKILL.md              # Main file (3-5KB max)
   ├── reference/            # Optional: Detailed docs
   │   └── [topic].md
   └── scripts/              # Optional: Utility scripts
       └── [script].py
   ```

5. **Apply Best Practices**
   - Use gerund form for name: `processing-pdfs`
   - Write description in third person
   - Keep SKILL.md under 500 lines
   - Use progressive disclosure for large content
   - Include concrete examples

6. **Review and Refine**
   - Check YAML frontmatter is valid
   - Verify description is specific
   - Ensure clear instructions
   - Test mental walkthrough

## Output Format

Always create:
1. **SKILL.md** - Main skill file
2. **Directory structure** - Planned reference/ scripts if needed
3. **Usage examples** - How to invoke the skill
4. **Next steps** - What user should do next

## Example Generation

If user says: "Create a skill for processing Excel files"

Generate:
```
.claude/skills/
├── excel-processor/
│   ├── SKILL.md
│   ├── reference/
│   │   ├── pandas-api.md
│   │   └── openpyxl-api.md
│   └── scripts/
│       ├── analyze.py
│       └── convert.py
```

SKILL.md includes:
- Name: `excel-processor`
- Description: "Processes Excel files including data extraction, format conversion, and analysis. Use when working with .xlsx files, spreadsheets, or tabular data."
- Process for reading, analyzing, converting Excel files
- Examples with pandas and openpyxl
- Links to reference docs for detailed API usage

## Quality Checklist

Before presenting to user, verify:
- [ ] YAML frontmatter is valid (starts with `---`)
- [ ] Name uses lowercase, numbers, hyphens only
- [ ] Description is specific and includes trigger terms
- [ ] Description is under 1024 characters
- [ ] Instructions are clear and numbered
- [ ] Examples are concrete and practical
- [ ] File paths use forward slashes
- [ ] Progressive disclosure used if content is large
- [ ] No reserved words (anthropic, claude) in name

## Common Patterns

### For Generator Skills
```
## Purpose
Generate [output type] from [input type]

## Process
1. Analyze [input]
2. Generate [output] using [best practices]
3. Validate output
4. Present to user
```

### For Integrator Skills
```
## Purpose
Integrate with [service name]

## Process
1. Understand user's goal
2. Prepare data for [service]
3. Call [service] API/tool
4. Handle response
5. Report results
```

### For Converter Skills
```
## Purpose
Convert [format A] to [format B]

## Process
1. Read [format A] file
2. Parse structure
3. Transform to [format B]
4. Write output
5. Verify conversion
```

## Progressive Disclosure Guidance

If skill will have >10KB of documentation:

**In SKILL.md:**
```markdown
## Quick Reference
[Brief overview and common tasks]

## Detailed Documentation
- **API Reference**: See [reference/api.md](reference/api.md)
- **Examples**: See [reference/examples.md](reference/examples.md)
- **Troubleshooting**: See [reference/troubleshooting.md](reference/troubleshooting.md)
```

Then create the reference files with detailed content.

## Troubleshooting

**If requirements are unclear:**
- Ask: "What specific task should this skill automate?"
- Ask: "What tools or APIs does it need to work with?"
- Ask: "Who will be using this skill?"

**If skill seems too complex:**
- Consider splitting into multiple focused skills
- Use progressive disclosure for documentation
- Create subtasks as separate skills

**If documentation is large:**
- Use progressive disclosure pattern
- Create reference/ directory
- Link to detailed docs from SKILL.md

## See Also

- [SKILL_REVIEWER.md](.claude/skills/skill-reviewer/SKILL.md) - Review skills for quality
- [SKILL_OPTIMIZER.md](.claude/skills/skill-optimizer/SKILL.md) - Optimize existing skills
- [SKILL_ARCHITECT.md](.claude/skills/skill-architect/SKILL.md) - Complete skill workflow

## Sources

Based on:
- [CLAUDE_SKILLS_ARCHITECTURE.md](../../../docs/CLAUDE_SKILLS_ARCHITECTURE.md)
- Official Anthropic skill documentation
