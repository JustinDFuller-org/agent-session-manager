---
layout: home
title: Agent Session Manager
description: A native macOS app for running multiple AI agent sessions in parallel.
---

<section class="home-grid">
  <div class="home-copy">
    <p class="eyebrow">Native macOS app for parallel AI agents</p>
    <h1>Agent Session Manager</h1>
    <p class="lede">Run multiple AI agent sessions in parallel in a tabbed, multi-pane terminal window, with each pane working in a git worktree context.</p>
    <div class="home-actions">
      <a class="button" href="{{ '/docs/' | relative_url }}">Browse documentation</a>
      <a class="button button-secondary" href="{{ '/documentation/user-guide/quickstart/' | relative_url }}">Start the quickstart</a>
      <a class="button button-secondary" href="https://github.com/{{ site.repository }}/releases">View releases</a>
    </div>
  </div>
  <img class="home-image" src="{{ '/assets/img/hero.png' | relative_url }}" alt="Agent Session Manager window showing tabs and terminal panes">
</section>

<section class="home-section">
  <p class="eyebrow">Start here</p>
  <h2>From download to your first session</h2>
  <ol>
    <li>Download the latest DMG from <a href="https://github.com/{{ site.repository }}/releases">GitHub Releases</a>, mount it, and drag the app to <code>/Applications</code>.</li>
    <li>Launch the app, then create a tab with <kbd>⌘T</kbd> and a pane with <kbd>⌘P</kbd>.</li>
    <li>Choose an agent tool and session name in the <strong>New Pane</strong> sheet.</li>
    <li>Use <strong>Settings</strong> to configure <strong>Harnesses</strong>, profiles, status information, and notifications.</li>
  </ol>
  <p>Each pane is a separate terminal session inside the tab, so you can work on multiple tasks at the same time.</p>
</section>

<section class="home-section">
  <p class="eyebrow">Supported tools</p>
  <h2>Use the agent tool that fits your workflow</h2>
  <p>Agent Session Manager supports Claude Code, Codex, Cursor, and OpenCode. Choose the tool for each pane when you create it, then customize its available options in <strong>Settings → Harnesses</strong>.</p>
  <p><a href="{{ '/docs/' | relative_url }}">Browse the user guides</a> for installation, first launch, core concepts, daily work, and tool configuration.</p>
</section>

<section class="home-section">
  <p class="eyebrow">At a glance</p>
  <h2>Core workflow</h2>
  <div class="shortcut-grid">
    <div class="shortcut"><kbd>⌘T</kbd><span>Create a tab</span></div>
    <div class="shortcut"><kbd>⌘P</kbd><span>Create a pane</span></div>
    <div class="shortcut"><kbd>⌘W</kbd><span>Close the active pane</span></div>
    <div class="shortcut"><kbd>⌘K</kbd><span>Close the active tab</span></div>
    <div class="shortcut"><kbd>⌘1–⌘9</kbd><span>Switch tabs</span></div>
  </div>
</section>

<section class="home-section">
  <p class="eyebrow">Explore</p>
  <h2>Documentation by task</h2>
  <div class="doc-catalog">
    {% for group in site.data.navigation limit: 6 %}
    <section class="catalog-group">
      <h3>{{ group.title }}</h3>
      <ul>
        {% for item in group.items limit: 4 %}
        <li><a href="{{ item.url | relative_url }}">{{ item.title }}</a></li>
        {% endfor %}
      </ul>
    </section>
    {% endfor %}
  </div>
</section>
