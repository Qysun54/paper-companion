# paper-companion

**English** | [简体中文](README.zh-CN.md)（check the attached md）

A skill for AI coding assistants. Give it a paper, a technical document, or an open-source project. It breaks the content down to first principles, retells it in plain language, and then tells you **what it means for your own work**.

> **Language note.** The skill's rules (`SKILL.md`) are written in Chinese, and the reports it produces are in Chinese. The phrases you say to it, shown below, are Chinese too. Only this README has been translated.

It is not a paper summarizer. A summary tells you what the paper says. This does three more things:

- **It explains until an outsider could repeat it.** Context first, example first, one number per finding, everything else in an appendix table.
- **It judges relevance against you.** What you do, what project you are on, and what topics you follow are asked once, on first use. Every report then rates the paper as strongly relevant, weakly relevant, or barely relevant to you.
- **It does not make things up.** Prior work it mentions is checked first. Anything it is unsure about is marked as such. Key conclusions cite where they come from. Questions the paper cannot answer are answered with "the paper does not say".

## Install

You need an AI coding tool that can read and write files. The steps below use Claude Code.

**Step 1: pick one fixed folder.** You will always use the skill from this folder (see "Keep using the same folder" below).

**Step 2: put this repo into that folder's `.claude/skills/paper-companion/`.**

```bash
git clone https://github.com/Qysun54/paper-companion.git .claude/skills/paper-companion
```

Or give the repo URL to your AI and ask it to install this skill into the current folder.

**Step 3: reopen Claude Code and give it a paper.** A PDF path or a link both work. Say "读一下这篇" (read this one).

**So far this has only been fully tested on Claude Code. Usage with other tools is for reference only.** For other tools (Codex, Cursor, and so on), put the whole folder wherever that tool reads skills from. If the tool has no skill mechanism, tell the AI to follow the `SKILL.md` in this folder.

You **do not need to edit `SKILL.md`**. Everything personal is asked on first use and saved by the skill itself.

## What it asks on first use

The first time it is triggered, it asks four questions before reading anything:

1. **What do you do?** One sentence. This is the only required answer.
2. **What project are you working on right now?** The more specific, the better the relevance judgment. You can skip it.
3. **Which topics do you want to keep following?** Each topic becomes a "topic pack". Everything you read or plan to read is grouped by pack. One or two is enough to start.
4. **Whose questions do you want to be ready for after reading?** Three roles by default: a technical colleague, a peer, and your manager. You can add, remove, or rename them.

The answers are saved to `个人设定.md` in your own folder and never enter this repo. To change them later, say **"改一下我的设定"** (change my settings). You do not need to edit the file by hand.

## Keep using the same folder

Your settings, reports, knowledge map, and excerpts are all stored in the folder you were in on first use.

**If you switch folders, it asks for your settings again, and nothing you have read carries over.** Pick one folder and stay there.

Over time that folder will contain the following (all of it lives in your own folder, not in this repo):

| File | What it is |
| --- | --- |
| `个人设定.md` | Your answers to the four questions |
| `papers/` | One file per report |
| `shorts/` | One short per report (a web page, double-click to open) |
| `认知地图.md` | A map of how the things you have read relate, an index table, and a to-read list |
| `提问清单.md` | The questions each role would ask. You can replace them with real questions you have been asked |
| `摘录.md` | The sentences you highlighted |

## Features

| Feature | How to use it | Notes |
| --- | --- | --- |
| Deep read | Give a PDF or link and say "读一下这篇" | Papers, technical documents, and open-source projects |
| Knowledge map | Automatic | Updates the relation map, index table, and to-read list after every read |
| Read alongside earlier ones | Automatic | When you have read related material, the report adds a section on how they combine |
| Role Q&A | Automatic | The end of each report answers every question in `提问清单.md`. Unanswerable ones say so |
| Paper short | Automatic | Up to five scenes, one plain sentence each |
| Pack synthesis | Automatic | When a topic pack is fully read, it produces a map of positions and a combined Q&A |
| Highlight | Say "高亮:" followed by the sentence | Saved to `摘录.md`. It first checks that the sentence appears word for word in the source |
| Change settings | Say "改一下我的设定" | The question list and to-read groups update with it |
| Select-to-highlight | Say "帮我装上选中高亮" | **macOS only**, see the next section |

