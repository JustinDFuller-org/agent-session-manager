#!/usr/bin/env bash

# Shared public distribution endpoints. Keep these values in one place so the
# packaged app, Sparkle feed, release workflow, and public documentation agree.
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://agent-session-manager.justindfuller.com}"
PUBLIC_APPCAST_URL="${PUBLIC_APPCAST_URL:-$PUBLIC_SITE_URL/appcast.xml}"
PUBLIC_DOWNLOADS_PATH="${PUBLIC_DOWNLOADS_PATH:-downloads}"
