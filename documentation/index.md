---
layout: doc-index
title: Documentation
description: User guides for installing, using, and configuring Agent Session Manager.
permalink: /docs/
---

# Documentation

Use these guides to install Agent Session Manager, start an agent session, organize daily work, configure supported tools, and recover from common problems.

New to Agent Session Manager? Start with **Getting Started**, then use the task groups below when you need a specific workflow or setting.

<label for="doc-search">Search user guides</label>
<input id="doc-search" class="catalog-search" type="search" placeholder="Filter by section or title" autocomplete="off">

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
