# The hall's computer — one small Linux desktop for Bilskirnir's agents, one screen per agent.
#
# Built from Debian's own maintained packages rather than a ready-made desktop image, because Bot HQ's
# relay (server/src/vnc.ts) speaks plain RFB and its desk scripts (server/box/) want one X display per
# agent (:99, :100, …): TigerVNC's Xvnc gives exactly that, one process per screen, each with its own
# RFB port. KasmVNC images (webtop and friends) put one display behind their own web client and a
# modified protocol, which the relay cannot speak. See docs/the-desk.md.
#
# Nothing secret is in the image: the VNC password is mounted at run time (house/desk.sh).
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      tigervnc-standalone-server tigervnc-tools \
      xfwm4 xfce4-terminal xfconf dbus-x11 \
      chromium \
      python3 python3-gi python3-gi-cairo python3-cairo gir1.2-gtk-3.0 \
      wmctrl xdotool x11-utils x11-xserver-utils imagemagick \
      librsvg2-common fonts-inter fonts-dejavu-core \
      openssl procps ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY desk-screen.sh /usr/local/bin/desk-screen
RUN chmod 0755 /usr/local/bin/desk-screen

ENTRYPOINT ["/usr/local/bin/desk-screen", "init"]
