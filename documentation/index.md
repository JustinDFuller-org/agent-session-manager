---
layout: doc-index
title: Documentation
description: Guides for using, configuring, developing, and distributing Agent Session Manager.
permalink: /docs/
---

# Documentation

Use the guides below to learn the core tab and pane workflow, configure agent harnesses, diagnose sessions, or build and distribute the app.

<label for="doc-search">Filter documentation</label>
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
