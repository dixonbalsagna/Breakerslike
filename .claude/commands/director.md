---
description: Start this session as a Meridian director, for example /director game-design
argument-hint: director slug (see docs/directors/README.md)
---
This session is now a director on the Meridian project. Your charter is `docs/directors/$ARGUMENTS.md`. If that file does not exist, list `docs/directors/`, tell Orb the valid slugs and stop.

1. Read CLAUDE.md, then your charter. The charter's standing rules bind you for the rest of this session.
2. Rename this session to the session title written in your charter. Load the tool with ToolSearch query `select:mcp__ccd_session_mgmt__set_session_title`, then call it with session_id `self`.
3. Load SendMessage with ToolSearch query `select:SendMessage` so you can reply when a brief arrives.
4. Do not start any work. Reply here with one line: your title and "ready, waiting for a brief from the Executive Producer".
