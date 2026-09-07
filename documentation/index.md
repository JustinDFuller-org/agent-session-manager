---
layout: doc-index
title: Documentation
description: User guides for installing, using, and configuring Agent Session Manager.
permalink: /docs/
---

# Documentation

Use these guides to learn Agent Session Manager, complete everyday tasks, consult exact supported-tool and shortcut information, and understand how tabs, panes, sessions, and Git worktrees fit together.

New to Agent Session Manager? Read the [Overview]({{ '/documentation/user-guide/overview/' | relative_url }}), complete [Install and First Launch]({{ '/documentation/user-guide/install/' | relative_url }}), and follow the [Quickstart]({{ '/documentation/user-guide/quickstart/' | relative_url }}). Then choose a how-to guide, reference page, or explanation for the need you have now.

<label for="doc-search">Search documentation</label> <input id="doc-search" class="catalog-search" type="search" placeholder="Filter by type or title" autocomplete="off">

<div id="doc-catalog" class="doc-catalog">
  {% for group in site.data.navigation %}
  <section class="catalog-group" data-search="{{ group.title | downcase }}">
    <h2>{{ group.title }}</h2>
    <ul>
      {% for item in group.items %}
      <li data-search="{{ item.title | downcase }}"><a href="{{ item.url | relative_url }}">{{ item.title }}</a></li>
      {% endfor %}
    </ul>
  </section>
  {% endfor %}
</div>

<script>
  const search = document.querySelector('#doc-search');
  const groups = [...document.querySelectorAll('#doc-catalog .catalog-group')];
  search.addEventListener('input', () => {
    const query = search.value.trim().toLowerCase();
    groups.forEach((group) => {
      const groupMatches = group.dataset.search.includes(query);
      let visibleItems = 0;
      group.querySelectorAll('li').forEach((item) => {
        const visible = !query || groupMatches || item.dataset.search.includes(query);
        item.hidden = !visible;
        if (visible) visibleItems += 1;
      });
      group.classList.toggle('is-hidden', visibleItems === 0);
    });
  });
</script>
