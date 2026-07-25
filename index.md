---
layout: home
title: Agent Session Manager
description: A native macOS app for managing and keeping track of many simultaneous AI agent sessions.
---

<section class="home-grid">
  <div class="home-copy">
    <p class="eyebrow">Manage many AI agent sessions at once</p>
    <h1>Agent Session Manager</h1>
    <p class="lede">Keep track of many simultaneous AI agent sessions in one native macOS app, with tabs and panes that keep projects and tasks organized.</p>
    <div class="home-actions">
      <a class="button" href="{{ '/download/' | relative_url }}">Download for macOS</a>
      <a class="button button-secondary" href="{{ '/docs/' | relative_url }}">See the user guides</a>
    </div>
  </div>
  <img class="home-image" src="{{ '/assets/img/docs/split-panes.png' | relative_url }}" alt="Agent Session Manager with two panes open in one tab">
</section>

<section class="home-section">
  <p class="eyebrow">Why use it</p>
  <h2>Keep every session in view</h2>
  <p>When several agents are working at once, Agent Session Manager keeps their sessions together in one window so you can see what is running, switch between tasks, and stay organized without managing separate terminal windows.</p>
  <h3>From download to your first session</h3>
  <ol>
    <li><a href="{{ '/download/' | relative_url }}">Download the latest DMG</a>, mount it, and drag the app to <code>/Applications</code>.</li>
    <li>Launch the app, then create a tab with <kbd>⌘T</kbd> and a pane with <kbd>⌘P</kbd>.</li>
    <li>Choose an agent tool and session name in the <strong>New Pane</strong> sheet.</li>
    <li>Use <strong>Settings</strong> to configure <strong>Harnesses</strong>, profiles, status information, and notifications.</li>
  </ol>
  <p>Each pane is a separate terminal session inside the tab, so you can keep multiple tasks visible and active at the same time.</p>
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
