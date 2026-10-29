#!/usr/bin/env bash
# input.sh - touchpad, mouse and gestures.
#
# Gestures are deliberately native. GNOME on Wayland already implements the
# three-finger swipes (horizontal = spaces, up = overview) that people reach
# for on a Mac, and a native gesture beats a daemon translating synthetic key
# presses. On Xorg those gestures do not exist; Rea says so rather than
# installing a polling daemon behind your back.

rea_input_configure() {
  local t=org.gnome.desktop.peripherals.touchpad
  local m=org.gnome.desktop.peripherals.mouse
  local k=org.gnome.desktop.peripherals.keyboard

  if [[ "${REA_SYS_TOUCHPAD:-no}" == "yes" ]]; then
    rea_gset "$t" send-events "'enabled'"
    rea_gset "$t" natural-scroll "$([[ "${REA_NATURAL_SCROLL:-1}" == "1" ]] && echo true || echo false)"
    rea_gset "$t" tap-to-click true
    rea_gset "$t" tap-and-drag true
    rea_gset "$t" tap-and-drag-lock false
    rea_gset "$t" two-finger-scrolling-enabled true
    rea_gset "$t" edge-scrolling-enabled false
    rea_gset "$t" click-method "'fingers'"        # two-finger = secondary click
    rea_gset "$t" disable-while-typing true
    rea_gset "$t" speed 0.3                       # macOS tracking feels faster than GNOME's default
    rea_gset "$t" accel-profile "'default'"
    rea_ok "Touchpad: natural scrolling, tap to click, two-finger secondary click"
  else
    rea_skip "No touchpad detected"
  fi

  # The mouse is left on its own scroll direction on purpose: inverting an
  # external wheel surprises people far more than it pleases them.
  rea_gset "$m" accel-profile "'default'"
  rea_gset "$m" natural-scroll \
    "$([[ "${REA_NATURAL_SCROLL_MOUSE:-0}" == "1" ]] && echo true || echo false)"

  rea_gset "$k" repeat-interval "uint32 30"
  rea_gset "$k" delay "uint32 250"
}

rea_input_gestures() {
  if [[ "${REA_SYS_SESSION_TYPE:-}" == "wayland" ]]; then
    rea_ok "Gestures are native on Wayland: three fingers sideways = spaces, three up = overview"
    rea_gset org.gnome.desktop.peripherals.touchpad natural-scroll true
  else
    rea_warn "On Xorg, GNOME has no multi-finger workspace gestures"
    rea_info "Log in to 'Ubuntu on Wayland' from the login screen's gear menu to get them"
    rea_info "Rea will not install a gesture daemon: it would need a third-party repository"
  fi
}
