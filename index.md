---
layout: home
title: Agent Session Manager
description: A native macOS app for running multiple AI agent sessions in parallel.
---

<section class="home-grid">
  <div class="home-copy">
    <p class="eyebrow">macOS documentation</p>
    <h1>Agent Session Manager</h1>
    <p class="lede">Run multiple AI agent sessions in parallel in a tabbed, multi-pane terminal window, with each pane working in a git worktree context.</p>
    <div class="home-actions">
      <a class="button" href="{{ '/docs/' | relative_url }}">Browse documentation</a>
      <a class="button button-secondary" href="https://github.com/{{ site.repository }}/releases">View releases</a>
    </div>
  </div>
  <img class="home-image" src="https://github.com/user-attachments/assets/fd19e0a4-b660-4913-ae49-a564250fa475" alt="Agent Session Manager window showing tabs and terminal panes">
</section>

<section class="home-section">
  <p class="eyebrow">Start here</p>
  <h2>From a repository to a running pane</h2>
  <ol>
    <li>Build and launch the app with <code>make run</code>.</li>
    <li>Create a tab with <kbd>⌘T</kbd>, then create a pane with <kbd>⌘⇧N</kbd>.</li>
    <li>Choose a harness and session/worktree name in the New Pane sheet.</li>
    <li>Use Settings to configure CLI options, profiles, status line items, and notifications.</li>
  </ol>
  <p>The app can attach to existing git worktree checkouts or create app-managed worktrees under <code>.agent-session-manager/worktrees/&lt;name&gt;</code>.</p>
</section>

<section class="home-section">
  <p class="eyebrow">At a glance</p>
  <h2>Core workflow</h2>
  <div class="shortcut-grid">
    <div class="shortcut"><kbd>⌘T</kbd><span>Create a tab</span></div>
    <div class="shortcut"><kbd>⌘⇧N</kbd><span>Create a pane</span></div>
    <div class="shortcut"><kbd>⌘W</kbd><span>Close the active pane</span></div>
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