Before delivering each report, it starts a separate AI that has not read the source and has it read the report as a "stranger", to catch anything an outsider would not understand. This makes a read slower than a plain summary. That is intentional.

## macOS only: select-to-highlight and Notes sync

**These two are installed together.** Without them, saying "高亮:" in the chat only writes to `摘录.md` and nothing goes to Notes.

Once installed:

- Select text in another app and trigger the system service 「高亮到论文摘录」. The text is saved to `摘录.md` and also added to the 「论文摘录」 folder in Notes, which syncs to your phone through iCloud.
- Highlights made in the chat with "高亮:" are synced to Notes as well.

**Requirements**: macOS, and Notes signed in to an iCloud account. Say "帮我装上选中高亮" to your AI. It checks both conditions first, installs only if they are met, and then walks you through one trial. If they are not met, it tells you why, and chat highlights keep working.

**Limits, stated plainly**:

- **Works from the right-click menu** in apps that use the system context menu, such as Preview, Safari, Notes, and TextEdit. Select, right-click, Services, 高亮到论文摘录.
- **Not in the right-click menu** in apps that draw their own, such as the Claude desktop app, VS Code, and Cursor. There you select the text, then use the app-name menu in the menu bar and its Services submenu. Or set a keyboard shortcut and press it after selecting.
- **You set the shortcut yourself**: System Settings, Keyboard, Keyboard Shortcuts, Services, Text, 高亮到论文摘录. The AI will not change system settings for you.
- **The first run may ask for permission again.** The permission granted at install time belongs to the terminal, and the system service is a different program. If nothing shows up in Notes, turn on the matching switch under System Settings, Privacy & Security, Automation.
- **Some apps do not work.** A few apps do not pass selected text to system services. Go by what happens in the trial right after install.
- **One folder per computer.** The service points to the folder it was installed from. If you move the folder, reinstall.
- **Windows, Linux, and the web**: only the in-chat "高亮:" is available.

To uninstall, say "卸掉选中高亮". Existing excerpts and notes are not deleted.

## Want new papers every week? Set up your own scheduled task

This skill **does not find papers**. It only reads them. If you want new papers regularly, create a separate weekly scheduled task: **the task finds, the skill reads.**

In Claude Code you can ask the AI to create a scheduled task. With other tools, anything that runs a prompt on a schedule works. Here is a task description you can use as is. Replace the parts in 【】 with your own. A Chinese version is in [README.zh-CN.md](README.zh-CN.md).

```text
Run once every 【weekday and time】. Working folder: 【full path of the folder you always use】.

Goal: find up to 【3】 new papers or technical articles worth reading this week.

Topics I follow (one per line):
【topic one】
【topic two】

Where to look: 【for example certain arXiv categories, blogs, or conferences. If left blank, you decide, but tell me where you looked】

Selection rules:
1. Only items published in the last 【7】 days.
2. For each one give: title, link, publication date, and one sentence on which of my topics it relates to.
3. Every link must actually be opened and checked. If it does not open, or you are not sure the item exists, do not list it. Fewer is fine. Made up is not.
4. Read 认知地图.md in the working folder first. Do not recommend anything already read or already on the to-read list.

When done:
1. Append the selected items to the to-read list in 认知地图.md under the matching topic pack. In the 「牵出 / 入选理由」 column write "每周推送".
2. Send me the list.
3. Do not start a deep read on your own. Wait until I say "读一下第 N 篇", then use the paper-companion skill.

If the working folder has no 个人设定.md yet, I have not used paper-companion: do not send anything, and remind me to read one paper in a conversation first to complete first-time setup.
```

Two reminders:

- **Read one paper by hand before creating the scheduled task.** Nobody is there to answer questions when a scheduled task runs, and the skill needs to ask you four questions on first use.
- **The more specific the topics, the better the picks.** "AI" is too broad. "How to evaluate the quality of AI output" is much better.

## What is in this repo

| File | What it is |
| --- | --- |
| `SKILL.md` | All the rules. The only current version |
| `提问清单-默认.md` | The three default roles and generic questions. Your own `提问清单.md` is created from it on first use |
| `paper-short-template.html` | The template for shorts. Generating a short only edits one array of scenes inside it |
| `install-highlight.sh` | The installer for select-to-highlight, macOS only |
| `README.zh-CN.md` | This README in Chinese |

## License

MIT, see `LICENSE`.
